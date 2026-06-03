`include "defs.vh"

`default_nettype none

module delay_master #(parameter integer data_width,
					  parameter n_buffers   = 32,
					  parameter addr_width  = 20)
	(
		input wire clk,
		input wire reset,
		
		input wire enable,
		
		input wire read_req,
		input wire alloc_req,
		input wire write_req,
		
		output reg signed [data_width - 1 : 0] data_out,
		output reg read_valid,
		output reg write_ack,
		
		input wire [data_width - 1 : 0] read_handle,
		input wire [data_width - 1 : 0] write_handle,
		
		input wire signed [data_width - 1 : 0] write_data,
		
		input wire signed [data_width - 1 : 0] read_depth,
		input wire signed [data_width - 1 : 0] read_offset,
		
		output reg mem_req,
		output reg mem_req_type,
		
		output reg 		  [addr_width - 1 : 0] mem_addr,
		input wire signed [data_width - 1 : 0] mem_data_in,
		output reg signed [data_width - 1 : 0] mem_data_out,
		
		input wire mem_read_valid,
		input wire mem_write_ack,
		
		output reg invalid_read,
		output reg invalid_write,
		output reg invalid_alloc,
		
		output wire any_buffers,
		
		`ifdef DEBUG_READS
		input wire data_req,
		output reg [31:0] data_return,
		output reg data_return_valid,

        output wire stuck,
        `endif
        
        input wire [`CTRL_DATA_BUS_WIDTH - 1 : 0] ctrl_data_in
	);
	
    reg alloc_req_r;
    reg [addr_width - 1 : 0] alloc_size_r;
	reg [addr_width - 1 : 0] alloc_delay_r;

    always @(posedge clk) begin
        if (reset) begin
            alloc_req_r <= 0;
        end else begin
            alloc_req_r <= alloc_req;
            alloc_size_r <= ctrl_data_in[24 + addr_width - 1 : 24];
            alloc_delay_r <= ctrl_data_in[addr_width - 1 : 0];
        end
    end

	localparam memory_size  = (1 << addr_width);
	localparam handle_width = $clog2(n_buffers);
	
	assign any_buffers = |n_buffers_allocd;
	
	localparam IDLE 	 	= 4'd0;
	localparam WRITE_1		= 4'd1;
	localparam WRITE_2	 	= 4'd2;
	localparam WRITE_3	 	= 4'd3;
	localparam WRITE_4	 	= 4'd4;
	localparam WRITE_5	 	= 4'd5;
	localparam READ_1	 	= 4'd6;
	localparam READ_2	 	= 4'd7;
	localparam READ_3	 	= 4'd8;
	localparam READ_4	 	= 4'd9;
	localparam READ_5	 	= 4'd10;
	localparam READ_6	 	= 4'd11;
	localparam READ_7	 	= 4'd12;
	localparam READ_8	 	= 4'd13;
	localparam READ_9	 	= 4'd14;
	
	reg [3:0] state;
	reg [3:0] state_prev;
	
	localparam buf_info_width = addr_width + addr_width + addr_width + addr_width + data_width + 1;
	localparam [data_width - 1 : 0] unity_gain = 1 << (data_width - 2);
	
	reg [buf_info_width - 1 : 0] buf_info [n_buffers - 1 : 0];
	
	reg [addr_width - 1 : 0] addr;
	reg [addr_width - 1 : 0] size;
	reg [addr_width - 1 : 0] delay;
	reg [addr_width - 1 : 0] position;
	reg signed [data_width - 1 : 0] gain;
	reg wrapped;
	
	wire [addr_width - 1 : 0] addr_f;
	wire [addr_width - 1 : 0] size_f;
	wire [addr_width - 1 : 0] delay_f;
	wire [addr_width - 1 : 0] position_f;
	wire signed [data_width - 1 : 0] gain_f;
	wire wrapped_f;
	
	assign {addr_f, size_f, delay_f, position_f, gain_f, wrapped_f} = buf_info_read;
	
	wire [addr_width  - 1 : 0] next_position = (position + 1 == size) ? 0 : position + 1;
	wire [data_width  - 1 : 0] next_gain	 = (wrapped && gain < 16'b0100000000000000) ? gain + 16'b0000000001000000 : gain;
	
	reg [buf_info_width - 1 : 0] buf_info_read;
	reg [buf_info_width - 1 : 0] buf_info_write_data;
	reg [handle_width   - 1 : 0] buf_info_write_handle;
	reg [handle_width   - 1 : 0] buf_info_read_handle;
	reg [handle_width   - 1 : 0] buf_info_read_handle_prev;
	reg [handle_width   - 1 : 0] buf_info_read_handle_prev_prev;
	reg buf_info_write_enable;
	
	always @(posedge clk) begin
		buf_info_read_handle_prev <= buf_info_read_handle;
		buf_info_read_handle_prev_prev <= buf_info_read_handle_prev;
		
		if (buf_info_write_enable)
			buf_info[buf_info_write_handle] <= buf_info_write_data;
		
		buf_info_read <= buf_info[buf_info_read_handle];
	end
	
	reg [n_buffers  - 1 : 0] buf_data_invalid;
	reg [n_buffers  - 1 : 0] buffer_initd;
	
	reg [addr_width - 1 : 0] alloc_addr;
	
	reg signed [addr_width - 1 : 0] delay_addr_delta;
	reg  [addr_width - 1 : 0] rdo;
	wire [addr_width - 1 : 0] delay_addr = (delay_addr_delta > position) ? addr + position - delay_addr_delta + size
																		 : addr + position - delay_addr_delta;
	
	reg [$clog2(n_buffers + 1) - 1 : 0] n_buffers_allocd;
	
	wire buffers_exhausted 	= (n_buffers_allocd == n_buffers);
	wire alloc_too_big		= alloc_addr + alloc_size_r > memory_size;
	
	reg signed [data_width - 1 : 0] buf_data_in;
	reg signed [data_width - 1 : 0] buf_data_new;
	
	reg signed [data_width - 1 : 0] write_data_r;
	reg signed [data_width - 1 : 0] write_inc_r;
	reg        [data_width - 1 : 0] write_handle_r;
	reg        [data_width - 1 : 0] read_handle_r;

	reg signed [data_width - 1 : 0] mul_a;
	reg signed [data_width - 1 : 0] mul_b;
	
	wire signed [2 * data_width - 1 : 0] product_a = $signed(mul_a) * $signed(mul_b);
	reg  signed [2 * data_width - 1 : 0] product_a_r;
	
	wire [addr_width  - 1 : 0] alloc_size_wm  = alloc_size_r [addr_width  - 1 : 0];
	wire [addr_width - 1 : 0] alloc_delay_wm = alloc_delay_r[addr_width - 1 : 0];
	
	reg  read_req_prev;
	wire read_req_posedge = read_req & ~read_req_prev;
	reg  read_req_posedge_latched;
	wire read_req_pending = read_req | read_req_posedge_latched;
	
	reg  write_req_prev;
	wire write_req_posedge = write_req & ~write_req_prev;
	reg  write_req_posedge_latched;
	wire write_req_pending = write_req | write_req_posedge_latched;
	
	always @(posedge clk) begin
		write_ack <= 0;
		read_valid <= 0;
		
		buf_info_write_enable <= 0;
		
		invalid_alloc <= 0;
		invalid_write <= 0;
		invalid_read  <= 0;
        
		read_req_prev <= read_req;
		read_req_posedge_latched <= read_req_posedge | read_req_posedge_latched;
		
		write_req_prev <= write_req;
		write_req_posedge_latched <= write_req_posedge | write_req_posedge_latched;
		
		mem_req <= 0;
		
		state_prev <= state;
		
		if (reset) begin
			state <= IDLE;
			
			n_buffers_allocd <= 0;
			buffer_initd 	 <= 0;
			
			alloc_addr <= 0;
			
			buf_info_write_enable 	<= 0;
			buf_data_invalid 		<= 0;
			
			alloc_addr <= 0;
			n_buffers_allocd <= 0;
			
			read_req_prev  <= 0;
			write_req_prev <= 0;
			read_req_posedge_latched  <= 0;
			write_req_posedge_latched <= 0;
			
		end else if (alloc_req_r) begin
			if (alloc_too_big || buffers_exhausted) begin
				invalid_alloc <= 1;
			end else begin
				alloc_addr <= alloc_addr + alloc_size_r;
				buffer_initd[n_buffers_allocd] <= 1;
				n_buffers_allocd <= n_buffers_allocd + 1;
				
                buf_info_write_data <= '0;
				buf_info_write_data[buf_info_width                  - 1 : buf_info_width -     addr_width              ] <= alloc_addr;
				buf_info_write_data[buf_info_width - 1 * addr_width - 1 : buf_info_width - 2 * addr_width              ] <= alloc_size_wm;
				buf_info_write_data[buf_info_width - 2 * addr_width - 1 : buf_info_width - 2 * addr_width - addr_width] <= alloc_delay_wm;
				
				buf_info_write_handle <= n_buffers_allocd;
				buf_info_write_enable <= 1;
			end
		end else if (enable) begin
			case (state)
				IDLE: begin
					if (read_req_pending) begin
						read_handle_r <= read_handle;
						buf_info_read_handle <= read_handle;
						
						invalid_read <= !buffer_initd[read_handle];
						
						mul_a <= read_depth < 1 ? 0 : read_depth;
						mul_b <= read_offset;
						
						read_req_posedge_latched <= 0;
						
						state <= buffer_initd[read_handle] ? READ_1 : IDLE;
						
					end else if (write_req_pending) begin
						write_data_r <= write_data;
						write_handle_r <= write_handle;
						buf_info_read_handle <= write_handle;
						
						write_req_posedge_latched <= 0;
						
						invalid_write <= !buffer_initd[write_handle];
						
						state <= buffer_initd[write_handle] ? WRITE_1 : IDLE;
					end
				end
				
				READ_1: begin
					state <= READ_2;
					
					product_a_r <= product_a;
				end
				
				READ_2: begin
					if (wrapped_f) begin
						{addr, size, delay, position, gain, wrapped} <= buf_info_read;
					
						mul_a <= product_a_r >>> (data_width - 1);
						mul_b <= size_f[addr_width - 1 -: data_width];
						
						state <= READ_3;
					end else begin
						data_out 	<= 0;
						read_valid 	<= 1;
						state 		<= IDLE;
					end
				end
				
				READ_3: begin
					delay_addr_delta <= delay + product_a >>> (data_width - 1 - (addr_width - data_width));
					state <= READ_4;
				end
				
				READ_4: begin
					if (delay_addr_delta <  -$signed(size) + 1)
						delay_addr_delta <= -$signed(size) + 1;
					else if (delay_addr_delta > size - 1)
						delay_addr_delta <= size - 1;
					else
						delay_addr_delta <= delay_addr_delta;
					
					state <= READ_5;
				end
				
				READ_5: begin
					mem_addr <= delay_addr;
					mem_req  <= 1;
                    mem_req_type <= 0;
                    
                    `ifdef DEBUG_READS
                    buf_last_read_addr[read_handle_r] <= delay_addr;
                    `endif
					
					state <= READ_6;
				end
				
				READ_6: begin
					if (mem_read_valid) begin
						if (gain == unity_gain) begin
							data_out 	<= mem_data_in;
							read_valid  <= 1;
							state 		<= IDLE;
						end else begin
							mul_a           <= mem_data_in;
							mul_b           <= gain;
							state 			<= READ_7;
						end
					end
				end
				
				READ_7: begin
					state <= READ_8;
				end
				
                READ_8: begin
                    product_a_r <= product_a;
                    state <= READ_9;
                end
                
				
				READ_9: begin
					data_out 	<= product_a_r >>> (data_width - 2);
					read_valid  <= 1;
					state 		<= IDLE;
				end
				
				WRITE_1: begin
					state <= WRITE_2;
				end
				
				WRITE_2: begin
					{addr, size, delay, position, gain, wrapped} <= buf_info_read;
					state <= WRITE_3;
				end
				
				WRITE_3: begin
					mem_data_out  <= write_data_r;
					mem_addr      <= addr + position;
					
					`ifdef DEBUG_READS
					buf_last_write_addr[write_handle_r] <= addr + position;
					`endif
					
					mem_req      <= 1;
                    mem_req_type <= 1;
					
					buf_info_write_data <= {addr, size, delay, next_position, next_gain, wrapped || (position == (size - 1))};
					buf_info_write_handle <= write_handle_r;
					buf_info_write_enable  <= 1;
					
					state <= WRITE_4;
				end
				
				WRITE_4: begin
					if (mem_write_ack) begin
						write_ack <= 1;
						state <= IDLE;
					end
				end
			endcase
		end
	end
	
	`ifdef DEBUG_READS
	reg [$clog2(`CYCLES_PER_SAMPLE) : 0] stuck_ctr;
	assign stuck = (stuck_ctr == `CYCLES_PER_SAMPLE);
	
	always @(posedge clk) begin
		if (reset || n_buffers_allocd == 0 || state != state_prev)
			stuck_ctr <= 0;
		else if (enable && stuck_ctr < `CYCLES_PER_SAMPLE)
			stuck_ctr <= stuck_ctr + 1;
	end
	
	reg data_req_active;
	
	reg  [`CTRL_DATA_BUS_WIDTH - 1 : 0] data_req_ctrl_data_r;
	wire [7:0] data_req_type = data_req_ctrl_data_r[7:0];
	
	wire [handle_width - 1 : 0] data_req_handle = data_req_ctrl_data_r[8 +: handle_width];
	
	reg [addr_width - 1 : 0] buf_last_write_addr [n_buffers - 1 : 0];
	reg [addr_width - 1 : 0] buf_last_read_addr  [n_buffers - 1 : 0];
	
	always @(posedge clk) begin
		data_return_valid <= 0;
	
		if (reset) begin
			data_req_active <= 0;
		end else begin
			if (data_req) begin
				data_req_ctrl_data_r <= ctrl_data_in;
				data_req_active <= 1;
			end else if (data_req_active) begin
				case (data_req_type)
					`DATA_REQ_N_DELAY_BUF: begin
						data_return <= n_buffers_allocd;
						data_return_valid <= 1;
						data_req_active <= 0;
					end
					
					`DATA_REQ_DELAY_BUF_SIZE: begin
						if (buf_info_read_handle_prev_prev == data_req_handle) begin
							data_return <= size;
							data_return_valid <= 1;
							data_req_active <= 0;
						end
					end
					
					`DATA_REQ_DELAY_BUF_DELAY: begin
						if (buf_info_read_handle_prev_prev == data_req_handle) begin
							data_return <= delay;
							data_return_valid <= 1;
							data_req_active <= 0;
						end
					end
					
					`DATA_REQ_DELAY_BUF_ADDR: begin
						if (buf_info_read_handle_prev_prev == data_req_handle) begin
							data_return <= addr;
							data_return_valid <= 1;
							data_req_active <= 0;
						end
					end
					
					`DATA_REQ_DELAY_BUF_POS: begin
						if (buf_info_read_handle_prev_prev == data_req_handle) begin
							data_return <= position;
							data_return_valid <= 1;
							data_req_active <= 0;
						end
					end
					
					`DATA_REQ_DELAY_BUF_GAIN: begin
						if (buf_info_read_handle_prev_prev == data_req_handle) begin
							data_return <= gain;
							data_return_valid <= 1;
							data_req_active <= 0;
						end
					end
					
					`DATA_REQ_DELAY_BUF_LRWA: begin
						if (buf_info_read_handle_prev_prev == data_req_handle) begin
							data_return[15: 0] <= buf_last_read_addr[data_req_handle];
							data_return[31:16] <= buf_last_write_addr[data_req_handle];
							data_return_valid <= 1;
							data_req_active <= 0;
						end
					end
					
					default: begin
						data_req_active <= 0;
					end
				endcase
			end
		end
	end
	
	`endif
endmodule

`default_nettype wire
