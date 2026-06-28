module pwm_generator #(parameter data_width = 16, parameter ctr_width = 7)
	(
		input wire clk,
		input wire reset,
		input wire enable,
		
		input wire signed [data_width - 1 : 0] data_in,
		input wire data_valid,
		
		output wire out
	);
	
	reg [ctr_width - 1 : 0] ctr;
	reg [ctr_width - 1 : 0] data_r;
	
	wire signed [data_width - 1 : 0] data_in_abs = data_in < 0 ? -data_in : data_in;
	
	assign out = data_r > ctr;
	
	always @(posedge clk) begin
		if (reset) begin
			ctr <= 0;
			data_r <= 0;
		end else if (enable) begin
			if (data_valid) begin
				data_r <= data_in_abs[data_width - 1 :- ctr_width];
				ctr <= 0;
			end else begin
				ctr <= ctr + 1;
			end
		end
	end
	
endmodule
