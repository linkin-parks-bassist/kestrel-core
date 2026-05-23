`include "controller.vh"
`include "instr_dec.vh"
`include "core.vh"
`include "lut.vh"

`default_nettype none

`define PIPELINE_READY 			0
`define PIPELINE_PROCESSING 	1
`define PIPELINE_INVALID	 	2

module dsp_pipeline #(
		parameter integer data_width,
		parameter filter_width		= 18,
		parameter n_blocks 			= 256,
		parameter sdram_addr_width  = 22
	) (
		input wire clk,
		input wire reset,
		
		input wire full_reset,
		input wire enable,
		
		input wire signed [data_width - 1:0] in_sample,
		input wire in_valid,
		
		output wire [data_width - 1:0] out_sample,
		output reg ready,
		
		output wire error,
		
		input wire instr_write,
	
		input wire [data_width - 1 : 0] ctrl_data,
		
		input wire reg_0_write,
		input wire reg_1_write,
		
		input wire filter_coef_write,
		input wire filter_coef_commit,
		
		output wire filter_ack,
		
		input wire reg_writes_commit,
		output wire regfile_syncing,
		
		output wire reg_write_ack,
		output wire instr_write_ack,
	
		input wire alloc_delay,
		input wire alloc_filter,
		output wire resetting,

		output wire[7:0] out,

		output wire [$clog2(n_blocks) - 1 : 0] n_blocks_running,
		output wire [31:0] commits_accepted,
		
		output wire sdram_req,
		output wire sdram_req_type,

		input wire sdram_write_ack,
		input wire sdram_read_valid,

		output wire [sdram_addr_width - 1 : 0] sdram_addr,
		output wire [data_width - 1 : 0] sdram_data_out,

		input wire [data_width - 1 : 0] sdram_data_in,
		
		input wire data_req,
		
		output reg [31:0] data_return,
		output reg data_return_valid,

        input wire [`CTRL_DATA_BUS_WIDTH - 1 : 0] ctrl_data_in
	);
	
	/*******************/
	/* Processing core */
	/*******************/
	
    wire [7:0] core_out;
    wire [15:0] stuck_flags_core;

	dsp_core #(
		.data_width(data_width),
		.n_blocks(n_blocks),
		.n_channels(8),
		.sdram_addr_width(sdram_addr_width)
	) core (
		.clk(clk),
		.reset(reset),
		
		.enable(enable),
		
		.tick(in_valid),
		
		.sample_in(in_sample),
		.sample_out(out_sample),
		
		.ready(core_ready),
		
		.command_reg_0_write(reg_0_write),
		.command_reg_1_write(reg_1_write),
		.command_instr_write(instr_write),
		
		.lut_req(lut_req),
		.lut_handle(lut_req_handle),
		.lut_arg(lut_req_arg),
		.lut_data(lut_data),
		.lut_valid(lut_valid),
		
		.delay_read_req  (delay_read_req),
		.delay_write_req (delay_write_req),
		.delay_req_handle(delay_req_handle),
		.delay_write_data(delay_write_data),
		.delay_read_data (delay_read_data),
		.delay_read_delay(delay_read_delay),
		.delay_read_valid(delay_read_valid),
		.delay_write_ack (delay_write_ack),
		
		.filter_calc_req(filter_calc_req),
		.filter_handle_out(filter_handle_out),
		.filter_data_out(filter_data_out),
		.filter_data_in(filter_data_in),
		.filter_data_valid(filter_data_valid),
		.filter_req_type(filter_req_type),
		
		.reg_writes_commit(reg_writes_commit),
		.regfile_syncing(regfile_syncing),
		
		.full_reset(full_reset),
		.resetting(resetting),
		
		.data_req(data_req_core),
		
		.data_return(data_return_core),
		.data_return_valid(data_return_valid_core),

        .ctrl_data_in(ctrl_data_in),
        
        .svf_data_out(svf_data_in),
		.svf_cutoff_out(svf_cutoff_in),
		.svf_d_out(svf_d_in),
		
		.svf_shift_out(svf_shift_in),
		
		.svf_low_in(svf_low_out),
		.svf_band_in(svf_band_out),
		.svf_high_in(svf_high_out),
	
		.svf_data_valid(svf_data_valid),
		
		.svf_req(svf_req),
		.svf_ack(svf_ack),
		.svf_block_out(svf_block_in),
		
		.stuck_flags(stuck_flags_core)
	);
	
	reg enable_latched;
	wire pr_enable = enable_latched;
	
	always @(posedge clk) begin
		enable_latched <= enable_latched | enable;
		
		if (reset | full_reset) begin
			enable_latched <= 0;
		end
	end
	
	
	
	/************************/
	/* Peripheral resources */
	/************************/
	
	// Lookup tables, for function calls
	`ifdef ENABLE_LUTS
	lut_master #(.data_width(data_width)) luts (
		.clk(clk),
		.reset(reset | full_reset),
		
		.enable(pr_enable),
		
		.lut_handle(lut_req_handle),
		.req_arg(lut_req_arg),
		.req(lut_req),
		
		.data_out(lut_data),
		.valid(lut_valid),
		
		.invalid_request(invalid_lut_request)
	);
	`else
	assign lut_valid = 0;
	`endif
	
	// Delay buffers
	localparam delay_mem_addr_width = sdram_addr_width;
	localparam delay_mem_size = (1 << (delay_mem_addr_width));

    wire [data_width - 1 : 0] delay_read_delay;
    wire any_delay_buffers;
    
    wire stuck_delay;

	delay_master #(
		.data_width(data_width), 
		.n_buffers(32),
		.addr_width(sdram_addr_width)
	) delays (
		.clk(clk),
		.reset(reset | full_reset),
		
		.enable(pr_enable),
		
		.alloc_req  (alloc_delay),
		
		.read_req (delay_read_req),
		.write_req(delay_write_req),
		
		.write_handle(delay_req_handle),
		.read_handle (delay_req_handle),
		.read_delay	 (delay_read_delay),
		.write_data  (delay_write_data),
			
		.data_out(delay_read_data),
		
		.read_valid(delay_read_valid),
		.write_ack(delay_write_ack),
		
		.mem_req (sdram_req),
		.mem_req_type(sdram_req_type),
		
		.mem_addr(sdram_addr),
		.mem_data_in(sdram_data_in),
		
		.mem_data_out  (sdram_data_out),
		
		.mem_read_valid(sdram_read_valid),
		.mem_write_ack (sdram_write_ack),

        .any_buffers(any_delay_buffers),

        .ctrl_data_in(ctrl_data_in),
        
        .data_req(data_req_delay),
        .data_return(data_return_delay),
        .data_return_valid(data_return_valid_delay),
        
        .stuck(stuck_delay)
	);
	
	wire filter_calc_req;
	wire [3:0] filter_req_type;
	wire [7:0] filter_handle_out;
	wire signed [data_width - 1 : 0] filter_data_out;
	wire signed [data_width - 1 : 0] filter_data_in;
	wire filter_data_valid;

	wire [data_width - 1 : 0] filter_coef_write_handle = ctrl_data_in[47:40];
	wire [data_width - 1 : 0] filter_coef_target = ctrl_data_in[39: 24];
	wire [17 : 0] filter_coef_data = ctrl_data_in[17:0];
	
    wire stuck_filter;
	
	filter_master #(.data_width(data_width), .math_width(data_width), .n_filters(32), .mem_size(1024)) filters (
		.clk(clk),
		.reset(reset | resetting),
		
		.enable(pr_enable),
		
		.alloc_req(alloc_filter),
		
		.coef_write(filter_coef_write),
		.coef_commit(filter_coef_commit),
		.coef_write_handle(filter_coef_write_handle),
		.coef_target(filter_coef_target),
		.coef_data(filter_coef_data),
		
		.coef_ack(filter_ack),
		
		.calc_req(filter_calc_req),
        .req_type_in(filter_req_type),
        
		.handle_in(filter_handle_out),
		.data_in(filter_data_out),
		.data_out(filter_data_in),
		.out_valid(filter_data_valid),

        .ctrl_data_in(ctrl_data_in),
        
        
        .stuck(stuck_filter)
	);
	
	wire signed [data_width - 1 : 0] svf_data_in;
	wire [data_width - 1 : 0] svf_cutoff_in;
	wire [data_width - 1 : 0] svf_d_in;
	
	wire signed [data_width - 1 : 0] svf_low_out;
	wire signed [data_width - 1 : 0] svf_band_out;
	wire signed [data_width - 1 : 0] svf_high_out;
	
	wire svf_data_valid;
	
	wire svf_req;
	wire [$clog2(n_blocks) - 1 : 0] svf_block_in;
	
	wire svf_ack;
	
	wire svf_slot_alloc_fail;
	
	wire [4 : 0] svf_shift_in;
	
	`ifdef ENABLE_SVF
	svf_master #(.data_width(data_width), .math_width(18), .block_addr_width($clog2(n_blocks)), .n_slots(32)) svf
	(
		.clk(clk),
		.reset(reset | resetting),
		
		.enable(pr_enable),
		
		.data_in(svf_data_in),
		.cutoff_in(svf_cutoff_in),
		.d_in(svf_d_in),
		
		.shift_in(svf_shift_in),
		
		.low_out(svf_low_out),
		.band_out(svf_band_out),
		.high_out(svf_high_out),
		
		.data_valid(svf_data_valid),
		
		.req(svf_req),
		.block_in(svf_block_in),
		
		.ack(svf_ack),
		
		.slot_alloc_fail(svf_slot_alloc_fail)
	);
	`else
	assign svf_ack = 0;
	`endif
	
	/**********/
	/* Wiring */
	/**********/
	
	reg signed [data_width - 1 : 0] sample_latched;
	
	reg [15:0] state;
	
	reg invalid = 0;
	assign error = invalid;
	
	reg [63 : 0] sample_ctr = 0;
	
	reg wait_one = 0;
	
	wire core_ready;

	wire lut_req;
	wire [`LUT_HANDLE_WIDTH - 1 : 0] lut_req_handle;
	wire signed [data_width - 1 : 0] lut_req_arg;
	wire signed [data_width - 1 : 0] lut_data;
	wire lut_valid;
	
	wire controller_valid;
	wire invalid_command;
	
	wire block_reg_write;
	wire invalid_lut_request;

	wire delay_read_req;
	wire delay_write_req;
	wire [data_width - 1 : 0] delay_req_handle;
	wire [data_width - 1 : 0] delay_write_data;
	wire [data_width - 1 : 0] delay_read_data;
	wire delay_read_valid;
	wire delay_write_ack;
	
	wire invalid_delay_read;
	wire invalid_delay_write;
	wire invalid_delay_alloc;
	
	always @(posedge clk) begin
		wait_one <= 0;
		if (reset | full_reset) begin
			state 			<= `PIPELINE_READY;
			sample_latched 	<= 0;
			ready 			<= 1;
			invalid 		<= 0;
			sample_ctr 		<= 0;
		end
		else begin
			case (state)
				`PIPELINE_READY: begin
					ready <= 1;
					
					if (in_valid) begin
						state 	<= `PIPELINE_PROCESSING;
						ready 	<= 0;
						sample_ctr <= sample_ctr + 1;
						wait_one <= 1;
					end
				end
			
				`PIPELINE_PROCESSING: begin
					if (!wait_one) begin
						if (core_ready) begin
							ready <= 1;
							state <= `PIPELINE_READY;
						end
					end
				end
				
				`PIPELINE_INVALID: begin
					invalid <= 1;
					ready 	<= 0;
				end
				
				default: begin
					invalid <= 1;
					state 	<= `PIPELINE_INVALID;
				end
			endcase
		end
	end
	
	reg data_req_active;
	
	localparam DATA_REQ_TARGET_NONE  = 4'd0;
	localparam DATA_REQ_TARGET_CORE  = 4'd1;
	localparam DATA_REQ_TARGET_DELAY = 4'd2;
	
	logic [3:0] data_req_target;
	wire data_req_core;
	wire data_req_delay;
	
	reg  [3:0] data_req_target_r;
	
	wire [31:0] data_return_core;
	wire [31:0] data_return_delay;
	wire data_return_valid_core;
	wire data_return_valid_delay;

	reg [`CTRL_DATA_BUS_WIDTH - 1 : 0] data_req_ctrl_data_r;
	
	wire [31:0] stuck_flags;
	
	assign stuck_flags[31:18] = 0;
	assign stuck_flags[16] = stuck_delay;
	assign stuck_flags[17] = stuck_filter;
	assign stuck_flags[15:0] = stuck_flags_core;
	
	always @(*) begin
		case (ctrl_data_in[7:0])
			`DATA_REQ_N_BLOCKS:    	data_req_target = DATA_REQ_TARGET_CORE;
			`DATA_REQ_BLOCK_INSTR: 	data_req_target = DATA_REQ_TARGET_CORE;
			`DATA_REQ_BLOCK_REG:   	data_req_target = DATA_REQ_TARGET_CORE;
			`DATA_REQ_MEM:  		data_req_target = DATA_REQ_TARGET_CORE;
			
			`DATA_REQ_N_DELAY_BUF: 	   data_req_target = DATA_REQ_TARGET_DELAY;
			`DATA_REQ_DELAY_BUF_SIZE:  data_req_target = DATA_REQ_TARGET_DELAY;
			`DATA_REQ_DELAY_BUF_DELAY: data_req_target = DATA_REQ_TARGET_DELAY;
			`DATA_REQ_DELAY_BUF_ADDR:  data_req_target = DATA_REQ_TARGET_DELAY;
			`DATA_REQ_DELAY_BUF_POS:   data_req_target = DATA_REQ_TARGET_DELAY;
			`DATA_REQ_DELAY_BUF_GAIN:  data_req_target = DATA_REQ_TARGET_DELAY;
			`DATA_REQ_DELAY_BUF_LRWA:  data_req_target = DATA_REQ_TARGET_DELAY;
			
			default: data_req_target = DATA_REQ_TARGET_NONE;
		endcase
	end
	
	assign data_req_core  = data_req & (data_req_target == DATA_REQ_TARGET_CORE);
	assign data_req_delay = data_req & (data_req_target == DATA_REQ_TARGET_DELAY);
	
	always @(posedge clk) begin
		data_return_valid <= 0;
	
		if (reset | resetting) begin
			data_return_valid <= 0;
			data_req_active <= 0;
		end else begin
			if (data_req) begin
				data_req_ctrl_data_r <= ctrl_data_in;
				data_req_active <= 1;
				data_req_target_r <= data_req_target;
				
				if (data_req_target == DATA_REQ_TARGET_NONE) begin
					data_req_active <= 0;
					case (ctrl_data_in[7:0])
						`DATA_REQ_SAMPLE_COUNT: begin
							data_return <= sample_ctr;
							data_return_valid <= 1;
						end
						
						`DATA_REQ_STUCK_FLAGS: begin
							data_return <= stuck_flags;
							data_return_valid <= 1;
						end
					endcase
				end
			end else if (data_req_active) begin
				case (data_req_target_r)
					DATA_REQ_TARGET_CORE: begin
						if (data_return_valid_core) begin
							data_return <= data_return_core;
							data_return_valid <= 1;
							data_req_active <= 0;
						end
					end
					
					DATA_REQ_TARGET_DELAY: begin
						if (data_return_valid_delay) begin
							data_return <= data_return_delay;
							data_return_valid <= 1;
							data_req_active <= 0;
						end
					end
				endcase
			end
		end
	end
endmodule


`default_nettype wire
