`define COMMAND_BEGIN_PROGRAM	 	8'd1
`define COMMAND_WRITE_BLOCK_INSTR 	8'd2
`define COMMAND_WRITE_BLOCK_REG_0 	8'd3
`define COMMAND_WRITE_BLOCK_REG_1 	8'd4
`define COMMAND_ALLOC_DELAY 		8'd5
`define COMMAND_END_PROGRAM	 		8'd10
`define COMMAND_SET_INPUT_GAIN 		8'd11
`define COMMAND_SET_OUTPUT_GAIN 	8'd12
`define COMMAND_UPDATE_BLOCK_REG_0 	8'd13
`define COMMAND_UPDATE_BLOCK_REG_1 	8'd14
`define COMMAND_COMMIT_REG_UPDATES 	8'd15
`define COMMAND_ALLOC_FILTER	 	8'd16
`define COMMAND_WRITE_FILTER_COEF 	8'd17
`define COMMAND_UPDATE_FILTER_COEF 	8'd18
`define COMMAND_COMMIT_FILTER_COEF	8'd19
`define COMMAND_READOUT				8'd20
`define COMMAND_CLEAR_TIMEOUT_FLAG	8'd35
`define COMMAND_CLEAR_BAD_FLAG		8'd36
`define COMMAND_CLEAR_CMD_ERR_FLAG	8'd37
`define COMMAND_READ				8'd38
`define COMMAND_ENABLE_TAIL			8'd39

`define DATA_REQ_COMMAND_LOG		8'd33

// If we're in a 'waiting' state, but no new data has
// appeared for a while, then it's likely
// there was an alignment mistake, possibly
// in software, or a transfer corruption.
// In this case, reset the controller, so that
// the machine doesn't get permanently locked up!
`define CONTROLLER_TIMEOUT_CYCLES	32'd112500000

`define CTRL_DATA_BUS_WIDTH (6 * 8)

`define DATA_REQ_BLOCK_INSTR 	8'd1
`define DATA_REQ_BLOCK_REG	 	8'd2

`define DATA_REQ_N_DELAY_BUF	 8'd3
`define DATA_REQ_DELAY_BUF_SIZE	 8'd4
`define DATA_REQ_DELAY_BUF_DELAY 8'd5
`define DATA_REQ_DELAY_BUF_ADDR  8'd6
`define DATA_REQ_DELAY_BUF_POS   8'd7
`define DATA_REQ_DELAY_BUF_GAIN  8'd8
`define DATA_REQ_DELAY_BUF_LRWA  8'd9
`define DATA_REQ_SAMPLE_COUNT	 8'd10
`define DATA_REQ_SDRAM_READ_CNT	 8'd11
`define DATA_REQ_SDRAM_WRITE_CNT 8'd12
`define DATA_REQ_STUCK_FLAGS	 8'd13
`define DATA_REQ_N_BLOCKS 		 8'd14
`define DATA_REQ_MEM			 8'd15
