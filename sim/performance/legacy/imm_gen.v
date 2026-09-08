`timescale 1ns/1ps

`include "rv32i_defs.vh"

module perf_legacy_imm_gen(
    input  wire [31:0] instr,
    output reg  [31:0] imm_i,
    output reg  [31:0] imm_s,
    output reg  [31:0] imm_b
);
    wire [6:0] opcode = instr[6:0];

    always @(*) begin
        // I-type: [31:20]
        imm_i = {{20{instr[31]}}, instr[31:20]};

        // S-type: [31:25|11:7]
        imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};

        // B-type: [31|7|30:25|11:8] << 1
        imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};

        if (opcode == 7'b0) begin
            imm_i = 32'h0;
            imm_s = 32'h0;
            imm_b = 32'h0;
        end
    end
endmodule

