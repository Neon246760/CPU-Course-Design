`timescale 1ns/1ps

module perf_legacy_dmem #(
    parameter integer DEPTH = 256,
    parameter         INIT_FILE = "dmem_init.mem"
)(
    input  wire clk,
    input  wire we,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    output wire [31:0] rdata
);
    reg [31:0] mem [0:DEPTH-1];
    integer i;

    initial begin
        for (i = 0; i < DEPTH; i = i + 1) mem[i] = 32'h0;
        $readmemh(INIT_FILE, mem);
    end

    // word-aligned access
    assign rdata = mem[addr[31:2]];

    always @(posedge clk) begin
        if (we) begin
            mem[addr[31:2]] <= wdata;
        end
    end
endmodule

