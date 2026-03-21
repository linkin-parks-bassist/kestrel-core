module sdram_interface #(parameter data_width = 16, parameter addr_width = 22)
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

	reg [3:0] cooldowns;
	
	reg client;
	reg next_priority;
	
	reg refresh_needed;
	
	localparam refresh_cycles = 1750;
	localparam ref_ctr_width = $clog2(refresh_cycles);
	
	reg [ref_ctr_width - 1 : 0] refresh_ctr;

	always @(posedge clk) begin
		read_valid <= 0;
		write_ack <= 0;
		cooldowns <= 0;
		
		wait_one <= 0;
		
		controller_read <= 0;
		controller_write <= 0;
		refresh <= 0;
		
		if (refresh_ctr < refresh_cycles - 1)
			refresh_ctr <= refresh_ctr + 1;
		else
			refresh_needed <= 1;
		
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
		end else if (ref_wait) begin
			ref_wait <= 0;
		end else if (read_wait) begin
			if (~wait_one) begin
				if (data_from_controller_valid) begin
					data_out <= data_from_controller;
					read_valid[client] <= 1;
					read_wait <= 0;
					
					cooldowns[{client, 0}] <= 1;
				end else if (~controller_busy) begin
					data_out <= 0;
					read_valid[client] <= 1;
					read_wait <= 0;
					
					cooldowns[{client, 0}] <= 1;
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
			end else if (req[next_priority]) begin
				if (req_type[next_priority] && !cooldowns[{next_priority, 1}]) begin // write
					data_to_controller <= data_in[next_priority];
					controller_write <= 1;
					write_ack[next_priority] <= 1;
					
					client <= next_priority;
					addr_to_controller <= {next_priority, addr_in[next_priority]};
					
					cooldowns[{next_priority, 1}] <= 1;
					
					next_priority <= ~next_priority;
					write_wait <= 1;
				end else if (!cooldowns[{next_priority, 0}]) begin //read
					controller_read <= 1;
					client <= next_priority;
					addr_to_controller <= {next_priority, addr_in[next_priority]};
					read_wait <= 1;
					wait_one <= 1;
					next_priority <= ~next_priority;
				end
			end else if (req[~next_priority]) begin
				if (req_type[~next_priority] && !cooldowns[{~next_priority, 1}]) begin // write
					data_to_controller <= data_in[~next_priority];
					controller_write <= 1;
					write_ack[~next_priority] <= 1;
					
					client <= ~next_priority;
					addr_to_controller <= {~next_priority, addr_in[~next_priority]};
					
					cooldowns[{~next_priority, 1}] <= 1;
					write_wait <= 1;
					wait_one <= 1;
				end else if (!cooldowns[{~next_priority, 0}]) begin //read
					controller_read <= 1;
					client <= ~next_priority;
					addr_to_controller <= {~next_priority, addr_in[~next_priority]};
					read_wait <= 1;
					wait_one <= 1;
				end
			end
		end
	end

endmodule
