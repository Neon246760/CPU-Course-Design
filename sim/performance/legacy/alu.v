`timescale 1ns/1ps

`include "rv32i_defs.vh"

module perf_legacy_alu(
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [2:0]  alu_ctrl,
    output reg  [31:0] y,
    output wire        zero
);
    always @(*) begin
        case (alu_ctrl)
            `ALU_ADD: y = a + b;
            `ALU_SUB: y = a - b;
            `ALU_OR : y = a | b;
            `ALU_SLT: y = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            default:  y = 32'h0000_0000;
        endcase
    end

    assign zero = (y == 32'h0000_0000);
endmodule

