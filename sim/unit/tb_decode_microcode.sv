`timescale 1ns/1ps

module tb_decode_microcode;
  import control_word_pkg::*;
  logic [31:0] instr;
  logic [4:0] rs1;
  logic [4:0] rs2;
  logic [4:0] rd;
  logic [5:0] uaddr;
  logic uses_rs1;
  logic uses_rs2;
  logic illegal;
  control_word_t control;

  decoder u_decoder (
    .instr(instr), .rs1_idx(rs1), .rs2_idx(rs2), .rd_idx(rd),
    .uaddr(uaddr), .uses_rs1(uses_rs1), .uses_rs2(uses_rs2),
    .illegal_instr(illegal)
  );
  microcode_rom u_rom (.uaddr(uaddr), .control(control));

  function automatic [31:0] r(input [6:0] f7, input [2:0] f3);
    r = {f7, 5'd2, 5'd1, f3, 5'd3, 7'b0110011};
  endfunction
  function automatic [31:0] i(input [6:0] opcode, input [2:0] f3);
    i = {12'h001, 5'd1, f3, 5'd3, opcode};
  endfunction
  function automatic [31:0] s(input [2:0] f3);
    s = {7'b0, 5'd2, 5'd1, f3, 5'b0, 7'b0100011};
  endfunction
  function automatic [31:0] b(input [2:0] f3);
    b = {7'b0, 5'd2, 5'd1, f3, 5'b0, 7'b1100011};
  endfunction

  task automatic check(
    input logic [31:0] test_instr,
    input logic [5:0] expected_uaddr,
    input logic expected_rs1,
    input logic expected_rs2
  );
    begin
      instr = test_instr;
      #1;
      if (illegal || uaddr !== expected_uaddr ||
          uses_rs1 !== expected_rs1 || uses_rs2 !== expected_rs2)
        $fatal(1, "decode instr=%h uaddr=%h illegal=%b uses=%b%b",
               instr, uaddr, illegal, uses_rs1, uses_rs2);
    end
  endtask

  initial begin
    check(r(7'b0000000,3'b000), UADDR_ADD, 1, 1);
    if (!control.overflow_check) $fatal(1, "ADD overflow control missing");
    check(r(7'b0100000,3'b000), UADDR_SUB, 1, 1);
    check(r(7'b0000000,3'b111), UADDR_AND, 1, 1);
    check(r(7'b0000000,3'b110), UADDR_OR, 1, 1);
    check(r(7'b0000000,3'b100), UADDR_XOR, 1, 1);
    check(r(7'b0000000,3'b001), UADDR_SLL, 1, 1);
    check(r(7'b0000000,3'b101), UADDR_SRL, 1, 1);
    check(r(7'b0100000,3'b101), UADDR_SRA, 1, 1);
    check(r(7'b0000000,3'b010), UADDR_SLT, 1, 1);
    check(r(7'b0000000,3'b011), UADDR_SLTU, 1, 1);
    check(i(7'b0010011,3'b000), UADDR_ADDI, 1, 0);
    check(i(7'b0010011,3'b111), UADDR_ANDI, 1, 0);
    check(i(7'b0010011,3'b110), UADDR_ORI, 1, 0);
    check(i(7'b0010011,3'b100), UADDR_XORI, 1, 0);
    check(i(7'b0000011,3'b010), UADDR_LW, 1, 0);
    check(i(7'b0000011,3'b000), UADDR_LB, 1, 0);
    check(i(7'b0000011,3'b100), UADDR_LBU, 1, 0);
    check(s(3'b010), UADDR_SW, 1, 1);
    check(s(3'b000), UADDR_SB, 1, 1);
    check(b(3'b000), UADDR_BEQ, 1, 1);
    check(b(3'b001), UADDR_BNE, 1, 1);
    check(b(3'b100), UADDR_BLT, 1, 1);
    check(b(3'b101), UADDR_BGE, 1, 1);
    check(32'h0000_00EF, UADDR_JAL, 0, 0);
    check(32'h0000_80E7, UADDR_JALR, 1, 0);
    check(32'h1234_50B7, UADDR_LUI, 0, 0);
    check(32'h1234_5097, UADDR_AUIPC, 0, 0);
    check(32'h0000_0073, UADDR_ECALL, 0, 0);
    if (control.system_op != SYS_ECALL) $fatal(1, "ECALL control missing");
    check(32'h3020_0073, UADDR_MRET, 0, 0);
    if (control.system_op != SYS_MRET) $fatal(1, "MRET control missing");

    instr = 32'hFFFF_FFFF;
    #1;
    if (!illegal || uaddr != UADDR_ILLEGAL || control.reg_write || control.mem_write)
      $fatal(1, "illegal instruction handling failed");
    $display("PASS tb_decode_microcode");
    $finish;
  end
endmodule
