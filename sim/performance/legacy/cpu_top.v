`timescale 1ns/1ps

`include "rv32i_defs.vh"

module perf_legacy_cpu_top #(
    parameter IMEM_FILE = "imem_sort.mem",
    parameter DMEM_FILE = "dmem_init.mem"
)(
    input  wire        clk,
    input  wire        rst_n,

    output wire [31:0] dbg_pc,
    output wire [31:0] dbg_instr,
    output wire        dbg_mem_we,
    output wire [31:0] dbg_mem_addr,
    output wire [31:0] dbg_mem_wdata
);
    // PC
    reg [31:0] pc;
    wire [31:0] pc_next;

    // IF
    wire [31:0] instr;

    // ID fields
    wire [6:0] opcode = instr[6:0];
    wire [4:0] rd     = instr[11:7];
    wire [2:0] funct3 = instr[14:12];
    wire [4:0] rs1    = instr[19:15];
    wire [4:0] rs2    = instr[24:20];

    // immediates
    wire [31:0] imm_i, imm_s, imm_b;

    // perf_legacy_control
    wire       reg_write;
    wire       alu_src;
    wire       mem_write;
    wire       mem_to_reg;
    wire       branch;
    wire [2:0] alu_ctrl;

    // perf_legacy_regfile
    wire [31:0] rs1_data, rs2_data;
    wire [31:0] wb_data;

    // ALU
    wire [31:0] alu_b = alu_src ? ((opcode == `OP_STORE) ? imm_s : imm_i) : rs2_data;
    wire [31:0] alu_y;
    wire        alu_zero;

    // Data memory
    wire [31:0] mem_rdata;

    // Branch decision (BEQ only)
    wire pc_src = branch & alu_zero & (funct3 == `F3_BEQ);

    assign pc_next = pc_src ? (pc + imm_b) : (pc + 32'd4);

    always @(posedge clk) begin
        if (!rst_n) pc <= 32'h0;
        else        pc <= pc_next;
    end

    perf_legacy_imem #(.INIT_FILE(IMEM_FILE)) u_imem (
        .addr (pc),
        .instr(instr)
    );

    perf_legacy_imm_gen u_imm (
        .instr(instr),
        .imm_i(imm_i),
        .imm_s(imm_s),
        .imm_b(imm_b)
    );

    perf_legacy_control u_ctrl (
        .instr(instr),
        .reg_write(reg_write),
        .alu_src(alu_src),
        .mem_write(mem_write),
        .mem_to_reg(mem_to_reg),
        .branch(branch),
        .alu_ctrl(alu_ctrl)
    );

    perf_legacy_regfile u_rf (
        .clk(clk),
        .we(reg_write),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .wd(wb_data),
        .rd1(rs1_data),
        .rd2(rs2_data)
    );

    perf_legacy_alu u_alu (
        .a(rs1_data),
        .b(alu_b),
        .alu_ctrl(alu_ctrl),
        .y(alu_y),
        .zero(alu_zero)
    );

    perf_legacy_dmem #(.INIT_FILE(DMEM_FILE)) u_dmem (
        .clk(clk),
        .we(mem_write),
        .addr(alu_y),
        .wdata(rs2_data),
        .rdata(mem_rdata)
    );

    assign wb_data = mem_to_reg ? mem_rdata : alu_y;

    // debug
    assign dbg_pc       = pc;
    assign dbg_instr    = instr;
    assign dbg_mem_we   = mem_write;
    assign dbg_mem_addr = alu_y;
    assign dbg_mem_wdata= rs2_data;
endmodule

