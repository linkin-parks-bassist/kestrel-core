`define BIQUAD_STATE_READY 0
`define BIQUAD_STATE_CALC1 1
`define BIQUAD_STATE_CALC2 2
`define BIQUAD_STATE_CALC3 3
`define BIQUAD_STATE_CALC4 4
`define BIQUAD_STATE_CALC5 5


module biquad_unit #(parameter integer data_width)
(
	input wire clk,
	input wire reset,
	
	input wire signed [data_width - 1 : 0] sample_in,
	input reg  signed [data_width - 1 : 0] sample_out,
	
	input wire start,
	output wire ready,
	
	input wire signed [data_width - 1 : 0] param_in,
	input wire [2:0]  param_target,
	input wire write_param
);
	
	reg signed [data_width + 1 : 0] b0;
	reg signed [data_width + 1 : 0] b1;
	reg signed [data_width + 1 : 0] b2;
	reg signed [data_width + 1 : 0] a1;
	reg signed [data_width + 1 : 0] a2;
	reg signed [data_width + 1 : 0] x1;
	reg signed [data_width + 1 : 0] x2;
	reg signed [data_width + 1 : 0] y1;
	reg signed [data_width + 1 : 0] y2;
	
	reg [4:0] state = 0;
	
	assign ready = (state == `BIQUAD_STATE_READY);
	
	wire signed [2 * (data_width + 1) : 0] maccumulator_1;
	wire signed [2 * (data_width + 1) : 0] maccumulator_2;
	wire signed [2 * (data_width + 1) : 0] maccumulator_3;
	wire signed [2 * (data_width + 1) : 0] maccumulator_4;
	wire signed [2 * (data_width + 1) : 0] maccumulator_5;
	
	wire signed [2 * (data_width + 1) : 0] mul_1;
	wire signed [2 * (data_width + 1) : 0] mul_2;
	
	reg signed [data_width - 1 : 0] f11;
	reg signed [data_width - 1 : 0] f12;
	reg signed [data_width - 1 : 0] f21;
	reg signed [data_width - 1 : 0] f22;
	
	assign mul_1 = f11 * f12;
	assign mul_2 = f21 * f22;
	
	reg signed [2 * (data_width + 1) : 0] acc;
	
	reg signed [data_width + 1 : 0] summand_a;
	reg signed [data_width + 1 : 0] summand_b;
	
	wire signed [data_width : 0] sum = summand_a + summand_b;
	wire signed [2 * (data_width + 1) : 0] sum_ext = {{(data_width){sum[data_width]}}, sum};
	reg  signed [2 * (data_width + 1) : 0] sum_ext_latched;
	
	wire signed [2 * (data_width + 1) : 0] accumulator_sum = acc + sum_ext;
	
	reg [data_width + 1 : 0] sample_in_latched;
	
	/* b0*x0 + b1*x1 + b2*x2 - a1*y1 - a2*y2 */
	
	always @(posedge clk) begin
		sum_ext_latched <= sum_ext;
		
		if (reset) begin
			state <= `BIQUAD_STATE_READY;
			
			b0 <= 0;
			b1 <= 0;
			b2 <= 0;
			a1 <= 0;
			x1 <= 0;
			x2 <= 0;
			y1 <= 0;
			y2 <= 0;
		end else begin
			if (write_param) begin
				case (param_target)
					0: b0 <= {param_in, 2'b0};
					1: b1 <= {param_in, 2'b0};
					2: b2 <= {param_in, 2'b0};
					3: a1 <= {param_in, 2'b0};
					4: a2 <= {param_in, 2'b0};
				endcase
			end
		
			case (state)
				`BIQUAD_STATE_READY: begin
					if (start) begin
						f11 <= b0;
						f12 <= {2'b0, sample_in};
						sample_in_latched <= {2'b0, sample_in};
						
						f21 <= b1;
						f22 <= x1;
						
						acc <= 0;
						
						state <= `BIQUAD_STATE_CALC1;
					end
				end
				
				`BIQUAD_STATE_CALC1: begin
					f11 <= b2;
					f12 <= x2;
					
					f21 <= a1;
					f22 <= y1;
					
					summand_a <= mul_1 >>> (data_width - 1);
					summand_b <= mul_2 >>> (data_width - 1);
					
					state <= `BIQUAD_STATE_CALC2;
				end
				
				`BIQUAD_STATE_CALC2: begin
					f11 <= a2;
					f12 <= y2;
					
					summand_a <=  mul_1[2 * (data_width + 1) : data_width];
					summand_b <= -mul_2[2 * (data_width + 1) : data_width];
					
					acc <= accumulator_sum;
					
					state <= `BIQUAD_STATE_CALC3;
				end
				
				`BIQUAD_STATE_CALC3: begin
					acc <= accumulator_sum;
					
					summand_a <= -mul_1[2 * (data_width + 1) : data_width];
					summand_b <= 0;
					
					state <= `BIQUAD_STATE_CALC4;
				end
				
				
				`BIQUAD_STATE_CALC3: begin
					//sample_out <= something;
					
					x2 <= x1;
					x1 <= sample_in_latched;
					
					y2 <= y1;
					//y1 <= something;
					
					
					state <= `BIQUAD_STATE_CALC4;
				end
			endcase
		end
	end
endmodule
