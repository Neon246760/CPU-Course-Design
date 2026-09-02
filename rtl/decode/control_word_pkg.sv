package control_word_pkg;
  typedef enum logic [3:0] {
    ALU_ADD    = 4'h0,
    ALU_SUB    = 4'h1,
    ALU_AND    = 4'h2,
    ALU_OR     = 4'h3,
    ALU_XOR    = 4'h4,
    ALU_SLL    = 4'h5,
    ALU_SRL    = 4'h6,
    ALU_SRA    = 4'h7,
    ALU_SLT    = 4'h8,
    ALU_SLTU   = 4'h9,
    ALU_COPY_B = 4'hA
  } alu_op_t;

  typedef enum logic [1:0] {
    OP_A_RS1  = 2'h0,
    OP_A_PC   = 2'h1,
    OP_A_ZERO = 2'h2
  } op_a_sel_t;

  typedef enum logic [1:0] {
    OP_B_RS2  = 2'h0,
    OP_B_IMM  = 2'h1,
    OP_B_FOUR = 2'h2
  } op_b_sel_t;

  typedef enum logic [2:0] {
    IMM_NONE = 3'h0,
    IMM_I    = 3'h1,
    IMM_S    = 3'h2,
    IMM_B    = 3'h3,
    IMM_U    = 3'h4,
    IMM_J    = 3'h5
  } imm_type_t;

  typedef enum logic [1:0] {
    WB_ALU = 2'h0,
    WB_MEM = 2'h1,
    WB_PC4 = 2'h2
  } wb_sel_t;

  typedef enum logic [1:0] {
    MEM_BYTE = 2'h0,
    MEM_HALF = 2'h1,
    MEM_WORD = 2'h2
  } mem_size_t;

  typedef enum logic [2:0] {
    BR_NONE = 3'h0,
    BR_EQ   = 3'h1,
    BR_NE   = 3'h2,
    BR_LT   = 3'h3,
    BR_GE   = 3'h4
  } branch_type_t;

  typedef enum logic [1:0] {
    JMP_NONE = 2'h0,
    JMP_JAL  = 2'h1,
    JMP_JALR = 2'h2
  } jump_type_t;

  typedef enum logic [1:0] {
    SYS_NONE  = 2'h0,
    SYS_ECALL = 2'h1,
    SYS_MRET  = 2'h2
  } system_op_t;

  typedef struct packed {
    alu_op_t       alu_op;
    op_a_sel_t     op_a_sel;
    op_b_sel_t     op_b_sel;
    imm_type_t     imm_type;
    logic          reg_write;
    wb_sel_t       wb_sel;
    logic          mem_read;
    logic          mem_write;
    mem_size_t     mem_size;
    logic          load_unsigned;
    branch_type_t  branch_type;
    jump_type_t    jump_type;
    logic          overflow_check;
    system_op_t    system_op;
  } control_word_t;

  localparam logic [5:0] UADDR_ADD     = 6'h00;
  localparam logic [5:0] UADDR_SUB     = 6'h01;
  localparam logic [5:0] UADDR_AND     = 6'h02;
  localparam logic [5:0] UADDR_OR      = 6'h03;
  localparam logic [5:0] UADDR_XOR     = 6'h04;
  localparam logic [5:0] UADDR_SLL     = 6'h05;
  localparam logic [5:0] UADDR_SRL     = 6'h06;
  localparam logic [5:0] UADDR_SRA     = 6'h07;
  localparam logic [5:0] UADDR_SLT     = 6'h08;
  localparam logic [5:0] UADDR_SLTU    = 6'h09;
  localparam logic [5:0] UADDR_ADDI    = 6'h0A;
  localparam logic [5:0] UADDR_ANDI    = 6'h0B;
  localparam logic [5:0] UADDR_ORI     = 6'h0C;
  localparam logic [5:0] UADDR_XORI    = 6'h0D;
  localparam logic [5:0] UADDR_LW      = 6'h10;
  localparam logic [5:0] UADDR_LB      = 6'h11;
  localparam logic [5:0] UADDR_LBU     = 6'h12;
  localparam logic [5:0] UADDR_SW      = 6'h13;
  localparam logic [5:0] UADDR_SB      = 6'h14;
  localparam logic [5:0] UADDR_BEQ     = 6'h18;
  localparam logic [5:0] UADDR_BNE     = 6'h19;
  localparam logic [5:0] UADDR_BLT     = 6'h1A;
  localparam logic [5:0] UADDR_BGE     = 6'h1B;
  localparam logic [5:0] UADDR_JAL     = 6'h1C;
  localparam logic [5:0] UADDR_JALR    = 6'h1D;
  localparam logic [5:0] UADDR_LUI     = 6'h1E;
  localparam logic [5:0] UADDR_AUIPC   = 6'h1F;
  localparam logic [5:0] UADDR_ECALL   = 6'h20;
  localparam logic [5:0] UADDR_MRET    = 6'h21;
  localparam logic [5:0] UADDR_ILLEGAL = 6'h3F;

  localparam logic [31:0] CAUSE_ILLEGAL_INSTR = 32'd2;
  localparam logic [31:0] CAUSE_ECALL_M       = 32'd11;
  localparam logic [31:0] CAUSE_OVERFLOW      = 32'd16;
  localparam logic [31:0] CAUSE_EXTERNAL_IRQ  = 32'd11;
endpackage
