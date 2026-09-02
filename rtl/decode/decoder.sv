module decoder (
  input  logic [31:0] instr,
  output logic [4:0]  rs1_idx,
  output logic [4:0]  rs2_idx,
  output logic [4:0]  rd_idx,
  output logic [5:0]  uaddr,
  output logic        uses_rs1,
  output logic        uses_rs2,
  output logic        illegal_instr
);
  import control_word_pkg::*;

  logic [6:0] opcode;
  logic [2:0] funct3;
  logic [6:0] funct7;

  always_comb begin
    opcode = instr[6:0];
    funct3 = instr[14:12];
    funct7 = instr[31:25];
    rs1_idx = instr[19:15];
    rs2_idx = instr[24:20];
    rd_idx = instr[11:7];
    uaddr = UADDR_ILLEGAL;
    uses_rs1 = 1'b0;
    uses_rs2 = 1'b0;
    illegal_instr = 1'b0;

    unique case (opcode)
      7'b0110011: begin
        uses_rs1 = 1'b1;
        uses_rs2 = 1'b1;
        unique case ({funct7, funct3})
          {7'b0000000, 3'b000}: uaddr = UADDR_ADD;
          {7'b0100000, 3'b000}: uaddr = UADDR_SUB;
          {7'b0000000, 3'b111}: uaddr = UADDR_AND;
          {7'b0000000, 3'b110}: uaddr = UADDR_OR;
          {7'b0000000, 3'b100}: uaddr = UADDR_XOR;
          {7'b0000000, 3'b001}: uaddr = UADDR_SLL;
          {7'b0000000, 3'b101}: uaddr = UADDR_SRL;
          {7'b0100000, 3'b101}: uaddr = UADDR_SRA;
          {7'b0000000, 3'b010}: uaddr = UADDR_SLT;
          {7'b0000000, 3'b011}: uaddr = UADDR_SLTU;
          default: illegal_instr = 1'b1;
        endcase
      end
      7'b0010011: begin
        uses_rs1 = 1'b1;
        unique case (funct3)
          3'b000: uaddr = UADDR_ADDI;
          3'b111: uaddr = UADDR_ANDI;
          3'b110: uaddr = UADDR_ORI;
          3'b100: uaddr = UADDR_XORI;
          default: illegal_instr = 1'b1;
        endcase
      end
      7'b0000011: begin
        uses_rs1 = 1'b1;
        unique case (funct3)
          3'b010: uaddr = UADDR_LW;
          3'b000: uaddr = UADDR_LB;
          3'b100: uaddr = UADDR_LBU;
          default: illegal_instr = 1'b1;
        endcase
      end
      7'b0100011: begin
        uses_rs1 = 1'b1;
        uses_rs2 = 1'b1;
        unique case (funct3)
          3'b010: uaddr = UADDR_SW;
          3'b000: uaddr = UADDR_SB;
          default: illegal_instr = 1'b1;
        endcase
      end
      7'b1100011: begin
        uses_rs1 = 1'b1;
        uses_rs2 = 1'b1;
        unique case (funct3)
          3'b000: uaddr = UADDR_BEQ;
          3'b001: uaddr = UADDR_BNE;
          3'b100: uaddr = UADDR_BLT;
          3'b101: uaddr = UADDR_BGE;
          default: illegal_instr = 1'b1;
        endcase
      end
      7'b1101111: uaddr = UADDR_JAL;
      7'b1100111: begin
        uses_rs1 = 1'b1;
        if (funct3 == 3'b000) uaddr = UADDR_JALR;
        else illegal_instr = 1'b1;
      end
      7'b0110111: uaddr = UADDR_LUI;
      7'b0010111: uaddr = UADDR_AUIPC;
      7'b1110011: begin
        if (instr == 32'h0000_0073) uaddr = UADDR_ECALL;
        else if (instr == 32'h3020_0073) uaddr = UADDR_MRET;
        else illegal_instr = 1'b1;
      end
      default: illegal_instr = 1'b1;
    endcase
  end
endmodule
