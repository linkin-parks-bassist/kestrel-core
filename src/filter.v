`include "filter.vh"
`include "defs.vh"

module filter_unit_normal
	(
		input wire clk,
		input wire reset,
		input wire enable,
		
		input wire alloc_req,
		
		input wire coef_write,
		input wire coef_commit,
		input wire [7:0] coef_write_handle,
		input wire [data_width - 1 : 0] coef_target,
		input wire signed [math_width - 1 : 0] coef_data,
		
		output reg coef_ack,
		
		output reg req_ack,
		input wire req_valid,
		input rw_req_t req_in,
		output reg req_invalid,
		output reg [data_width - 1 : 0] req_response,
		output reg req_response_valid,

        input wire [`CTRL_DATA_BUS_WIDTH - 1 : 0] ctrl_data_in,
        
        output wire stuck
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
	
	wire [data_width - 1 : 0] req_arg_a = active_req.arg_a;
	wire [data_width - 1 : 0] req_arg_b = active_req.arg_b;
	wire [7 : 0] req_handle = active_req.handle;
	wire [3:0] req_flags = active_req.flags;
	wire [`BLOCK_ADDR_W - 1 : 0] req_block = active_req.block;
	
	reg [$clog2(`CYCLES_PER_SAMPLE) : 0] stuck_ctr;
	assign stuck = (stuck_ctr == `CYCLES_PER_SAMPLE);
	
	always @(posedge clk) begin
		if (reset || next_handle == 0 || run_state != run_state_prev)
			stuck_ctr <= 0;
		else if (enable && stuck_ctr < `CYCLES_PER_SAMPLE)
			stuck_ctr <= stuck_ctr + 1;
	end
	
	localparam handle_width = $clog2(`N_FILTERS);
	localparam addr_width   = $clog2(`FILTER_MEM_SIZE);
	
	localparam degree_width = data_width;
	localparam config_width = 
		   addr_width    // address
		 + degree_width  // feed-forward degree
		 + degree_width  // feed-back degree
		 + 5			 // format
		 + 1;			 // coef bank
	
	reg [3:0] req_type_r;

    reg alloc_req_r;
    reg coef_write_r;
    reg coef_commit_r;

    reg [7 : 0] alloc_format_r;
    reg [data_width - 1 : 0] order_ff_r;
	reg [data_width - 1 : 0] order_fb_r;

    reg [7:0] coef_write_handle_r;
    reg [7:0] coef_commit_handle_r;
    reg [data_width - 1 : 0] coef_target_r;
    reg signed [math_width - 1 : 0] coef_data_r;

    always @(posedge clk) begin
        if (reset) begin
            alloc_req_r <= 0;
            coef_write_r <= 0;
            coef_commit_r <= 0;
        end else begin
            alloc_req_r <= alloc_req;
            coef_write_r <= coef_write;
            coef_commit_r <= coef_commit;
            
            order_fb_r <= ctrl_data_in[7 : 0];
            order_ff_r <= ctrl_data_in[15 : 8];
            alloc_format_r <= ctrl_data_in[23 : 16];

            coef_write_handle_r <= ctrl_data_in[6 * 8 - 1 : 5 * 8];
            coef_commit_handle_r <= ctrl_data_in[7 : 0];
            coef_target_r <= ctrl_data_in[24 + 2 * 8 - 1 : 24];
            coef_data_r <= ctrl_data_in[data_width - 1 + math_width - data_width : 0];
        end
    end

	reg signed [math_width - 1 : 0] coef_mem_a [`FILTER_MEM_SIZE  - 1 : 0];
	reg signed [math_width - 1 : 0] coef_mem_b [`FILTER_MEM_SIZE  - 1 : 0];
	reg signed [math_width - 1 : 0] state_mem  [`FILTER_MEM_SIZE  - 1 : 0];
	reg [config_width - 1 : 0] config_mem [`N_FILTERS - 1 : 0];
	
	reg [`N_FILTERS - 1 : 0] state_invalid;

	reg         [addr_width - 1 : 0] coef_mem_read_addr;
	reg signed  [math_width - 1 : 0] coef_mem_a_read_val;
	reg signed  [math_width - 1 : 0] coef_mem_b_read_val;
	wire signed [math_width - 1 : 0] coef_mem_read_val = coef_bank ? coef_mem_b_read_val : coef_mem_a_read_val;
	reg         [addr_width - 1 : 0] coef_mem_write_addr;
	reg signed  [math_width - 1 : 0] coef_mem_write_val;
	reg coef_mem_a_write_enable;
	reg coef_mem_b_write_enable;

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
		coef_mem_a_read_val <= coef_mem_a[coef_mem_read_addr];
		if (coef_mem_a_write_enable) coef_mem_a[coef_mem_write_addr] <= coef_mem_write_val;
		
		coef_mem_b_read_val <= coef_mem_b[coef_mem_read_addr];
		if (coef_mem_b_write_enable) coef_mem_b[coef_mem_write_addr] <= coef_mem_write_val;
		
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
	
	wire filter_capacity = (next_handle < `N_FILTERS);
	wire mem_capacity = (next_addr + order_ff_r + order_fb_r < `FILTER_MEM_SIZE);
	
	reg [addr_width - 1 : 0] coef_target_addr;
	reg signed [math_width - 1 : 0] coef_to_write;
	
	reg coef_writing;
	reg coef_committing;
	reg wait_one;
	
	reg signed [math_width - 1 : 0] factor_a;
	reg signed [math_width - 1 : 0] factor_b;
	
	wire signed [2 * math_width - 1 : 0] product = factor_a * factor_b;
	wire signed [2 * math_width + 8 - 1 : 0] product_sext = {{8{product[2 * math_width - 1]}}, product};
	wire signed [2 * math_width + 8 - 1 : 0] product_sum = accumulator + product_sext;
	
	reg signed [2 * math_width + 8 - 1 : 0] accumulator;
	
	localparam signed [2 * math_width + 8 - 1  : 0] sat_max = ( 1 << (data_width - 1)) - 1;
	localparam signed [2 * math_width + 8 - 1  : 0] sat_min = (-1 << (data_width - 1));
	
	localparam signed [data_width - 1  : 0] sat_max_t = ( 1 << (data_width - 1)) - 1;
	localparam signed [data_width - 1  : 0] sat_min_t = (-1 << (data_width - 1));
	
	wire signed [data_width - 1 : 0] acc_t = accumulator[data_width - 1 : 0];
	wire signed [data_width - 1 : 0] resul_sat = (accumulator > sat_max) ? sat_max_t : ((accumulator < sat_min) ? sat_min_t : acc_t);
	
	localparam FETCH_CONFIG = 3'd0;
	localparam STARTUP 		= 3'd1;
	localparam FIRST_SAMPLE = 3'd2;
	localparam FEED_FORWARD = 3'd3;
	localparam FEED_BACK	= 3'd4;
	localparam DONE			= 3'd5;
	localparam SHIFT		= 3'd6;
	localparam SEND			= 3'd7;
	
	reg [2:0] run_state_prev;
	reg [2:0] run_state;
	reg calc_cooldown;
	reg coef_write_cooldown;
	reg coef_commit_cooldown;
	
	always @(posedge clk)
		run_state_prev <= run_state;
	
	reg first_sample;
	reg invalid_state;
	
	reg [data_width - 1 : 0] counter;
	
	reg [handle_width - 1 : 0] handle_r;
	reg [5:0] format;
	reg [8:0] shift;
	reg coef_bank;
	
	reg calculating;
	
	reg write_back;

	reg skip_state_write;
	
	reg signed [data_width - 1 : 0] data_in_r;
	
	wire signed [2 * data_width - 1 : 0] next_pow_p = data_in_r * pow;
	wire signed [data_width - 1 : 0] next_pow = next_pow_p >>> (data_width - 1);
	
	reg signed [data_width : 0] pow;
	
	wire poly_mode = (req_type_r == `FILTER_REQ_TYPE_POLY);
	
	always @(posedge clk) begin
		req_response_valid <= 0;
		wait_one <= 0;
		
		config_mem_write_enable <= 0;
		coef_mem_a_write_enable <= 0;
		coef_mem_b_write_enable <= 0;
		state_mem_write_enable  <= 0;
		
		state_mem_read_addr_prev <= state_mem_read_addr;
		
		skip_state_write <= 0;
		
		coef_ack <= 0;
		
		calc_cooldown <= 0;
		coef_write_cooldown <= coef_ack;
		coef_commit_cooldown <= coef_ack;
	
		if (reset) begin
			busy <= 0;
			calc_cooldown <= 0;
			next_handle <= 0;
			next_addr <= 0;
			
			state_invalid <= ~0;

			req_response <= 0;
			
			current_addr <= 0;
			current_order_ff <= 0;
			current_order_fb <= 0;
			
			coef_target_addr <= 0;
			coef_to_write <= 0;
			
			coef_committing <= 0;
			coef_writing <= 0;
			calculating <= 0;
			
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
			
			req_type_r <= 0;
		end else if (busy) begin
			if (coef_writing) begin
				if (!wait_one) begin
					coef_mem_write_addr <= config_mem_read_val[addr_width : 1] + coef_target_addr;
					coef_mem_write_val <= coef_to_write;
					{coef_mem_b_write_enable, coef_mem_a_write_enable} <= {write_back ^ config_mem_read_val[0], write_back ^ ~config_mem_read_val[0]};
					coef_commit_cooldown <= 1;
					coef_write_cooldown <= 1;
					coef_writing <= 0;
					coef_ack <= 1;
					busy <= 0;
				end
			end else if (coef_committing) begin
				if (!wait_one) begin
					config_mem_write_val <= {config_mem_read_val[config_width - 1 : 1], ~config_mem_read_val[0]};
					config_mem_write_enable <= 1;
					coef_commit_cooldown <= 1;
					coef_committing <= 0;
					coef_ack <= 1;
					busy <= 0;
				end
			end else if (calculating) begin
				case (run_state)
					FETCH_CONFIG: begin
						if (!wait_one) begin
							{format, current_order_fb, current_order_ff, current_addr, coef_bank} <= config_mem_read_val;
							coef_mem_read_addr  <= config_mem_read_val[addr_width : 1];
							state_mem_read_addr <= config_mem_read_val[addr_width : 1];
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
						factor_b <= poly_mode ? pow : data_in_r;
						
						pow <= next_pow;
						
						coef_mem_read_addr <= coef_mem_read_addr + 1;
						state_mem_read_addr <= state_mem_read_addr + 1;
						
						counter <= 1;
						run_state <= FEED_FORWARD;
					end
					
					FEED_FORWARD: begin
						accumulator <= accumulator + product_sext;
					
						coef_mem_read_addr  <= coef_mem_read_addr  + 1;
						state_mem_read_addr <= state_mem_read_addr + 1;
						
						if (!poly_mode) begin
							state_mem_write_addr <= state_mem_read_addr_prev;
							state_mem_write_val  <= factor_b;
							state_mem_write_enable <= 1;
						end
						
						counter <= counter + 1;
						
						factor_a <=  coef_mem_read_val;
						factor_b <= poly_mode ? pow : (invalid_state ? 0 : state_mem_read_val);
						
						pow <= next_pow;
						
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
						accumulator <= product_sum;
						
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
						accumulator <= product_sum;
						run_state <= SHIFT;
						
						shift <= math_width - 1 - format;
						
						if (!poly_mode) begin
							state_mem_write_addr   <= state_mem_read_addr_prev;
							state_mem_write_val    <= factor_b;
							state_mem_write_enable <= ~skip_state_write;
						end
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
							if (current_order_fb != 0 && ~poly_mode) begin
								state_mem_write_addr <= current_addr + current_order_ff - 1;
								state_mem_write_val <= accumulator;
								state_mem_write_enable <= 1;
							end
							run_state <= SEND;
						end
					end
					
					
					SEND: begin
						busy <= 0;
						
						req_response <= resul_sat;
						
						req_response_valid <= 1;
						calculating <= 0;
						calc_cooldown <= 1;
						state_invalid[handle_r] <= 0;
					end
				endcase
			end 
		end else begin
			if (alloc_req_r) begin
				if (filter_capacity && mem_capacity) begin
					config_mem_write_addr <= next_handle;
					config_mem_write_val <= {alloc_format_r[4:0], order_fb_r[degree_width - 1 : 0], order_ff_r[degree_width - 1 : 0], next_addr, 1'b0};
					config_mem_write_enable <= 1;
					next_handle <= next_handle + 1;
					next_addr <= next_addr + order_ff_r + order_fb_r;
					state_invalid[next_handle] <= 1;
				end
			end else if (~coef_write_cooldown & coef_write_r) begin
				config_mem_read_addr <= coef_write_handle_r;
				coef_target_addr <= coef_target_r[addr_width - 1 : 0];
				coef_to_write <= coef_data_r;
				write_back <= ~coef_commit_r;
				coef_writing <= 1;
				wait_one <= 1;
				busy <= 1;
			end else if (~coef_commit_cooldown & coef_commit_r) begin
				config_mem_read_addr <= coef_commit_handle_r;
				coef_committing <= 1;
				wait_one <= 1;
				busy <= 1;
			end else if (req_pending) begin
				req_ack <= 1;
			
				if (pending_req.handle >= next_handle) begin
					req_response_valid <= 1;
					req_response <= pending_req.arg_a;
				end else begin
					busy <= 1;
					wait_one <= 1;
					calculating <= 1;
					
					config_mem_read_addr <= pending_req.handle;
					
					accumulator <= 0;
					
					invalid_state <= state_invalid[pending_req.handle];
					
					handle_r <= pending_req.handle;
					data_in_r <= pending_req.flags[0] ? req_response : pending_req.arg_a;
					req_type_r <= pending_req.flags;
					
					if (pending_req.flags == `FILTER_REQ_TYPE_POLY) begin
						pow <= (1 << data_width - 1);
					end
					
					run_state <= FETCH_CONFIG;
				end
			end
		end
	end
endmodule

module filter_unit_svf
	(
		input wire clk,
		input wire reset,
		
		input wire enable,
		
		output reg req_ack,
		input wire req_valid,
		output reg req_invalid,
		input filter_rw_req_t req_in,
		
		output reg low_valid,
		output reg band_valid,
		output reg high_valid,
		
		output reg signed [data_width - 1 : 0] low_out,
		output reg signed [data_width - 1 : 0] band_out,
		output reg signed [data_width - 1 : 0] high_out
	);
	
	filter_rw_req_t pending_req;
	reg req_pending;
	
	always @(posedge clk) begin
		if (req_valid) begin
			pending_req <= req_in;
			req_pending <= 1;
		end else if (req_ack) begin
			req_pending <= 0;
		end
	end
	
	filter_rw_req_t active_req;
	
	wire        [data_width - 1 : 0] req_arg_a = active_req.arg_a;
	wire        [data_width - 1 : 0] req_arg_b = active_req.arg_b;
	wire        [data_width - 1 : 0] req_arg_c = active_req.arg_c;
	wire        [data_width - 1 : 0] req_shift = active_req.shift;
	wire [7 : 0] req_handle = active_req.handle;
	wire [3:0] req_flags = active_req.flags;
	wire [`BLOCK_ADDR_W - 1 : 0] req_block = active_req.block;
	
	localparam handle_addr_width = $clog2(`N_SVF);
	
	reg signed [2 * math_width - 1 : 0] state_mem [`N_SVF - 1 : 0];
	reg signed [2 * math_width - 1 : 0] state_mem_write_val;
	reg signed [2 * math_width - 1 : 0] state_mem_read_val;
	reg [handle_addr_width  - 1 : 0] state_mem_write_addr;
	reg [handle_addr_width  - 1 : 0] state_mem_read_addr;
	
	reg state_mem_write_enable;
	
	always @(posedge clk) begin
		if (state_mem_write_enable)
			state_mem[state_mem_write_addr] <= state_mem_write_val;
		
		state_mem_read_val <= state_mem[state_mem_read_addr];
	end
	
	reg [handle_addr_width - 1 : 0] n_slots_used;
	
	logic signed [data_width - 1 : 0] arg_a_pending = pending_req.arg_a;
	
	reg signed [math_width - 1 : 0] data_in_r;
	reg signed [math_width - 1 : 0] cutoff_in_r;
	reg signed [math_width - 1 : 0] d_in_r;
	reg [4 : 0] shift_in_r;
	
	reg signed [math_width - 1 : 0] low;
	reg signed [math_width - 1 : 0] band;
	reg signed [math_width - 1 : 0] high;
	
	reg [handle_addr_width - 1 : 0] prev_slot;
	reg [handle_addr_width - 1 : 0] current_slot;
	reg [`BLOCK_ADDR_W  - 1 : 0] prev_block;
	
	reg signed [math_width - 1 : 0] factor_a;
	reg signed [math_width - 1 : 0] factor_b;
	
	wire signed [2 * math_width - 1 : 0] product = factor_a * factor_b;
	reg  signed [2 * math_width - 1 : 0] product_r;
	
	wire signed [math_width - 1 : 0] product_r_plus_low  = low  + (product_r >>> (data_width - 1));
	wire signed [math_width - 1 : 0] band_plus_product_r = band + (product_r >>> (data_width - 1));
	
	wire signed [math_width - 1 : 0] x_minus_low_minus_product_r = data_in_r - low - (product_r >>> (data_width - 1 - shift_in_r));
	
	wire blocks_wrapped = (pending_req.block <= prev_block);
	wire new_slot_needed = ~|n_slots_used | ((prev_slot == (n_slots_used - 1)) & ~blocks_wrapped);
	wire req_inv = new_slot_needed && (n_slots_used == `N_SVF);
	
	localparam IDLE 			= 4'd0;
	localparam STATE_LOAD_WAIT 	= 4'd1;
	localparam STATE_LOAD 		= 4'd2;
	localparam CALC_1 			= 4'd3;
	localparam CALC_2 			= 4'd4;
	localparam CALC_3 			= 4'd5;
	localparam CALC_4 			= 4'd6;
	localparam CALC_5 			= 4'd7;
	localparam CALC_6 			= 4'd8;
	localparam CALC_7 			= 4'd9;
	localparam CALC_8 			= 4'd10;
	
	reg [3:0] state;
	
	localparam signed [math_width - 1 : 0] sat_max = ( 1 << (data_width - 1)) - 1;
	localparam signed [math_width - 1 : 0] sat_min = (-1 << (data_width - 1));
	
	wire signed [data_width - 1 : 0] low_sat  = (low  > sat_max) ? sat_max : ((low  < sat_min) ? sat_min : low);
	wire signed [data_width - 1 : 0] band_sat = (band > sat_max) ? sat_max : ((band < sat_min) ? sat_min : band);
	wire signed [data_width - 1 : 0] high_sat = (high > sat_max) ? sat_max : ((high < sat_min) ? sat_min : high);
	
	wire signed [2 * math_width - 1 : 0] band_normalised 	= d_in_r * band;
	wire signed [math_width - 1 : 0] band_normalised_sh 	= band_normalised >> (data_width - 1 - shift_in_r);
	reg  signed [math_width - 1 : 0] band_normalised_sh_r;
	wire signed [data_width - 1 : 0] band_normalised_sh_sat	= (band_normalised_sh_r > sat_max) ? sat_max : ((band_normalised_sh_r < sat_min) ? sat_min : band_normalised_sh_r);
	
	always @(posedge clk) begin
		req_ack <= 0;
		req_invalid <= 0;
		
		if (reset) begin
			state <= IDLE;
			n_slots_used <= 0;
			
			low_valid  <= 0;
			band_valid <= 0;
			high_valid <= 0;
		end else if (enable) begin
			product_r <= product;
			state_mem_write_enable <= 0;
			
			case (state)
				IDLE: begin
					if (req_pending) begin
						req_ack <= 1;
						
						low_valid  <= 0;
						band_valid <= 0;
						high_valid <= 0;
						if (new_slot_needed) begin // need to allocate a new slot
							if (n_slots_used == `N_SVF) begin
								req_invalid <= 1;
								low_out  <= 0;
								band_out <= 0;
								high_out <= 0;
							end else begin
								current_slot <= n_slots_used;
								n_slots_used <= n_slots_used + 1;
								
								state_mem_write_val <= 0;
								state_mem_write_addr <= n_slots_used;
								state_mem_write_enable <= 1;
								
								low <= 0;
								band <= 0;
								
								state <= CALC_1;
							end
						end else if (blocks_wrapped) begin
							current_slot <= 0;
							state_mem_read_addr <= 0;
							state <= STATE_LOAD_WAIT;
						end else begin
							current_slot <= current_slot + 1;
							state_mem_read_addr <= current_slot + 1;
							state <= STATE_LOAD_WAIT;
						end
						
						data_in_r 	<= pending_req.arg_a << (math_width - data_width);
						cutoff_in_r <= pending_req.arg_b << (math_width - data_width);
						d_in_r 		<= pending_req.arg_c << (math_width - data_width);
						shift_in_r  <= pending_req.shift;
						
						prev_block <= pending_req.block;
					end
				end
				
				STATE_LOAD_WAIT: begin
					state <= STATE_LOAD;
				end
				
				STATE_LOAD: begin
					{low, band} <= state_mem_read_val;
					state <= CALC_1;
				end
				
				CALC_1: begin
					factor_a <= cutoff_in_r;
					factor_b <= band;
					
					state <= CALC_2;
				end
				
				CALC_2: begin
					// product_r <= product (automatic)
					factor_a <= d_in_r;
					factor_b <= band;
					
					state <= CALC_3;
				end
				
				CALC_3: begin
					low <= product_r_plus_low;
					state <= CALC_4;
				end
				
				CALC_4: begin
					high <= x_minus_low_minus_product_r;
					factor_a <= cutoff_in_r;
					factor_b <= x_minus_low_minus_product_r;
					
					state <= CALC_5;
				end
				
				CALC_5: begin
					state <= CALC_6;
				end
				
				CALC_6: begin
					band <= band_plus_product_r;
					
					high_out <= high_sat;
					low_out  <= low_sat;
					
					high_valid <= 1;
					low_valid <= 1;
					
					factor_a <= band_plus_product_r;
					factor_b <= d_in_r;
					
					state_mem_write_val <= {low, band_plus_product_r};
					state_mem_write_addr <= current_slot;
					state_mem_write_enable <= 1;
					
					state <= CALC_7;
				end
				
				CALC_7: begin
					band_out <= band_sat;
					
					band_valid <= 1;
					prev_slot <= current_slot;
					state <= IDLE;
				end
			endcase
		end
	end
endmodule

module filter_master
	(
		input wire clk,
		input wire reset,
		input wire enable,
		
		input wire alloc_req,
		
		input wire coef_write,
		input wire coef_commit,
		input wire [7:0] coef_write_handle,
		input wire [data_width - 1 : 0] coef_target,
		input wire signed [math_width - 1 : 0] coef_data,
		
		output reg coef_ack,
		
		output reg req_ack,
		input wire req_valid,
		input filter_rw_req_t req_in,
		output reg req_invalid,
		output reg [data_width - 1 : 0] req_response,
		output reg req_response_valid,

        input wire [`CTRL_DATA_BUS_WIDTH - 1 : 0] ctrl_data_in,
        
        output wire stuck
	);

	reg pending_target_svf;
	reg active_target_svf;
	
	filter_rw_req_t pending_req;
	reg req_pending;
	
	always @(posedge clk) begin
		if (req_valid) begin
			pending_req <= req_in;
			req_pending <= 1;
			
			pending_target_svf <= req_in.flags != `FILTER_REQ_TYPE_FILTER
							   && req_in.flags != `FILTER_REQ_TYPE_FCASC
							   && req_in.flags != `FILTER_REQ_TYPE_POLY;
		end else if (req_ack) begin
			req_pending <= 0;
		end
	end
	
	filter_rw_req_t active_req;
	
	wire [data_width - 1 : 0] req_arg_a = active_req.arg_a;
	wire [data_width - 1 : 0] req_arg_b = active_req.arg_b;
	wire [7 : 0] req_handle = active_req.handle;
	wire [3:0] req_flags = active_req.flags;
	wire [`BLOCK_ADDR_W - 1 : 0] req_block = active_req.block;

	wire filter_req_ack;
	reg  filter_req_valid;
	rw_req_t filter_req_in;
	wire filter_req_invalid;
	reg [data_width - 1 : 0] filter_req_response;
	wire filter_req_response_valid;
	wire filter_stuck;
	
	filter_unit_normal filters (
			.clk(clk),
			.reset(reset),
			.enable(enable),
			
			.alloc_req(alloc_req),
			
			.coef_write(coef_write),
			.coef_commit(coef_commit),
			.coef_write_handle(coef_write_handle),
			.coef_target(coef_target),
			.coef_data(coef_data),
			
			.coef_ack(coef_ack),
			
			.req_ack(filter_req_ack),
			.req_valid(filter_req_valid),
			.req_in(filter_req_in),
			.req_invalid(filter_req_invalid),
			.req_response(filter_req_response),
			.req_response_valid(filter_req_response_valid),

			.ctrl_data_in(ctrl_data_in),
			
			.stuck(filter_stuck)
		);
	
	wire svf_req_ack;
	reg  svf_req_valid;
	wire svf_req_invalid;
	filter_rw_req_t svf_req_in;

	wire svf_low_valid;
	wire svf_band_valid;
	wire svf_high_valid;
	
	wire signed [data_width - 1 : 0] svf_low_out;
	wire signed [data_width - 1 : 0] svf_band_out;
	wire signed [data_width - 1 : 0] svf_high_out;
	
	filter_unit_svf svfs (
			.clk(clk),
			.reset(reset),
			.enable(enable),
			
			.req_ack(svf_req_ack),
			.req_valid(svf_req_valid),
			.req_invalid(svf_req_invalid),
			.req_in(svf_req_in),
			
			.low_out(svf_low_out),
			.band_out(svf_band_out),
			.high_out(svf_high_out),
			
			.low_valid(svf_low_valid),
			.band_valid(svf_band_valid),
			.high_valid(svf_high_valid)
		);
	
	reg busy;
	
	always @(posedge clk) begin
		req_ack <= 0;
		req_invalid <= 0;
		req_response_valid <= 0;
		
		svf_req_valid <= 0;
		filter_req_valid <= 0;
	
		if (reset) begin
			busy <= 0;
		end else if (busy) begin
			if (active_target_svf) begin
				if (svf_req_invalid) begin
					req_invalid <= 1;
					busy <= 0;
				end else
					case (active_req.flags)
						`FILTER_REQ_TYPE_SVF: begin
							if (svf_req_ack) begin
								busy <= 0;
							end
						end
						
						`FILTER_REQ_TYPE_SVF_LOW: begin
							if (svf_low_valid) begin
								req_response <= svf_low_out;
								req_response_valid <= 1;
								busy <= 0;
							end
						end
						
						`FILTER_REQ_TYPE_SVF_BAND: begin
							if (svf_band_valid) begin
								req_response <= svf_band_out;
								req_response_valid <= 1;
								busy <= 0;
							end
						end
						
						`FILTER_REQ_TYPE_SVF_HIGH: begin
							if (svf_high_valid) begin
								req_response <= svf_high_out;
								req_response_valid <= 1;
								busy <= 0;
							end
						end
					endcase
					if (svf_req_ack) begin
					busy <= 0;
				end
			end else begin
				if (filter_req_invalid) begin
					req_invalid <= 1;
					busy <= 0;
				end else if (filter_req_response_valid) begin
					req_response_valid <= 1;
					req_response <= filter_req_response;
					busy <= 0;
				end
			end
		end else begin
			if (req_pending) begin
				active_req <= pending_req;
				req_ack <= 1;
				
				active_target_svf <= pending_target_svf;
				
				busy <= 1;
				if (pending_target_svf) begin
					busy <= 1;
					
					if (req_in.flags == `FILTER_REQ_TYPE_SVF) begin
						svf_req_in <= req_in;
						svf_req_valid <= 1;
					end
				end else begin
					filter_req_in.handle <= pending_req.handle;
					filter_req_in.arg_a  <= pending_req.arg_a;
					filter_req_in.arg_b  <= pending_req.arg_b;
					filter_req_in.flags  <= pending_req.flags;
					filter_req_in.block  <= pending_req.block;
					filter_req_valid <= 1;
				end
			end
		end
	end
endmodule
