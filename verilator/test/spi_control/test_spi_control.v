`include "defs.vh"
`include "filter.vh"
import types_pkg::*;
module test_spi_control (
    input wire clk, reset, sck, cs, mosi,
    output wire miso, byte_valid,
    output wire [7:0] received, status,
    output wire [47:0] control,
    output wire [1:0] alloc, write_coef, update_coef, commit_coef,
    input wire request, request_pipeline,
    input wire [7:0] handle,
    input wire [15:0] audio,
    output wire result_valid, result_invalid, current_pipeline,
    output wire [15:0] result
);
    wire [1:0] filter_ack, valid, invalid;
    wire [15:0] results [1:0];
    filter_rw_req_t req;
    assign req = '{handle:handle, arg_a:audio, arg_b:0, arg_c:0,
                   shift:0, block:0, flags:`FILTER_REQ_TYPE_POLY};
    assign result_valid = valid[request_pipeline];
    assign result_invalid = invalid[request_pipeline];
    assign result = results[request_pipeline];
    for (genvar p=0;p<2;p=p+1) begin: pipelines
        filter_master master (
            .clk(clk), .reset(reset), .enable(1'b1), .alloc_req(alloc[p]),
            .coef_write(write_coef[p]), .coef_update(update_coef[p]),
            .coef_commit(commit_coef[p]), .coef_ack(filter_ack[p]),
            .coef_write_handle(8'b0), .coef_target(16'b0), .coef_data(18'b0),
            .ctrl_data_in(control), .req_valid(request && request_pipeline==p),
            .req_in(req), .req_ack(), .req_invalid(invalid[p]),
            .req_response(results[p]), .req_response_valid(valid[p]), .stuck()
        );
    end
    sync_spi_slave spi (
        .clk(clk), .reset(reset), .sck(sck), .cs(cs), .mosi(mosi), .miso(miso),
        .enable(1'b1), .miso_byte(status), .mosi_byte(received), .data_valid(byte_valid)
    );
    control_unit #(.data_width(16)) controller (
        .clk(clk), .reset(reset), .in_byte(received), .in_valid(byte_valid),
        .spi_byte_out(status), .ctrl_data_out(control), .alloc_filter(alloc),
        .filter_coef_write(write_coef), .filter_coef_update(update_coef),
        .filter_coef_commit(commit_coef), .filter_ack(filter_ack),
        .current_pipeline(current_pipeline),
        .pipeline_regfiles_syncing(2'b0), .pipeline_resetting(2'b0),
        .pipelines_swapping(1'b0), .health(1'b1),
        .pipeline_data_return('{default:32'b0}), .pipeline_data_return_valid(2'b0),
        .read32_data(32'b0), .read32_valid(1'b0),
        .sdram_read_count(64'b0), .sdram_write_count(64'b0)
    );
endmodule
