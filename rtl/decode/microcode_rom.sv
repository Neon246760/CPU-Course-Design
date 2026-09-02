module microcode_rom (
  input  logic [5:0] uaddr,
  output control_word_pkg::control_word_t control
);
  import control_word_pkg::*;

  function automatic control_word_t make_control(
    input alu_op_t alu_op,
    input op_a_sel_t op_a_sel,
    input op_b_sel_t op_b_sel,
    input imm_type_t imm_type,
    input logic reg_write,
    input wb_sel_t wb_sel,
    input logic mem_read,
    input logic mem_write,
    input mem_size_t mem_size,
    input logic load_unsigned,
    input branch_type_t branch_type,
    input jump_type_t jump_type
  );
    control_word_t value;
    begin
      value.alu_op = alu_op;
      value.op_a_sel = op_a_sel;
      value.op_b_sel = op_b_sel;
      value.imm_type = imm_type;
      value.reg_write = reg_write;
      value.wb_sel = wb_sel;
      value.mem_read = mem_read;
      value.mem_write = mem_write;
      value.mem_size = mem_size;
      value.load_unsigned = load_unsigned;
      value.branch_type = branch_type;
      value.jump_type = jump_type;
      value.overflow_check = 1'b0;
      value.system_op = SYS_NONE;
      make_control = value;
    end
  endfunction

  always_comb begin
    control = make_control(ALU_ADD, OP_A_ZERO, OP_B_RS2, IMM_NONE,
                           1'b0, WB_ALU, 1'b0, 1'b0, MEM_WORD,
                           1'b0, BR_NONE, JMP_NONE);
    unique case (uaddr)
      UADDR_ADD:   control = make_control(ALU_ADD, OP_A_RS1, OP_B_RS2, IMM_NONE, 1, WB_ALU, 0, 0, MEM_WORD, 0, BR_NONE, JMP_NONE);
      UADDR_SUB:   control = make_control(ALU_SUB, OP_A_RS1, OP_B_RS2, IMM_NONE, 1, WB_ALU, 0, 0, MEM_WORD, 0, BR_NONE, JMP_NONE);
      UADDR_AND:   control = make_control(ALU_AND, OP_A_RS1, OP_B_RS2, IMM_NONE, 1, WB_ALU, 0, 0, MEM_WORD, 0, BR_NONE, JMP_NONE);
      UADDR_OR:    control = make_control(ALU_OR, OP_A_RS1, OP_B_RS2, IMM_NONE, 1, WB_ALU, 0, 0, MEM_WORD, 0, BR_NONE, JMP_NONE);
      UADDR_XOR:   control = make_control(ALU_XOR, OP_A_RS1, OP_B_RS2, IMM_NONE, 1, WB_ALU, 0, 0, MEM_WORD, 0, BR_NONE, JMP_NONE);
      UADDR_SLL:   control = make_control(ALU_SLL, OP_A_RS1, OP_B_RS2, IMM_NONE, 1, WB_ALU, 0, 0, MEM_WORD, 0, BR_NONE, JMP_NONE);
      UADDR_SRL:   control = make_control(ALU_SRL, OP_A_RS1, OP_B_RS2, IMM_NONE, 1, WB_ALU, 0, 0, MEM_WORD, 0, BR_NONE, JMP_NONE);
      UADDR_SRA:   control = make_control(ALU_SRA, OP_A_RS1, OP_B_RS2, IMM_NONE, 1, WB_ALU, 0, 0, MEM_WORD, 0, BR_NONE, JMP_NONE);
      UADDR_SLT:   control = make_control(ALU_SLT, OP_A_RS1, OP_B_RS2, IMM_NONE, 1, WB_ALU, 0, 0, MEM_WORD, 0, BR_NONE, JMP_NONE);
      UADDR_SLTU:  control = make_control(ALU_SLTU, OP_A_RS1, OP_B_RS2, IMM_NONE, 1, WB_ALU, 0, 0, MEM_WORD, 0, BR_NONE, JMP_NONE);
      UADDR_ADDI:  control = make_control(ALU_ADD, OP_A_RS1, OP_B_IMM, IMM_I, 1, WB_ALU, 0, 0, MEM_WORD, 0, BR_NONE, JMP_NONE);
      UADDR_ANDI:  control = make_control(ALU_AND, OP_A_RS1, OP_B_IMM, IMM_I, 1, WB_ALU, 0, 0, MEM_WORD, 0, BR_NONE, JMP_NONE);
      UADDR_ORI:   control = make_control(ALU_OR, OP_A_RS1, OP_B_IMM, IMM_I, 1, WB_ALU, 0, 0, MEM_WORD, 0, BR_NONE, JMP_NONE);
      UADDR_XORI:  control = make_control(ALU_XOR, OP_A_RS1, OP_B_IMM, IMM_I, 1, WB_ALU, 0, 0, MEM_WORD, 0, BR_NONE, JMP_NONE);
      UADDR_LW:    control = make_control(ALU_ADD, OP_A_RS1, OP_B_IMM, IMM_I, 1, WB_MEM, 1, 0, MEM_WORD, 0, BR_NONE, JMP_NONE);
      UADDR_LB:    control = make_control(ALU_ADD, OP_A_RS1, OP_B_IMM, IMM_I, 1, WB_MEM, 1, 0, MEM_BYTE, 0, BR_NONE, JMP_NONE);
      UADDR_LBU:   control = make_control(ALU_ADD, OP_A_RS1, OP_B_IMM, IMM_I, 1, WB_MEM, 1, 0, MEM_BYTE, 1, BR_NONE, JMP_NONE);
      UADDR_SW:    control = make_control(ALU_ADD, OP_A_RS1, OP_B_IMM, IMM_S, 0, WB_ALU, 0, 1, MEM_WORD, 0, BR_NONE, JMP_NONE);
      UADDR_SB:    control = make_control(ALU_ADD, OP_A_RS1, OP_B_IMM, IMM_S, 0, WB_ALU, 0, 1, MEM_BYTE, 0, BR_NONE, JMP_NONE);
      UADDR_BEQ:   control = make_control(ALU_ADD, OP_A_PC, OP_B_IMM, IMM_B, 0, WB_ALU, 0, 0, MEM_WORD, 0, BR_EQ, JMP_NONE);
      UADDR_BNE:   control = make_control(ALU_ADD, OP_A_PC, OP_B_IMM, IMM_B, 0, WB_ALU, 0, 0, MEM_WORD, 0, BR_NE, JMP_NONE);
      UADDR_BLT:   control = make_control(ALU_ADD, OP_A_PC, OP_B_IMM, IMM_B, 0, WB_ALU, 0, 0, MEM_WORD, 0, BR_LT, JMP_NONE);
      UADDR_BGE:   control = make_control(ALU_ADD, OP_A_PC, OP_B_IMM, IMM_B, 0, WB_ALU, 0, 0, MEM_WORD, 0, BR_GE, JMP_NONE);
      UADDR_JAL:   control = make_control(ALU_ADD, OP_A_PC, OP_B_IMM, IMM_J, 1, WB_PC4, 0, 0, MEM_WORD, 0, BR_NONE, JMP_JAL);
      UADDR_JALR:  control = make_control(ALU_ADD, OP_A_RS1, OP_B_IMM, IMM_I, 1, WB_PC4, 0, 0, MEM_WORD, 0, BR_NONE, JMP_JALR);
      UADDR_LUI:   control = make_control(ALU_COPY_B, OP_A_ZERO, OP_B_IMM, IMM_U, 1, WB_ALU, 0, 0, MEM_WORD, 0, BR_NONE, JMP_NONE);
      UADDR_AUIPC: control = make_control(ALU_ADD, OP_A_PC, OP_B_IMM, IMM_U, 1, WB_ALU, 0, 0, MEM_WORD, 0, BR_NONE, JMP_NONE);
      default: ;
    endcase

    if ((uaddr == UADDR_ADD) || (uaddr == UADDR_SUB) ||
        (uaddr == UADDR_ADDI))
      control.overflow_check = 1'b1;
    if (uaddr == UADDR_ECALL) control.system_op = SYS_ECALL;
    if (uaddr == UADDR_MRET) control.system_op = SYS_MRET;
  end
endmodule
