#include "test_framework.h"

static void mix(Vpostprocessing_stage* dut, VerilatedVcdC* tfp,
                int a, int b, int gain, int gain_a, int gain_b)
{
    dut->reset = 1;
    dut->tick = 0;
    for (int i = 0; i < 3; ++i) tick(dut, tfp);
    dut->reset = 0;
    dut->samples_in[0] = a; dut->samples_in[1] = b;
    dut->output_gain = gain;
    dut->output_gains[0] = gain_a; dut->output_gains[1] = gain_b;
    dut->tick = 1; tick(dut, tfp); dut->tick = 0;
    for (int i = 0; i < 20; ++i) tick(dut, tfp);
}

TEST(unity_gain_sums_both_pipelines)
{
    mix(dut, tfp, 1234, -234, 1024, 1024, 1024);
    EXPECT_S(16, dut->sample_out, 1000);
}
TEST(equal_opposite_samples_cancel)
{
    mix(dut, tfp, 12000, -12000, 1024, 1024, 1024);
    EXPECT_S(16, dut->sample_out, 0);
}
TEST(pipeline_and_master_gains_compose)
{
    mix(dut, tfp, 8000, 4000, 512, 512, 256);
    EXPECT_S(16, dut->sample_out, 2500);
}
TEST(positive_mix_saturates)
{
    mix(dut, tfp, 30000, 30000, 1024, 1024, 1024);
    EXPECT_S(16, dut->sample_out, 32767);
}
TEST(negative_mix_saturates)
{
    mix(dut, tfp, -30000, -30000, 1024, 1024, 1024);
    EXPECT_S(16, dut->sample_out, -32768);
}
