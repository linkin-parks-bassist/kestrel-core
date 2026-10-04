`include "defs.vh"
`include "controller.vh"
import types_pkg::*;
module core_test #(
		parameter integer data_width = 16,
		parameter integer acc_width			= 2 * data_width + 8,
		parameter integer n_blocks			= 256,
		parameter integer sdram_addr_width 	= 20,
		parameter integer memory_size		= 8,
		parameter integer n_channels		= 16
	) (
		input wire clk,
		input wire reset,

		input wire enable,
		input wire tick,
        input wire use_internal_filter,

		input wire signed [data_width - 1 : 0] sample_in,
		output reg signed [data_width - 1 : 0] sample_out,

		output reg ready,

        input wire [`CTRL_DATA_BUS_WIDTH - 1 : 0] ctrl_data_in,

		input wire command_reg_0_write,
		input wire command_reg_1_write,
		input wire command_instr_write,
		input wire reg_writes_commit,
		input wire data_req,

		input wire full_reset,

		output rw_req_t delay_req,
		input  wire delay_req_ack,
		output wire delay_req_valid,
		input  wire delay_req_invalid,
		input  wire delay_req_response_valid,
		input  wire [data_width - 1 : 0] delay_req_response,

		output filter_rw_req_t filter_req,
		input  wire filter_req_ack,
		output wire filter_req_valid,
		output wire filter_req_invalid,
		input  wire filter_req_response_valid,
		input  wire [data_width - 1 : 0] filter_req_response,

		output rw_req_t lut_req,
		input  wire lut_req_ack,
		output wire lut_req_valid,
		input  wire lut_req_invalid,
		input  wire lut_req_response_valid,
		input  wire [data_width - 1 : 0] lut_req_response,

		output wire regfile_syncing,

		output reg resetting,

		output reg [31:0] data_return,
		output reg data_return_valid,

		output wire [47:0] debug_args,
        output wire debug_fetch,
        output wire [7:0] debug_block,
        output wire [2:0] fetch_busy,
        output wire [2:0] fetch_occupied,
        output wire [8:0] active_blocks,
        output wire write_channel,
        output wire [3:0] write_dest,
        output wire [15:0] write_value,
        output wire write_accumulator,
        output wire [6:0] retire,
        output wire [5:0] next_commit,
        output wire debug_svf_accept,
        output wire [15:0] debug_svf_audio, debug_svf_cutoff, debug_svf_damping,
        output wire [4:0] debug_svf_shift,
        output wire [7:0] debug_svf_block,
        output wire debug_filter_invalid,
        output wire [15:0] stuck_flags
	);

    wire internal_filter_ack, internal_filter_response_valid;
    wire [15:0] internal_filter_response;
    filter_master filters (
        .clk(clk), .reset(reset), .enable(enable && use_internal_filter),
        .alloc_req(1'b0), .coef_write(1'b0), .coef_update(1'b0), .coef_commit(1'b0),
        .coef_write_handle(8'b0), .coef_target(16'b0), .coef_data(18'b0),
        .req_ack(internal_filter_ack), .req_valid(filter_req_valid && use_internal_filter),
        .req_in(filter_req), .req_invalid(debug_filter_invalid),
        .req_response(internal_filter_response), .req_response_valid(internal_filter_response_valid),
        .ctrl_data_in(ctrl_data_in), .stuck()
    );
    assign debug_svf_accept = filters.svf_req_valid;
    assign debug_svf_audio = filters.svf_req_in.arg_a;
    assign debug_svf_cutoff = filters.svf_req_in.arg_b;
    assign debug_svf_damping = filters.svf_req_in.arg_c;
    assign debug_svf_shift = filters.svf_req_in.shift;
    assign debug_svf_block = filters.svf_req_in.block;
    dsp_core #(.data_width(data_width), .n_blocks(n_blocks), .memory_size(memory_size), .n_channels(n_channels)) dut (
        .filter_req_ack(use_internal_filter ? internal_filter_ack : filter_req_ack),
        .filter_req_response_valid(use_internal_filter ? internal_filter_response_valid : filter_req_response_valid),
        .filter_req_response(use_internal_filter ? internal_filter_response : filter_req_response), .*
    );
    assign debug_args = {dut.arg_c_out_ofs, dut.arg_b_out_ofs, dut.arg_a_out_ofs};
    assign debug_fetch = dut.out_valid_ofs & dut.in_ready_router;
    assign debug_block = dut.block_out_ofs;
    assign fetch_busy = {dut.operand_fetch_stage.fetch_3.busy, dut.operand_fetch_stage.fetch_2.busy, dut.operand_fetch_stage.fetch_1.busy};
    assign fetch_occupied = fetch_busy | {dut.operand_fetch_stage.out_valid_3, dut.operand_fetch_stage.out_valid_2, dut.operand_fetch_stage.out_valid_1};
    assign active_blocks = dut.n_blocks_running;
    assign write_channel = dut.channel_write_enable;
    assign write_dest = dut.channel_write_addr;
    assign write_value = dut.channel_write_val;
    assign write_accumulator = dut.accumulator_write_enable;
    assign retire = dut.in_ready_commit_master;
    assign next_commit = dut.commit_master.next_commit_id;
endmodule
