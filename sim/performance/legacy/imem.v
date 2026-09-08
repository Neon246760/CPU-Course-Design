`timescale 1ns/1ps

module perf_legacy_imem #(
    parameter integer DEPTH = 256,
    parameter         INIT_FILE = "imem_sort.mem"
)(
    input  wire [31:0] addr,
    output wire [31:0] instr
);
    reg [31:0] mem [0:DEPTH-1];
    integer i;

    initial begin
        for (i = 0; i < DEPTH; i = i + 1) mem[i] = 32'h0000_0013; // NOP=addi x0,x0,0
        $readmemh(INIT_FILE, mem);
    end

    assign instr = mem[addr[31:2]];
endmodule

