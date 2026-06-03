module preprocessing_stage #(parameter integer data_width, parameter gain_format = 5)
	(
		input wire clk,
		input wire reset,
		
		input wire tick,
		
		input wire signed [data_width - 1 : 0] sample_in,
		
		output reg signed [data_width - 1 : 0] sample_out_a,
		output reg signed [data_width - 1 : 0] sample_out_b,
		
		input wire signed [data_width - 1 : 0] input_gain,
		input wire signed [data_width - 1 : 0] input_gains [1:0]
	);

	reg signed [data_width - 1 : 0] sample_in_r;
	reg signed [data_width - 1 : 0] sample_in_pg;
	
	wire signed [data_width - 1 : 0] sample_out_gain_a;
	wire signed [data_width - 1 : 0] sample_out_gain_b;

	reg in_valid_1;
	reg in_valid_gain;

	bimultiplier #(.data_width(data_width), .format(gain_format)) input_gain_applier
		(
			.clk(clk),
			.reset(reset),

			.x(sample_in_pg),
			.y(sample_in_pg),

			.a(input_gain),
			.b(input_gain),
			.c(input_gains[0]),
			.d(input_gains[1]),

			.in_valid(in_valid_gain),

			.out_1(sample_out_gain_a),
			.out_2(sample_out_gain_b)
		);
	
	reg [15:0] cycle;
	
	always @(posedge clk) begin
		sample_in_pg 	<= sample_in_r;
		
		in_valid_1 		<= tick;
		in_valid_gain 	<= in_valid_1;
		
		sample_out_a <= sample_out_gain_a;
		sample_out_b <= sample_out_gain_b;
	
		if (reset) begin
			sample_out_a <= 0;
			sample_out_b <= 0;
			
			sample_in_r  <= 0;
			sample_in_pg <= 0;
		end else begin
			if (tick) begin
				sample_in_r <= sample_in;
			end
		end
	end
	
endmodule
