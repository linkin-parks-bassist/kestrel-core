`define MIXER_STATE_READY		 		0
`define MIXER_APPLY_INPUT_GAIN_1 		1
`define MIXER_APPLY_INPUT_GAIN_2 		2
`define MIXER_APPLY_INPUT_GAIN_3 		3
`define MIXER_APPLY_INPUT_GAIN_DONE		4
`define MIXER_APPLY_INPUT_GAINS_1		13
`define MIXER_APPLY_INPUT_GAINS_2		14
`define MIXER_APPLY_INPUT_GAINS_3		15
`define MIXER_APPLY_INPUT_GAINS_DONE	16
`define MIXER_MIX_PIPELINES_1	 		5
`define MIXER_MIX_PIPELINES_2	 		6
`define MIXER_MIX_PIPELINES_3	 		7
`define MIXER_APPLY_OUTPUT_GAIN_1 		8
`define MIXER_APPLY_OUTPUT_GAIN_2 		9
`define MIXER_APPLY_OUTPUT_GAIN_3 		10
`define MIXER_APPLY_OUTPUT_GAIN_DONE 	11
`define MIXER_REST				 		12

`default_nettype none

module gain_controller #(parameter data_width = 16, parameter gain_shift = 4)
	(
		input wire clk,
		input wire reset,

		input wire tick,

		input wire set_input_gain,
		input wire set_output_gain,
		input wire [data_width - 1 : 0] data_in,
		
		output reg signed [data_width - 1 : 0] input_gain,
		output reg signed [data_width - 1 : 0] input_gains [1:0],
		
		output reg signed [data_width - 1 : 0] output_gain,
		output reg signed [data_width - 1 : 0] output_gains [1:0],
		
		input reg signed  [data_width - 1 : 0] envelopes [1:0],
		
		input wire swap_pipelines,
		input wire swap_tail_enable,
		
		output reg pipelines_swapping,
		
		input wire current_pipeline
	);
	
	localparam signed [data_width - 1 : 0] unity_gain 				= 1 << (data_width - 1 - gain_shift);
	localparam signed [data_width - 1 : 0] switch_velocity 			= unity_gain >> 8;
	localparam signed [data_width - 1 : 0] tail_close_velocity 		= unity_gain >> 9;
	localparam signed [data_width - 1 : 0] tail_envelope_threshold 	= 1 << 5;
	
	localparam [2:0] TAIL_SWAP_RAMP  = 3'd0;
	localparam [2:0] TAIL_SWAP_DECAY = 3'd1;
	localparam [2:0] TAIL_SWAP_CLOSE = 3'd2;
	
	reg swap_tail_enable_r;
	reg [ 2:0] swap_tail_enable_state;
	reg [63:0] swap_tail_enable_ctr;
	
	always @(posedge clk) begin
	
		if (set_input_gain)   input_gain <= data_in;
		if (set_output_gain) output_gain <= data_in;
		
		if (swap_pipelines) begin
			pipelines_swapping <= 1;
			swap_tail_enable_r <= swap_tail_enable;
			
			swap_tail_enable_state <= TAIL_SWAP_RAMP;
			swap_tail_enable_ctr <= 0;
		end
		
		if (reset) begin
			input_gain     <= 0;
			input_gains[0] <= unity_gain;
			input_gains[1] <= unity_gain;
			
			output_gain  	<= 0;
			output_gains[0] <= unity_gain;
			output_gains[1] <= 0;
			
			pipelines_swapping <= 0;
			swap_tail_enable_r <= 0;
		end else if (tick) begin
			if (pipelines_swapping) begin
				if (swap_tail_enable_r) begin
					case (swap_tail_enable_state)
						TAIL_SWAP_RAMP: begin
							if (input_gains[current_pipeline] == 0) begin
								swap_tail_enable_state <= TAIL_SWAP_DECAY;
								output_gains[~current_pipeline] <= unity_gain;
							end else begin
								input_gains [ current_pipeline] <=  input_gains[ current_pipeline] - switch_velocity;
								output_gains[ current_pipeline] <= output_gains[ current_pipeline] - (switch_velocity >> 1);
								output_gains[~current_pipeline] <= output_gains[~current_pipeline] + switch_velocity;
							end
						end
						
						TAIL_SWAP_DECAY: begin
							swap_tail_enable_ctr <= swap_tail_enable_ctr + 1;
							
							if (output_gains[current_pipeline] == 0) begin
								swap_tail_enable_state <= TAIL_SWAP_CLOSE;
							end else begin
								if (swap_tail_enable_ctr[4:0] == 5'b0)
									output_gains[current_pipeline] <= output_gains[current_pipeline] - 1;
								
								if (envelopes[current_pipeline] < tail_envelope_threshold) begin
									swap_tail_enable_state <= TAIL_SWAP_CLOSE;
								end
							end
						end
						
						TAIL_SWAP_CLOSE: begin
							output_gains[current_pipeline] <= output_gains[current_pipeline] - tail_close_velocity;
							
							if ($signed(output_gains[current_pipeline] - tail_close_velocity) <= 0) begin
								input_gains [current_pipeline] <= unity_gain;
								output_gains[current_pipeline] <= 0;
								pipelines_swapping <= 0;
							end
						end
					endcase
				end else begin
					if (output_gains[current_pipeline] == 0) begin
						output_gains[~current_pipeline] <= unity_gain;
						pipelines_swapping <= 0;
					end
					else begin
						output_gains[ current_pipeline] <= output_gains[ current_pipeline] - switch_velocity;
						output_gains[~current_pipeline] <= output_gains[~current_pipeline] + switch_velocity;
					end
				end
			end
		end
	end
endmodule

module bimultiplier #(parameter data_width = 16, parameter shift = 4)
	(
		input wire clk,
		input wire reset,
		
		input wire signed [data_width - 1 : 0] x,
		input wire signed [data_width - 1 : 0] y,
		
		input wire signed [data_width - 1 : 0] a,
		input wire signed [data_width - 1 : 0] b,
		input wire signed [data_width - 1 : 0] c,
		input wire signed [data_width - 1 : 0] d,
		
		input wire in_valid,
		
		output reg [data_width - 1 : 0] out_1,
		output reg [data_width - 1 : 0] out_2,
		
		output reg out_valid,
		output reg busy
	);

	reg signed [data_width - 1 : 0] c_r;
	reg signed [data_width - 1 : 0] d_r;
	
	reg signed [data_width - 1 : 0] factor_1;
	reg signed [data_width - 1 : 0] factor_2;
	
	reg signed [data_width - 1 : 0] coef_1;
	reg signed [data_width - 1 : 0] coef_2;
	
	reg signed [2 * data_width - 1 : 0] prod_1;
	reg signed [2 * data_width - 1 : 0] prod_2;
	
	reg signed [2 * data_width - 1 : 0] prod_1_sh;
	reg signed [2 * data_width - 1 : 0] prod_2_sh;
	
	reg signed [2 * data_width - 1 : 0] prod_1_sh_sat;
	reg signed [2 * data_width - 1 : 0] prod_2_sh_sat;
	
	wire signed [data_width - 1 : 0] prod_1_sh_sat_trunc = prod_1_sh_sat[data_width - 1 : 0];
	wire signed [data_width - 1 : 0] prod_2_sh_sat_trunc = prod_2_sh_sat[data_width - 1 : 0];
	
	reg [7:0] ctr;
	
	localparam signed [2 * data_width - 1 : 0] sat_max = ( 1 << (data_width - 1)) - 1;
	localparam signed [2 * data_width - 1 : 0] sat_min = (-1 << (data_width - 1));
	
	always @(posedge clk) begin
		prod_1 		  <= factor_1 * coef_1;
		prod_1_sh 	  <= prod_1 >>> (data_width - 1 - shift);
		prod_1_sh_sat <= (prod_1_sh > sat_max) ? sat_max : ((prod_1_sh < sat_min) ? sat_min : prod_1_sh);
		prod_2 		  <= factor_2 * coef_2;
		prod_2_sh 	  <= prod_2 >>> (data_width - 1 - shift);
		prod_2_sh_sat <= (prod_2_sh > sat_max) ? sat_max : ((prod_2_sh < sat_min) ? sat_min : prod_2_sh);
		
		out_valid <= 0;
		
		if (reset) begin
			busy <= 0;
			ctr <= 0;
		end else if (busy) begin
			ctr <= ctr + 1;
			if (ctr == 3) begin
				factor_1 <= prod_1_sh_sat_trunc;
				factor_2 <= prod_2_sh_sat_trunc;
				coef_1 <= c_r;
				coef_2 <= d_r;
			end else if (ctr == 7) begin
				out_1 <= prod_1_sh_sat_trunc;
				out_2 <= prod_2_sh_sat_trunc;
				
				out_valid <= 1;
				busy <= 0;
				
				ctr <= 0;
			end
		end else if (in_valid) begin
			busy <= 1;

			c_r <= c;
			d_r <= d;
			
			factor_1 <= x;
			factor_2 <= y;
			coef_1 <= a;
			coef_2 <= b;
		end
	end
	
endmodule

module mixer #(parameter data_width = 16, parameter gain_shift = 4)
	(
		input wire clk,
		input wire reset,

		input  wire signed [data_width - 1 : 0] in_sample,
		output wire signed [data_width - 1 : 0] in_sample_out_a,
		output wire signed [data_width - 1 : 0] in_sample_out_b,
		
		input wire signed [data_width - 1 : 0] out_sample_in_a,
		input wire signed [data_width - 1 : 0] out_sample_in_b,
		
		output reg signed [data_width - 1 : 0] out_sample,
		
		input wire [data_width - 1 : 0] data_in,
		
		input wire in_sample_valid,
		input wire out_samples_valid,
		
		output wire in_sample_mixed,
		output reg  out_sample_valid,
		
		input wire set_input_gain,
		input wire set_output_gain,
		
		input wire swap_pipelines,
		input wire swap_tail_enable,
		
		output wire pipelines_swapping,
		input  wire current_pipeline
	);
	
	wire [data_width - 1 : 0] envelope_a;
	wire [data_width - 1 : 0] envelope_b;
	wire envelope_a_valid;
	wire envelope_b_valid;
	
	envelope_follower env_a
		(.clk(clk), .reset(reset), .enable(1), .sample_in(out_sample_in_a), .sample_valid(out_samples_valid), .envelope(envelope_a), .envelope_valid(envelope_a_valid));
	envelope_follower env_b
		(.clk(clk), .reset(reset), .enable(1), .sample_in(out_sample_in_b), .sample_valid(out_samples_valid), .envelope(envelope_b), .envelope_valid(envelope_b_valid));
	
	wire signed [data_width - 1 : 0] input_gain;
	wire signed [data_width - 1 : 0] input_gains [1:0];
	
	wire signed [data_width - 1 : 0] output_gain;
	wire signed [data_width - 1 : 0] output_gains [1:0];
	
	gain_controller gain_ctrl
		(
			.clk(clk),
			.reset(reset),

			.tick(out_sample_valid),

			.set_input_gain(set_input_gain),
			.set_output_gain(set_output_gain),
			.data_in(data_in),
			
			.input_gain(input_gain),
			.input_gains(input_gains),
			
			.output_gain(output_gain),
			.output_gains(output_gains),
			
			.envelopes({envelope_b, envelope_a}),
			
			.swap_pipelines(swap_pipelines),
			.swap_tail_enable(swap_tail_enable),
			
			.pipelines_swapping(pipelines_swapping),
			
			.current_pipeline(current_pipeline)
		);
	
	wire output_gain_valid;
	
	bimultiplier input_gain_applier
		(
			.clk(clk),
			.reset(reset),

			.x(in_sample),
			.y(in_sample),

			.a(input_gain),
			.b(input_gain),
			.c(input_gains[0]),
			.d(input_gains[1]),

			.in_valid(in_sample_valid),

			.out_1(in_sample_out_a),
			.out_2(in_sample_out_b),

			.out_valid(in_sample_mixed)
		);
	
	wire signed [data_width - 1 : 0] out_sample_a_amp;
	wire signed [data_width - 1 : 0] out_sample_b_amp;
	
	bimultiplier output_gain_applier
		(
			.clk(clk),
			.reset(reset),

			.x(out_sample_in_a),
			.y(out_sample_in_b),

			.a(output_gains[0]),
			.b(output_gains[1]),
			.c(output_gain),
			.d(output_gain),

			.in_valid(out_samples_valid),

			.out_1(out_sample_a_amp),
			.out_2(out_sample_b_amp),

			.out_valid(output_gain_valid)
		);
	
	
	localparam signed [data_width : 0] sat_max = ( 1 << (data_width - 1)) - 1;
	localparam signed [data_width : 0] sat_min = (-1 << (data_width - 1));
	
	localparam signed sat_max_t = sat_max[data_width - 1 : 0];
	localparam signed sat_min_t = sat_min[data_width - 1 : 0];
	
	reg  signed [data_width     : 0] out_sum;
	wire signed [data_width - 1 : 0] out_sum_t = out_sum[data_width - 1 : 0];
	wire signed [data_width - 1 : 0] out_sum_sat = (out_sum > sat_max) ? sat_max_t : ((out_sum < sat_min) ? sat_min_t : out_sum_t);
	
	reg out_sum_valid;
	
	always @(posedge clk) begin
		out_sum <= out_sample_a_amp + out_sample_b_amp;
		out_sum_valid <= output_gain_valid;
		
		out_sample_valid <= 0;
		
		if (reset) begin
			out_sum_valid <= 0;
		end else begin
			if (out_sum_valid) begin
				out_sample <= out_sum_sat;
				out_sample_valid <= 1;
			end
		end
	end
	
endmodule

`default_nettype wire
