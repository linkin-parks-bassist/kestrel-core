`include "instr_dec.vh"
`include "filter.vh"
`include "defs.vh"
`include "lut.vh"
`include "core.vh"

import types_pkg::*;

`default_nettype none

module resource_branch #(parameter integer data_width, parameter handle_width = 8, parameter n_blocks = 256, parameter acc_width = 2 * data_width + 8, parameter n_channels = 16) (
		input wire clk,
		input wire reset,
		
		input wire enable,
		
		input  wire in_valid,
		output wire in_ready,
		
		output wire out_valid,
		input  wire out_ready,
		
		input wire [$clog2(n_blocks) - 1 : 0] block_in,
		output reg [$clog2(n_blocks) - 1 : 0] block_out,
		
		output reg [data_width - 1 : 0] req_id_out,
		
		input wire write,
		
		input wire [handle_width - 1 : 0] handle_in,
		input wire signed [data_width   - 1 : 0] arg_a_in,
		input wire signed [data_width   - 1 : 0] arg_b_in,
		
		output wire read_req,
		output wire write_req,
		
		output reg 		[handle_width - 1 : 0] handle_out,
		output reg signed [data_width - 1 : 0] arg_a_out,
		output reg signed [data_width - 1 : 0] arg_b_out,
		input wire signed [data_width - 1 : 0] data_in,
		
		input wire read_valid,
		input wire write_ack,
		
		input wire [ch_addr_w - 1 : 0] dest_in,
		output reg [ch_addr_w - 1 : 0] dest_out,
		
		output reg signed [data_width - 1 : 0] result_out,
		
		input wire [`COMMIT_ID_WIDTH - 1 : 0] commit_id_in,
		output reg [`COMMIT_ID_WIDTH - 1 : 0] commit_id_out,
		
		input wire [3:0] flags_in,
		output reg [3:0] flags_out
	);
	
	localparam ch_addr_w = $clog2(n_channels);
	
	localparam IDLE = 2'd0;
	localparam REQ  = 2'd1;
	localparam DONE = 2'd2;
	
	assign in_ready  = (state == IDLE);
	assign out_valid = (state == DONE);
	
	assign read_req  = (state == REQ) & ~write_latched;
	assign write_req = (state == REQ) &  write_latched;
	
	reg [$clog2(n_blocks) - 1 : 0] block_latched;
	reg [`COMMIT_ID_WIDTH - 1 : 0] commit_id_latched;
	reg [ch_addr_w - 1 : 0] dest_latched;
	reg write_latched;
	reg [1:0] state;
	
	reg [3:0] flags_latched;
	
	always @(posedge clk) begin
		if (reset) begin
			state <= IDLE;
			commit_id_out <= 0;
			write_latched <= 0;
			
			block_latched <= 0;
			commit_id_latched <= 0;
			dest_latched <= 0;
		end else if (enable) begin
			
			case (state)
				IDLE: begin
					if (in_valid && in_ready) begin
						handle_out <= handle_in;
						
						arg_a_out <= arg_a_in;
						arg_b_out <= arg_b_in;
						
						dest_latched <= dest_in;
						
						write_latched <= write;
						
						commit_id_latched <= commit_id_in;
						block_latched <= block_in;
						
						req_id_out <= block_in;
						flags_out <= flags_in;
						
						state <= REQ;
					end
				end
				
				REQ: begin
					if (write_latched && write_ack) begin
						state <= IDLE;
					end else if (!write_latched && read_valid) begin
						result_out <= data_in;
						
						commit_id_out <= commit_id_latched;
						block_out <= block_latched;
						dest_out <= dest_latched;
						
						state <= DONE;
					end
				end
				
				DONE: begin
					if (out_ready) begin
						state <= IDLE;
					end
				end
			endcase
		end
	end
endmodule

module resource_branch_pulsed #(parameter integer data_width, parameter handle_width = 8, parameter n_blocks = 256, parameter acc_width = 2 * data_width + 8, parameter n_channels = 16) (
		input wire clk,
		input wire reset,
		
		input wire enable,
		
		input  wire in_valid,
		output wire in_ready,
		
		output wire out_valid,
		input  wire out_ready,
		
		input wire [$clog2(n_blocks) - 1 : 0] block_in,
		output reg [$clog2(n_blocks) - 1 : 0] block_out,
		
		output reg [data_width - 1 : 0] req_id_out,
		
		input wire write,
		
		input wire [handle_width - 1 : 0] handle_in,
		input wire signed [data_width - 1 : 0] arg_a_in,
		input wire signed [data_width - 1 : 0] arg_b_in,
		
		output reg read_req,
		output reg write_req,
		
		output reg 		[handle_width - 1 : 0] handle_out,
		output reg signed [data_width - 1 : 0] arg_a_out,
		output reg signed [data_width - 1 : 0] arg_b_out,
		
		input wire signed [data_width - 1 : 0] data_in,
		
		input wire read_valid,
		input wire write_ack,
		
		input wire [ch_addr_w - 1 : 0] dest_in,
		output reg [ch_addr_w - 1 : 0] dest_out,
		
		output reg signed [data_width - 1 : 0] result_out,
		
		input wire [`COMMIT_ID_WIDTH - 1 : 0] commit_id_in,
		output reg [`COMMIT_ID_WIDTH - 1 : 0] commit_id_out,
		
		input wire [3:0] flags_in,
		output reg [3:0] flags_out
	);
	
	localparam ch_addr_w = $clog2(n_channels);
	
	localparam IDLE = 2'd0;
	localparam REQ  = 2'd1;
	localparam DONE = 2'd2;
	
	assign in_ready  = (state == IDLE);
	assign out_valid = (state == DONE);
	
	reg [$clog2(n_blocks) - 1 : 0] block_latched;
	reg [`COMMIT_ID_WIDTH - 1 : 0] commit_id_latched;
	reg [ch_addr_w - 1 : 0] dest_latched;
	reg write_latched;
	reg [1:0] state;
	
	reg [3:0] flags_latched;
	
	always @(posedge clk) begin
		read_req <= 0;
		write_req <= 0;
		
		if (reset) begin
			state <= IDLE;
			
			commit_id_out	<= 0;
			read_req 		<= 0;
			write_req 		<= 0;
			write_latched 	<= 0;
			
			block_latched 		<= 0;
			commit_id_latched 	<= 0;
			dest_latched 		<= 0;
		end else if (enable) begin
			case (state)
				IDLE: begin
					if (in_valid && in_ready) begin
						handle_out <= handle_in;
						
						arg_a_out <= arg_a_in;
						arg_b_out <= arg_b_in;
						
						dest_latched <= dest_in;
						
						write_latched <= write;
						
						commit_id_latched 	<= commit_id_in;
						block_latched 		<= block_in;
						
						req_id_out 	<= block_in;
						flags_out 	<= flags_in;
						
						state <= REQ;
						
						if (write)
							write_req <= 1;
						else
							read_req <= 1;
					end
				end
				
				REQ: begin
					if (write_latched && write_ack) begin
						state <= IDLE;
					end else if (!write_latched && read_valid) begin
						result_out <= data_in;
						
						commit_id_out <= commit_id_latched;
						block_out <= block_latched;
						dest_out <= dest_latched;
						
						state <= DONE;
					end
				end
				
				DONE: begin
					if (out_ready) begin
						state <= IDLE;
					end
				end
			endcase
		end
	end
endmodule

module rsp_req_str
	(
		input wire clk,
		input wire reset,
		
		input wire enable,
		
		input  wire in_valid,
		output wire in_ready,
		
		output wire out_valid,
		input  wire out_ready,
		
		input wire [`BLOCK_ADDR_W - 1 : 0] block_addr_in,
		output reg [`BLOCK_ADDR_W - 1 : 0] block_addr_out,
		
		input wire write,
		input wire [7 : 0] handle_in,
		
		input wire [data_width - 1 : 0] arg_a_in,
		input wire [data_width - 1 : 0] arg_b_in,
		
		output reg req_valid,
		output rw_req_t req_out,
		
		input wire req_ack,
		input wire req_response_valid,
		input wire [data_width - 1 : 0] req_response_in,
		
		input wire [3 : 0] dest_in,
		output reg [3 : 0] dest_out,
		
		output reg [data_width - 1 : 0] result_out,
		
		input wire [`COMMIT_ID_WIDTH - 1 : 0] commit_id_in,
		output reg [`COMMIT_ID_WIDTH - 1 : 0] commit_id_out,
		
		input wire [3:0] flags_in
	);
	
	
	assign in_ready  = (state == IDLE);
	assign out_valid = (state == DONE);
	
	reg [`BLOCK_ADDR_W - 1 : 0]   block_latched;
	reg [`COMMIT_ID_WIDTH - 1 : 0]    commit_id_latched;
	reg [3 : 0] dest_latched;
	
	reg write_latched;
	
	reg [3:0] flags_latched;
	
	localparam IDLE = 2'd0;
	localparam REQ  = 2'd1;
	localparam DONE = 2'd2;
	
	reg [1:0] state;
	always @(posedge clk) begin
		
		req_valid <= 0;
		
		if (reset) begin
			state <= IDLE;
		end else if (enable) begin
			case (state)
				IDLE: begin
					if (in_valid && in_ready) begin
					
						req_out.handle <= handle_in;
						req_out.arg_a  <= arg_a_in;
						req_out.arg_b  <= arg_b_in;
						req_out.block  <= block_addr_in;
						req_out.flags  <= flags_in;
						
						req_valid <= 1;
						
						dest_latched <= dest_in;
						write_latched <= write;
						
						commit_id_latched 	<= commit_id_in;
						block_latched 		<= block_addr_in;
						
						state <= REQ;
					end
				end
				
				REQ: begin
					if (write_latched) begin 
						if (req_ack) state <= IDLE;
					end else if (req_response_valid) begin
					
						result_out <= req_response_in;
						
						commit_id_out  	<= commit_id_latched;
						block_addr_out 	<= block_latched;
						dest_out 		<= dest_latched;
						
						state <= DONE;
					end
				end
				
				DONE: begin
					if (out_ready) begin
						state <= IDLE;
					end
				end
			endcase
		end
	end
endmodule

module rsp_req_str_filter
	(
		input wire clk,
		input wire reset,
		
		input wire enable,
		
		input  wire in_valid,
		output wire in_ready,
		
		output wire out_valid,
		input  wire out_ready,
		
		input wire [`BLOCK_ADDR_W - 1 : 0] block_addr_in,
		output reg [`BLOCK_ADDR_W - 1 : 0] block_addr_out,
		
		input wire write,
		input wire [7 : 0] handle_in,
		
		input wire        [data_width - 1 : 0] arg_a_in,
		input wire        [data_width - 1 : 0] arg_b_in,
		input wire        [data_width - 1 : 0] arg_c_in,
		input wire [3:0] shift_in,
		
		output reg req_valid,
		output filter_rw_req_t req_out,
		
		input wire req_ack,
		input wire req_response_valid,
		input wire [data_width - 1 : 0] req_response_in,
		
		input wire [3 : 0] dest_in,
		output reg [3 : 0] dest_out,
		
		output reg [data_width - 1 : 0] result_out,
		
		input wire [`COMMIT_ID_WIDTH - 1 : 0] commit_id_in,
		output reg [`COMMIT_ID_WIDTH - 1 : 0] commit_id_out,
		
		input wire [3:0] flags_in
	);
	
	
	assign in_ready  = (state == IDLE);
	assign out_valid = (state == DONE);
	
	reg [`BLOCK_ADDR_W    - 1 : 0]   block_latched;
	reg [`COMMIT_ID_WIDTH - 1 : 0] commit_id_latched;
	reg [3 : 0] dest_latched;
	
	reg write_latched;
	
	reg [3:0] flags_latched;
	
	localparam IDLE 	= 2'd0;
	localparam REQ  	= 2'd1;
	localparam DONE 	= 2'd2;
	localparam SVF_WAIT = 2'd3;
	
	reg [1:0] state;
	always @(posedge clk) begin
		
		req_valid <= 0;
		
		if (reset) begin
			state <= IDLE;
		end else if (enable) begin
			case (state)
				IDLE: begin
					if (in_valid && in_ready) begin
					
						req_out.handle <= handle_in;
						req_out.arg_a  <= arg_a_in;
						req_out.arg_b  <= arg_b_in;
						req_out.arg_c  <= arg_c_in;
						req_out.shift  <= shift_in;
						req_out.block  <= block_addr_in;
						req_out.flags  <= flags_in;
						
						req_valid <= 1;
						
						dest_latched <= dest_in;
						write_latched <= write;
						
						commit_id_latched 	<= commit_id_in;
						block_latched 		<= block_addr_in;
						
						if (flags_in == `FILTER_REQ_TYPE_SVF)
							state <= SVF_WAIT;
						else
							state <= REQ;
					end
				end
				
				REQ: begin
					if (write_latched) begin 
						if (req_ack) state <= IDLE;
					end else if (req_response_valid) begin
					
						result_out <= req_response_in;
						
						commit_id_out  	<= commit_id_latched;
						block_addr_out 	<= block_latched;
						dest_out 		<= dest_latched;
						
						state <= DONE;
					end
				end
				
				SVF_WAIT: begin
					if (req_ack) state <= IDLE;
				end
				
				DONE: begin
					if (out_ready) begin
						state <= IDLE;
					end
				end
			endcase
		end
	end
endmodule

module resource_branch_filter #(parameter integer data_width, parameter handle_width = 8, parameter n_blocks = 256, parameter acc_width = 2 * data_width + 8, parameter n_channels = 16) (
		input wire clk,
		input wire reset,
		
		input wire enable,
		
		input  wire in_valid,
		output wire in_ready,
		
		output wire out_valid,
		input  wire out_ready,
		
		input wire [$clog2(n_blocks) - 1 : 0] block_in,
		output reg [$clog2(n_blocks) - 1 : 0] block_out,
		
		output reg [data_width - 1 : 0] req_id_out,
		
		input wire write,
		
		input wire [handle_width - 1 : 0] handle_in,
		input wire signed [data_width   - 1 : 0] arg_a_in,
		input wire signed [data_width   - 1 : 0] arg_b_in,
		input wire signed [data_width   - 1 : 0] arg_c_in,
		
		output wire filter_req,
		output reg  svf_req,
		
		input wire [3:0] req_type_in,
		output reg [3:0] req_type_out,
		
		output reg 		[handle_width - 1 : 0] handle_out,
		output reg signed [data_width - 1 : 0] arg_a_out,
		output reg signed [data_width - 1 : 0] arg_b_out,
		output reg signed [data_width - 1 : 0] arg_c_out,
		input wire signed [data_width - 1 : 0] data_in,
		input wire signed [data_width - 1 : 0] svf_low_in,
		input wire signed [data_width - 1 : 0] svf_high_in,
		input wire signed [data_width - 1 : 0] svf_band_in,
		
		input wire data_valid,
		
		input wire svf_ack,
		input wire svf_valid,
		
		input wire [ch_addr_w - 1 : 0] dest_in,
		output reg [ch_addr_w - 1 : 0] dest_out,
		
		input wire [4 : 0] shift_in,
		output reg [4 : 0] shift_out,
		
		output reg signed [data_width - 1 : 0] result_out,
		
		input wire [`COMMIT_ID_WIDTH - 1 : 0] commit_id_in,
		output reg [`COMMIT_ID_WIDTH - 1 : 0] commit_id_out
	);
	
	localparam ch_addr_w = $clog2(n_channels);
	
	localparam IDLE 		= 3'd0;
	localparam FILTER_REQ  	= 3'd1;
	localparam FILTER_DONE 	= 3'd2;
	localparam SVF_REQ 		= 3'd3;
	localparam SVF_WAIT		= 3'd4;
	localparam DONE			= 3'd5;
	
	assign in_ready  = (state == IDLE);
	assign out_valid = (state == DONE);
	
	assign filter_req  = (state == FILTER_REQ);
	
	reg [$clog2(n_blocks) - 1 : 0] block_latched;
	reg [`COMMIT_ID_WIDTH - 1 : 0] commit_id_latched;
	reg [ch_addr_w - 1 : 0] dest_latched;
	reg write_latched;
	reg [2:0] state;
	
	reg [3:0] req_type_latched;
	
	wire signed [acc_width - 1 : 0] svf_low  = {{(acc_width - data_width){svf_low_in[data_width-1]}}, svf_low_in};
	wire signed [acc_width - 1 : 0] svf_high = {{(acc_width - data_width){svf_high_in[data_width-1]}}, svf_high_in};
	wire signed [acc_width - 1 : 0] svf_band = {{(acc_width - data_width){svf_band_in[data_width-1]}}, svf_band_in};
	
	always @(posedge clk) begin
		svf_req <= 0;
		
		if (reset) begin
			state <= IDLE;
			commit_id_out <= 0;
			
			block_latched <= 0;
			commit_id_latched <= 0;
			dest_latched <= 0;
		end else if (enable) begin
			case (state)
				IDLE: begin
					if (in_valid && in_ready) begin
						handle_out <= handle_in;
						
						arg_a_out <= arg_a_in;
						arg_b_out <= arg_b_in;
						arg_c_out <= arg_c_in;
						dest_latched <= dest_in;
						shift_out <= shift_in;
						
						block_latched <= block_in;
						
						write_latched <= write;
						
						commit_id_latched <= commit_id_in;
						
						req_id_out <= block_in;
						req_type_out <= req_type_in;
						
						case (req_type_in)
							`FILTER_REQ_TYPE_FILTER: state <= FILTER_REQ;
							`FILTER_REQ_TYPE_FCASC:  state <= FILTER_REQ;
							`FILTER_REQ_TYPE_SVF:  begin
								state <= SVF_REQ;
								svf_req <= 1;
							end
							
							`FILTER_REQ_TYPE_SVF_LOW:  state <= SVF_WAIT;
							`FILTER_REQ_TYPE_SVF_BAND: state <= SVF_WAIT;
							`FILTER_REQ_TYPE_SVF_HIGH: state <= SVF_WAIT;
						endcase
					end
				end
				
				FILTER_REQ: begin
					if (data_valid) begin
						result_out <= data_in;
						
						commit_id_out <= commit_id_latched;
						dest_out <= dest_latched;
						
						block_out <= block_latched;
						
						state <= DONE;
					end
				end
				
				SVF_REQ: begin
					if (svf_ack) state <= IDLE;
				end
				
				SVF_WAIT: begin
					if (svf_valid) begin
						case (req_type_out)
							`FILTER_REQ_TYPE_SVF_LOW:  result_out <= svf_low;
							`FILTER_REQ_TYPE_SVF_HIGH: result_out <= svf_high;
							`FILTER_REQ_TYPE_SVF_BAND: result_out <= svf_band;
						endcase
						
						commit_id_out <= commit_id_latched;
						dest_out <= dest_latched;
						
						block_out <= block_latched;
						
						state <= DONE;
					end
				end
				
				DONE: begin
					if (out_ready) begin
						state <= IDLE;
					end
				end
			endcase
		end
	end
endmodule

`default_nettype wire
