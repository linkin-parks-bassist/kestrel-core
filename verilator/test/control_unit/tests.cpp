#include "test_framework.h"
#include <initializer_list>

static void boot(Vcontrol_unit* dut, VerilatedVcdC* tfp)
{
    dut->in_valid = 0; dut->pipelines_swapping = 0;
    dut->pipeline_resetting = 0; dut->pipeline_regfiles_syncing = 0;
    dut->filter_ack = 0; dut->health = 1;
    dut->read32_valid = 0;
    for (int i = 0; i < 4; ++i) tick(dut, tfp);
    EXPECT_EQ(dut->current_pipeline, 0);
    EXPECT_EQ(dut->spi_byte_out & 1, 1); // initialized status flag
    EXPECT_EQ(dut->spi_byte_out & 8, 0); // programming status flag
}

static void byte(Vcontrol_unit* dut, VerilatedVcdC* tfp, int value)
{
    dut->in_byte = value; dut->in_valid = 1; tick(dut, tfp);
    dut->in_valid = 0; tick(dut, tfp);
}
static void command(Vcontrol_unit* dut, VerilatedVcdC* tfp,
                    int opcode, std::initializer_list<int> payload = {})
{
    byte(dut, tfp, opcode);
    for (int value : payload) byte(dut, tfp, value);
}
TEST(reset_reaches_initialized_idle)
{
    boot(dut, tfp);
    EXPECT_EQ(dut->health_monitor_enable, 0);
    EXPECT_U(2, dut->pipeline_enables, 0);
}
TEST(begin_program_sets_programming_flag)
{
    boot(dut, tfp); command(dut, tfp, 1);
    EXPECT_EQ(dut->spi_byte_out & 8, 8);
}
TEST(instruction_payload_and_back_pipeline_strobe)
{
    boot(dut, tfp); command(dut, tfp, 1);
    command(dut, tfp, 2, {0, 42, 0x12, 0x34, 0x56, 0x78});
    EXPECT_U(48, dut->ctrl_data_out, 0x002a12345678ULL);
    EXPECT_U(2, dut->block_instr_write, 2);
    tick(dut, tfp); EXPECT_U(2, dut->block_instr_write, 0);
}
TEST(register_write_without_programming_is_ignored)
{
    boot(dut, tfp); command(dut, tfp, 3, {0, 42, 0x12, 0x34});
    EXPECT_U(2, dut->block_reg_0_write, 0);
    EXPECT_U(2, dut->block_reg_1_write, 0);
}
TEST(register_writes_target_back_pipeline)
{
    boot(dut, tfp); command(dut, tfp, 1);
    command(dut, tfp, 3, {0, 42, 0x12, 0x34});
    EXPECT_U(48, dut->ctrl_data_out, 0x002a1234ULL);
    EXPECT_U(2, dut->block_reg_0_write, 2);
    command(dut, tfp, 4, {0, 43, 0xab, 0xcd});
    EXPECT_U(48, dut->ctrl_data_out, 0x002babcdULL);
    EXPECT_U(2, dut->block_reg_1_write, 2);
}
TEST(live_register_update_targets_front_pipeline)
{
    boot(dut, tfp); command(dut, tfp, 14, {0, 51, 0xab, 0xcd});
    EXPECT_U(48, dut->ctrl_data_out, 0x0033abcdULL);
    EXPECT_U(2, dut->block_reg_1_write, 1);
}
TEST(live_update_is_ignored_during_swap)
{
    boot(dut, tfp); dut->pipelines_swapping = 1;
    command(dut, tfp, 13, {0, 68, 0xde, 0xad});
    EXPECT_U(2, dut->block_reg_0_write, 0);
}
TEST(live_update_waits_for_register_sync)
{
    boot(dut, tfp); dut->pipeline_regfiles_syncing = 1;
    command(dut, tfp, 13, {0, 68, 0xde, 0xad});
    EXPECT_U(2, dut->block_reg_0_write, 0);
    for (int i = 0; i < 4; ++i) tick(dut, tfp);
    EXPECT_U(2, dut->block_reg_0_write, 0);
    dut->pipeline_regfiles_syncing = 0; tick(dut, tfp);
    EXPECT_U(2, dut->block_reg_0_write, 1);
    EXPECT_U(48, dut->ctrl_data_out, 0x0044deadULL);
}
TEST(commit_live_registers_pulses_front_pipeline)
{
    boot(dut, tfp); dut->in_byte = 15; dut->in_valid = 1; tick(dut, tfp);
    EXPECT_U(2, dut->reg_writes_commit, 1);
    dut->in_valid = 0; tick(dut, tfp); EXPECT_U(2, dut->reg_writes_commit, 0);
}
TEST(gain_commands_preserve_payload)
{
    boot(dut, tfp); command(dut, tfp, 11, {0x13, 0x57});
    EXPECT_U(48, dut->ctrl_data_out, 0x1357);
    EXPECT_EQ(dut->set_input_gain, 1); EXPECT_EQ(dut->set_output_gain, 0);
    command(dut, tfp, 12, {0x24, 0x68});
    EXPECT_U(48, dut->ctrl_data_out, 0x2468);
    EXPECT_EQ(dut->set_input_gain, 0); EXPECT_EQ(dut->set_output_gain, 1);
}
TEST(delay_allocation_preserves_six_byte_payload)
{
    boot(dut, tfp); command(dut, tfp, 1);
    command(dut, tfp, 5, {1, 2, 3, 4, 5, 6});
    EXPECT_U(48, dut->ctrl_data_out, 0x010203040506ULL);
    EXPECT_U(2, dut->alloc_delay, 2);
}
TEST(filter_allocation_preserves_three_byte_payload)
{
    boot(dut, tfp); command(dut, tfp, 1);
    command(dut, tfp, 16, {0x7e, 5, 3});
    EXPECT_U(48, dut->ctrl_data_out, 0x7e0503);
    EXPECT_U(2, dut->alloc_filter, 2);
}
TEST(filter_coefficient_write_and_commit_are_separate_commands)
{
    boot(dut, tfp); command(dut, tfp, 1);
    command(dut, tfp, 17, {0x22, 1, 0x23, 2, 0x45, 0x67});
    EXPECT_U(48, dut->ctrl_data_out, 0x220123024567ULL);
    EXPECT_U(2, dut->filter_coef_write, 2);
    EXPECT_U(2, dut->filter_coef_commit, 0);
    command(dut, tfp, 19, {0x22});
    EXPECT_U(48, dut->ctrl_data_out, 0x22);
    EXPECT_U(2, dut->filter_coef_commit, 1);
}
TEST(idle_ff_byte_is_drained_without_command_error)
{
    boot(dut, tfp); byte(dut, tfp, 255);
    EXPECT_EQ(dut->spi_byte_out & 64, 0);
    EXPECT_EQ(dut->spi_byte_out & 8, 0);
}

TEST(read32_dispatches_full_address_and_waits_for_external_reply)
{
    boot(dut, tfp);
    command(dut, tfp, 40, {0xab, 0xcd, 0xfc});
    EXPECT_EQ(dut->read32_addr, 0xabcdfc);
    EXPECT_EQ(dut->read32_req, 1);
    EXPECT_EQ(dut->pipeline_data_req, 0);
    EXPECT_EQ(dut->spi_byte_out & 32, 0);
    tick(dut, tfp); EXPECT_EQ(dut->read32_req, 0);
    for (int i = 0; i < 8; ++i) tick(dut, tfp);
    EXPECT_EQ(dut->spi_byte_out & 32, 0);
    dut->read32_data = 0x89abcdef;
    dut->read32_valid = 1; tick(dut, tfp); dut->read32_valid = 0;
    EXPECT_EQ(dut->spi_byte_out & 32, 32);
    command(dut, tfp, 20); EXPECT_EQ(dut->spi_byte_out, 0x89);
    command(dut, tfp, 20); EXPECT_EQ(dut->spi_byte_out, 0xab);
    command(dut, tfp, 20); EXPECT_EQ(dut->spi_byte_out, 0xcd);
    command(dut, tfp, 20); EXPECT_EQ(dut->spi_byte_out, 0xef);
    command(dut, tfp, 37); EXPECT_EQ(dut->spi_byte_out & 32, 0);
}