module filter_master #(parameter data_width = 16, parameter math_width = 18, parameter n_filters = 128, parameter mem_size = 2048)
	(
		input wire clk,
		input wire reset,
		input wire enable,
		
		input wire alloc_req,
		input wire [data_width - 1 : 0] order_ff,
		input wire [data_width - 1 : 0] order_fb,
		input wire [7 : 0] alloc_format,
		
		input wire coef_write,
		input wire [7:0] coef_write_handle,
		input wire [data_width - 1 : 0] coef_target,
		input wire signed [math_width - 1 : 0] coef_data,
		
		input wire calc_req,
		input wire [7:0] handle_in,
		input wire signed [data_width - 1 : 0] data_in,
		output reg signed [data_width - 1 : 0] data_out,
		output reg out_valid
	);

	localparam handle_width = $clog2(n_filters);
	localparam addr_width   = $clog2(mem_size);
	localparam degree_width = data_width;
	localparam config_width = 
		   addr_width    // address
		 + degree_width  // feed-forward degree
		 + degree_width  // feed-back degree
		 + 5;			 // format

	reg signed [math_width - 1 : 0] coef_mem   [mem_size  - 1 : 0];
	reg signed [math_width - 1 : 0] state_mem  [mem_size  - 1 : 0];
	reg [config_width - 1 : 0] config_mem [n_filters - 1 : 0];
	
	reg [n_filters - 1 : 0] state_invalid;

	reg        [addr_width - 1 : 0] coef_mem_read_addr;
	reg signed [math_width - 1 : 0] coef_mem_read_val;
	reg        [addr_width - 1 : 0] coef_mem_write_addr;
	reg signed [math_width - 1 : 0] coef_mem_write_val;
	reg coef_mem_write_enable;

	reg        [addr_width - 1 : 0] state_mem_read_addr;
	reg        [addr_width - 1 : 0] state_mem_read_addr_prev;
	reg signed [math_width - 1 : 0] state_mem_read_val;
	reg        [addr_width - 1 : 0] state_mem_write_addr;
	reg signed [math_width - 1 : 0] state_mem_write_val;
	reg state_mem_write_enable;

	reg        [handle_width - 1 : 0] config_mem_read_addr;
	reg signed [config_width - 1 : 0] config_mem_read_val;
	reg        [handle_width - 1 : 0] config_mem_write_addr;
	reg signed [config_width - 1 : 0] config_mem_write_val;
	reg config_mem_write_enable;
	
	always @(posedge clk) begin
		coef_mem_read_val <= coef_mem[coef_mem_read_addr];
		if (coef_mem_write_enable) coef_mem[coef_mem_write_addr] <= coef_mem_write_val;
		
		state_mem_read_val <= state_mem[state_mem_read_addr];
		if (state_mem_write_enable) state_mem[state_mem_write_addr] <= state_mem_write_val;
		
		config_mem_read_val <= config_mem[config_mem_read_addr];
		if (config_mem_write_enable) config_mem[config_mem_write_addr] <= config_mem_write_val;
	end

	reg [handle_width : 0] next_handle;
	reg [addr_width - 1 : 0] next_addr;
	
	reg [addr_width   - 1 : 0] current_addr;
	reg [degree_width - 1 : 0] current_order_ff;
	reg [degree_width - 1 : 0] current_order_fb;
	
	reg busy;
	
	wire filter_capacity = (next_handle < n_filters);
	wire mem_capacity = (next_addr + order_ff + order_fb < mem_size);
	
	reg [addr_width - 1 : 0] coef_target_r;
	reg signed [math_width - 1 : 0] coef_to_write;
	
	reg coef_writing;
	reg wait_one;
	
	reg signed [math_width - 1 : 0] factor_a;
	reg signed [math_width - 1 : 0] factor_b;
	
	wire signed [2 * math_width - 1 : 0] product = factor_a * factor_b;
	wire signed [2 * math_width + 8 - 1 : 0] product_sext = {{8{product[2 * math_width - 1]}}, product};
	
	reg signed [2 * math_width + 8 - 1 : 0] accumulator;
	
	localparam FETCH_CONFIG = 3'd0;
	localparam STARTUP 		= 3'd1;
	localparam FIRST_SAMPLE = 3'd2;
	localparam FEED_FORWARD = 3'd3;
	localparam FEED_BACK	= 3'd4;
	localparam DONE			= 3'd5;
	localparam SHIFT		= 3'd6;
	localparam SEND			= 3'd7;
	
	reg [2:0] run_state;
	reg calc_cooldown;
	
	reg first_sample;
	reg invalid_state;
	
	reg [data_width - 1 : 0] counter;
	
	reg [handle_width - 1 : 0] handle_r;
	reg [4:0] format;
	reg [4:0] shift;

	reg skip_state_write;
	
	always @(posedge clk) begin
		out_valid <= 0;
		wait_one <= 0;
		
		config_mem_write_enable <= 0;
		coef_mem_write_enable   <= 0;
		state_mem_write_enable  <= 0;
		
		state_mem_read_addr_prev <= state_mem_read_addr;
		
		skip_state_write <= 0;
	
		if (reset) begin
			busy <= 0;
			calc_cooldown <= 0;
			next_handle <= 0;
			next_addr <= 0;
			
			state_invalid <= ~0;

			
			current_addr <= 0;
			current_order_ff <= 0;
			current_order_fb <= 0;
			
			coef_target_r <= 0;
			coef_to_write <= 0;
			
			coef_writing <= 0;
			
			factor_a <= 0;
			factor_b <= 0;
			
			accumulator <= 0;
			
			run_state <= 0;
			calc_cooldown <= 0;
			
			first_sample <= 0;
			invalid_state <= 1;
			
			counter <= 0;
			
			handle_r <= 0;
			format <= 0;
			shift <= 0;
		end else if (alloc_req) begin
			if (filter_capacity && mem_capacity) begin
				config_mem_write_addr <= next_handle;
				config_mem_write_val <= {alloc_format[4:0], order_fb[degree_width - 1 : 0], order_ff[degree_width - 1 : 0], next_addr};
				config_mem_write_enable <= 1;
				next_handle <= next_handle + 1;
				next_addr <= next_addr + order_ff + order_fb;
				state_invalid[next_handle] <= 1;
			end
		end else if (coef_write) begin
			config_mem_read_addr <= coef_write_handle;
			coef_target_r <= coef_target[addr_width - 1 : 0];
			coef_to_write <= coef_data;
			coef_writing <= 1;
			wait_one <= 1;
		end else if (coef_writing) begin
			if (!wait_one) begin
				coef_mem_write_addr <= config_mem_read_val[addr_width - 1 : 0] + coef_target_r;
				coef_mem_write_val <= coef_to_write;
				coef_mem_write_enable <= 1;
				coef_writing <= 0;
			end
		end else if (busy) begin
			case (run_state)
				FETCH_CONFIG: begin
					if (!wait_one) begin
						{format, current_order_fb, current_order_ff, current_addr} <= config_mem_read_val;
						coef_mem_read_addr  <= config_mem_read_val[addr_width - 1 : 0];
						state_mem_read_addr <= config_mem_read_val[addr_width - 1 : 0];
						run_state <= STARTUP;
						counter <= 0;
					end
				end
					
				STARTUP: begin
					coef_mem_read_addr <= coef_mem_read_addr + 1;
					run_state <= FIRST_SAMPLE;
				end
				
				FIRST_SAMPLE: begin
					factor_a <= coef_mem_read_val;
					factor_b <= data_in;
					
					coef_mem_read_addr <= coef_mem_read_addr + 1;
					state_mem_read_addr <= state_mem_read_addr + 1;
					
					counter <= 1;
					run_state <= FEED_FORWARD;
				end
				
				FEED_FORWARD: begin
					accumulator <= accumulator + product_sext;
				
					coef_mem_read_addr  <= coef_mem_read_addr  + 1;
					state_mem_read_addr <= state_mem_read_addr + 1;
					
					state_mem_write_addr <= state_mem_read_addr_prev;
					state_mem_write_val  <= factor_b;
					state_mem_write_enable <= 1;
					
					counter <= counter + 1;
					
					factor_a <=  coef_mem_read_val;
					factor_b <= invalid_state ? 0 : state_mem_read_val;
					
					if (counter == current_order_ff - 1) begin
						skip_state_write <= 1;
						if (current_order_fb == 0) begin
							run_state <= DONE;
						end else begin
							run_state <= FEED_BACK;
							counter <= 0;
						end
					end
				end
				
				FEED_BACK: begin
					accumulator <= accumulator + product_sext;
					
					state_mem_write_addr <= state_mem_read_addr_prev;
					state_mem_write_val  <= factor_b;
					state_mem_write_enable <= ~skip_state_write;
					
					coef_mem_read_addr  <= coef_mem_read_addr  + 1;
					state_mem_read_addr <= state_mem_read_addr + 1;
					counter <= counter + 1;
					
					factor_a <=  coef_mem_read_val;
					factor_b <= invalid_state ? 0 : state_mem_read_val;
					
					if (counter == current_order_fb - 1) begin
						run_state <= DONE;
					end
				end
				
				DONE: begin
					accumulator <= accumulator + product_sext;
					run_state <= SHIFT;
					
					shift <= 16 - format;
					
					state_mem_write_addr   <= state_mem_read_addr_prev;
					state_mem_write_val    <= factor_b;
					state_mem_write_enable <= ~skip_state_write;
				end
				
				SHIFT: begin
					if (shift >= 8) begin
						accumulator <= accumulator >>> 8;
						shift <= shift - 8;
					end else if (shift[2]) begin
						accumulator <= accumulator >>> 4;
						shift <= shift & 5'b11011;
					end else if (shift[1]) begin
						accumulator <= accumulator >>> 2;
						shift <= shift & 5'b11101;
					end else if (shift[0]) begin
						accumulator <= accumulator >>> 1;
						shift <= shift & 5'b11110;
					end else begin
						if (current_order_fb != 0) begin
							state_mem_write_addr <= current_addr + current_order_ff - 1;
							state_mem_write_val <= accumulator;
							state_mem_write_enable <= 1;
						end
						run_state <= SEND;
					end
				end
				
				
				SEND: begin
					busy <= 0;
					
					data_out <= accumulator;
					
					out_valid <= 1;
					calc_cooldown <= 1;
					state_invalid[handle_r] <= 0;
				end
			endcase
		end else if (calc_cooldown) begin
			calc_cooldown <= 0;
		end else if (calc_req) begin
			if (handle_in >= next_handle) begin
				out_valid <= 1;
				data_out <= data_in;
			end else begin
				busy <= 1;
				config_mem_read_addr <= handle_in;
				wait_one <= 1;
				accumulator <= 0;
				run_state <= FETCH_CONFIG;
				wait_one <= 1;
				invalid_state <= state_invalid[handle_in];
				handle_r <= handle_in;
			end
		end
	end
endmodule
