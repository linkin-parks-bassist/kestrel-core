`include "defs.vh"
`include "filter.vh"
import types_pkg::*;
module test_polynomial (
    input wire clk, reset, alloc, coef_write, coef_update, coef_commit, request,
    input wire [47:0] control,
    input wire [7:0] handle,
    input wire [15:0] audio,
    output wire valid, invalid,
    output wire [15:0] result
);
    filter_rw_req_t req;
    assign req = '{handle:handle, arg_a:audio, arg_b:0, arg_c:0,
                   shift:0, block:0, flags:`FILTER_REQ_TYPE_POLY};
    filter_master dut (
        .clk(clk), .reset(reset), .enable(1'b1), .alloc_req(alloc),
        .coef_write(coef_write), .coef_update(coef_update), .coef_commit(coef_commit),
        .coef_write_handle(8'b0), .coef_target(16'b0), .coef_data(18'b0),
        .req_valid(request), .req_in(req), .req_ack(), .req_invalid(invalid),
        .req_response(result), .req_response_valid(valid), .coef_ack(),
        .ctrl_data_in(control), .stuck()
    );
endmodule
