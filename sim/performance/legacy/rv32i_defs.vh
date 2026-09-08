`ifndef RV32I_DEFS_VH
`define RV32I_DEFS_VH

// RV32I opcodes
`define OP_RTYPE   7'b0110011
`define OP_ITYPE   7'b0010011   // e.g. ORI
`define OP_LOAD    7'b0000011   // e.g. LW
`define OP_STORE   7'b0100011   // e.g. SW
`define OP_BRANCH  7'b1100011   // e.g. BEQ

// funct3
`define F3_ADD_SUB 3'b000
`define F3_SLT     3'b010
`define F3_OR      3'b110

`define F3_LW_SW   3'b010
`define F3_BEQ     3'b000

// ALU perf_legacy_control encoding
`define ALU_ADD 3'd0
`define ALU_SUB 3'd1
`define ALU_OR  3'd2
`define ALU_SLT 3'd3

`endif

