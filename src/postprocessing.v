module postprocessing_stage #(parameter integer data_width, parameter gain_format = 5)
	(
		input wire clk,
		input wire reset,
		
		input wire tick,
		
		input wire signed [data_width - 1 : 0] samples_in [1:0],
		
		output reg signed [data_width - 1 : 0] sample_out,
		
		input wire signed [data_width - 1 : 0] output_gain,
		input wire signed [data_width - 1 : 0] output_gains [1:0]
	);

	reg signed [data_width - 1 : 0] samples_in_r  [1:0];
	reg signed [data_width - 1 : 0] samples_in_pg [1:0];

	reg in_valid_1;
	reg in_valid_gain;

	bimultiplier #(.data_width(data_width), .format(gain_format)) input_gain_applier
		(
			.clk(clk),
			.reset(reset),

			.x(samples_in_pg[0]),
			.y(samples_in_pg[1]),

			.a(output_gain),
			.b(output_gain),
			.c(output_gains[0]),
			.d(output_gains[1]),

			.in_valid(in_valid_gain),

			.out_1(sample_out_a_gain),
			.out_2(sample_out_b_gain)
		);
	
	wire signed [data_width - 1 : 0] sample_out_a_gain;
	wire signed [data_width - 1 : 0] sample_out_b_gain;
	
	reg signed [data_width : 0] samples_mixed;
	
	localparam signed [data_width : 0] sat_max = ( 1 << (data_width - 1)) - 1;
	localparam signed [data_width : 0] sat_min = (-1 << (data_width - 1));
	
	always @(posedge clk) begin
		samples_in_pg[0] 	<= samples_in_r[0];
		samples_in_pg[1] 	<= samples_in_r[1];
		
		in_valid_1 		<= tick;
		in_valid_gain 	<= in_valid_1;
		
		samples_mixed <= sample_out_a_gain + sample_out_b_gain;
		
		sample_out <= samples_mixed > sat_max ? sat_max[data_width - 1 : 0]
											  : ((samples_mixed < sat_min) ? sat_min      [data_width - 1 : 0]
																		   : samples_mixed[data_width - 1 : 0]);
		
		if (reset) begin
			samples_in_r[0]  <= 0;
			samples_in_r[1]  <= 0;
		end else begin
			if (tick) begin
				samples_in_r[0] <= samples_in[0];
				samples_in_r[1] <= samples_in[1];
			end
		end
	end

endmodule
