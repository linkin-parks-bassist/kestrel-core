#include "test_framework.h"

#include <cstdint>
#include <initializer_list>

static constexpr uint8_t COMMAND_BEGIN_PROGRAM        = 1;
static constexpr uint8_t COMMAND_WRITE_BLOCK_INSTR    = 2;
static constexpr uint8_t COMMAND_WRITE_BLOCK_REG_0    = 3;
static constexpr uint8_t COMMAND_WRITE_BLOCK_REG_1    = 4;
static constexpr uint8_t COMMAND_ALLOC_DELAY          = 5;
static constexpr uint8_t COMMAND_END_PROGRAM          = 10;
static constexpr uint8_t COMMAND_SET_INPUT_GAIN       = 11;
static constexpr uint8_t COMMAND_SET_OUTPUT_GAIN      = 12;
static constexpr uint8_t COMMAND_UPDATE_BLOCK_REG_0   = 13;
static constexpr uint8_t COMMAND_UPDATE_BLOCK_REG_1   = 14;
static constexpr uint8_t COMMAND_COMMIT_REG_UPDATES   = 15;
static constexpr uint8_t COMMAND_ALLOC_FILTER         = 16;
static constexpr uint8_t COMMAND_WRITE_FILTER_COEF    = 17;
static constexpr uint8_t COMMAND_UPDATE_FILTER_COEF   = 18;
static constexpr uint8_t COMMAND_COMMIT_FILTER_COEF   = 19;

static constexpr uint8_t SPI_RESPONSE_OK           = 0;
static constexpr uint8_t SPI_RESPONSE_INITIALISING = 1;
static constexpr uint8_t SPI_RESPONSE_PROGRAMMING  = 2;
static constexpr uint8_t SPI_RESPONSE_REJECTED     = 3;
static constexpr uint8_t SPI_RESPONSE_TIMEOUT      = 4;

static void clear_inputs(Vcontrol_unit* dut)
{
    dut->in_byte = 0;
    dut->in_valid = 0;

    dut->pipeline_regfiles_syncing = 0;
    dut->pipeline_resetting = 0;
    dut->filter_ack = 0;
    dut->pipelines_swapping = 0;
    dut->health = 1;
}

static void idle(Vcontrol_unit* dut, VerilatedVcdC* tfp, int n = 1)
{
    for (int i = 0; i < n; ++i) {
        dut->in_valid = 0;
        tick(dut, tfp);
    }
}

static void boot_to_ready(Vcontrol_unit* dut, VerilatedVcdC* tfp)
{
    clear_inputs(dut);

    // main() leaves us just after reset deassertion + settle().
    // The DUT still needs a couple of clocks to get through INITIAL_RESET_WAIT.
    for (int i = 0; i < 4; ++i)
        tick(dut, tfp);

    EXPECT_EQ(dut->current_pipeline, 0);
    EXPECT_U(8, dut->spi_byte_out, SPI_RESPONSE_OK);
    EXPECT_EQ(dut->health_monitor_enable, 0);
}

static void send_byte(Vcontrol_unit* dut, VerilatedVcdC* tfp, uint8_t byte)
{
    dut->in_byte = byte;
    dut->in_valid = 1;
    tick(dut, tfp);

    dut->in_valid = 0;
    tick(dut, tfp);
}

static void send_command(Vcontrol_unit* dut,
                         VerilatedVcdC* tfp,
                         uint8_t command,
                         std::initializer_list<uint8_t> payload = {})
{
    send_byte(dut, tfp, command);

    for (uint8_t b : payload)
        send_byte(dut, tfp, b);
}

TEST(initial_reset_reaches_ready_and_enables_front_pipeline)
{
    boot_to_ready(dut, tfp);

    EXPECT_EQ(dut->current_pipeline, 0);
    EXPECT_U(8, dut->spi_byte_out, SPI_RESPONSE_OK);
    EXPECT_U(2, dut->pipeline_enables, 0);
    EXPECT_U(2, dut->pipeline_full_reset, 0);
}

TEST(begin_program_enters_programming_mode)
{
    boot_to_ready(dut, tfp);

    dut->in_byte = COMMAND_BEGIN_PROGRAM;
    dut->in_valid = 1;
    tick(dut, tfp);

    EXPECT_U(8, dut->spi_byte_out, SPI_RESPONSE_PROGRAMMING);
    EXPECT_EQ((dut->control_state >> 1) & 1, 1);

    dut->in_valid = 0;
    tick(dut, tfp);

    EXPECT_EQ((dut->control_state >> 1) & 1, 1);
}

TEST(write_block_reg_ignored_when_not_programming)
{
    boot_to_ready(dut, tfp);

    send_command(dut, tfp, COMMAND_WRITE_BLOCK_REG_0, {
        0x2a,       // block
        0x12, 0x34  // data
    });

    EXPECT_U(2, dut->block_reg_write, 0);
    EXPECT_EQ(dut->reg_target, 0);
}

TEST(write_block_reg_0_writes_back_pipeline_during_programming)
{
    boot_to_ready(dut, tfp);

    send_command(dut, tfp, COMMAND_BEGIN_PROGRAM);

    send_command(dut, tfp, COMMAND_WRITE_BLOCK_REG_0, {
        0x2a,       // block
        0x12, 0x34  // data
    });

    EXPECT_U(8, dut->block_target, 0x2a);
    EXPECT_EQ(dut->reg_target, 0);
    EXPECT_U(16, dut->data_out, 0x1234);
    EXPECT_U(2, dut->block_reg_write, 0b10);
}

TEST(update_block_reg_1_writes_front_pipeline_when_allowed)
{
    boot_to_ready(dut, tfp);

    send_command(dut, tfp, COMMAND_UPDATE_BLOCK_REG_1, {
        0x33,       // block
        0xab, 0xcd  // data
    });

    EXPECT_U(8, dut->block_target, 0x33);
    EXPECT_EQ(dut->reg_target, 1);
    EXPECT_U(16, dut->data_out, 0xabcd);
    EXPECT_U(2, dut->block_reg_write, 0b01);
}

TEST(update_block_reg_is_dropped_while_swapping)
{
    boot_to_ready(dut, tfp);

    dut->pipelines_swapping = 1;

    send_command(dut, tfp, COMMAND_UPDATE_BLOCK_REG_0, {
        0x44,
        0xde, 0xad
    });

    EXPECT_U(2, dut->block_reg_write, 0);
}

TEST(commit_reg_updates_pulses_front_pipeline)
{
    boot_to_ready(dut, tfp);

    dut->in_byte = COMMAND_COMMIT_REG_UPDATES;
    dut->in_valid = 1;
    tick(dut, tfp);

    EXPECT_U(2, dut->reg_writes_commit, 0b01);

    dut->in_valid = 0;
    tick(dut, tfp);

    EXPECT_U(2, dut->reg_writes_commit, 0);
}

TEST(set_input_and_output_gain_emit_expected_values)
{
    boot_to_ready(dut, tfp);

    send_command(dut, tfp, COMMAND_SET_INPUT_GAIN, {
        0x13, 0x57
    });

    EXPECT_U(16, dut->data_out, 0x1357);
    EXPECT_EQ(dut->set_input_gain, 1);
    EXPECT_EQ(dut->set_output_gain, 0);

    idle(dut, tfp);

    send_command(dut, tfp, COMMAND_SET_OUTPUT_GAIN, {
        0x24, 0x68
    });

    EXPECT_U(16, dut->data_out, 0x2468);
    EXPECT_EQ(dut->set_input_gain, 0);
    EXPECT_EQ(dut->set_output_gain, 1);
}

TEST(alloc_delay_writes_back_pipeline_payload_correctly)
{
    boot_to_ready(dut, tfp);

    send_command(dut, tfp, COMMAND_BEGIN_PROGRAM);

    // Payload order is byte_5 ... byte_0.
    send_command(dut, tfp, COMMAND_ALLOC_DELAY, {
        0x01, 0x02, 0x03,   // delay size
        0x04, 0x05, 0x06    // initial delay
    });

    EXPECT_U(32, dut->delay_size_out, 0x00010203ULL);
    EXPECT_U(32, dut->init_delay_out, 0x00040506ULL);
    EXPECT_U(2, dut->alloc_delay, 0b10);
}

TEST(alloc_filter_writes_back_pipeline_payload_correctly)
{
    boot_to_ready(dut, tfp);

    send_command(dut, tfp, COMMAND_BEGIN_PROGRAM);

    send_command(dut, tfp, COMMAND_ALLOC_FILTER, {
        0x7e,       // format
        0x00, 0x05, // ff order
        0x00, 0x03  // fb order
    });

    EXPECT_U(8,  dut->filter_alloc_format, 0x7e);
    EXPECT_U(16, dut->filter_order_ff_out, 0x0005);
    EXPECT_U(16, dut->filter_order_fb_out, 0x0003);
    EXPECT_U(2,  dut->alloc_filter, 0b10);
}

TEST(write_filter_coef_waits_for_ack_then_completes)
{
    boot_to_ready(dut, tfp);

    send_command(dut, tfp, COMMAND_BEGIN_PROGRAM);

    dut->filter_ack = 0;

    send_command(dut, tfp, COMMAND_WRITE_FILTER_COEF, {
        0x22,             // handle
        0x01, 0x23,       // target
        0x02, 0x45, 0x67  // 18-bit coef => {byte_2[1:0], byte_1, byte_0}
    });

    EXPECT_U(16, dut->filter_coef_write_handle_out, 0x22);
    EXPECT_U(16, dut->filter_coef_target_out, 0x0123);
    EXPECT_U(18, dut->filter_coef_data_out, 0x24567);
    EXPECT_U(2, dut->filter_coef_write, 0b10);
    EXPECT_U(2, dut->filter_coef_commit, 0b10);

    dut->filter_ack = 0b10;
    tick(dut, tfp);

    EXPECT_U(2, dut->filter_coef_write, 0);
    EXPECT_U(2, dut->filter_coef_commit, 0);

    dut->filter_ack = 0;
    tick(dut, tfp);
}
