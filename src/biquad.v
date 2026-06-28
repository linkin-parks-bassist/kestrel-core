`include "controller.vh"
`include "defs.vh"

`ifdef ENABLE_BIQUAD

`default_nettype none

module biquad_pl #(parameter n_slots = 16)
	(
		input wire clk,
		input wire reset,
		
		input wire enable,
		
		input  wire in_valid,
		output wire in_ready,
		
		output wire out_valid,
		input  wire out_ready,
		
		input wire  [`DATA_WIDTH - 1 : 0] data_in,
		output wire [`DATA_WIDTH - 1 : 0] data_out,
		
		input wire coef_write,
		
        input wire [`CTRL_DATA_BUS_WIDTH - 1 : 0] ctrl_data_in
	);
	
	localparam slot_addr_width = $clog2(n_slots);
	
	assign in_ready = enable & (~out_valid | out_ready);
	
	wire take_in  = in_ready & in_valid;
	wire take_out = out_valid & out_ready;
	
	reg [`CTRL_DATA_BUS_WIDTH - 1 : 0] ctrl_data_r;
	
	reg coef_write_r;
	reg coef_write_pending;
	
	wire [`HANDLE_WIDTH - 1 : 0] write_handle_r;
	
	wire [2 : 0] write_coef_n;
	wire [`FILTER_COEF_WIDTH - 1 : 0] write_coef_r;
	
	reg [n_slots - 1 : 0] coef_bank_select;
	
	reg [5 * `FILTER_COEF_WIDTH - 1 : 0] coef_bank_a [n_slots - 1 : 0];
	reg [5 * `FILTER_COEF_WIDTH - 1 : 0] coef_bank_b [n_slots - 1 : 0];
	
	reg  [5 * `FILTER_COEF_WIDTH - 1 : 0] coef_read_a_val;
	reg  [5 * `FILTER_COEF_WIDTH - 1 : 0] coef_read_b_val;
	wire [5 * `FILTER_COEF_WIDTH - 1 : 0] coef_read_val;
	reg  [5 * `FILTER_COEF_WIDTH - 1 : 0] coef_write_val;
	
	assign coef_read_val = coef_read_addr[slot_addr_width] ? coef_read_b_val : coef_read_a_val;
	
	reg [slot_addr_width - 1 : 0] coef_write_addr;
	reg [slot_addr_width : 0] coef_read_addr;
	
	reg coef_write_a_enable;
	reg coef_write_b_enable;
	
	always @(posedge clk) begin
		coef_read_a_val <= coef_bank_a[coef_read_addr[slot_addr_width - 1 : 0]];
		coef_read_b_val <= coef_bank_b[coef_read_addr[slot_addr_width - 1 : 0]];
		
		if (coef_write_a_enable) coef_bank_a[coef_write_addr] <= coef_write_val;
		if (coef_write_b_enable) coef_bank_b[coef_write_bddr] <= coef_write_val;
	end
	
	always @(posedge clk) begin
		ctrl_data_r  <= ctrl_data_in;
		alloc_req_r  <= alloc_req;
		coef_write_r <= coef_write;
	
		if (reset) begin
			alloc_handle <= 0;
			coef_write_enable <= 0;
			coef_write_pending <= 0;
		end else if (enable) begin
			if (coef_write_r) begin
				write_handle_r <= ctrl_data_r[`HANDLE_WIDTH - 1 : 0];
				write_coef_n   <= ctrl_data_r[8 +: 3];
				write_coef_r   <= ctrl_data_r[16 +: `FILTER_COEF_WIDTH];
				
				coef_write_pending <= 1;
			end
			
			if (coef_write_pending) begin
				coef_write_pending <= 0;
			end
		end
	end
endmodule

module biquad_stage_1 #(parameter data_width = `DATA_WIDTH)
	(
		input wire clk,
		input wire reset,
		
		input wire enable,
		
		input  wire in_valid,
		output wire in_ready,
		
		output reg out_valid,
		input wire out_ready,
		
		input wire [data_width - 1 : 0] d_in,
		output reg [data_width - 1 : 0] d_out
	);
	
	assign in_ready = enable & (~out_valid | out_ready);
	
	wire take_in  = in_ready & in_valid;
	wire take_out = out_valid & out_ready;
	
	wire [data_width - 1 : 0] d = d_in;
	
	always @(posedge clk) begin
		if (reset) begin
			out_valid 	<= 0;
		end else if (enable) begin
			if (take_in) begin
				
				d_out <= d;
				out_valid <= 1;
				
			end else if (take_out) begin
				out_valid <= 0;
			end
		end
	end
endmodule

`endif
