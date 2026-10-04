`include "defs.vh"

// Byte addresses identify word-aligned registers. Unmapped reads have no reply.
module build_registers (
    input wire clk, reset, read_req,
    input wire [23:0] read_addr,
    output reg [31:0] read_data,
    output reg read_valid
);
    always @(posedge clk) begin
        read_valid <= 0;
        if (!reset && read_req) begin
            case (read_addr)
                24'h000000: begin read_data <= `KESTREL_MAGIC; read_valid <= 1; end
                24'h000004: begin read_data <= `BUILD_FLAGS; read_valid <= 1; end
            endcase
        end
    end
endmodule
