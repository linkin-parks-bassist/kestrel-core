`include "filter.vh"
`include "defs.vh"
`include "controller.vh"
import types_pkg::*;
`ifdef ENABLE_POLYNOMIAL

module polynomial_unit
	(
		input wire clk,
		input wire reset,
		input wire enable,

		input wire alloc_req,

		input wire coef_write,
		input wire coef_update,
		input wire coef_commit,

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
		if (reset) begin
            req_pending <= 0;
        end else if (req_valid) begin
			pending_req <= req_in;
			req_pending <= 1;
		end else if (req_ack) begin
			req_pending <= 0;
		end
	end

	reg [$clog2(`CYCLES_PER_SAMPLE) : 0] stuck_ctr;
	assign stuck = (stuck_ctr == `CYCLES_PER_SAMPLE);

	always @(posedge clk) begin
		if (reset || next_handle == 0 || state != state_prev)
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
				 + 5			 // format
		 + 1;			 // coef bank

    reg alloc_req_r;
    reg coef_write_r;
    reg coef_update_r;
    reg coef_commit_r;

    reg [7 : 0] alloc_format_r;
    reg [data_width - 1 : 0] order_ff_r;
    reg [7:0] coef_write_handle_r, coef_commit_handle_r;

    reg [data_width - 1 : 0] coef_target_r;
    reg signed [math_width - 1 : 0] coef_data_r;

    always @(posedge clk) begin
        if (reset) begin
            alloc_req_r <= 0;
            coef_write_r <= 0;
            coef_update_r <= 0;
            coef_commit_r  <= 0;
        end else begin
            alloc_req_r <= alloc_req;
            coef_write_r <= coef_write;
            coef_update_r <= coef_update;
            coef_commit_r  <= coef_commit;

            order_ff_r <= ctrl_data_in[15 : 8];
            alloc_format_r <= ctrl_data_in[23 : 16];
            coef_write_handle_r <= ctrl_data_in[47:40];
            coef_commit_handle_r <= ctrl_data_in[7:0];

            coef_target_r <= ctrl_data_in[24 + 2 * 8 - 1 : 24];
            coef_data_r <= ctrl_data_in[data_width - 1 + math_width - data_width : 0];
        end
    end

	reg signed [math_width - 1 : 0] coef_mem_a [`FILTER_MEM_SIZE  - 1 : 0];
	reg signed [math_width - 1 : 0] coef_mem_b [`FILTER_MEM_SIZE  - 1 : 0];
	reg [config_width - 1 : 0] config_mem [`N_FILTERS - 1 : 0];

	reg         [addr_width - 1 : 0] coef_mem_read_addr;
	reg signed  [math_width - 1 : 0] coef_mem_a_read_val;
	reg signed  [math_width - 1 : 0] coef_mem_b_read_val;
	wire signed [math_width - 1 : 0] coef_mem_read_val = coef_bank ? coef_mem_b_read_val : coef_mem_a_read_val;
	reg         [addr_width - 1 : 0] coef_mem_write_addr;
	reg signed  [math_width - 1 : 0] coef_mem_write_val;
	reg coef_mem_a_write_enable;
	reg coef_mem_b_write_enable;

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

		config_mem_read_val <= config_mem[config_mem_read_addr];
		if (config_mem_write_enable) config_mem[config_mem_write_addr] <= config_mem_write_val;
	end

	reg [handle_width : 0] next_handle;
	reg [addr_width - 1 : 0] next_addr;

	reg [degree_width - 1 : 0] current_order_ff;

	wire poly_capacity = (next_handle < `N_FILTERS);
    wire mem_capacity = ({1'b0, next_addr} + order_ff_pending < `FILTER_MEM_SIZE);

	reg [addr_width - 1 : 0] coef_target_addr;
	reg signed [math_width - 1 : 0] coef_to_write;

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

	always @(posedge clk)
		state_prev <= state;

	reg [data_width - 1 : 0] counter;

	reg [5:0] format;
	reg [8:0] shift;
	reg coef_bank;

	reg signed [data_width - 1 : 0] data_in_r;

	wire signed [2 * data_width - 1 : 0] next_pow_p = data_in_r * pow;
	wire signed [data_width - 1 : 0] next_pow = next_pow_p >>> (data_width - 1);

	reg signed [data_width : 0] pow;

	localparam STATE_IDLE 			= 0;
	localparam STATE_WRITING 		= 1;
	localparam STATE_UPDATING 		= 2;
	localparam STATE_COMMITTING 	= 3;
	localparam STATE_FETCH_CONFIG 	= 4;
	localparam STATE_STARTUP 		= 5;
	localparam STATE_FIRST_SAMPLE 	= 6;
	localparam STATE_FEED_FORWARD 	= 7;
	localparam STATE_DONE			= 9;
	localparam STATE_SHIFT			= 10;
	localparam STATE_SEND			= 11;

	reg [7:0] state;
	reg [7:0] state_prev;

	reg alloc_pending;
	reg alloc_ack;
	reg coef_write_pending;
	reg coef_write_ack;
	reg coef_update_pending;
	reg coef_update_ack;
	reg coef_commit_pending;
	reg coef_commit_ack;

	reg [7 : 0] alloc_format_pending;
    reg [data_width - 1 : 0] order_ff_pending;

    reg [7:0] coef_commit_handle_pending;

    reg [7:0] coef_write_handle_pending;
    reg [data_width - 1 : 0] coef_write_target_pending;
    reg signed [math_width - 1 : 0] coef_write_data_pending;

    always @(posedge clk) begin
		if (reset) begin
			alloc_pending 		<= 0;
			coef_write_pending 	<= 0;
			coef_update_pending <= 0;
			coef_commit_pending <= 0;
		end else begin
			if (alloc_req_r) begin
				alloc_pending <= 1;
				alloc_format_pending <= alloc_format_r;
				order_ff_pending <= order_ff_r;
			end else if (alloc_ack) begin
				alloc_pending <= 0;
			end
			if (coef_write_r) begin
				coef_write_pending <= 1;
                coef_write_handle_pending <= coef_write_handle_r;
				coef_write_target_pending <= coef_target_r;
				coef_write_data_pending <= coef_data_r;
			end else if (coef_write_ack) begin
				coef_write_pending <= 0;
			end
			if (coef_update_r) begin
				coef_update_pending <= 1;
                coef_write_handle_pending <= coef_write_handle_r;
				coef_write_target_pending <= coef_target_r;
				coef_write_data_pending <= coef_data_r;
			end else if (coef_update_ack) begin
				coef_update_pending <= 0;
			end
			if (coef_commit_r) begin
				coef_commit_pending <= 1;
                coef_commit_handle_pending <= coef_commit_handle_r;
			end else if (coef_commit_ack) begin
				coef_commit_pending <= 0;
			end
		end
    end

    reg alloc_cooldown;

	always @(posedge clk) begin
		req_response_valid <= 0;
		wait_one <= 0;

		config_mem_write_enable <= 0;
		coef_mem_a_write_enable <= 0;
		coef_mem_b_write_enable <= 0;

		alloc_cooldown <= 0;

		req_ack <= 0;
        req_invalid <= 0;

		alloc_ack 			<= 0;
		coef_write_ack 		<= 0;
		coef_update_ack 	<= 0;
		coef_commit_ack 	<= 0;

		if (reset) begin
            state <= STATE_IDLE;
			next_handle <= 0;
			next_addr <= 0;

			req_response <= 0;

			current_order_ff <= 0;

			coef_target_addr <= 0;
			coef_to_write <= 0;

			factor_a <= 0;
			factor_b <= 0;

			accumulator <= 0;

			counter <= 0;

			format <= 0;
			shift <= 0;

		end else begin
			case (state)
				STATE_IDLE: begin
					if (~alloc_cooldown & alloc_pending) begin
						alloc_ack <= 1;

						if (poly_capacity && mem_capacity) begin
							config_mem_write_addr <= next_handle;
                            config_mem_write_val <= {alloc_format_pending[4:0], order_ff_pending, next_addr, 1'b0};
							config_mem_write_enable <= 1;
							next_handle <= next_handle + 1;
                            next_addr <= next_addr + order_ff_pending;
							alloc_cooldown <= 1;
						end
					end else if (coef_write_pending) begin
						coef_write_ack <= 1;

						config_mem_read_addr <= coef_write_handle_pending;
						coef_target_addr <= coef_write_target_pending[addr_width - 1 : 0];
						coef_to_write <= coef_write_data_pending;
						state <= STATE_WRITING;
						wait_one <= 1;
					end else if (coef_update_pending) begin
						coef_update_ack <= 1;

						config_mem_read_addr <= coef_write_handle_pending;
						coef_target_addr <= coef_write_target_pending[addr_width - 1 : 0];
						coef_to_write <= coef_write_data_pending;
						state <= STATE_UPDATING;
						wait_one <= 1;
					end else if (coef_commit_pending) begin
						coef_commit_ack <= 1;

						config_mem_read_addr <= coef_commit_handle_pending;
						state <= STATE_COMMITTING;
						wait_one <= 1;
					end else if (req_pending) begin
						req_ack <= 1;

						if (pending_req.handle >= next_handle) begin
							req_response_valid <= 1;
							req_response <= pending_req.arg_a;
						end else begin
							wait_one <= 1;

							config_mem_read_addr <= pending_req.handle;

							accumulator <= 0;

							data_in_r <= pending_req.arg_a;

							pow <= (1 << (data_width - 1));

							state <= STATE_FETCH_CONFIG;
						end
					end
				end

				STATE_WRITING: begin
					if (!wait_one) begin
						coef_mem_write_addr <= config_mem_read_val[addr_width : 1] + coef_target_addr;
						coef_mem_write_val <= coef_to_write;
						if (coef_target_addr < config_mem_read_val[addr_width + degree_width : addr_width + 1])
                            {coef_mem_b_write_enable, coef_mem_a_write_enable} <= {config_mem_read_val[0], ~config_mem_read_val[0]};
						state <= STATE_IDLE;
					end
				end

				STATE_UPDATING: begin
					if (!wait_one) begin
						coef_mem_write_addr <= config_mem_read_val[addr_width : 1] + coef_target_addr;
						coef_mem_write_val <= coef_to_write;
						if (coef_target_addr < config_mem_read_val[addr_width + degree_width : addr_width + 1])
                            {coef_mem_b_write_enable, coef_mem_a_write_enable} <= {~config_mem_read_val[0], config_mem_read_val[0]};
						state <= STATE_IDLE;
					end
				end

				STATE_COMMITTING: begin
					if (!wait_one) begin
						config_mem_write_addr <= config_mem_read_addr;
						config_mem_write_val <= {config_mem_read_val[config_width - 1 : 1], ~config_mem_read_val[0]};
						config_mem_write_enable <= 1;
						state <= STATE_IDLE;
					end
				end

				STATE_FETCH_CONFIG: begin
					if (!wait_one) begin
                        format <= config_mem_read_val[config_width - 1 -: 5];
                        current_order_ff <= config_mem_read_val[addr_width + degree_width : addr_width + 1];
                        coef_bank <= config_mem_read_val[0];
                        coef_mem_read_addr <= config_mem_read_val[addr_width : 1];
						state <= STATE_STARTUP;
						counter <= 0;
					end
				end

				STATE_STARTUP: begin
					coef_mem_read_addr <= coef_mem_read_addr + 1;
					state <= STATE_FIRST_SAMPLE;
				end

                STATE_FIRST_SAMPLE: begin
                    factor_a <= coef_mem_read_val;
                    factor_b <= pow;
                    pow <= next_pow;
                    coef_mem_read_addr <= coef_mem_read_addr + 1;
                    counter <= 1;
                    state <= current_order_ff == 1 ? STATE_DONE : STATE_FEED_FORWARD;
                end
                STATE_FEED_FORWARD: begin
                    accumulator <= product_sum;
                    factor_a <= coef_mem_read_val;
                    factor_b <= pow;
                    pow <= next_pow;
                    coef_mem_read_addr <= coef_mem_read_addr + 1;
                    counter <= counter + 1;
                    if (counter == current_order_ff - 1) state <= STATE_DONE;
                end
                STATE_DONE: begin
                    accumulator <= product_sum;
                    shift <= math_width - 1 - format;
                    state <= STATE_SHIFT;
                end
				STATE_SHIFT: begin
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
						state <= STATE_SEND;
					end
				end

				STATE_SEND: begin

					req_response <= resul_sat;

					req_response_valid <= 1;

					state <= STATE_IDLE;
				end
			endcase
		end
	end
endmodule
`endif
