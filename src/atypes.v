`include "defs.vh"

package types_pkg;
	
	parameter integer data_width = 16;
	parameter integer math_width = 18;
	
	typedef logic signed [data_width - 1 : 0] sample_t;
	typedef logic        [data_width - 1 : 0] word_t;
	
	parameter integer n_blocks   = 256;
	parameter integer block_addr_w = $clog2(n_blocks + 1);
	
	typedef logic [block_addr_w - 1 : 0] block_addr_t;
	
	typedef byte handle_t;
	typedef logic [3:0] channel_addr_t;
	
	parameter integer commit_id_width = `COMMIT_ID_WIDTH;
	
	typedef logic [commit_id_width - 1 : 0] commit_id_t;
	
	typedef struct packed {
		handle_t handle;
		word_t arg_a;
		word_t arg_b;
		block_addr_t block;
		bit [3:0] flags;
	} rw_req_t;
	
	typedef struct packed {
		handle_t handle;
		word_t arg_a;
		word_t arg_b;
		word_t arg_c;
		bit [3:0] shift;
		block_addr_t block;
		bit [3:0] flags;
	} filter_rw_req_t;
	
endpackage
