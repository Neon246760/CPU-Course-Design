module alu (
  input  logic [31:0] a,
  input  logic [31:0] b,
  input  control_word_pkg::alu_op_t op,
  output logic [31:0] result,
  output logic        overflow
);
  import control_word_pkg::*;

  always_comb begin
    overflow = 1'b0;
    unique case (op)
      ALU_ADD: begin
        result = a + b;
        overflow = (~(a[31] ^ b[31])) & (result[31] ^ a[31]);
      end
      ALU_SUB: begin
        result = a - b;
        overflow = (a[31] ^ b[31]) & (result[31] ^ a[31]);
      end
      ALU_AND:    result = a & b;
      ALU_OR:     result = a | b;
      ALU_XOR:    result = a ^ b;
      ALU_SLL:    result = a << b[4:0];
      ALU_SRL:    result = a >> b[4:0];
      ALU_SRA:    result = $signed(a) >>> b[4:0];
      ALU_SLT:    result = {31'b0, $signed(a) < $signed(b)};
      ALU_SLTU:   result = {31'b0, a < b};
      ALU_COPY_B: result = b;
      default:    result = 32'b0;
    endcase
  end
endmodule
