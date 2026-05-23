`include "instr_dec.vh"
`include "core.vh"
`include "lut.vh"

`default_nettype none

module commit_master #(parameter integer data_width, parameter n_blocks = 256, parameter acc_width = 2 * data_width + 8, parameter n_channels = 16)
	(
		input wire clk,
		input wire reset,
		
		input wire enable,
		
		input wire sample_tick,
		input wire signed [data_width - 1 : 0] sample_in,
		
		input wire   [`N_INSTR_BRANCHES - 1 : 0] in_valid,
		output logic [`N_INSTR_BRANCHES - 1 : 0] in_ready,
		
		input wire [$clog2(n_blocks)  - 1 : 0] block_in		[`N_INSTR_BRANCHES - 1 : 0],
		input wire signed [data_width - 1 : 0] result		[`N_INSTR_BRANCHES - 1 : 0],
		input wire [ch_addr_w 		  - 1 : 0] dest			[`N_INSTR_BRANCHES - 1 : 0],
		input wire [`COMMIT_ID_WIDTH  - 1 : 0] commit_id	[`N_INSTR_BRANCHES - 1 : 0],
		input wire [`N_INSTR_BRANCHES - 1 : 0] commit_flag,
		
		output reg [ch_addr_w - 1 : 0] channel_write_addr,
		output reg signed [data_width - 1 : 0] channel_write_val,
		output reg channel_write_enable,
		
		input wire signed [acc_width - 1 : 0] result_mac_branch,
		output reg signed [acc_width - 1 : 0] accumulator_write_val,
		output reg accumulator_write_enable,
		output reg accumulator_add_enable,
		
		output reg [`COMMIT_ID_WIDTH - 1 : 0] next_commit_id,
		
		output wire stuck
	);
	
	reg [$clog2(`CYCLES_PER_SAMPLE) : 0] stuck_ctr;
	assign stuck = (stuck_ctr == `CYCLES_PER_SAMPLE);
	
	localparam ch_addr_w = $clog2(n_channels);
	
	genvar i;
	generate
		for (i = 0; i < `N_INSTR_BRANCHES; i = i + 1) begin : one_hot
			assign in_ready[i] = (in_valid[i] && commit_id[i] == next_commit_id) & ~sample_tick;
		end
	endgenerate
	
	reg [`N_INSTR_BRANCHES - 1 : 0] in_ready_prev;
	reg acc_overwrite_prev;
	reg signed [data_width	- 1 : 0] result_prev [`N_INSTR_BRANCHES - 1 : 0];
	reg signed [acc_width   - 1 : 0] result_mac_branch_prev;
	reg [ch_addr_w  - 1 : 0] dest_prev	 [`N_INSTR_BRANCHES - 1 : 0];

	integer j;
	integer k;
	always @(posedge clk) begin	
		
		accumulator_add_enable <= 0;
		accumulator_write_enable <= 0;
		channel_write_enable <= 0;
		
		acc_overwrite_prev <= commit_flag[`INSTR_BRANCH_MAC];
		in_ready_prev <= in_ready;
		
		for (k = 0; k < `N_INSTR_BRANCHES; k = k + 1) begin
			result_prev[k] <= result[k];
			dest_prev[k]   <= dest[k];
		end
		
		result_mac_branch_prev <= result_mac_branch;
		
		if (enable && stuck_ctr < `CYCLES_PER_SAMPLE)
			stuck_ctr <= stuck_ctr + 1;
		
		if (reset) begin
			next_commit_id <= 0;
			stuck_ctr <= 0;
		end else if (sample_tick) begin
			channel_write_addr 		<= 0;
			channel_write_val  		<= sample_in;
			channel_write_enable 	<= 1;
			
			if (enable) begin
				acc_overwrite_prev <= acc_overwrite_prev;
				in_ready_prev <= in_ready_prev;
				result_prev <= result_prev;
				dest_prev <= dest_prev;
			end
		end else if (enable) begin
			if (|in_ready) next_commit_id <= next_commit_id + 1;
			
			for (j = 0; j < `N_INSTR_BRANCHES; j = j + 1) begin
				if (in_ready_prev[j]) begin
					if (j == `INSTR_BRANCH_MAC) begin
						accumulator_write_val <= result_mac_branch_prev;
						accumulator_add_enable <= ~acc_overwrite_prev;
						accumulator_write_enable <= 1;
						stuck_ctr <= 0;
					end else begin
						channel_write_val <= result_prev[j][data_width - 1 : 0];
						channel_write_addr <= dest_prev[j];
						channel_write_enable <= 1;
						stuck_ctr <= 0;
					end
				end
			end
		end
	end
endmodule

`default_nettype wire
