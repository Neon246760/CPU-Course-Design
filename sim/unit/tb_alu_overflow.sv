`timescale 1ns/1ps

module tb_alu_overflow;
  import control_word_pkg::*;
  logic [31:0] a;
  logic [31:0] b;
  alu_op_t op;
  logic [31:0] result;
  logic overflow;

  alu dut (.a(a), .b(b), .op(op), .result(result), .overflow(overflow));

  task automatic check(
    input logic [31:0] test_a,
    input logic [31:0] test_b,
    input alu_op_t test_op,
    input logic [31:0] expected_result,
    input logic expected_overflow
  );
    begin
      a = test_a;
      b = test_b;
      op = test_op;
      #1;
      if (result !== expected_result || overflow !== expected_overflow)
        $fatal(1, "ALU mismatch a=%h b=%h op=%h result=%h ov=%b",
               a, b, op, result, overflow);
    end
  endtask

  initial begin
    check(32'h7FFF_FFFF, 32'd1, ALU_ADD, 32'h8000_0000, 1'b1);
    check(32'h8000_0000, 32'hFFFF_FFFF, ALU_ADD, 32'h7FFF_FFFF, 1'b1);
    check(32'h8000_0000, 32'd1, ALU_SUB, 32'h7FFF_FFFF, 1'b1);
    check(32'h7FFF_FFFF, 32'hFFFF_FFFF, ALU_SUB, 32'h8000_0000, 1'b1);
    check(32'd10, 32'd20, ALU_ADD, 32'd30, 1'b0);
    check(32'hFFFF_FFF6, 32'd5, ALU_ADD, 32'hFFFF_FFFB, 1'b0);
    check(32'd10, 32'd20, ALU_SUB, 32'hFFFF_FFF6, 1'b0);
    check(32'h7FFF_FFFF, 32'd1, ALU_AND, 32'd1, 1'b0);
    check(32'hA5A5_0000, 32'h0000_5A5A, ALU_OR, 32'hA5A5_5A5A, 1'b0);
    check(32'hFFFF_0000, 32'h0F0F_0F0F, ALU_XOR, 32'hF0F0_0F0F, 1'b0);
    check(32'd1, 32'd31, ALU_SLL, 32'h8000_0000, 1'b0);
    check(32'h8000_0000, 32'd31, ALU_SRL, 32'd1, 1'b0);
    check(32'h8000_0000, 32'd31, ALU_SRA, 32'hFFFF_FFFF, 1'b0);
    check(32'hFFFF_FFFF, 32'd1, ALU_SLT, 32'd1, 1'b0);
    check(32'hFFFF_FFFF, 32'd1, ALU_SLTU, 32'd0, 1'b0);
    $display("PASS tb_alu_overflow");
    $finish;
  end
endmodule
