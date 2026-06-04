`include "instr_dec.vh"

`default_nettype none

module instr_decoder #(parameter integer data_width)
	(
		input wire clk,

		input  wire [31 : 0] instr,
		
		output logic [4 : 0] operation,
		
		output logic [3 : 0] src_a,
		output logic [3 : 0] src_b,
		output logic [3 : 0] src_c,
		output logic [3 : 0] dest,
		
		output logic src_a_reg,
		output logic src_b_reg,
		output logic src_c_reg,
		
		output logic saturate_disable,
		output logic shift_disable,
		output logic signedness,
		
		output logic [4 : 0] shift,
		output logic [11 : 0] res_addr,
		
		output logic arg_a_needed,
		output logic arg_b_needed,
		output logic arg_c_needed,
		
		output logic accumulator_needed,
		
		output logic writes_channel,
		output logic writes_acc,
		output logic commit_flag,
		output logic writes_external,
		
		output logic [$clog2(`N_INSTR_BRANCHES) - 1 : 0] branch,

		output logic [$clog2(`N_MISC_OPS) - 1 : 0] misc_op,
		
		output logic [3:0] flags
	);
	
	wire   instr_format 	  = instr[5];
	
	assign operation 		  = instr[4  :  0];
	assign {src_a_reg, src_a} = instr[10 :  6];
	assign {src_b_reg, src_b} = instr[15 : 11];
	assign shift_disable  	  = instr[	   31];
	
	assign {src_c_reg, src_c} = (instr_format) ? 		5'b0  : instr[20:16];
	assign dest 			  = (instr_format) ? instr[19:16] : instr[24:21];
	assign shift			  = (instr_format) ? 		5'b0  : instr[29:25];
	assign saturate_disable   = (instr_format) ? 		   0  : instr[30];
	assign res_addr			  = (instr_format) ? instr[31:20] : 12'b0;
	
	assign arg_a_needed = (operation == `BLOCK_INSTR_MADD
						|| operation == `BLOCK_INSTR_ARSH
						|| operation == `BLOCK_INSTR_LSH
						|| operation == `BLOCK_INSTR_RSH
						|| operation == `BLOCK_INSTR_ABS
						|| operation == `BLOCK_INSTR_MIN
						|| operation == `BLOCK_INSTR_MAX
						|| operation == `BLOCK_INSTR_CLAMP
						|| operation == `BLOCK_INSTR_MACZ
						|| operation == `BLOCK_INSTR_MAC
						|| operation == `BLOCK_INSTR_UMACZ
						|| operation == `BLOCK_INSTR_UMAC
						|| operation == `BLOCK_INSTR_LUT_READ
						|| operation == `BLOCK_INSTR_DELAY_READ
						|| operation == `BLOCK_INSTR_DELAY_WRITE
						|| operation == `BLOCK_INSTR_MEM_WRITE
						|| operation == `BLOCK_INSTR_FILTER
						|| operation == `BLOCK_INSTR_SVF
						|| operation == `BLOCK_INSTR_POLY);
	
	assign arg_b_needed = (operation == `BLOCK_INSTR_MADD
						|| operation == `BLOCK_INSTR_MIN
						|| operation == `BLOCK_INSTR_MAX
						|| operation == `BLOCK_INSTR_CLAMP
						|| operation == `BLOCK_INSTR_MACZ
						|| operation == `BLOCK_INSTR_MAC
						|| operation == `BLOCK_INSTR_UMACZ
						|| operation == `BLOCK_INSTR_UMAC
						|| operation == `BLOCK_INSTR_DELAY_WRITE
						|| operation == `BLOCK_INSTR_SVF);
	
	assign arg_c_needed = (operation == `BLOCK_INSTR_MADD || operation == `BLOCK_INSTR_CLAMP || operation == `BLOCK_INSTR_SVF);
	
	assign accumulator_needed = (operation == `BLOCK_INSTR_MOV_ACC
					  || operation == `BLOCK_INSTR_MOV_LACC
					  || operation == `BLOCK_INSTR_MOV_UACC);
	
	assign signedness = (operation != `BLOCK_INSTR_UMACZ && operation != `BLOCK_INSTR_UMAC);
	
	always_comb begin
		if	  (operation == `BLOCK_INSTR_DELAY_READ || operation == `BLOCK_INSTR_DELAY_WRITE)   branch = `INSTR_BRANCH_DELAY;
		else if (operation == `BLOCK_INSTR_LUT_READ) 											branch = `INSTR_BRANCH_LUT;
		else if (operation == `BLOCK_INSTR_MEM_WRITE  || operation == `BLOCK_INSTR_MEM_READ) 	branch = `INSTR_BRANCH_MEM;
		else if (operation == `BLOCK_INSTR_MACZ 	  || operation == `BLOCK_INSTR_UMACZ
			  || operation == `BLOCK_INSTR_MAC  	  || operation == `BLOCK_INSTR_UMAC)		branch = `INSTR_BRANCH_MAC;
		else if (operation == `BLOCK_INSTR_LSH 		  || operation == `BLOCK_INSTR_RSH
			  || operation == `BLOCK_INSTR_ABS 		  || operation == `BLOCK_INSTR_MIN
			  || operation == `BLOCK_INSTR_MAX 		  || operation == `BLOCK_INSTR_CLAMP
			  || operation == `BLOCK_INSTR_MOV_ACC	  || operation == `BLOCK_INSTR_MOV_LACC
			  || operation == `BLOCK_INSTR_MOV_UACC)		 									branch = `INSTR_BRANCH_MISC;
		else if (operation == `BLOCK_INSTR_FILTER     || operation == `BLOCK_INSTR_FCASC
			  || operation == `BLOCK_INSTR_SVF		  || operation == `BLOCK_INSTR_SVF_LOW
			  || operation == `BLOCK_INSTR_SVF_HIGH	  || operation == `BLOCK_INSTR_SVF_BAND
			  || operation == `BLOCK_INSTR_POLY)												branch = `INSTR_BRANCH_FILT;
		else
			branch = `INSTR_BRANCH_MADD;
	end
	
	assign writes_channel = (branch != `INSTR_BRANCH_MAC && !writes_external);
	
	assign writes_acc = (branch == `INSTR_BRANCH_MAC);
	
	assign commit_flag = (operation == `BLOCK_INSTR_MACZ || operation == `BLOCK_INSTR_UMACZ);
	
	assign writes_external = (operation == `BLOCK_INSTR_DELAY_WRITE || operation == `BLOCK_INSTR_MEM_WRITE || operation == `BLOCK_INSTR_SVF);
	
	assign misc_op = operation - `MISC_OPCODE_MIN;
	
	always_comb begin
		case (operation)
			`BLOCK_INSTR_FILTER:	flags = `FILTER_REQ_TYPE_FILTER;
			`BLOCK_INSTR_FCASC: 	flags = `FILTER_REQ_TYPE_FCASC;
			`BLOCK_INSTR_SVF: 		flags = `FILTER_REQ_TYPE_SVF;
			`BLOCK_INSTR_SVF_LOW: 	flags = `FILTER_REQ_TYPE_SVF_LOW;
			`BLOCK_INSTR_SVF_HIGH: 	flags = `FILTER_REQ_TYPE_SVF_HIGH;
			`BLOCK_INSTR_SVF_BAND: 	flags = `FILTER_REQ_TYPE_SVF_BAND;
			`BLOCK_INSTR_POLY: 		flags = `FILTER_REQ_TYPE_POLY;
			
			default:				flags = writes_external ? 4'd1 : 4'd0;
		endcase
	end
	
endmodule

`default_nettype wire
