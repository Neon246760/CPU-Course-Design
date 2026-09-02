module forwarding_unit (
  input  logic [4:0] id_ex_rs1,
  input  logic [4:0] id_ex_rs2,
  input  logic       ex_mem_valid,
  input  logic       ex_mem_reg_write,
  input  logic       ex_mem_mem_read,
  input  logic [4:0] ex_mem_rd,
  input  logic       mem_wb_valid,
  input  logic       mem_wb_reg_write,
  input  logic [4:0] mem_wb_rd,
  output logic [1:0] forward_a,
  output logic [1:0] forward_b
);
  localparam logic [1:0] FWD_REG = 2'b00;
  localparam logic [1:0] FWD_WB  = 2'b01;
  localparam logic [1:0] FWD_MEM = 2'b10;

  always_comb begin
    forward_a = FWD_REG;
    forward_b = FWD_REG;

    if (mem_wb_valid && mem_wb_reg_write && (mem_wb_rd != 5'd0) &&
        (mem_wb_rd == id_ex_rs1))
      forward_a = FWD_WB;
    if (mem_wb_valid && mem_wb_reg_write && (mem_wb_rd != 5'd0) &&
        (mem_wb_rd == id_ex_rs2))
      forward_b = FWD_WB;

    if (ex_mem_valid && ex_mem_reg_write && !ex_mem_mem_read &&
        (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs1))
      forward_a = FWD_MEM;
    if (ex_mem_valid && ex_mem_reg_write && !ex_mem_mem_read &&
        (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs2))
      forward_b = FWD_MEM;
  end
endmodule
