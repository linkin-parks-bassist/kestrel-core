module test_spi_engine (
    input wire clk, reset, sck, cs, mosi, sample_valid,
    input wire [15:0] sample_in,
    output wire miso, current_pipeline, error, pipeline_ready,
    output wire [5:0] fifo_count,
    output wire [7:0] status,
    output wire [15:0] sample_out,
    output wire issued,
    output wire [7:0] issued_block,
    output wire [15:0] issued_reg0, issued_reg1,
    output wire ram_read, ram_write, ram_refresh,
    output wire [19:0] ram_addr,
    output wire [15:0] ram_write_data,
    input wire [15:0] ram_read_data,
    input wire ram_valid, ram_busy,
    output wire b_issued,
    output wire [7:0] b_issued_block
);
    wire [7:0] received;
    wire byte_valid;
    sync_spi_slave spi (
        .clk(clk), .reset(reset), .sck(sck), .cs(cs), .mosi(mosi), .miso(miso),
        .enable(1'b1), .miso_byte(status), .mosi_byte(received), .data_valid(byte_valid)
    );
    dsp_engine #(.data_width(16), .sdram_addr_width(20), .sdram_size(1<<20)) engine (
        .clk(clk), .reset(reset), .in_sample(sample_in), .out_sample(sample_out),
        .sample_valid(sample_valid), .command_in(received), .command_in_valid(byte_valid),
        .fifo_count(fifo_count),
        .current_pipeline(current_pipeline), .spi_byte_out(status),
        .sdram_read(ram_read), .sdram_write(ram_write), .sdram_refresh(ram_refresh),
        .addr_to_sdram(ram_addr), .data_to_sdram(ram_write_data),
        .data_from_sdram(ram_read_data), .sdram_data_valid(ram_valid), .sdram_busy(ram_busy),
        .sdram_read_count(64'b0), .sdram_write_count(64'b0)
    );
    assign error = engine.pipeline_a_error | engine.pipeline_b_error;
    assign pipeline_ready = current_pipeline ? engine.pipeline_b.ready : engine.pipeline_a.ready;
    reg [15:0] router_a_reg0, router_a_reg1, router_b_reg0, router_b_reg1;
    always @(posedge clk) begin
        if(engine.pipeline_a.core.out_valid_ofs && engine.pipeline_a.core.in_ready_router) begin
            router_a_reg0 <= engine.pipeline_a.core.register_0_out_ofs;
            router_a_reg1 <= engine.pipeline_a.core.register_1_out_ofs;
        end
        if(engine.pipeline_b.core.out_valid_ofs && engine.pipeline_b.core.in_ready_router) begin
            router_b_reg0 <= engine.pipeline_b.core.register_0_out_ofs;
            router_b_reg1 <= engine.pipeline_b.core.register_1_out_ofs;
        end
    end
    assign issued = current_pipeline ? |(engine.pipeline_b.core.out_valid_router & engine.pipeline_b.core.out_ready_router) : |(engine.pipeline_a.core.out_valid_router & engine.pipeline_a.core.out_ready_router);
    assign issued_block = current_pipeline ? engine.pipeline_b.core.block_out_router : engine.pipeline_a.core.block_out_router;
    assign issued_reg0 = current_pipeline ? router_b_reg0 : router_a_reg0;
    assign issued_reg1 = current_pipeline ? router_b_reg1 : router_a_reg1;
    assign b_issued = |(engine.pipeline_b.core.out_valid_router & engine.pipeline_b.core.out_ready_router);
    assign b_issued_block = engine.pipeline_b.core.block_out_router;
endmodule
