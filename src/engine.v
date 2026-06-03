`include "engine.vh"
`include "core.vh"

`default_nettype none

module dsp_engine #(
		parameter n_blocks 			= 256,
		parameter integer data_width,
		parameter spi_fifo_length	= 32,
		parameter sdram_addr_width,
		parameter sdram_size
	) (
		input wire clk,
		input wire reset,

		input wire [data_width - 1 : 0]  in_sample,
		output reg [data_width - 1 : 0] out_sample,
		
		input wire sample_valid,
		
		input  wire [7:0] command_in,
		input  wire command_in_valid,
		output wire invalid_command,
		
		output wire [$clog2(spi_fifo_length) : 0] fifo_count,

		output wire current_pipeline,
		
		output wire [7:0] spi_byte_out,
		
		output wire sdram_read,
		output wire sdram_write,
		output wire sdram_refresh,
		output wire [sdram_addr_width - 1 : 0] addr_to_sdram,
		output wire [data_width - 1 : 0] data_to_sdram,
		input  wire [data_width - 1 : 0] data_from_sdram,

		input wire sdram_data_valid,
		input wire sdram_busy,
		
		input wire [63:0] sdram_read_count,
		input wire [63:0] sdram_write_count
	);

	wire signed [data_width - 1 : 0] input_gain;
	wire signed [data_width - 1 : 0] input_gains [1:0];
	
	wire signed [data_width - 1 : 0] output_gain;
	wire signed [data_width - 1 : 0] output_gains [1:0];
	
	reg tick;
	wire signed [data_width - 1 : 0] in_sample_r;
	
	always @(posedge clk) begin
		tick <= 0;
		
		if (sample_valid) begin
			in_sample_r <= in_sample;
			tick <= 1;
		end
		
		if (tick) begin
			out_sample <= sample_out_processed;
		end
	end
	
	gain_controller #(.data_width(data_width), .gain_format(`GAIN_FORMAT)) gain_ctrl
		(
			.clk(clk),
			.reset(reset),

			.tick(tick),

			.set_input_gain(set_input_gain),
			.set_output_gain(set_output_gain),
			.data_in(ctrl_data_out),
			
			.input_gain(input_gain),
			.input_gains(input_gains),
			
			.output_gain(output_gain),
			.output_gains(output_gains),
			
			.out_samples(out_samples),
			
			.swap_pipelines(swap_pipelines),
			.swap_tail_enable(swap_tail_enable),
			
			.pipelines_swapping(pipelines_swapping),
			
			.current_pipeline(current_pipeline)
		);
	
	/*******/
	/*******/
	/* DSP */
	/*******/
	/*******/
	
	wire signed [data_width - 1 : 0] sample_preproc_a;
	wire signed [data_width - 1 : 0] sample_preproc_b;
	
	preprocessing_stage #(.data_width(data_width), .gain_format(`GAIN_FORMAT)) preproc
	(
		.clk(clk),
		.reset(reset),
		
		.tick(tick),
		
		.sample_in(in_sample),
		
		.sample_out_a(sample_preproc_a),
		.sample_out_b(sample_preproc_b),
		
		.input_gain(input_gain),
		.input_gains(input_gains)
	);

	/***************************************************************************/
	/* Dual DSP piplines for atomic, artifact-free runtime DSP reconfiguration */
	/***************************************************************************/
	
	dsp_pipeline #(.data_width(data_width), .n_blocks(n_blocks), .sdram_addr_width(sdram_addr_width - 1)) pipeline_a (
		.clk(clk),
		.reset(reset | pipeline_a_reset),
		
		.in_valid(tick),
		
		.in_sample(sample_preproc_a),
		.out_sample(out_samples[0]),
		
		.error(pipeline_a_error),

		.instr_write(pipeline_a_block_instr_write),
	
		.ctrl_data(ctrl_data_out),
		.reg_0_write(pipeline_a_block_reg_0_write),
		.reg_1_write(pipeline_a_block_reg_1_write),
		
		.reg_writes_commit(pipeline_a_reg_writes_commit),
		.regfile_syncing(pipeline_a_regfile_syncing),
	
		.alloc_delay(pipeline_a_alloc_delay),
		.alloc_filter(pipeline_a_alloc_filter),
		
		.filter_coef_write(pipeline_a_filter_coef_write),
		.filter_coef_commit(pipeline_a_filter_coef_commit),
		
		.filter_ack(filter_ack[0]),
		
		.full_reset(pipeline_a_full_reset),
		.enable(pipeline_a_enable),
		
		.resetting(pipeline_a_resetting),

		.sdram_req(pipeline_sdram_reqs[0]),
		.sdram_req_type(pipeline_sdram_req_types[0]),
		
		.sdram_write_ack(sdram_write_ack[0]),
		.sdram_read_valid(sdram_read_valid[0]),

		.sdram_addr(pipeline_a_sdram_addr),
		.sdram_data_out(pipeline_a_sdram_data),
		
		.sdram_data_in(sdram_data_in),
		
		.data_req(pipeline_data_req[0]),
		
		.data_return(pipeline_a_data_return),
		.data_return_valid(pipeline_a_data_return_valid),

        .ctrl_data_in(ctrl_data)
	);
	
	dsp_pipeline #(.data_width(data_width), .n_blocks(n_blocks), .sdram_addr_width(sdram_addr_width - 1)) pipeline_b (
		.clk(clk),
		.reset(reset | pipeline_b_reset),
		
		.in_valid(tick),
		
		.in_sample(sample_preproc_b),
		.out_sample(out_samples[1]),
		
		.error(pipeline_b_error),

		.instr_write(pipeline_b_block_instr_write),
	
		.ctrl_data(ctrl_data_out),
		.reg_0_write(pipeline_b_block_reg_0_write),
		.reg_1_write(pipeline_b_block_reg_1_write),
		
		.reg_writes_commit(pipeline_b_reg_writes_commit),
		.regfile_syncing(pipeline_b_regfile_syncing),
	
		.alloc_delay(pipeline_b_alloc_delay),
		.alloc_filter(pipeline_b_alloc_filter),
		
		.filter_coef_write(pipeline_b_filter_coef_write),
		.filter_coef_commit(pipeline_b_filter_coef_commit),
		
		.filter_ack(filter_ack[1]),

		.full_reset(pipeline_b_full_reset),
		.enable(pipeline_b_enable),
		
		.resetting(pipeline_b_resetting),
		
		.sdram_req(pipeline_sdram_reqs[1]),
		.sdram_req_type(pipeline_sdram_req_types[1]),
		
		.sdram_write_ack(sdram_write_ack[1]),
		.sdram_read_valid(sdram_read_valid[1]),

		.sdram_addr(pipeline_b_sdram_addr),
		.sdram_data_out(pipeline_b_sdram_data),
		
		.sdram_data_in(sdram_data_in),
		
		.data_req(pipeline_data_req[1]),
		
		.data_return(pipeline_b_data_return),
		.data_return_valid(pipeline_b_data_return_valid),

        .ctrl_data_in(ctrl_data)
	);
	
	wire signed [data_width - 1 : 0] sample_out_processed;
	
	postprocessing_stage #(.data_width(data_width), .gain_format(`GAIN_FORMAT)) postproc
	(
		.clk(clk),
		.reset(reset),
		
		.tick(tick),
		
		.samples_in(out_samples),
		
		.sample_out(sample_out_processed),
		
		.output_gain(output_gain),
		.output_gains(output_gains)
	);
	
	/********************************************************/
	/* Health monitor; reports busted configs/DSP disasters */
	/********************************************************/
	
	wire health;
	wire peak_detect;
	wire envl_detect;
	
	wire health_monitor_enable;
	wire health_monitor_reset;
	
	health_monitor #(.data_width(data_width)) health_monitor (
		.clk(clk),
		.enable(health_monitor_enable),
		
		.reset(health_monitor_reset),
		
		.sample_valid(tick),
		.sample_in(out_samples[~current_pipeline]),
		
		.health(health),
		
		.peak_detect(peak_detect),
		.envl_detect(envl_detect)
	);
	
	/*****************/
	/*****************/
	/* Input/control */
	/*****************/
	/*****************/
	
	// A FIFO to store incoming SPI transfers
	fifo_buffer #(.data_width(8), .n(spi_fifo_length)) spi_fifo (
		.clk(clk),
		.reset(reset),
		
		.data_in(command_in),
		.data_out(command_byte),
		
		.write(command_in_valid),
		.next(inp_fifo_next),
		
		.nonempty(inp_fifo_nonempty),
		.full(inp_fifo_full),
		
		.count(fifo_count)
	);
	
	/************************************************************/
	/* Global control unit; executes commands recieved over SPI */
	/************************************************************/
	
	localparam filter_width = 18;
	
	wire [7:0] control_state;
	
	wire [1:0] alloc_filter;
	wire pipeline_a_alloc_filter = alloc_filter[0];
	wire pipeline_b_alloc_filter = alloc_filter[1];
	wire [1:0] filter_coef_write;
	wire [1:0] filter_coef_commit;
	wire [1:0] filter_ack;
	wire pipeline_a_filter_coef_write  = filter_coef_write [0];
	wire pipeline_a_filter_coef_commit = filter_coef_commit[0];
	wire pipeline_b_filter_coef_write  = filter_coef_write [1];
	wire pipeline_b_filter_coef_commit = filter_coef_commit[1];
	wire [data_width - 1 : 0] filter_coef_write_handle;
	wire [data_width - 1 : 0] filter_order_ff;
	wire [data_width - 1 : 0] filter_order_fb;
	wire [7 : 0] filter_alloc_format;
	wire [data_width - 1 : 0] filter_coef_target;
	wire [filter_width : 0] filter_coef_data;

    wire [`CTRL_DATA_BUS_WIDTH - 1 : 0] ctrl_data;
    
    wire [1:0] pipeline_data_req;
    
    wire [31:0] pipeline_a_data_return;
    wire pipeline_a_data_return_valid;
    wire [31:0] pipeline_b_data_return;
    wire pipeline_b_data_return_valid;
    wire [31:0] pipeline_data_return [1:0];
    wire [1 :0] pipeline_data_return_valid;
    
    assign pipeline_data_return[0] = pipeline_a_data_return;
    assign pipeline_data_return[1] = pipeline_b_data_return;
    assign pipeline_data_return_valid[0] = pipeline_a_data_return_valid;
    assign pipeline_data_return_valid[1] = pipeline_b_data_return_valid;
	
	control_unit #(.n_blocks(n_blocks), .data_width(data_width)) controller (
		.clk(clk),
		.reset(reset),
		
		.in_byte(command_byte),
		.in_valid(inp_fifo_nonempty),
		
		.next(inp_fifo_next),
		
		.current_pipeline(current_pipeline),
		
		.block_target(block_target),
		.reg_target(reg_target),
		.instr_out(ctrl_instr_out),
		.data_out(ctrl_data_out),
		
		.block_instr_write(block_instr_write),
		.block_reg_0_write(block_reg_0_write),
		.block_reg_1_write(block_reg_1_write),
		
		.reg_writes_commit(reg_writes_commit),
		
		.alloc_delay(alloc_delay),
		.alloc_filter(alloc_filter),
		.delay_size_out(delay_alloc_size),
		.init_delay_out(delay_init_delay),
		.filter_order_ff_out(filter_order_ff),
		.filter_order_fb_out(filter_order_fb),
		.filter_alloc_format(filter_alloc_format),
		.filter_coef_write(filter_coef_write),
		.filter_coef_commit(filter_coef_commit),
		.filter_ack(filter_ack),
		.filter_coef_write_handle_out(filter_coef_write_handle),
		.filter_coef_target_out(filter_coef_target),
		.filter_coef_data_out(filter_coef_data),
		
		.swap_pipelines(swap_pipelines),
		.swap_tail_enable(swap_tail_enable),
		.pipelines_swapping(pipelines_swapping),
		.pipeline_regfiles_syncing(pipeline_regfiles_syncing),
		.pipeline_reset(pipeline_reset),
		.pipeline_full_reset(pipeline_full_reset),
		.pipeline_resetting(pipeline_resetting),
		.pipeline_enables(pipeline_enables),
		.set_input_gain(set_input_gain),
		.set_output_gain(set_output_gain),
		
		.health(health),
		.health_monitor_enable(health_monitor_enable),
		.health_monitor_reset(health_monitor_reset),
		
		.spi_byte_out(spi_byte_out),
		
		.pipeline_data_req(pipeline_data_req),

		.pipeline_data_return(pipeline_data_return),
		.pipeline_data_return_valid(pipeline_data_return_valid),

        .ctrl_data_out(ctrl_data),
        
        .sdram_read_count(sdram_read_count),
        .sdram_write_count(sdram_write_count)
	);
	
	wire pipeline_a_sdram_reqs;
	wire pipeline_b_sdram_reqs;
	wire pipeline_a_sdram_req_types;
	wire pipeline_b_sdram_req_types;
	
	wire [sdram_addr_width - 2 : 0] pipeline_a_sdram_addr;
	wire [sdram_addr_width - 2 : 0] pipeline_b_sdram_addr;
	wire [data_width       - 1 : 0] pipeline_a_sdram_data;
	wire [data_width       - 1 : 0] pipeline_b_sdram_data;
	
	wire [sdram_addr_width - 2 : 0] pipeline_sdram_addr [1:0];
	assign pipeline_sdram_addr[0] = pipeline_a_sdram_addr;
	assign pipeline_sdram_addr[1] = pipeline_b_sdram_addr;
	
	wire [data_width - 1 : 0] pipeline_sdram_data [1:0];
	assign pipeline_sdram_data[0] = pipeline_a_sdram_data;
	assign pipeline_sdram_data[1] = pipeline_b_sdram_data;

	wire [1:0] pipeline_sdram_reqs;
	wire [1:0] pipeline_sdram_req_types;
	
	wire [1:0] sdram_write_ack;
	wire [1:0] sdram_read_valid;
	
	wire [data_width - 1 : 0] sdram_data_in;
	
	sdram_interface #(.data_width(data_width), .addr_width(sdram_addr_width), .sdram_size(sdram_size)) sdram_int
		(
			.clk(clk),
			.reset(reset),
			
			.req(pipeline_sdram_reqs),
			.req_type(pipeline_sdram_req_types),
			.write_ack(sdram_write_ack),
			.read_valid(sdram_read_valid),
			
			.addr_in(pipeline_sdram_addr),
			.data_in(pipeline_sdram_data),
			
			.data_out(sdram_data_in),
			
			.controller_read(sdram_read),
			.controller_write(sdram_write),
			.refresh(sdram_refresh),
			.addr_to_controller(addr_to_sdram),
			.data_to_controller(data_to_sdram),
			.data_from_controller(data_from_sdram),
			
			.data_from_controller_valid(sdram_data_valid),
			.controller_busy(sdram_busy)
		);
	
	/**********/
	/* Wiring */
	/**********/
	
	wire signed [data_width - 1 : 0] out_samples [1:0];

	wire pipeline_a_error;
	wire pipeline_b_error;

	wire pipelines_swapping;

	wire [1:0] block_instr_write;
	wire [1:0] block_reg_0_write;
	wire [1:0] block_reg_1_write;
	wire [1:0] reg_writes_commit;
	wire [1:0] alloc_delay;
	wire [1:0] pipeline_reset;
	wire [1:0] pipeline_full_reset;
	wire [1:0] pipeline_enables;
	wire [1:0] pipeline_resetting;
	wire [1:0] pipeline_regfiles_syncing;

	wire [$clog2(n_blocks) - 1 : 0] block_target;
	wire reg_target;

	wire [data_width 		 - 1 : 0] ctrl_data_out;
	wire [`BLOCK_INSTR_WIDTH - 1 : 0] ctrl_instr_out;

	wire swap_pipelines;
	wire swap_tail_enable;
	wire controller_ready;

	reg  ctrl_inp_ready = 0;
	wire ctrl_inp_req;
	wire ctrl_inp_ack;

	wire [7:0] command_byte;
	wire inp_fifo_nonempty;
	wire inp_fifo_full;

	wire inp_fifo_next;

	reg [63 : 0] sample_ctr = 0;

	reg apply_input_gain = 0;
	reg mix_outputs = 0;

	reg out_sample_ready;
	wire in_sample_valid;
	wire out_sample_valid;

	reg [7:0] state = `ENGINE_STATE_READY;

	reg inp_fifo_waiting = 0;
	
	wire set_input_gain;
	wire set_output_gain;
	
	wire [2 * data_width - 1 : 0] delay_alloc_size;
	wire [2 * data_width - 1 : 0] delay_init_delay;
	
	wire pipeline_a_block_instr_write 	= block_instr_write		[0];
	wire pipeline_a_block_reg_0_write 	= block_reg_0_write  	[0];
	wire pipeline_a_block_reg_1_write 	= block_reg_1_write  	[0];
	wire pipeline_a_reg_writes_commit 	= reg_writes_commit 	[0];
	wire pipeline_a_regfile_syncing;
	wire pipeline_a_alloc_delay 		= alloc_delay 			[0];
	wire pipeline_a_enable 				= pipeline_enables 		[0];
	wire pipeline_a_full_reset 			= pipeline_full_reset	[0];
	wire pipeline_a_resetting;
	wire pipeline_a_reset	 			= pipeline_reset		[0];

	wire pipeline_b_block_instr_write 	= block_instr_write		[1];
	wire pipeline_b_block_reg_0_write 	= block_reg_0_write  	[1];
	wire pipeline_b_block_reg_1_write 	= block_reg_1_write  	[1];
	wire pipeline_b_reg_writes_commit 	= reg_writes_commit 	[1];
	wire pipeline_b_regfile_syncing;
	wire pipeline_b_alloc_delay 		= alloc_delay 			[1];
	wire pipeline_b_enable 				= pipeline_enables 		[1];
	wire pipeline_b_full_reset 			= pipeline_full_reset	[1];
	wire pipeline_b_resetting;
	wire pipeline_b_reset	 			= pipeline_reset		[1];
	
	assign pipeline_resetting = {pipeline_b_resetting, pipeline_a_resetting};
	assign pipeline_regfiles_syncing = {pipeline_b_regfile_syncing, pipeline_a_regfile_syncing};
endmodule

`default_nettype wire
