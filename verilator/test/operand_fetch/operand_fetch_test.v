`include "defs.vh"
`include "core.vh"
`include "instr_dec.vh"
module operand_fetch_test #(parameter integer data_width = 16, parameter n_blocks = 256, parameter n_channels = 16)
	(
		input  wire clk,
		input  wire reset,

		input  wire enable,

		input  wire sample_tick,

		input  wire in_valid,
		output wire in_ready,

		output wire out_valid,
		input  wire out_ready,

		input  wire [$clog2(n_blocks) : 0] n_blocks_running,

		input  wire [$clog2(n_blocks) - 1 : 0] block_in,
		output wire [$clog2(n_blocks) - 1 : 0] block_out,

		input  wire signed [data_width - 1 : 0] register_0_in,
		output wire signed [data_width - 1 : 0] register_0_out,
		input  wire signed [data_width - 1 : 0] register_1_in,
		output wire signed [data_width - 1 : 0] register_1_out,

		input  wire [4 : 0] operation_in,
		output wire [4 : 0] operation_out,

		input  wire [$clog2(`N_MISC_OPS) - 1 : 0] misc_op_in,
		output wire [$clog2(`N_MISC_OPS) - 1 : 0] misc_op_out,

		input  wire [ch_addr_w - 1 : 0] dest_in,
		output wire [ch_addr_w - 1 : 0] dest_out,

		input  wire signed [ch_addr_w - 1 : 0] src_a_in,
		input  wire signed [ch_addr_w - 1 : 0] src_b_in,
		input  wire signed [ch_addr_w - 1 : 0] src_c_in,

		input  wire src_a_reg_in,
		input  wire src_b_reg_in,
		input  wire src_c_reg_in,

		input  wire arg_a_needed_in,
		input  wire arg_b_needed_in,
		input  wire arg_c_needed_in,

		output wire signed [data_width - 1 : 0] arg_a_out,
		output wire signed [data_width - 1 : 0] arg_b_out,
		output wire signed [data_width - 1 : 0] arg_c_out,

		input  wire saturate_disable_in,
		output wire saturate_disable_out,

		input  wire signedness_in,
		output wire signedness_out,

		input  wire accumulator_needed_in,
		output wire accumulator_needed_out,

		input  wire [4 : 0] shift_in,
		output wire [4 : 0] shift_out,
		input  wire shift_disable_in,
		output wire shift_disable_out,

		input  wire [7 : 0] res_addr_in,
		output wire [7 : 0] res_addr_out,

		input  wire writes_external_in,
		output wire writes_external_out,

		input  wire writes_channel_in,
		output wire writes_channel_out,
		input  wire writes_accumulator_in,

		output wire [`COMMIT_ID_WIDTH - 1 : 0] commit_id_out,

		input  wire commit_flag_in,
		output wire commit_flag_out,

		input  wire [$clog2(`N_INSTR_BRANCHES) - 1 : 0] branch_in,
		output wire [$clog2(`N_INSTR_BRANCHES) - 1 : 0] branch_out,

		input  wire [ch_addr_w - 1 : 0] channel_write_addr,
		input  wire signed [data_width - 1 : 0] channel_write_val,
		input  wire channel_write_enable,

		input  wire signed [data_width - 1 : 0] channel_read_val,

		input  wire accumulator_write_enable,

		input  wire [3:0] flags_in,
		output wire [3:0] flags_out,

		output wire [2:0] stage_busy,
        output wire [2:0] stage_valid,
        output wire [23:0] stage_blocks,
        output wire stuck
	);

    localparam ch_addr_w = $clog2(n_channels);
    operand_fetch_stage #(.data_width(data_width), .n_blocks(n_blocks), .n_channels(n_channels)) dut (.*);
    assign stage_busy = {dut.fetch_3.busy, dut.fetch_2.busy, dut.fetch_1.busy};
    assign stage_valid = {dut.out_valid_3, dut.out_valid_2, dut.out_valid_1};
    assign stage_blocks = {dut.block_3_out, dut.block_2_out, dut.block_1_out};
endmodule
