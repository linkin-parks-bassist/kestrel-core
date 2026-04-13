`include "controller.vh"
`include "instr_dec.vh"
`include "core.vh"

`default_nettype none

module control_unit
	#(
		parameter n_blocks 			= 256,
		parameter data_width 		= 16,
		parameter filter_width		= 18
	)
	(
		input wire clk,
		input wire reset,
		
		input wire [7:0] in_byte,
		input wire in_valid,
		
		output reg [$clog2(n_blocks)	  - 1 : 0] block_target,
		output reg reg_target,
		output reg [`BLOCK_INSTR_WIDTH	  - 1 : 0] instr_out,
		output reg [data_width 			  - 1 : 0] data_out,
		output reg [2 * data_width 		  - 1 : 0] delay_size_out,
		output reg [2 * data_width 		  - 1 : 0] init_delay_out,
		output reg [data_width 			  - 1 : 0] filter_order_ff_out,
		output reg [data_width 			  - 1 : 0] filter_order_fb_out,
		output reg [7 : 0] filter_alloc_format,
		
		output reg [data_width   - 1 : 0] filter_coef_write_handle_out,
		output reg [data_width   - 1 : 0] filter_coef_target_out,
		output reg [filter_width - 1 : 0] filter_coef_data_out,
		
		output reg [1:0] block_instr_write,
		output reg [1:0] block_reg_0_write,
		output reg [1:0] block_reg_1_write,
		output reg [1:0] filter_coef_write,
		output reg [1:0] filter_coef_commit,
		output reg [1:0] reg_writes_commit,
		input wire [1:0] pipeline_regfiles_syncing,
		output reg [1:0] alloc_delay,
		output reg [1:0] alloc_filter,
		output reg [1:0] pipeline_full_reset,
		input wire [1:0] pipeline_resetting,
		output reg [1:0] pipeline_enables,
		output reg [1:0] pipeline_reset,
		
		input wire [1:0] filter_ack,
		
		output reg swap_pipelines,
		input wire pipelines_swapping,
		output reg current_pipeline,
		
		output reg set_input_gain,
		output reg set_output_gain,
		
		output reg next,
		
		output reg health_monitor_enable,
		output reg health_monitor_reset,
		input wire health,
		
		output wire [7:0] spi_byte_out,
		
		output reg [1:0] pipeline_data_req,
		
		input wire [31:0] pipeline_data_return [1:0],
		input wire [1 :0] pipeline_data_return_valid,

		input wire [63:0] sdram_read_count,
		input wire [63:0] sdram_write_count,

        output reg [`CTRL_DATA_BUS_WIDTH - 1 : 0] ctrl_data_out
	);
	
	wire [7:0] flags;
	
	assign flags[0] = initialised_flag;
	assign flags[1] = busy_flag;
	assign flags[2] = timeout_flag;
	assign flags[3] = programming_flag;
	assign flags[4] = bad_flag;
	assign flags[5] = data_ready_flag;
	assign flags[6] = cmd_err_flag;
	assign flags[7] = swapping;
	
	reg initialised_flag;
	reg swapping;
	reg busy_flag;
	reg timeout_flag;
	wire programming_flag = programming;
	reg bad_flag;
	wire data_ready_flag = data_ready;
	reg cmd_err_flag;
	
	reg [7:0] data_req_type;
	
	reg data_ready;
	
	reg expecting_pipeline_data;
	reg pipeline_data_req_target;
	
	reg returning_data;
	reg [4:0] readout_n_bytes;
	reg [4:0] readout_index;
	reg [8 * 8 -  1 : 0] returned_data;
	
	assign spi_byte_out = returning_data ? returned_data[8 * readout_index +: 8] : flags;
	
	reg [7:0] in_byte_latched;
	reg [7:0] command = 0;
	
	reg [2:0] state = READY;
	reg [2:0] state_prev = READY;
	
	reg [8 * 8 -  1 : 0] command_log;
	
	reg push_command_log;
	
	integer k;
	always @(posedge clk) begin
		if (reset) begin
			command_log <= 0;
		end else if (push_command_log) begin
			command_log <= {command_log[7 * 8 - 1 : 0], command};
		end
	end
	
	reg wait_one = 0;

	wire ready = (state == READY);
	
	localparam block_bytes 		 = 2;
	localparam data_bytes		 = 2;
	localparam instr_bytes   	 = 4;
	localparam delay_addr_bytes  = 3;
	localparam max_bytes_needed  = 6;
	localparam filter_coef_bytes = 3;
	
	reg [$clog2(max_bytes_needed) : 0] byte_ctr;
	reg [$clog2(max_bytes_needed) : 0] bytes_needed;
	reg [max_bytes_needed * 8 - 1 : 0] bytes_in;
	
	wire [7:0] byte_0_in = bytes_in[7:0];
	wire [7:0] byte_1_in = bytes_in[15:8];
	wire [7:0] byte_2_in = bytes_in[23:16];
	wire [7:0] byte_3_in = bytes_in[31:24];
	wire [7:0] byte_4_in = bytes_in[39:32];
	wire [7:0] byte_5_in = bytes_in[47:40];
	
	wire [8 * block_bytes - 1 : 0] instr_write_block;
	wire [8 * block_bytes - 1 : 0] reg_write_block;
	generate
		if (block_bytes == 2) begin
			assign instr_write_block = {byte_5_in, byte_4_in};
			assign reg_write_block = {byte_3_in, byte_2_in};
		end else begin
			assign instr_write_block = byte_4_in;
			assign reg_write_block = byte_2_in;
		end
	endgenerate
	
    localparam READY      		  = 3'd0;
    localparam LISTEN     		  = 3'd1;
    localparam EXECUTE    		  = 3'd2;
    localparam SWAP_WARMUP  	  = 3'd3;
    localparam SWAP_WAIT  		  = 3'd4;
    localparam RESET_WAIT 		  = 3'd5;
    localparam INITIAL_RESET_WAIT = 3'd6;
    localparam FILTER_COMMIT_WAIT = 3'd7;

	wire front_pipeline = current_pipeline;
	wire back_pipeline = ~current_pipeline;

    reg [15 : 0] total_bytes;
    
    reg [31:0] timeout_ctr;
    reg [31:0] timeout_max;
    reg timeout;
    
    wire timeout_blinker = |timeout_blinker_ctr;
    reg [31:0] timeout_blinker_ctr;
    
    reg programming;
    reg ignore_command;
    reg timeout_active;
    
    localparam warmup_cycles = 326530;
    
    reg warmup;
    reg [31:0] warmup_ctr;

	always @(posedge clk) begin
		reg_writes_commit <= 0;
		wait_one <= 0;
		
		swapping <= 0;
		next <= 0;
		
		swap_pipelines <= 0;
		pipeline_reset <= 0;
		pipeline_full_reset <= 0;
		
		block_instr_write <= 0;
		block_reg_0_write <= 0;
		block_reg_1_write <= 0;
		
		alloc_delay <= 0;
		alloc_filter <= 0;
		filter_coef_write <= 0;
		
		set_input_gain  <= 0;
		set_output_gain <= 0;

        timeout <= 0;
        
        state_prev <= state;
        
        health_monitor_reset <= 0;
		
		pipeline_enables <= 2'b00;
		
		pipeline_data_req <= 0;
		
		push_command_log <= 0;
		
		if (reset) begin
			state 		<= INITIAL_RESET_WAIT;
            state_prev  <= INITIAL_RESET_WAIT;
            
			pipeline_full_reset <= 2'b11;
			wait_one <= 1;
			current_pipeline <= 0;
			
			byte_ctr <= 0;
			bytes_in <= 0;

			health_monitor_enable <= 0;

            total_bytes <= 0;
            
            programming <= 0;
            reg_target <= 0;
            
            ignore_command <= 0;
            timeout_active <= 0;
			
			ignore_command <= 0;
            
			timeout_ctr <= 0;
            timeout_max <= `CONTROLLER_TIMEOUT_CYCLES;
            
            data_ready		  <= 0;
			returning_data 	  <= 0;
			readout_n_bytes   <= 0;
			readout_index 	  <= 0;
			returned_data[0]  <= 0;
			returned_data[1]  <= 0;
			returned_data[2]  <= 0;
			returned_data[3]  <= 0;
			
			initialised_flag 	<= 0;
			busy_flag 			<= 0;
			timeout_flag 		<= 0;
			bad_flag 			<= 0;
			cmd_err_flag		<= 0;
		end else if (timeout) begin
			pipeline_full_reset[back_pipeline] <= 1;
			programming 	<= 0;
			timeout_active 	<= 0;
			timeout_ctr 	<= 0;
			timeout 		<= 0;
			ignore_command  <= 0;
			state 			<= RESET_WAIT;
            timeout_max 	<= `CONTROLLER_TIMEOUT_CYCLES;
            timeout_flag	<= 1;
            
            timeout_blinker_ctr <= 32'd112500000;
		end else begin
			if (timeout_active | programming) begin
				if ((wait_one && in_valid) || state_prev != state)
					timeout_ctr <= 0;
				else if (timeout_ctr == timeout_max - 1)
					timeout <= 1;
				else
					timeout_ctr <= timeout_ctr + 1;
			end else begin
				timeout_ctr <= 0;
			end
			
			if (timeout_blinker_ctr != 0)
				timeout_blinker_ctr <= timeout_blinker_ctr - 1;
		
			if (expecting_pipeline_data && pipeline_data_return_valid[pipeline_data_req_target]) begin
				returned_data <= pipeline_data_return[pipeline_data_req_target];
				expecting_pipeline_data <= 0;
				data_ready <= 1;
			end
			
			// Ignore null bytes when not actively recieving data;
			// they are used for reading the flags, so drain them
			// from the FIFO before it fills up
			if (state != READY && state != LISTEN && in_valid && in_byte == 0)
				next <= 1;
			
			case (state)
				READY: begin
					busy_flag <= 0;
					timeout_active <= 0;
					ignore_command <= 0;
					
					if (!wait_one && in_valid) begin
						command <= in_byte;
						push_command_log <= 1;
						
						wait_one <= 1;
						next <= 1;
						
						state <= LISTEN;
						
						byte_ctr <= 0;
						bytes_in <= 0;

                        total_bytes <= total_bytes + 1;
						
						returning_data <= 0;
						
						case (in_byte)
							`COMMAND_BEGIN_PROGRAM: begin
								programming <= 1;
								state <= READY;
							end
						
							`COMMAND_WRITE_BLOCK_INSTR: begin
								bytes_needed <= block_bytes + instr_bytes;
								
								if (!programming) ignore_command <= 1;
							end
							
							`COMMAND_WRITE_BLOCK_REG_0: begin
								reg_target <= 0;
								bytes_needed <= block_bytes + data_bytes;
								
								if (!programming) ignore_command <= 1;
							end
							
							
							`COMMAND_WRITE_BLOCK_REG_1: begin
								reg_target <= 1;
								bytes_needed <= block_bytes + data_bytes;
								
								if (!programming) ignore_command <= 1;
							end
							
							`COMMAND_ALLOC_DELAY: begin
								bytes_needed <= 2 * delay_addr_bytes;
								
								if (!programming) ignore_command <= 1;
							end
							
							`COMMAND_UPDATE_BLOCK_REG_0: begin
								reg_target <= 0;
								bytes_needed <= block_bytes + data_bytes;
							end
							
							`COMMAND_UPDATE_BLOCK_REG_1: begin
								reg_target <= 1;
								bytes_needed <= block_bytes + data_bytes;
							end
							
							`COMMAND_COMMIT_REG_UPDATES: begin
								reg_writes_commit[front_pipeline] <= 1;
								state <= READY;
							end
							
							`COMMAND_END_PROGRAM: begin
								if (programming) begin
									programming <= 0;
									
									reg_writes_commit[back_pipeline] <= 1;
									pipeline_enables [back_pipeline] <= 1;
									
									health_monitor_enable <= 1;
									health_monitor_reset <= 1;
									
									warmup_ctr <= 0;
									
									state <= SWAP_WARMUP;
								end else begin
									state <= READY;
								end
							end
							
							`COMMAND_SET_INPUT_GAIN: begin
								bytes_needed <= data_bytes;
							end
							
							`COMMAND_SET_OUTPUT_GAIN: begin
								bytes_needed <= data_bytes;
							end
							
							`COMMAND_ALLOC_FILTER: begin
								bytes_needed <= data_bytes + data_bytes + 1;
								if (!programming) ignore_command <= 1;
							end
							
							`COMMAND_WRITE_FILTER_COEF: begin
								bytes_needed <= 1 + 2 + filter_coef_bytes;
								if (!programming) ignore_command <= 1;
							end
							
							`COMMAND_UPDATE_FILTER_COEF: begin
								bytes_needed <= 1 + 2 + filter_coef_bytes;
							end
							
							`COMMAND_COMMIT_FILTER_COEF: begin
								state <= FILTER_COMMIT_WAIT;
								filter_coef_commit[front_pipeline] <= 1;
							end
							
							`COMMAND_READOUT: begin
								if (returning_data) begin
									cmd_err_flag <= 0;
									if (readout_index == 0) begin
										data_ready <= 0;
									end else begin
										readout_index <= readout_index - 1;
										returning_data <= 1;
									end
								end else begin
									if (data_ready) begin
										returning_data <= 1;
										readout_index <= readout_n_bytes - 1;
									end else begin
										cmd_err_flag <= 1;
									end
								end
								state <= READY;
								push_command_log <= 0;
							end
							
							`COMMAND_READ: begin
								bytes_needed <= 1;
							end
							
							`COMMAND_CLEAR_TIMEOUT_FLAG: begin
								timeout_flag <= 0;
								state <= READY;
							end
							
							`COMMAND_CLEAR_BAD_FLAG: begin
								bad_flag <= 0;
								state <= READY;
							end
							
							`COMMAND_CLEAR_CMD_ERR_FLAG: begin
								cmd_err_flag <= 0;
								state <= READY;
							end
							
							default: begin
								state <= READY;
							end
						endcase
					end
				end
				
				LISTEN: begin
					timeout_active <= 1;
					if (!wait_one && in_valid) begin
						bytes_in <= (bytes_in << 8) | in_byte;
						byte_ctr <= byte_ctr + 1;
						
						next <= 1;
						wait_one <= 1;
						
						// If we're doing a read command, use the first byte in
						// to see how many more bytes we need to obtain
						if (command == `COMMAND_READ && byte_ctr == 0) begin
							data_req_type <= in_byte;
							byte_ctr <= 1;
							
							case (in_byte)
								`DATA_REQ_N_BLOCKS: begin
									ctrl_data_out[7:0] <= `DATA_REQ_N_BLOCKS;
									pipeline_data_req[current_pipeline] <= 1;
									expecting_pipeline_data <= 1;
									pipeline_data_req_target <= current_pipeline;
									readout_n_bytes <= 2;
									state <= READY;
								end
								
								`DATA_REQ_BLOCK_INSTR: begin
									bytes_needed <= block_bytes + 1;
								end
								
								`DATA_REQ_BLOCK_REG: begin
									bytes_needed <= block_bytes + 1 + 1;
								end
								
								`DATA_REQ_N_DELAY_BUF: begin
									ctrl_data_out[7:0] <= `DATA_REQ_N_DELAY_BUF;
									pipeline_data_req[current_pipeline] <= 1;
									expecting_pipeline_data <= 1;
									pipeline_data_req_target <= current_pipeline;
									readout_n_bytes <= 2;
									state <= READY;
								end
								
								`DATA_REQ_DELAY_BUF_SIZE: begin
									bytes_needed <= 2 + 1;
								end
								
								`DATA_REQ_DELAY_BUF_DELAY: begin
									bytes_needed <= 2 + 1;
								end
								
								`DATA_REQ_DELAY_BUF_ADDR: begin
									bytes_needed <= 2 + 1;
								end
								
								`DATA_REQ_DELAY_BUF_POS: begin
									bytes_needed <= 2 + 1;
								end
								
								`DATA_REQ_DELAY_BUF_GAIN: begin
									bytes_needed <= 2 + 1;
								end
								
								`DATA_REQ_DELAY_BUF_LRWA: begin
									bytes_needed <= 2 + 1;
								end
								
								`COMMAND_READ_COMMAND_LOG: begin
									returned_data <= command_log;
									push_command_log <= 0;
									readout_n_bytes <= 8;
									data_ready <= 1;
									state <= READY;
								end
								
								`DATA_REQ_SAMPLE_COUNT: begin
									ctrl_data_out[7:0] <= `DATA_REQ_SAMPLE_COUNT;
									pipeline_data_req[current_pipeline] <= 1;
									expecting_pipeline_data <= 1;
									pipeline_data_req_target <= current_pipeline;
									readout_n_bytes <= 8;
									state <= READY;
								end
								
								`DATA_REQ_SDRAM_READ_CNT: begin
									returned_data[63:0] <= sdram_read_count;
									readout_n_bytes <= 8;
									data_ready <= 1;
									state <= READY;
								end
								
								`DATA_REQ_SDRAM_WRITE_CNT: begin
									returned_data[63:0] <= sdram_write_count;
									readout_n_bytes <= 8;
									data_ready <= 1;
									state <= READY;
								end
								
								`DATA_REQ_STUCK_FLAGS: begin
									ctrl_data_out[7:0] <= `DATA_REQ_STUCK_FLAGS;
									pipeline_data_req[current_pipeline] <= 1;
									expecting_pipeline_data <= 1;
									pipeline_data_req_target <= current_pipeline;
									readout_n_bytes <= 4;
									state <= READY;
								end

								default: begin
									cmd_err_flag <= 1;
									state <= READY;
								end
							endcase
						end else if (byte_ctr == bytes_needed - 1) begin
							state <= ignore_command ? READY : EXECUTE;
							timeout_active <= 0;
						end
					end
				end
				
				EXECUTE: begin
                    ctrl_data_out <= bytes_in;
					case (command)
						`COMMAND_WRITE_BLOCK_INSTR: begin
							block_target <= instr_write_block;
							
							instr_out 	 <= {byte_3_in, byte_2_in, byte_1_in, byte_0_in};
							block_instr_write[back_pipeline] <= 1;
							state <= READY;
							wait_one <= 1;
						end

						`COMMAND_WRITE_BLOCK_REG_0: begin
							timeout_active <= 1;
							if (!pipelines_swapping && !pipeline_resetting[back_pipeline] && !pipeline_regfiles_syncing[back_pipeline]) begin
								data_out <= {byte_1_in, byte_0_in};
								block_reg_0_write[back_pipeline] <= 1;
								state <= READY;
							end
						end
						
						`COMMAND_WRITE_BLOCK_REG_1: begin
							timeout_active <= 1;
							if (!pipelines_swapping && !pipeline_resetting[back_pipeline] && !pipeline_regfiles_syncing[back_pipeline]) begin
								data_out <= {byte_1_in, byte_0_in};
								block_reg_1_write[back_pipeline] <= 1;
								state <= READY;
							end
						end

						`COMMAND_ALLOC_DELAY: begin
							delay_size_out <= {8'd0, byte_5_in, byte_4_in, byte_3_in};
							init_delay_out <= {8'd0, byte_2_in, byte_1_in, byte_0_in};
							alloc_delay[back_pipeline] <= 1;
							state <= READY;
						end

						`COMMAND_UPDATE_BLOCK_REG_0: begin
							timeout_active <= 1;
							if (pipelines_swapping) begin
								state <= READY;
							end else if (!pipeline_regfiles_syncing[front_pipeline]) begin
								data_out <= {byte_1_in, byte_0_in};
								block_reg_0_write[front_pipeline] <= 1;
								state <= READY;
							end
						end

						`COMMAND_UPDATE_BLOCK_REG_1: begin
							timeout_active <= 1;
							if (pipelines_swapping) begin
								state <= READY;
							end else if (!pipeline_regfiles_syncing[front_pipeline]) begin
								data_out <= {byte_1_in, byte_0_in};
								block_reg_1_write[front_pipeline] <= 1;
								state <= READY;
							end
						end
						
						`COMMAND_SET_INPUT_GAIN: begin
							data_out <= {byte_1_in, byte_0_in};
							set_input_gain <= 1;
							state <= READY;
						end

						`COMMAND_SET_OUTPUT_GAIN: begin
							data_out <= {byte_1_in, byte_0_in};
							set_output_gain <= 1;
							state <= READY;
						end
						
						`COMMAND_ALLOC_FILTER: begin
							filter_alloc_format <= byte_4_in;
							filter_order_ff_out <= {byte_3_in, byte_2_in};
							filter_order_fb_out <= {byte_1_in, byte_0_in};
							alloc_filter[back_pipeline] <= 1;
							state <= READY;
						end
						
						`COMMAND_WRITE_FILTER_COEF: begin
							filter_coef_write_handle_out <= {byte_5_in};
							filter_coef_target_out <= {byte_4_in, byte_3_in};
							filter_coef_data_out <= {byte_2_in[1:0], byte_1_in, byte_0_in};
							filter_coef_write[back_pipeline] <= 1;
							filter_coef_commit[back_pipeline] <= 1;
							busy_flag <= 1;
							
							if (filter_coef_write[back_pipeline] && filter_ack[back_pipeline]) begin
								state <= READY;
								filter_coef_write[back_pipeline] <= 0;
								filter_coef_commit[back_pipeline] <= 0;
								wait_one <= 1;
								busy_flag <= 0;
							end
						end
						
						`COMMAND_UPDATE_FILTER_COEF: begin
							filter_coef_write_handle_out <= {byte_5_in};
							filter_coef_target_out <= {byte_4_in, byte_3_in};
							filter_coef_data_out <= {byte_2_in[1:0], byte_1_in, byte_0_in};
							filter_coef_write[front_pipeline] <= 1;
							filter_coef_commit[front_pipeline] <= 0;
							busy_flag <= 1;
							
							if (filter_coef_write[front_pipeline] && filter_ack[front_pipeline]) begin
								state <= READY;
								filter_coef_write[front_pipeline] <= 0;
								filter_coef_commit[front_pipeline] <= 0;
								wait_one <= 1;
								busy_flag <= 0;
							end
						end
						
						`COMMAND_READ: begin
							ctrl_data_out <= {bytes_in[`CTRL_DATA_BUS_WIDTH - 8 - 1 : 0], data_req_type};
							
							case (data_req_type)
								`COMMAND_GET_BLOCK_INSTR: 		readout_n_bytes <= 4;
								`COMMAND_GET_BLOCK_REG: 		readout_n_bytes <= data_bytes;
								`COMMAND_GET_DELAY_BUF_SIZE: 	readout_n_bytes <= 3;
								`COMMAND_GET_DELAY_BUF_DELAY: 	readout_n_bytes <= 3;
								`COMMAND_GET_DELAY_BUF_ADDR: 	readout_n_bytes <= 3;
								`COMMAND_GET_DELAY_BUF_POS: 	readout_n_bytes <= 3;
								`COMMAND_GET_DELAY_BUF_GAIN: 	readout_n_bytes <= 2;
								`COMMAND_GET_DELAY_BUF_LRWA: 	readout_n_bytes <= 4;
								default:						readout_n_bytes <= 2;
							endcase
							
							pipeline_data_req_target <= current_pipeline;
							pipeline_data_req[current_pipeline] <= 1;
							expecting_pipeline_data <= 1;
							
							state <= READY;
						end
						
						default: begin
							state <= READY;
						end
					endcase
				end
				
				SWAP_WARMUP: begin
					swapping <= 1;
					
					if (warmup_ctr == warmup_cycles) begin
						if (health) begin
							swap_pipelines <= 1;
							
							swap_pipelines <= 1;
							
							state <= SWAP_WAIT;
							
							wait_one <= 1;
						end else begin
							pipeline_full_reset[back_pipeline] <= 1;
							state <= READY;
							
							bad_flag <= 1;
						end
						
						health_monitor_enable <= 0;
						health_monitor_reset <= 1;
						
						warmup_ctr <= 0;
					end else begin
						warmup_ctr <= warmup_ctr + 1;
					end
				end
				
				SWAP_WAIT: begin
					swapping <= 1;
					if (!wait_one && !pipelines_swapping) begin
						current_pipeline <= ~current_pipeline;
						pipeline_full_reset[front_pipeline] <= 1;
						pipeline_enables   [front_pipeline] <= 0;
						
						wait_one <= 1;
						state <= RESET_WAIT;
					end
				end
				
				RESET_WAIT: begin
					if (!wait_one && !(|pipeline_resetting)) begin
						state <= READY;
					end
				end
				
				INITIAL_RESET_WAIT: begin
					if (!wait_one && !(|pipeline_resetting[front_pipeline])) begin
						state <= READY;
						pipeline_enables[front_pipeline] <= 1;
						
						initialised_flag <= 1;
					end
				end
				
				FILTER_COMMIT_WAIT: begin
					if (~wait_one & filter_ack[front_pipeline]) begin
						filter_coef_commit <= 0;
						state <= READY;
					end
				end
			endcase
		end
	end
endmodule

`default_nettype wire
