module regfile (
  input  logic        clk,
  input  logic        reset,
  input  logic [4:0]  rs1_addr,
  input  logic [4:0]  rs2_addr,
  output logic [31:0] rs1_data,
  output logic [31:0] rs2_data,
  input  logic        write_enable,
  input  logic [4:0]  write_addr,
  input  logic [31:0] write_data
);
  logic [31:0] regs [0:31];
  integer i;

  always_ff @(posedge clk) begin
    if (reset) begin
      for (i = 0; i < 32; i = i + 1) regs[i] <= 32'b0;
    end else if (write_enable && (write_addr != 5'd0)) begin
      regs[write_addr] <= write_data;
    end
  end

  always_comb begin
    rs1_data = (rs1_addr == 5'd0) ? 32'b0 : regs[rs1_addr];
    rs2_data = (rs2_addr == 5'd0) ? 32'b0 : regs[rs2_addr];
    if (write_enable && (write_addr != 5'd0) && (write_addr == rs1_addr))
      rs1_data = write_data;
    if (write_enable && (write_addr != 5'd0) && (write_addr == rs2_addr))
      rs2_data = write_data;
  end
endmodule
