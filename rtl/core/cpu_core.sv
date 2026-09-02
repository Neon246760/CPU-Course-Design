module cpu_core #(
  parameter logic [31:0] RESET_VECTOR = 32'h0000_0000,
  parameter logic [31:0] MTVEC_RESET = 32'h0000_0100,
  parameter logic ENABLE_BRANCH_PREDICTION = 1'b1
) (
  input  logic        clk,
  input  logic        reset,
  input  logic        ext_irq,

  output logic        imem_req,
  output logic [31:0] imem_addr,
  input  logic        imem_ready,
  input  logic [31:0] imem_rdata,

  output logic        dmem_req,
  output logic [31:0] dmem_addr,
  output logic        dmem_write,
  output logic [31:0] dmem_wdata,
  output logic [3:0]  dmem_wstrb,
  input  logic        dmem_ready,
  input  logic [31:0] dmem_rdata,

  output logic        retire_valid,
  output logic [31:0] retire_pc,
  output logic [31:0] retire_instr,
  output logic [31:0] cycle_count,
  output logic [31:0] instret_count,
  output logic [31:0] stall_data_count,
  output logic [31:0] stall_fetch_count,
  output logic [31:0] stall_memory_count,
  output logic [31:0] control_flush_count,
  output logic [31:0] branch_count,
  output logic [31:0] branch_mispredict_count,
  output logic [31:0] interrupt_count,
  output logic [31:0] exception_count,
  output logic [31:0] csr_mepc,
  output logic [31:0] csr_mcause,
  output logic        overflow_debug,
  output logic        illegal_instr_debug,
  output logic        misaligned_debug
);
  import control_word_pkg::*;

  typedef struct packed {
    logic        valid;
    logic [31:0] pc;
    logic [31:0] pc_plus4;
    logic [31:0] instr;
    logic        pred_taken;
    logic [31:0] pred_target;
  } if_id_t;

  typedef struct packed {
    logic         valid;
    logic [31:0]  pc;
    logic [31:0]  pc_plus4;
    logic [31:0]  instr;
    logic [4:0]   rs1_idx;
    logic [4:0]   rs2_idx;
    logic [4:0]   rd_idx;
    logic [31:0]  rs1_value;
    logic [31:0]  rs2_value;
    logic [31:0]  imm;
    logic         uses_rs1;
    logic         uses_rs2;
    alu_op_t      alu_op;
    op_a_sel_t    op_a_sel;
    op_b_sel_t    op_b_sel;
    logic         reg_write;
    wb_sel_t      wb_sel;
    logic         mem_read;
    logic         mem_write;
    mem_size_t    mem_size;
    logic         load_unsigned;
    branch_type_t branch_type;
    jump_type_t   jump_type;
    logic         illegal_instr;
    logic         pred_taken;
    logic [31:0]  pred_target;
    logic         overflow_check;
    system_op_t   system_op;
  } id_ex_t;

  typedef struct packed {
    logic         valid;
    logic [31:0]  pc;
    logic [31:0]  pc_plus4;
    logic [31:0]  instr;
    logic [4:0]   rd_idx;
    logic [31:0]  alu_result;
    logic [31:0]  store_data;
    logic         reg_write;
    wb_sel_t      wb_sel;
    logic         mem_read;
    logic         mem_write;
    mem_size_t    mem_size;
    logic         load_unsigned;
    logic         illegal_instr;
  } ex_mem_t;

  typedef struct packed {
    logic        valid;
    logic [31:0] pc;
    logic [31:0] instr;
    logic [4:0]  rd_idx;
    logic [31:0] alu_result;
    logic [31:0] load_data;
    logic [31:0] pc_plus4;
    logic        reg_write;
    wb_sel_t     wb_sel;
    logic        illegal_instr;
  } mem_wb_t;

  logic [31:0] pc;
  if_id_t if_id;
  id_ex_t id_ex;
  ex_mem_t ex_mem;
  mem_wb_t mem_wb;

  logic [4:0] dec_rs1;
  logic [4:0] dec_rs2;
  logic [4:0] dec_rd;
  logic [5:0] dec_uaddr;
  logic dec_uses_rs1;
  logic dec_uses_rs2;
  logic dec_illegal;
  control_word_t dec_control;
  logic [31:0] dec_imm;
  logic [31:0] rf_rs1_data;
  logic [31:0] rf_rs2_data;

  logic [31:0] wb_data;
  logic rf_write_enable;
  logic [1:0] forward_a;
  logic [1:0] forward_b;
  logic [31:0] ex_mem_forward_value;
  logic [31:0] forwarded_rs1;
  logic [31:0] forwarded_rs2;
  logic [31:0] alu_a;
  logic [31:0] alu_b;
  logic [31:0] alu_result;
  logic alu_overflow;
  logic branch_taken;
  logic is_branch;
  logic is_jump;
  logic is_control;
  logic actual_taken;
  logic [31:0] actual_target;
  logic [31:0] actual_next_pc;
  logic branch_mispredict;
  logic predictor_update;
  logic predict_taken_if;
  logic [31:0] predict_target_if;

  logic interrupt_pending;
  logic interrupt_enable;
  logic [31:0] csr_mtvec;
  logic sync_exception_raw;
  logic exception_accept;
  logic interrupt_accept;
  logic interrupt_safe_boundary;
  logic mret_accept;
  logic trap_enter;
  logic trap_is_interrupt;
  logic [31:0] trap_pc;
  logic [31:0] trap_cause;
  logic frontend_redirect;
  logic [31:0] frontend_redirect_pc;

  logic [31:0] lsu_write_data;
  logic [3:0] lsu_write_strobe;
  logic [31:0] lsu_load_data;
  logic lsu_misaligned;
  logic dmem_wait;
  logic load_use;
  logic redirect_accept;
  logic hold_backend;
  logic hold_frontend;
  logic bubble_id_ex;
  logic flush_if_id;
  logic flush_id_ex;

  branch_predictor #(
    .ENTRIES(16),
    .ENABLE(ENABLE_BRANCH_PREDICTION)
  ) u_branch_predictor (
    .clk(clk),
    .reset(reset),
    .query_pc(pc),
    .predict_taken(predict_taken_if),
    .predict_target(predict_target_if),
    .update_enable(predictor_update),
    .update_pc(id_ex.pc),
    .update_taken(actual_taken),
    .update_target(actual_target)
  );

  csr_file #(
    .MTVEC_RESET(MTVEC_RESET),
    .MIE_RESET(1'b1)
  ) u_csr_file (
    .clk(clk),
    .reset(reset),
    .ext_irq(ext_irq),
    .trap_enter(trap_enter),
    .trap_is_interrupt(trap_is_interrupt),
    .trap_pc(trap_pc),
    .trap_cause(trap_cause),
    .mret(mret_accept),
    .interrupt_pending(interrupt_pending),
    .interrupt_enable(interrupt_enable),
    .mtvec(csr_mtvec),
    .mepc(csr_mepc),
    .mcause(csr_mcause),
    .interrupt_count(interrupt_count),
    .exception_count(exception_count)
  );

  decoder u_decoder (
    .instr(if_id.instr),
    .rs1_idx(dec_rs1),
    .rs2_idx(dec_rs2),
    .rd_idx(dec_rd),
    .uaddr(dec_uaddr),
    .uses_rs1(dec_uses_rs1),
    .uses_rs2(dec_uses_rs2),
    .illegal_instr(dec_illegal)
  );

  microcode_rom u_microcode_rom (
    .uaddr(dec_uaddr),
    .control(dec_control)
  );

  imm_gen u_imm_gen (
    .instr(if_id.instr),
    .imm_type(dec_control.imm_type),
    .imm(dec_imm)
  );

  regfile u_regfile (
    .clk(clk),
    .reset(reset),
    .rs1_addr(dec_rs1),
    .rs2_addr(dec_rs2),
    .rs1_data(rf_rs1_data),
    .rs2_data(rf_rs2_data),
    .write_enable(rf_write_enable),
    .write_addr(mem_wb.rd_idx),
    .write_data(wb_data)
  );

  always_comb begin
    unique case (mem_wb.wb_sel)
      WB_MEM: wb_data = mem_wb.load_data;
      WB_PC4: wb_data = mem_wb.pc_plus4;
      default: wb_data = mem_wb.alu_result;
    endcase
  end
  assign rf_write_enable = mem_wb.valid && mem_wb.reg_write &&
                           (mem_wb.rd_idx != 5'd0);

  forwarding_unit u_forwarding_unit (
    .id_ex_rs1(id_ex.rs1_idx),
    .id_ex_rs2(id_ex.rs2_idx),
    .ex_mem_valid(ex_mem.valid),
    .ex_mem_reg_write(ex_mem.reg_write),
    .ex_mem_mem_read(ex_mem.mem_read),
    .ex_mem_rd(ex_mem.rd_idx),
    .mem_wb_valid(mem_wb.valid),
    .mem_wb_reg_write(mem_wb.reg_write),
    .mem_wb_rd(mem_wb.rd_idx),
    .forward_a(forward_a),
    .forward_b(forward_b)
  );

  always_comb begin
    ex_mem_forward_value = (ex_mem.wb_sel == WB_PC4) ?
                           ex_mem.pc_plus4 : ex_mem.alu_result;
    unique case (forward_a)
      2'b10: forwarded_rs1 = ex_mem_forward_value;
      2'b01: forwarded_rs1 = wb_data;
      default: forwarded_rs1 = id_ex.rs1_value;
    endcase
    unique case (forward_b)
      2'b10: forwarded_rs2 = ex_mem_forward_value;
      2'b01: forwarded_rs2 = wb_data;
      default: forwarded_rs2 = id_ex.rs2_value;
    endcase

    unique case (id_ex.op_a_sel)
      OP_A_PC: alu_a = id_ex.pc;
      OP_A_ZERO: alu_a = 32'b0;
      default: alu_a = forwarded_rs1;
    endcase
    unique case (id_ex.op_b_sel)
      OP_B_IMM: alu_b = id_ex.imm;
      OP_B_FOUR: alu_b = 32'd4;
      default: alu_b = forwarded_rs2;
    endcase
  end

  alu u_alu (
    .a(alu_a),
    .b(alu_b),
    .op(id_ex.alu_op),
    .result(alu_result),
    .overflow(alu_overflow)
  );

  branch_unit u_branch_unit (
    .lhs(forwarded_rs1),
    .rhs(forwarded_rs2),
    .branch_type(id_ex.branch_type),
    .taken(branch_taken)
  );

  always_comb begin
    is_branch = (id_ex.branch_type != BR_NONE);
    is_jump = (id_ex.jump_type != JMP_NONE);
    is_control = is_branch || is_jump;
    actual_taken = is_jump || (is_branch && branch_taken);
    if (id_ex.jump_type == JMP_JALR)
      actual_target = (forwarded_rs1 + id_ex.imm) & 32'hFFFF_FFFE;
    else
      actual_target = id_ex.pc + id_ex.imm;
    actual_next_pc = actual_taken ? actual_target : id_ex.pc_plus4;
    branch_mispredict = id_ex.valid && is_control &&
                        ((id_ex.pred_taken != actual_taken) ||
                         (actual_taken && (id_ex.pred_target != actual_target))) &&
                        !dmem_wait;
    predictor_update = id_ex.valid && is_control && !dmem_wait &&
                       !exception_accept && !interrupt_accept;
  end

  always_comb begin
    sync_exception_raw = id_ex.valid &&
                         (id_ex.illegal_instr ||
                          (id_ex.system_op == SYS_ECALL) ||
                          (id_ex.overflow_check && alu_overflow));
    exception_accept = sync_exception_raw && !dmem_wait;
    mret_accept = id_ex.valid && (id_ex.system_op == SYS_MRET) &&
                  !dmem_wait && !exception_accept;
    interrupt_safe_boundary = !id_ex.valid ||
                              (!is_control &&
                               (id_ex.system_op == SYS_NONE) &&
                               !id_ex.illegal_instr);
    interrupt_accept = interrupt_pending && interrupt_enable &&
                       interrupt_safe_boundary && !dmem_wait &&
                       !exception_accept && !mret_accept;

    trap_enter = exception_accept || interrupt_accept;
    trap_is_interrupt = interrupt_accept;
    if (exception_accept) trap_pc = id_ex.pc_plus4;
    else if (id_ex.valid) trap_pc = id_ex.pc_plus4;
    else if (if_id.valid) trap_pc = if_id.pc;
    else trap_pc = pc;

    if (interrupt_accept) trap_cause = CAUSE_EXTERNAL_IRQ;
    else if (id_ex.illegal_instr) trap_cause = CAUSE_ILLEGAL_INSTR;
    else if (id_ex.system_op == SYS_ECALL) trap_cause = CAUSE_ECALL_M;
    else trap_cause = CAUSE_OVERFLOW;

    frontend_redirect = trap_enter || mret_accept || branch_mispredict;
    if (trap_enter) frontend_redirect_pc = csr_mtvec;
    else if (mret_accept) frontend_redirect_pc = csr_mepc;
    else frontend_redirect_pc = actual_next_pc;
  end

  load_store_unit u_load_store_unit (
    .address(ex_mem.alu_result),
    .store_data(ex_mem.store_data),
    .read_word(dmem_rdata),
    .mem_size(ex_mem.mem_size),
    .load_unsigned(ex_mem.load_unsigned),
    .write_data(lsu_write_data),
    .write_strobe(lsu_write_strobe),
    .load_data(lsu_load_data),
    .misaligned(lsu_misaligned)
  );

  assign imem_req = !reset && !hold_backend && !bubble_id_ex &&
                    !frontend_redirect;
  assign imem_addr = pc;
  assign dmem_req = ex_mem.valid && (ex_mem.mem_read || ex_mem.mem_write);
  assign dmem_addr = ex_mem.alu_result;
  assign dmem_write = ex_mem.mem_write;
  assign dmem_wdata = lsu_write_data;
  assign dmem_wstrb = ex_mem.mem_write ? lsu_write_strobe : 4'b0000;
  assign dmem_wait = dmem_req && !dmem_ready;

  hazard_unit u_hazard_unit (
    .id_ex_valid(id_ex.valid),
    .id_ex_mem_read(id_ex.mem_read),
    .id_ex_rd(id_ex.rd_idx),
    .if_id_valid(if_id.valid),
    .dec_uses_rs1(dec_uses_rs1),
    .dec_uses_rs2(dec_uses_rs2),
    .dec_rs1(dec_rs1),
    .dec_rs2(dec_rs2),
    .load_use(load_use)
  );

  pipeline_ctrl u_pipeline_ctrl (
    .reset(reset),
    .redirect_raw(frontend_redirect),
    .dmem_wait(dmem_wait),
    .load_use(load_use),
    .redirect_accept(redirect_accept),
    .hold_backend(hold_backend),
    .hold_frontend(hold_frontend),
    .bubble_id_ex(bubble_id_ex),
    .flush_if_id(flush_if_id),
    .flush_id_ex(flush_id_ex)
  );

  assign retire_valid = mem_wb.valid;
  assign retire_pc = mem_wb.pc;
  assign retire_instr = mem_wb.instr;
  assign overflow_debug = exception_accept && id_ex.overflow_check && alu_overflow;
  assign illegal_instr_debug = exception_accept && id_ex.illegal_instr;
  assign misaligned_debug = dmem_req && lsu_misaligned;

  always_ff @(posedge clk) begin
    if (reset) begin
      pc <= RESET_VECTOR;
      if_id <= '0;
      id_ex <= '0;
      ex_mem <= '0;
      mem_wb <= '0;
      cycle_count <= 32'b0;
      instret_count <= 32'b0;
      stall_data_count <= 32'b0;
      stall_fetch_count <= 32'b0;
      stall_memory_count <= 32'b0;
      control_flush_count <= 32'b0;
      branch_count <= 32'b0;
      branch_mispredict_count <= 32'b0;
    end else begin
      cycle_count <= cycle_count + 32'd1;
      if (mem_wb.valid) instret_count <= instret_count + 32'd1;
      if (bubble_id_ex) stall_data_count <= stall_data_count + 32'd1;
      if (!imem_ready && !hold_backend && !bubble_id_ex && !redirect_accept)
        stall_fetch_count <= stall_fetch_count + 32'd1;
      if (dmem_wait) stall_memory_count <= stall_memory_count + 32'd1;
      if (redirect_accept) control_flush_count <= control_flush_count + 32'd1;
      if (predictor_update && is_branch) branch_count <= branch_count + 32'd1;
      if (branch_mispredict && is_branch)
        branch_mispredict_count <= branch_mispredict_count + 32'd1;

      if (hold_backend) begin
        // The current WB instruction has already retired at this edge.  Insert
        // a bubble so it cannot retire again while EX/MEM is waiting.
        mem_wb.valid <= 1'b0;
      end else begin
        mem_wb.valid <= ex_mem.valid;
        mem_wb.pc <= ex_mem.pc;
        mem_wb.instr <= ex_mem.instr;
        mem_wb.rd_idx <= ex_mem.rd_idx;
        mem_wb.alu_result <= ex_mem.alu_result;
        mem_wb.load_data <= lsu_load_data;
        mem_wb.pc_plus4 <= ex_mem.pc_plus4;
        mem_wb.reg_write <= ex_mem.reg_write;
        mem_wb.wb_sel <= ex_mem.wb_sel;
        mem_wb.illegal_instr <= ex_mem.illegal_instr;

        ex_mem.valid <= id_ex.valid;
        ex_mem.pc <= id_ex.pc;
        ex_mem.pc_plus4 <= id_ex.pc_plus4;
        ex_mem.instr <= id_ex.instr;
        ex_mem.rd_idx <= id_ex.rd_idx;
        ex_mem.alu_result <= alu_result;
        ex_mem.store_data <= forwarded_rs2;
        ex_mem.reg_write <= id_ex.reg_write;
        ex_mem.wb_sel <= id_ex.wb_sel;
        ex_mem.mem_read <= id_ex.mem_read;
        ex_mem.mem_write <= id_ex.mem_write;
        ex_mem.mem_size <= id_ex.mem_size;
        ex_mem.load_unsigned <= id_ex.load_unsigned;
        ex_mem.illegal_instr <= id_ex.illegal_instr;

        if (exception_accept) begin
          pc <= csr_mtvec;
          if_id.valid <= 1'b0;
          id_ex.valid <= 1'b0;
          // The faulting instruction must not create architectural side effects.
          ex_mem.valid <= 1'b0;
        end else if (interrupt_accept) begin
          pc <= csr_mtvec;
          if_id.valid <= 1'b0;
          id_ex.valid <= 1'b0;
        end else if (mret_accept) begin
          pc <= csr_mepc;
          if_id.valid <= 1'b0;
          id_ex.valid <= 1'b0;
        end else if (branch_mispredict) begin
          pc <= actual_next_pc;
          if (flush_if_id) if_id.valid <= 1'b0;
          if (flush_id_ex) id_ex.valid <= 1'b0;
        end else if (hold_frontend && bubble_id_ex) begin
          pc <= pc;
          if_id <= if_id;
          id_ex.valid <= 1'b0;
        end else begin
          id_ex.valid <= if_id.valid;
          id_ex.pc <= if_id.pc;
          id_ex.pc_plus4 <= if_id.pc_plus4;
          id_ex.instr <= if_id.instr;
          id_ex.rs1_idx <= dec_rs1;
          id_ex.rs2_idx <= dec_rs2;
          id_ex.rd_idx <= dec_rd;
          id_ex.rs1_value <= rf_rs1_data;
          id_ex.rs2_value <= rf_rs2_data;
          id_ex.imm <= dec_imm;
          id_ex.uses_rs1 <= dec_uses_rs1;
          id_ex.uses_rs2 <= dec_uses_rs2;
          id_ex.alu_op <= dec_control.alu_op;
          id_ex.op_a_sel <= dec_control.op_a_sel;
          id_ex.op_b_sel <= dec_control.op_b_sel;
          id_ex.reg_write <= dec_control.reg_write;
          id_ex.wb_sel <= dec_control.wb_sel;
          id_ex.mem_read <= dec_control.mem_read;
          id_ex.mem_write <= dec_control.mem_write;
          id_ex.mem_size <= dec_control.mem_size;
          id_ex.load_unsigned <= dec_control.load_unsigned;
          id_ex.branch_type <= dec_control.branch_type;
          id_ex.jump_type <= dec_control.jump_type;
          id_ex.illegal_instr <= dec_illegal;
          id_ex.pred_taken <= if_id.pred_taken;
          id_ex.pred_target <= if_id.pred_target;
          id_ex.overflow_check <= dec_control.overflow_check;
          id_ex.system_op <= dec_control.system_op;

          if (imem_ready) begin
            if_id.valid <= 1'b1;
            if_id.pc <= pc;
            if_id.pc_plus4 <= pc + 32'd4;
            if_id.instr <= imem_rdata;
            if_id.pred_taken <= predict_taken_if;
            if_id.pred_target <= predict_target_if;
            pc <= predict_taken_if ? predict_target_if : (pc + 32'd4);
          end else begin
            // ID may still consume its current instruction while IF waits.
            if_id.valid <= 1'b0;
            pc <= pc;
          end
        end
      end
    end
  end
endmodule
