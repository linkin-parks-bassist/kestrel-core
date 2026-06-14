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

module gain_controller #(parameter integer data_width, parameter gain_format = 5)
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
		
		input wire signed  [data_width - 1 : 0] out_samples [1:0],
		
		input wire swap_pipelines,
		input wire swap_tail_enable,
		
		output reg pipelines_swapping,
		
		input wire current_pipeline
	);
	
	localparam signed [data_width - 1 : 0] unity_gain 				= 1 << (data_width - 1 - gain_format);
	localparam signed [data_width - 1 : 0] switch_velocity 			= unity_gain >> 8;
	localparam signed [data_width - 1 : 0] tail_close_velocity 		= unity_gain >> 9;
	localparam signed [data_width - 1 : 0] tail_envelope_threshold 	= 1 << 4;
	
	localparam [2:0] NO_SWAP  		 = 3'd0;
	localparam [2:0] CROSSFADE 		 = 3'd1;
	localparam [2:0] TAIL_SWAP_RAMP  = 3'd2;
	localparam [2:0] TAIL_SWAP_DECAY = 3'd3;
	localparam [2:0] TAIL_SWAP_CLOSE = 3'd4;
	
	reg swap_tail_enable_r;
	reg [ 2:0] swap_tail_enable_state;
	reg [63:0] swap_tail_enable_ctr;
	
	reg [2:0] swap_state;
	
	reg current_pipeline_r;
	
	wire signed [data_width - 1 : 0] envelopes [1:0];
	wire envelope_valids [1:0];
	
	reg signed [data_width - 1 : 0] envelope_a_r;
	reg signed [data_width - 1 : 0] envelope_b_r;
	
	reg signed [data_width - 1 : 0] out_sample_0_r;
	reg signed [data_width - 1 : 0] out_sample_1_r;
	
	reg signed [data_width - 1 : 0] envelopes_r;
	
	assign envelopes_r[0] = envelope_a_r;
	assign envelopes_r[1] = envelope_b_r;
	
	envelope_follower #(.data_width(data_width)) env_a
		(.clk(clk), .reset(reset), .enable(1), .sample_in(out_sample_0_r), .sample_valid(tick), .envelope(envelopes[0]), .envelope_valid(envelope_valids[0]));
	envelope_follower #(.data_width(data_width)) env_b
		(.clk(clk), .reset(reset), .enable(1), .sample_in(out_sample_1_r), .sample_valid(tick), .envelope(envelopes[1]), .envelope_valid(envelope_valids[1]));
	
	reg set_input_gain_r;
	reg set_output_gain_r;
	
	reg [data_width - 1 : 0] data_in_r;
	
	always @(posedge clk) begin
		set_input_gain_r  <= set_input_gain;
		set_output_gain_r <= set_output_gain;
		data_in_r <= data_in;
	
		if (set_input_gain_r)   input_gain <= data_in_r;
		if (set_output_gain_r) output_gain <= data_in_r;
		
		if (swap_pipelines) begin
			pipelines_swapping <= 1;
			
			if (swap_tail_enable)
				swap_state <= TAIL_SWAP_RAMP;
			else
				swap_state <= CROSSFADE;
			
			swap_tail_enable_ctr <= 0;
		end
		
		if (envelope_valids[0])	envelope_a_r <= envelopes[0];
		if (envelope_valids[1])	envelope_b_r <= envelopes[1];		
	
		current_pipeline_r <= current_pipeline;
		
		if (reset) begin
			input_gain     <= 0;
			input_gains[0] <= unity_gain;
			input_gains[1] <= unity_gain;
			
			output_gain  	<= 0;
			output_gains[0] <= unity_gain;
			output_gains[1] <= 0;
			
			pipelines_swapping <= 0;
			swap_state <= NO_SWAP;
			
			out_sample_0_r <= 0;
			out_sample_1_r <= 0;
			
			envelope_a_r <= 0;
			envelope_b_r <= 0;
			
			set_input_gain_r <= 0;
			set_output_gain_r <= 0;
		end else if (tick) begin
			out_sample_0_r <= out_samples[0];
			out_sample_1_r <= out_samples[1];
		
			case (swap_state)
				CROSSFADE: begin
					if (output_gains[ current_pipeline_r] == 0) begin
						output_gains[~current_pipeline_r] <= unity_gain;
						pipelines_swapping <= 0;
						swap_state <= NO_SWAP;
					end
					else begin
						output_gains[ current_pipeline_r] <= output_gains[ current_pipeline_r] - switch_velocity;
						output_gains[~current_pipeline_r] <= output_gains[~current_pipeline_r] + switch_velocity;
					end
				end
				
				TAIL_SWAP_RAMP: begin
					if (input_gains[current_pipeline_r] == 0) begin
						output_gains[~current_pipeline_r] <= unity_gain;
						swap_state <= TAIL_SWAP_DECAY;
					end else begin
						input_gains [ current_pipeline_r] <=  input_gains[ current_pipeline_r] - switch_velocity;
						output_gains[~current_pipeline_r] <= output_gains[~current_pipeline_r] + switch_velocity;
					end
				end
				
				TAIL_SWAP_DECAY: begin
					swap_tail_enable_ctr <= swap_tail_enable_ctr + 1;
					
					if (output_gains[current_pipeline_r] == 0) begin
						swap_state <= TAIL_SWAP_CLOSE;
					end else begin
						if (swap_tail_enable_ctr[5:0] == 6'b0)
							output_gains[current_pipeline_r] <= output_gains[current_pipeline_r] - 1;
						
						if (envelopes_r[current_pipeline_r] < tail_envelope_threshold) begin
							swap_state <= TAIL_SWAP_CLOSE;
						end
					end
				end
				
				TAIL_SWAP_CLOSE: begin
					output_gains[current_pipeline_r] <= output_gains[current_pipeline_r] - tail_close_velocity;
					
					if ($signed(output_gains[current_pipeline_r] - tail_close_velocity) <= 0) begin
						input_gains [current_pipeline_r] <= unity_gain;
						output_gains[current_pipeline_r] <= 0;
						pipelines_swapping <= 0;
						swap_state <= NO_SWAP;
					end
				end
			endcase
		end
	end
endmodule

module bimultiplier #(parameter integer data_width, parameter format = 0)
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
		prod_1_sh 	  <= prod_1 >>> (data_width - 1 - format);
		prod_1_sh_sat <= (prod_1_sh > sat_max) ? sat_max : ((prod_1_sh < sat_min) ? sat_min : prod_1_sh);
		prod_2 		  <= factor_2 * coef_2;
		prod_2_sh 	  <= prod_2 >>> (data_width - 1 - format);
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

`default_nettype wire
