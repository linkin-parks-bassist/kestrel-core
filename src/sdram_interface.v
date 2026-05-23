module sdram_interface #(parameter integer data_width, parameter addr_width = 21, parameter sdram_size = (1 << addr_width))
	(
		input wire clk,
		input wire reset,
		
		input  wire [1:0] req,
		input  wire [1:0] req_type, // 0 for read, 1 for write
		output reg  [1:0] write_ack,
		output reg  [1:0]read_valid,
		
		input wire [addr_width - 2 : 0] addr_in [1:0],
		input wire [data_width - 1 : 0] data_in [1:0],
		
		output reg [data_width - 1 : 0] data_out,
		
		output reg controller_read,
		output reg controller_write,
		output reg refresh,
		output reg [addr_width - 1 : 0] addr_to_controller,
		output reg [data_width - 1 : 0] data_to_controller,
		input wire [data_width - 1 : 0] data_from_controller,
		
		input wire data_from_controller_valid,
		input wire controller_busy
	);

	reg ref_wait;
	reg read_wait;
	reg write_wait;

	reg wait_one;
	
	reg client;
	reg next_priority;
	
	reg refresh_needed;
	
	localparam refresh_cycles = 1750;
	localparam ref_ctr_width = $clog2(refresh_cycles);
	
	reg [ref_ctr_width - 1 : 0] refresh_ctr;
	
	reg  [1:0] req_prev;
	wire [1:0] req_posedge = {req[1] & ~req_prev[1], req[0] & ~req_prev[0]};
	reg  [1:0] req_posedge_latched;
	wire [1:0] req_pending = {req[1] |  req_posedge_latched[1], req[0] | req_posedge_latched[0]};

	reg  [1:0] req_type_latched;
	wire [1:0] req_type_current = {req[1] ? req_type[1] : req_type_latched[1],
								   req[0] ? req_type[0] : req_type_latched[0]};

	wire [addr_width - 1 : 0] base_addr [1:0];
	
	assign base_addr[0] = 0;
	assign base_addr[1] = sdram_size / 2;

	always @(posedge clk) begin
		read_valid <= 0;
		write_ack <= 0;
		
		wait_one <= 0;
		
		controller_read <= 0;
		controller_write <= 0;
		refresh <= 0;
		
		if (refresh_ctr < refresh_cycles - 1)
			refresh_ctr <= refresh_ctr + 1;
		else
			refresh_needed <= 1;
		
		req_prev <= req;
		
		req_posedge_latched[0] <= req_posedge[0] | req_posedge_latched[0];
		req_posedge_latched[1] <= req_posedge[1] | req_posedge_latched[1];
		
		req_type_latched[0] <= req[0] ? req_type[0] : req_type_latched[0];
		req_type_latched[1] <= req[1] ? req_type[1] : req_type_latched[1];
		
		if (reset) begin
			client <= 0;
			next_priority <= 0;
			refresh_needed <= 1;
			
			refresh_ctr <= 0;
			
			ref_wait <= 0;
			read_wait <= 0;
			write_wait <= 0;
			
			write_ack <= 0;
			read_valid <= 0;
			
			data_out <= 0;
			
			addr_to_controller <= 0;
			data_to_controller <= 0;
			
			req_prev <= 0;
			req_posedge_latched <= 0;
			req_type_latched <= 0;
		end else if (ref_wait) begin
			ref_wait <= 0;
		end else if (read_wait) begin
			if (~wait_one) begin
				if (data_from_controller_valid) begin
					data_out <= data_from_controller;
					read_valid[client] <= 1;
					read_wait <= 0;
				end
			end
		end else if (write_wait) begin
			write_wait <= 0;
		end else if (!controller_busy) begin
			if (refresh_needed) begin
				refresh <= 1;
				
				refresh_ctr <= 0;
				refresh_needed <= 0;
				
				ref_wait <= 1;
			end else if (req_pending[next_priority]) begin
				if (req_type_current[next_priority]) begin // write
					data_to_controller <= data_in[next_priority];
					controller_write <= 1;
					write_ack[next_priority] <= 1;
					
					client <= next_priority;
					addr_to_controller <= addr_in[next_priority] + base_addr[next_priority];
					
					next_priority <= ~next_priority;
					write_wait <= 1;
				end else begin //read
					controller_read <= 1;
					client <= next_priority;
					addr_to_controller <= addr_in[next_priority] + base_addr[next_priority];
					read_wait <= 1;
					wait_one <= 1;
					next_priority <= ~next_priority;
				end
				
				req_posedge_latched[next_priority] <= 0;
			end else if (req_pending[~next_priority]) begin
				if (req_type_current[~next_priority]) begin // write
					data_to_controller <= data_in[~next_priority];
					controller_write <= 1;
					write_ack[~next_priority] <= 1;
					
					client <= ~next_priority;
					addr_to_controller <= addr_in[~next_priority] + base_addr[~next_priority];
					
					write_wait <= 1;
				end else begin //read
					controller_read <= 1;
					client <= ~next_priority;
					addr_to_controller <= addr_in[~next_priority] + base_addr[~next_priority];
					read_wait <= 1;
					wait_one <= 1;
				end
				
				req_posedge_latched[~next_priority] <= 0;
			end
		end
	end

endmodule
