module csr_file #(
  parameter logic [31:0] MTVEC_RESET = 32'h0000_0100,
  parameter logic        MIE_RESET = 1'b1
) (
  input  logic        clk,
  input  logic        reset,
  input  logic        ext_irq,
  input  logic        trap_enter,
  input  logic        trap_is_interrupt,
  input  logic [31:0] trap_pc,
  input  logic [31:0] trap_cause,
  input  logic        mret,
  output logic        interrupt_pending,
  output logic        interrupt_enable,
  output logic [31:0] mtvec,
  output logic [31:0] mepc,
  output logic [31:0] mcause,
  output logic [31:0] interrupt_count,
  output logic [31:0] exception_count
);
  logic irq_meta;
  logic irq_sync;
  logic mstatus_mie;
  logic mstatus_mpie;
  logic interrupt_pending_reg;

  assign interrupt_pending = irq_sync || interrupt_pending_reg;
  assign interrupt_enable = mstatus_mie;

  always_ff @(posedge clk) begin
    if (reset) begin
      irq_meta <= 1'b0;
      irq_sync <= 1'b0;
      interrupt_pending_reg <= 1'b0;
      mstatus_mie <= MIE_RESET;
      mstatus_mpie <= 1'b1;
      mtvec <= MTVEC_RESET;
      mepc <= 32'b0;
      mcause <= 32'b0;
      interrupt_count <= 32'b0;
      exception_count <= 32'b0;
    end else begin
      irq_meta <= ext_irq;
      irq_sync <= irq_meta;
      if (irq_sync) interrupt_pending_reg <= 1'b1;

      if (trap_enter) begin
        mepc <= trap_pc;
        mcause <= {trap_is_interrupt, trap_cause[30:0]};
        mstatus_mpie <= mstatus_mie;
        mstatus_mie <= 1'b0;
        if (trap_is_interrupt) begin
          interrupt_pending_reg <= 1'b0;
          interrupt_count <= interrupt_count + 32'd1;
        end else begin
          exception_count <= exception_count + 32'd1;
        end
      end else if (mret) begin
        mstatus_mie <= mstatus_mpie;
        mstatus_mpie <= 1'b1;
      end
    end
  end
endmodule
