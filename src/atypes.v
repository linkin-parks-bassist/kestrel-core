`include "defs.vh"

package types_pkg;
	
	parameter integer data_width = 16;
	parameter integer math_width = 18;
	
	typedef struct packed {
		logic [7 : 0] handle;
		logic [`DATA_WIDTH - 1 : 0] arg_a;
		logic [`DATA_WIDTH - 1 : 0] arg_b;
		logic [`BLOCK_ADDR_W - 1 : 0] block;
		bit [3:0] flags;
	} rw_req_t;
	
	typedef struct packed {
		logic [7 : 0] handle;
		logic [`DATA_WIDTH - 1 : 0] arg_a;
		logic [`DATA_WIDTH - 1 : 0] arg_b;
		logic [`DATA_WIDTH - 1 : 0] arg_c;
		bit   [3 : 0] shift;
		logic [`BLOCK_ADDR_W - 1 : 0] block;
		bit   [3 : 0] flags;
	} filter_rw_req_t;
	
endpackage
