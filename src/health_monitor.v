module envelope_follower #(parameter integer data_width)
	(
		input wire clk,
		input wire enable,
		
		input wire reset,
		
		input wire sample_valid,
		
		input wire signed [data_width - 1 : 0] sample_in,
		
		output reg envelope_valid,
		output reg [data_width - 1 : 0] envelope
	);
	
	reg abs_valid;
	reg envelope_1_valid;
	reg envelope_2_valid;
	reg envelope_3_valid;
	reg envelope_4_valid;
	
	reg [data_width - 1 : 0] abs;
	reg [data_width - 1 : 0] envelope_1;
	reg [data_width - 1 : 0] envelope_2;
	reg [data_width - 1 : 0] envelope_3;
	reg [data_width - 1 : 0] envelope_4;
	
	always @(posedge clk) begin
		if (reset) begin
			abs_valid <= 0;
			
			envelope_1_valid <= 0;
			envelope_2_valid <= 0;
			envelope_3_valid <= 0;
			envelope_4_valid <= 0;
			envelope_valid 	 <= 0;
			
			abs 		<= 0;
			envelope_1 	<= 0;
			envelope_2 	<= 0;
			envelope_3 	<= 0;
			envelope_4 	<= 0;
			envelope 	<= 0;
		end else if (enable) begin
			abs 	   <= sample_in < 0 ? -sample_in : sample_in;
			envelope_1 <= (abs  >> 5) + (envelope >> 1);
			envelope_2 <=  envelope_1 + (envelope >> 2);
			envelope_3 <=  envelope_2 + (envelope >> 3);
			envelope_4 <=  envelope_3 + (envelope >> 4);
			envelope <= (envelope_4_valid) ? (envelope_4 + (envelope >> 5)) : envelope;
			
			abs_valid 		 <= sample_valid;
			envelope_1_valid <= abs_valid;
			envelope_2_valid <= envelope_1_valid;
			envelope_3_valid <= envelope_2_valid;
			envelope_4_valid <= envelope_3_valid;
			envelope_valid 	 <= envelope_4_valid;
		end
	end
endmodule

module health_monitor #(parameter integer data_width)
	(
		input wire clk,
		input wire enable,
		
		input wire reset,
		
		input wire sample_valid,
		
		input wire signed [data_width - 1 : 0] sample_in,
		
		output reg health,
		
		output wire envl_detect,
		output wire peak_detect
	);
	
	reg [data_width - 1 : 0] envelope;
	reg [data_width - 1 : 0] envelope_1;
	reg [data_width - 1 : 0] envelope_2;
	
	reg signed [data_width - 1 : 0] sample_in_r;
	reg [data_width - 1 : 0] abs;
	
	reg abs_valid;
	reg envelope_1_valid;
	reg envelope_2_valid;
	reg envelope_valid;
	
	reg [7:0] peak_ctr;
	reg [7:0] envelope_threshold_ctr;
	
	localparam envelope_threshold = (1 << (data_width - 1)) * 0.75;
	localparam envelope_threshold_ctr_threshold = 64;
	localparam peak_ctr_threshold = 10;
	
	assign peak_detect = (peak_ctr > peak_ctr_threshold);
	assign envl_detect = (envelope_threshold_ctr > envelope_threshold_ctr_threshold);
	
	localparam sat_min = -(1 << (data_width - 1));
	localparam sat_max =  (1 << (data_width - 1)) - 1;
	
	always @(posedge clk) begin
		abs_valid <= sample_valid;
		envelope_1_valid <= abs_valid;
		envelope_2_valid <= envelope_1_valid;
		envelope_valid 	 <= envelope_2_valid;
		
		if (reset) begin
			health <= 1;
			peak_ctr <= 0;
			envelope_threshold_ctr <= 0;
			
			abs_valid <= 0;
			envelope_1_valid <= 0;
			envelope_2_valid <= 0;
			envelope_valid 	 <= 0;
			
			envelope <= 0;
			envelope_1 <= 0;
			envelope_2 <= 0;
			abs <= 0;
		end else if (enable) begin
			if (sample_valid) begin
				abs <= sample_in < 0 ? -sample_in : sample_in;
				
				if (sample_in == sat_min || sample_in == sat_max)
					peak_ctr <= peak_ctr + (peak_detect ? 0 : 1);
				else
					peak_ctr <= 0;
				
				if (peak_detect)
					health <= 0;
			end
			
			if (abs_valid) envelope_1 		 <= (envelope >> 1) + (abs >> 3);
			if (envelope_1_valid) envelope_2 <=  envelope_1 + (envelope >> 2);
			if (envelope_2_valid) envelope   <=  envelope_2 + (envelope >> 3);
			
			if (envelope_valid) begin
				if (envelope > envelope_threshold)
					envelope_threshold_ctr <= envelope_threshold_ctr + (envl_detect ? 0 : 1);
				else
					envelope_threshold_ctr <= 0;
				
				if (envl_detect) health <= 0;
			end
		end
	end
	
	
	wire env1_valid;
	wire [data_width - 1 : 0] env1;
	
	envelope_follower #(.data_width(data_width)) tef (.clk(clk), .reset(reset), .enable(1), .sample_in(sample_in), .sample_valid(sample_valid), .envelope(env1), .envelope_valid(env1_valid));
endmodule
