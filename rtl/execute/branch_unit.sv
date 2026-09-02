module branch_unit (
  input  logic [31:0] lhs,
  input  logic [31:0] rhs,
  input  control_word_pkg::branch_type_t branch_type,
  output logic taken
);
  import control_word_pkg::*;

  always_comb begin
    unique case (branch_type)
      BR_EQ:   taken = (lhs == rhs);
      BR_NE:   taken = (lhs != rhs);
      BR_LT:   taken = ($signed(lhs) < $signed(rhs));
      BR_GE:   taken = ($signed(lhs) >= $signed(rhs));
      default: taken = 1'b0;
    endcase
  end
endmodule
