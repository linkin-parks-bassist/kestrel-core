`define LUT_MASTER_STATE_READY 		 	0
`define LUT_MASTER_STATE_PROCESSING  	1
`define LUT_MASTER_STATE_SIN_WAIT  		2
`define LUT_MASTER_STATE_TANH_WAIT  	3
`define LUT_MASTER_STATE_WAIT_INTERP1 	5
`define LUT_MASTER_STATE_WAIT_INTERP2 	6
`define LUT_MASTER_STATE_SEND		 	7
`define LUT_MASTER_STATE_ERROR		 	8

`define LUT_HANDLE_SIN	0
`define LUT_HANDLE_TANH	1

`define N_CORE_LUTS	2

`default_nettype none

module lut_master #(parameter integer data_width) (
		input wire clk,
		input wire reset,
		
		input wire enable,
		
		output reg req_ack,
		input wire req_valid,
		input rw_req_t req_in,
		output reg req_invalid,
		output word_t req_response,
		output reg req_response_valid
		
	);
	
		rw_req_t pending_req;
	reg req_pending;
	
	always @(posedge clk) begin
		if (req_valid) begin
			pending_req <= req_in;
			req_pending <= 1;
		end else if (req_ack) begin
			req_pending <= 0;
		end
	end
	
	rw_req_t active_req;
	
	word_t req_arg_a = active_req.arg_a;
	word_t req_arg_b = active_req.arg_b;
	handle_t req_handle = active_req.handle;
	logic [3:0] req_flags = active_req.flags;
	block_addr_t req_block = active_req.block;
	
	reg [7:0] state = `LUT_MASTER_STATE_READY;
	
	reg [`LUT_HANDLE_WIDTH - 1 : 0] lut_handle_latched;
	reg [data_width - 1 : 0] req_arg_latched;
	
	reg [data_width - 1 : 0] base_sample;
	reg [data_width - 1 : 0] next_sample;
	
	reg [`LUT_FRAC_WIDTH - 1 : 0] frac;
	
	wire signed [data_width - 1 : 0] interpolated;
	
	reg  interp_start = 0;
	wire interp_valid;
	
	wire [data_width - 1 : 0] tanh_base_sample;
	wire [data_width - 1 : 0] tanh_next_sample;
	wire [`LUT_FRAC_WIDTH - 1 : 0] tanh_frac;
	reg tanh_read = 0;
	wire tanh_valid;

	wire [data_width - 1 : 0] sin_base_sample;
	wire [data_width - 1 : 0] sin_next_sample;
	wire [`LUT_FRAC_WIDTH - 1 : 0] sin_frac;
	reg sin_read = 0;
	wire sin_valid;

	sequential_interp #(.data_width(data_width), .interp_bits(`LUT_FRAC_WIDTH)) interp (
		.clk(clk),
		.reset(reset),
		
		.base(base_sample),
		.target(next_sample),
		.frac(frac),
		.interpolated(interpolated),
		
		.start(interp_start),
		.out_valid(interp_valid)
	);
	
	reg wait_one = 0;

	always @(posedge clk) begin
		wait_one  <= 0;
		sin_read  <= 0;
		tanh_read <= 0;
		
		req_ack <= 0;
		req_invalid <= 0;
		req_response_valid <= 0;
		
		if (reset) begin
			state <= `LUT_MASTER_STATE_READY;
		end else if (enable) begin
			case (state)
				`LUT_MASTER_STATE_READY: begin
					if (req_pending) begin
						req_ack <= 1;
						
						lut_handle_latched 	<= pending_req.handle;
						req_arg_latched 	<= pending_req.arg_a;
						
						state <= `LUT_MASTER_STATE_PROCESSING;
					end
				end
				
				`LUT_MASTER_STATE_PROCESSING: begin
					case (lut_handle_latched)
						// Handle all the built-in LUTs
						`LUT_HANDLE_SIN: begin
							sin_read <= 1;

							state <= `LUT_MASTER_STATE_SIN_WAIT;
							wait_one <= 1;
						end
						
						`LUT_HANDLE_TANH: begin
							tanh_read <= 1;

							state <= `LUT_MASTER_STATE_TANH_WAIT;
							wait_one <= 1;
						end
						
						// If it wasn't one of those, it must be an alloc'd LUT.
						// ... to implement later
						default: begin
							req_invalid <= 1;
						end
					endcase
				end
				
				`LUT_MASTER_STATE_SIN_WAIT: begin
					sin_read <= 0;
					if (!wait_one && sin_valid) begin
						base_sample <= sin_base_sample;
						next_sample <= sin_next_sample;
						frac <= sin_frac;
						
						interp_start <= 1;
						state <= `LUT_MASTER_STATE_WAIT_INTERP1;
					end
				end

				`LUT_MASTER_STATE_TANH_WAIT: begin
					tanh_read <= 0;
					if (!wait_one && tanh_valid) begin
						base_sample <= tanh_base_sample;
						next_sample <= tanh_next_sample;
						frac <= tanh_frac;
						
						interp_start <= 1;
						state <= `LUT_MASTER_STATE_WAIT_INTERP1;
					end
				end

				`LUT_MASTER_STATE_WAIT_INTERP1: begin
					interp_start <= 0;
					state <= `LUT_MASTER_STATE_WAIT_INTERP2;
				end
				
				`LUT_MASTER_STATE_WAIT_INTERP2: begin
					if (interp_valid) begin
						req_response <= interpolated;
						req_response_valid <= 1;
						state <= `LUT_MASTER_STATE_READY;
						wait_one <= 1;
					end
				end
				
				`LUT_MASTER_STATE_SEND: begin
					req_response <= interpolated;
					req_response_valid <= 1;
					state <= `LUT_MASTER_STATE_READY;
					wait_one <= 1;
				end
				
				`LUT_MASTER_STATE_ERROR: begin
					req_invalid <= 1;
				end
			endcase
		end	
	end
	
	sin_2pi_lut_16 sin_lut (
		.clk(clk),
		.reset(reset),

		.x(req_arg_latched),
		.base_sample(sin_base_sample),
		.next_sample(sin_next_sample),
		.frac(sin_frac),

		.read(sin_read),
		.valid(sin_valid)
	);
	
	tanh_4_lut_16 tanh_lut (
		.clk(clk),
		.reset(reset),

		.x(req_arg_latched),
		.base_sample(tanh_base_sample),
		.next_sample(tanh_next_sample),
		.frac(tanh_frac),
	
		.read(tanh_read),
		.valid(tanh_valid)
	);
	
endmodule

`default_nettype wire
