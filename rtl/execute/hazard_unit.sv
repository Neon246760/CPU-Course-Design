module hazard_unit (
  input  logic       id_ex_valid,
  input  logic       id_ex_mem_read,
  input  logic [4:0] id_ex_rd,
  input  logic       if_id_valid,
  input  logic       dec_uses_rs1,
  input  logic       dec_uses_rs2,
  input  logic [4:0] dec_rs1,
  input  logic [4:0] dec_rs2,
  output logic       load_use
);
  always_comb begin
    load_use = id_ex_valid && id_ex_mem_read && (id_ex_rd != 5'd0) &&
               if_id_valid &&
               ((dec_uses_rs1 && (id_ex_rd == dec_rs1)) ||
                (dec_uses_rs2 && (id_ex_rd == dec_rs2)));
  end
endmodule
