module pipeline_stage_template #(parameter data_width = 8)
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

module pipeline_stage_template_elastic #(parameter data_width = 8)
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
	
	assign in_ready = enable & ~stalled & (~out_valid | out_ready);
	
	wire take_in  = in_ready & in_valid;
	wire take_out = out_valid & out_ready;
	
	reg  [data_width - 1 : 0] d_in_r;
	wire [data_width - 1 : 0] d_stall = d_in_r;
	wire [data_width - 1 : 0] d = stalled ? d_stall : d_in;
	
	reg stalled;
	
	wire stall_condition  = 1'b0;
	wire resume_condition = 1'b1;
	
	always @(posedge clk) begin
		if (reset) begin
			out_valid 	<= 0;
			stalled		<= 0;
		end else if (enable) begin
			if (stalled) begin
				if (take_out) begin
					out_valid <= 0;
				end
				
				if (resume_condition & (~out_valid | out_ready)) begin
					d_out <= d;
					stalled <= 0;
					out_valid <= 1;
				end
			end else if (take_in) begin
				if (stall_condition) begin
					d_in_r <= d_in;
					
					if (take_out) begin
						out_valid <= 0;
					end
					
					stalled <= 1;
				end else begin
					d_out <= d;
					out_valid <= 1;
				end
			end else if (take_out) begin
				out_valid <= 0;
			end
		end
	end
endmodule
