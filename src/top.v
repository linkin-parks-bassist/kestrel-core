`default_nettype none

module top #(
		parameter n_blocks 			= 256,
		parameter data_width 		= 16,
		parameter spi_fifo_length	= 16
	) (
		`ifndef verilator
		input wire crystal,
		`else
		input wire sys_clk,
		`endif

		input  wire cs,
		input  wire mosi,
		output wire miso,
		input  wire sck,

		output wire led0,
		output wire led1,
		output wire led2,
		output wire led3,
		output wire led4,
		output wire led5,

		output wire mclk_out,
		output wire bclk_out,
		output wire lrclk_out,
		
		input  wire i2s_din,
		output wire i2s_dout,

		output wire codec_en,
		
		// "Magic" port names that the gowin compiler connects to the on-chip SDRAM
		output wire  O_sdram_clk,
		output wire  O_sdram_cke,
		output wire  O_sdram_cs_n,            // chip select
		output wire  O_sdram_cas_n,           // columns address select
		output wire  O_sdram_ras_n,           // row address select
		output wire  O_sdram_wen_n,           // write enable
		inout  wire  [31:0] IO_sdram_dq,      // 32 bit bidirectional data bus
		output wire  [10:0] O_sdram_addr,     // 11 bit multiplexed address bus
		output wire  [1:0] O_sdram_ba,        // two banks
		output wire  [3:0] O_sdram_dqm        // 32/4
	);
	
	/**********/
	/* Engine */
	/**********/
	
	dsp_engine #(
		.n_blocks(n_blocks),
		.data_width(data_width),
		.spi_fifo_length(spi_fifo_length),
		.sdram_addr_width(sdram_addr_width),
		.sdram_size(sdram_size)
	) engine (
		.clk(sys_clk),
		.reset(reset),

		.in_sample(sample_in),
		.out_sample(sample_out),
	
		.sample_valid(sample_valid),
	
		.command_in(spi_in),
		.command_in_valid(spi_in_valid),

		.current_pipeline(current_pipeline),
		
		.out(out),
		.spi_byte_out(spi_byte_out),

		.sdram_read(sdram_read),
		.sdram_write(sdram_write),
		.sdram_refresh(sdram_refresh),
		.addr_to_sdram(addr_to_sdram),
		.data_to_sdram(data_to_sdram),
		.data_from_sdram(data_from_sdram),

		.sdram_data_valid(sdram_data_valid),
		.sdram_busy(sdram_busy),
		
		.sdram_read_count(sdram_read_count),
		.sdram_write_count(sdram_write_count)
	);
	
	wire [7:0] out;
	wire [7:0] spi_byte_out;
	
	wire current_pipeline;
	
	localparam RESET_MIN_CYCLES = 16'd1024;
	localparam PLL_LOCK_STABLE_MIN_CYCLES = 16'd1024;
	
	reg reset = 1;
	reg [15:0] reset_counter = 0;
	reg [15:0] pll_lock_ctr = 0;
	
	reg pll_lock_r;
	reg pll_lock_sync;
	
	reg [63:0] cycle_ctr = 0;
	reg [15:0] sample_mclk_cycle_ctr = 0;
	reg [15:0] sample_bclk_cycle_ctr = 0;
	reg [15:0] sample_cycle_ctr = 0;
	
	reg mclk_prev;
	reg bclk_prev;
	reg lrclk_prev;
	
	wire mclk_posedge = mclk & ~mclk_prev;
	wire bclk_posedge = bclk & ~bclk_prev;
	wire lrclk_posedge   = lrclk & ~lrclk_prev;
	
	reg [63:0] sample_ctr;
	
	always @(posedge sys_clk) begin
		mclk_prev <= mclk;
		bclk_prev <= bclk;
		lrclk_prev <= lrclk;
		
		cycle_ctr <= cycle_ctr + 1;
		if (sample_valid) begin
			sample_ctr <= sample_ctr + 1;
			sample_cycle_ctr <= 0;
			sample_mclk_cycle_ctr <= 0;
			sample_bclk_cycle_ctr <= 0;
		end else begin
			sample_cycle_ctr <= sample_cycle_ctr + 1;
			
			if (mclk_posedge)
				sample_mclk_cycle_ctr <= sample_mclk_cycle_ctr + 1;
				
			if (bclk_posedge)
				sample_bclk_cycle_ctr <= sample_bclk_cycle_ctr + 1;
		end
		
		pll_lock_r <= pll_lock;
		pll_lock_sync <= pll_lock_r;
	
		if (reset_counter < RESET_MIN_CYCLES - 1) begin
			reset_counter <= reset_counter + 1;
			pll_lock_ctr <= 0;
			reset <= 1;
		end else begin
			if (!pll_lock_sync) begin
				pll_lock_ctr <= 0;
				reset <= 1;
			end else begin
				if (pll_lock_ctr >= PLL_LOCK_STABLE_MIN_CYCLES - 1) begin
					reset <= 0;
				end else begin
					pll_lock_ctr <= pll_lock_ctr + 1;
					reset <= 1;
				end
			end
		end
		
		if (reset) sample_ctr <= 0;
	end
	
	localparam MAIN_FREQ  = 112500000;
	localparam MCLK_FREQ  = 11250000;
	localparam BCLK_FREQ  = 2812500;
	localparam LRCLK_FREQ = 44100;
	
	reg [$clog2(MAIN_FREQ  / 2) - 1 : 0] sys_clk_blinker_ctr;
	reg [$clog2(MCLK_FREQ  / 2) - 1 : 0] mclk_blinker_ctr;
	reg [$clog2(BCLK_FREQ  / 2) - 1 : 0] bclk_blinker_ctr;
	reg [$clog2(LRCLK_FREQ / 2) - 1 : 0] lrclk_blinker_ctr;

	reg sys_clk_blinker;
	reg mclk_blinker;
	reg bclk_blinker;
	reg lrclk_blinker;

    always @(posedge sys_clk) begin
        if (reset) begin
            sys_clk_blinker_ctr <= 0;
            lrclk_blinker_ctr <= 0;
            mclk_blinker_ctr <= 0;
            bclk_blinker_ctr <= 0;
            sys_clk_blinker <= 0;
            lrclk_blinker <= 0;
            mclk_blinker <= 0;
            bclk_blinker <= 0;
        end else begin
			sys_clk_blinker_ctr <= sys_clk_blinker_ctr + 1;
			
			if (lrclk_posedge)
				lrclk_blinker_ctr <= lrclk_blinker_ctr + 1;
				
			if (mclk_posedge)
				mclk_blinker_ctr <= mclk_blinker_ctr + 1;
			
			if (bclk_posedge)
				bclk_blinker_ctr <= bclk_blinker_ctr + 1;
        
            if (sys_clk_blinker_ctr == (MAIN_FREQ / 2) - 1) begin
				sys_clk_blinker <= ~sys_clk_blinker;
				sys_clk_blinker_ctr <= 0;
            end
        
            if (mclk_blinker_ctr == (MCLK_FREQ / 2) - 1) begin
				mclk_blinker <= ~mclk_blinker;
				mclk_blinker_ctr <= 0;
            end
        
            if (bclk_blinker_ctr == (BCLK_FREQ / 2) - 1) begin
				bclk_blinker <= ~bclk_blinker;
				bclk_blinker_ctr <= 0;
            end
        
            if (lrclk_blinker_ctr == (LRCLK_FREQ / 2) - 1) begin
				lrclk_blinker <= ~lrclk_blinker;
				lrclk_blinker_ctr <= 0;
            end
        end
    end

	/***********/
	/*   I/O   */
	/***********/

	// Useful LED indicators (active low)
	assign led0 = ~sys_clk_blinker;
	assign led1 = ~lrclk_blinker;
	assign led3 = ~mclk_blinker;
	assign led4 = ~bclk_blinker;

	// I2S
	wire sample_valid;

	wire [data_width - 1 : 0] sample_out;
	wire [data_width - 1 : 0] sample_in;

	i2s_trx #(.sample_size(data_width)) i2s_driver (
		.sys_clk(sys_clk), .bclk(bclk), .lrclk(lrclk), .din(i2s_din), .dout(i2s_dout),
		.enable(1'b1), .reset(reset), .rx_valid(sample_valid),
		.tx_l(sample_out), .tx_r(sample_out),
		.rx_l(sample_in), .rx_r()
	);
	
	// SPI
	wire [7:0] spi_in;
	wire spi_in_valid;
	
	reg  [4:0] spi_byte_ctr = 0;

	sync_spi_slave spi (
		.clk(sys_clk),
		.reset(reset),

		.sck(sck),
		.cs(cs),
		.mosi(mosi),
		.miso(miso),
		.miso_byte(spi_byte_out),

		.enable(1),

		.mosi_byte(spi_in),
		.data_valid(spi_in_valid)
	);
	
	// Enable power supply to codec when PLL is locked
	assign codec_en = pll_lock;
	
	/**********/
	/* Clocks */
	/**********/
	
	`ifndef verilator // Non-simulated; use crystal and PLL
	wire sys_clk;
	wire pll_lock;
	
	/* PLL to generate main clock from crystal */
	Gowin_rPLL pll(
		.clkout(sys_clk),
        .clkoutp(clk_sdram),
        .lock(pll_lock),
		.clkin(crystal)
	);
	`else // Simulated; clock is generated by simulator
	reg pll_lock = 1;
	
	always @(posedge sys_clk)
		pll_lock <= 1;
	`endif

	/* I2S clocks */
	reg mclk = 1'b0;
	reg bclk = 1'b0;
	wire lrclk;
	
	reg [2:0] mclk_ctr = 0;
	reg [3:0] bclk_counter = 4'd0;
	
	reg [5:0] lrclk_counter = 6'd0;
	assign lrclk = lrclk_counter[5];
	
	assign mclk_out  = mclk;
	assign bclk_out  = bclk;
	assign lrclk_out = lrclk;
	
	wire toggle_bclk;
	
	`ifdef verilator
	assign toggle_bclk = 1; // Run the sim at 4x speed so it's faster
	`else
	assign toggle_bclk = (bclk_counter == 3);
	`endif
	
	always @(posedge sys_clk) begin
		if (pll_lock) begin
			if (mclk_ctr == 4) begin
				mclk <= ~mclk;
				mclk_ctr <= 0;

				bclk_counter <= bclk_counter + 1'b1;
				if (toggle_bclk) begin
					bclk <= ~bclk;
					bclk_counter <= 0;

					if (bclk)
						lrclk_counter <= lrclk_counter + 1;
					end
			end else begin
				mclk_ctr <= mclk_ctr + 1;
			end
		end   
	end
	
	//`define USE_BRAM_INSTEAD
	`ifdef USE_BRAM_INSTEAD
	localparam sdram_size = (1024 * 14);
	localparam sdram_addr_width = $clog2(sdram_size);
	`else
	localparam sdram_addr_width = 20;
	localparam sdram_size = (1 << sdram_addr_width);
	`endif
	
	wire clk_sdram;
	
	wire sdram_read;
	wire sdram_write;
	wire sdram_refresh;
	wire [sdram_addr_width - 1 : 0] addr_to_sdram;
	wire [data_width - 1 : 0] data_to_sdram;
	wire [data_width - 1 : 0] data_from_sdram;

	wire sdram_data_valid;
	wire sdram_busy;
	
	wire [63:0] sdram_read_count;
	wire [63:0] sdram_write_count;
	
	`ifdef USE_BRAM_INSTEAD
	bram_standin #(.data_width(data_width), .mem_size(sdram_size), .addr_width(sdram_addr_width)) fake_sdram (
			.clk(sys_clk),
			.reset(reset),
			
			.read(sdram_read),
			.write(sdram_write),

			.addr(addr_to_sdram),
			.data_in(data_to_sdram),

			.data_out(data_from_sdram),
			.read_valid(sdram_data_valid),
			.busy(sdram_busy),

			.read_count(sdram_read_count),
			.write_count(sdram_write_count),
			
			.refresh(sdram_refresh)
		);
	
	`else
	sdram  #(
			.data_width(data_width),
			
			.FREQ(112_500_000),
			
			.ROW_WIDTH(11),
			.COL_WIDTH(8),
			.BANK_WIDTH(2),  

			.CAS(4'd3),     
			.T_WR(4'd4),
			.T_MRD(4'd4),
			.T_RP(4'd3),
			.T_RCD(4'd3),
			.T_RC(4'd8)
		)
		sdram_controller
		(
			.SDRAM_DQ(IO_sdram_dq),     // 32 bit bidirectional data bus
			.SDRAM_A(O_sdram_addr),     // 11 bit multiplexed address bus
			.SDRAM_BA(O_sdram_ba),      // 4 banks
			.SDRAM_nCS(O_sdram_cs_n),   // a single chip select
			.SDRAM_nWE(O_sdram_wen_n),  // write enable
			.SDRAM_nRAS(O_sdram_ras_n), // row address select
			.SDRAM_nCAS(O_sdram_cas_n), // columns address select
			.SDRAM_CLK(O_sdram_clk),
			.SDRAM_CKE(O_sdram_cke),
			.SDRAM_DQM(O_sdram_dqm),
			
			.clk(sys_clk),
			.clk_sdram(clk_sdram),
			.resetn(~reset),
			.rd(sdram_read),
			.wr(sdram_write),
			.refresh(sdram_refresh),
			.addr(addr_to_sdram),
			.din(data_to_sdram),
			.dout(data_from_sdram),
			.dout32(),
			.data_ready(sdram_data_valid),
			.busy(sdram_busy),
			
			.read_count(sdram_read_count),
			.write_count(sdram_write_count)
		);
	`endif
endmodule

module bram_standin #(parameter data_width = 16, parameter mem_size = 8192, parameter addr_width = $clog2(mem_size)) (
	input wire clk,
	input wire reset,
	
	input wire read,
	input wire write,
	
	input wire [addr_width - 1 : 0] addr,
	input wire [data_width - 1 : 0] data_in,
	
	output reg [data_width - 1 : 0] data_out,
	output reg read_valid,
	output wire busy,
	
	output reg [63:0] read_count,
	output reg [63:0] write_count,
	
	input wire refresh
);
	
	reg [data_width - 1 : 0] mem [mem_size - 1 : 0];
	
	reg [data_width - 1 : 0] mem_read_val;
	reg [data_width - 1 : 0] mem_write_val;
	reg [addr_width - 1 : 0] mem_read_addr;
	reg [addr_width - 1 : 0] mem_write_addr;
	reg mem_write_enable;
	
	always @(posedge clk) begin
		mem_read_val <= mem[mem_read_addr];
		
		if (mem_write_enable)
			mem[mem_write_addr] <= mem_write_val;
	end
	
	localparam IDLE 		= 3'd0;
	localparam READ_WAIT 	= 3'd1;
	localparam READ_DONE 	= 3'd2;
	localparam WRITE_BUSY 	= 3'd3;
	localparam REF 			= 3'd4;
	
	reg [2:0] state;
	
	assign busy = (state != IDLE);
	
	wire addr_valid = addr < mem_size;
	
	reg [2:0] sim_ref_ctr;
	
	always @(posedge clk) begin
		mem_write_enable <= 0;
		read_valid <= 0;
		
		if (reset) begin
			state <= IDLE;
			read_count <= 0;
			write_count <= 0;
		end else begin
			case (state)
				IDLE: begin
					if (read && addr_valid) begin
						mem_read_addr <= addr;
						
						read_count <= read_count + 1;
						state <= READ_WAIT;
					end else if (write && addr_valid) begin
						mem_write_val <= data_in;
						mem_write_addr <= addr;
						mem_write_enable <= 1;
						write_count <= write_count + 1;
						
						state <= WRITE_BUSY;
					end else if (refresh) begin
						sim_ref_ctr <= 3;
						state <= REF;
					end
				end
				
				READ_WAIT: begin
					state <= READ_DONE;
				end
				
				READ_DONE: begin
					data_out <= mem_read_val;
					read_valid <= 1;
					state <= IDLE;
				end
				
				WRITE_BUSY: begin
					state <= IDLE;
				end
			
				REF: begin
					if (sim_ref_ctr == 1)
						state <= IDLE;
					sim_ref_ctr <= sim_ref_ctr - 1;
				end
			endcase
		end
	end

endmodule

`default_nettype wire
