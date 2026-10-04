`include "defs.vh"
`include "controller.vh"
import types_pkg::*;
`include "filter.v"

module test_svf (
    input logic clk, reset, valid,
    input logic [15:0] audio, cutoff, damping,
    input logic [3:0] shift,
    input logic [`BLOCK_ADDR_W-1:0] block,
    output logic ack, band_valid,
    output logic signed [15:0] low, band, high
);
    filter_rw_req_t request;
    assign request = '{handle:0, arg_a:audio, arg_b:cutoff, arg_c:damping,
        shift:shift, block:block, flags:2};
    filter_unit_svf unit (
        .clk(clk), .reset(reset), .enable(1'b1),
        .req_valid(valid), .req_in(request), .req_ack(ack), .req_invalid(),
        .low_valid(), .band_valid(band_valid), .high_valid(),
        .low_out(low), .band_out(band), .high_out(high)
    );
endmodule
