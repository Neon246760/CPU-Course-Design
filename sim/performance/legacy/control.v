`timescale 1ns/1ps

`include "rv32i_defs.vh"

module perf_legacy_control(
    input  wire [31:0] instr,
    output reg         reg_write,
    output reg         alu_src,
    output reg         mem_write,
    output reg         mem_to_reg,
    output reg         branch,
    output reg  [2:0]  alu_ctrl
);
    wire [6:0] opcode = instr[6:0];
    wire [2:0] funct3 = instr[14:12];
    wire [6:0] funct7 = instr[31:25];

    always @(*) begin
        // defaults
        reg_write = 1'b0;
        alu_src   = 1'b0;
        mem_write = 1'b0;
        mem_to_reg= 1'b0;
        branch    = 1'b0;
        alu_ctrl  = `ALU_ADD;

        case (opcode)
            `OP_RTYPE: begin
                reg_write = 1'b1;
                alu_src   = 1'b0;
                mem_to_reg= 1'b0;
                mem_write = 1'b0;
                branch    = 1'b0;
                case (funct3)
                    `F3_ADD_SUB: alu_ctrl = (funct7 == 7'b0100000) ? `ALU_SUB : `ALU_ADD;
                    `F3_OR     : alu_ctrl = `ALU_OR;
                    `F3_SLT    : alu_ctrl = `ALU_SLT;
                    default    : alu_ctrl = `ALU_ADD;
                endcase
            end

            `OP_ITYPE: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                mem_to_reg= 1'b0;
                mem_write = 1'b0;
                branch    = 1'b0;
                alu_ctrl  = (funct3 == 3'b110) ? `ALU_OR : `ALU_ADD;
            end

            `OP_LOAD: begin
                // LW
                reg_write = 1'b1;
                alu_src   = 1'b1;
                mem_to_reg= 1'b1;
                mem_write = 1'b0;
                branch    = 1'b0;
                alu_ctrl  = `ALU_ADD; // address = rs1 + imm
            end

            `OP_STORE: begin
                // SW
                reg_write = 1'b0;
                alu_src   = 1'b1;
                mem_to_reg= 1'b0;
                mem_write = 1'b1;
                branch    = 1'b0;
                alu_ctrl  = `ALU_ADD; // address = rs1 + imm
            end

            `OP_BRANCH: begin
                // BEQ
                reg_write = 1'b0;
                alu_src   = 1'b0;
                mem_to_reg= 1'b0;
                mem_write = 1'b0;
                branch    = 1'b1;
                alu_ctrl  = `ALU_SUB; // compare rs1-rs2
            end
            default: begin
                // keep defaults
            end
        endcase
    end
endmodule

