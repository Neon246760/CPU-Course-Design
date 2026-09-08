`timescale 1ns/1ps

module perf_legacy_regfile(
    input  wire        clk,
    input  wire        we,
    input  wire [4:0]  rs1,
    input  wire [4:0]  rs2,
    input  wire [4:0]  rd,
    input  wire [31:0] wd,
    output wire [31:0] rd1,
    output wire [31:0] rd2
);
    reg [31:0] regs [0:31];
    integer i;

    initial begin
        for (i = 0; i < 32; i = i + 1) regs[i] = 32'h0;
    end

    assign rd1 = (rs1 == 0) ? 32'h0 : regs[rs1];
    assign rd2 = (rs2 == 0) ? 32'h0 : regs[rs2];

    always @(posedge clk) begin
        if (we && (rd != 0)) begin
            regs[rd] <= wd;
        end
        regs[0] <= 32'h0; // x0 hard-wired to 0
    end
endmodule

