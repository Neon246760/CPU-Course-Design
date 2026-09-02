`timescale 1ns/1ps

module tb_extended_system;
  logic clk;
  logic reset;
  logic ext_irq;
  logic [31:0] gpio_in;
  logic uart_tx_ready;
  logic [31:0] gpio_out;
  logic uart_tx_valid;
  logic [7:0] uart_tx_data;
  logic tohost_valid;
  logic [31:0] tohost_data;
  logic [31:0] cycle_count;
  logic [31:0] instret_count;
  logic [31:0] stall_data_count;
  logic [31:0] stall_fetch_count;
  logic [31:0] stall_memory_count;
  logic [31:0] control_flush_count;
  logic [31:0] branch_count;
  logic [31:0] branch_mispredict_count;
  logic [31:0] icache_hit_count;
  logic [31:0] icache_miss_count;
  logic [31:0] dcache_hit_count;
  logic [31:0] dcache_miss_count;
  logic [31:0] interrupt_count;
  logic [31:0] exception_count;
  logic [31:0] csr_mepc;
  logic [31:0] csr_mcause;
  logic overflow_seen;
  logic irq_sent;
  integer timeout_cycles;

  soc_top #(
    .IMEM_WORDS(256), .DMEM_WORDS(256),
    .ENABLE_ICACHE(1'b1), .ENABLE_DCACHE(1'b1),
    .ENABLE_BRANCH_PREDICTION(1'b1)
  ) dut (
    .clk(clk), .reset(reset), .ext_irq(ext_irq),
    .gpio_in(gpio_in), .uart_tx_ready(uart_tx_ready),
    .gpio_out(gpio_out), .uart_tx_valid(uart_tx_valid),
    .uart_tx_data(uart_tx_data), .tohost_valid(tohost_valid),
    .tohost_data(tohost_data), .cycle_count(cycle_count),
    .instret_count(instret_count), .stall_data_count(stall_data_count),
    .stall_fetch_count(stall_fetch_count),
    .stall_memory_count(stall_memory_count),
    .control_flush_count(control_flush_count),
    .branch_count(branch_count),
    .branch_mispredict_count(branch_mispredict_count),
    .icache_hit_count(icache_hit_count), .icache_miss_count(icache_miss_count),
    .dcache_hit_count(dcache_hit_count), .dcache_miss_count(dcache_miss_count),
    .interrupt_count(interrupt_count), .exception_count(exception_count),
    .csr_mepc(csr_mepc), .csr_mcause(csr_mcause)
  );

  function automatic [31:0] enc_r(input [6:0] f7, input [4:0] rs2,
    input [4:0] rs1, input [2:0] f3, input [4:0] rd);
    enc_r = {f7, rs2, rs1, f3, rd, 7'b0110011};
  endfunction
  function automatic [31:0] enc_i(input integer imm, input [4:0] rs1,
    input [2:0] f3, input [4:0] rd, input [6:0] opcode);
    enc_i = {imm[11:0], rs1, f3, rd, opcode};
  endfunction
  function automatic [31:0] enc_s(input integer imm, input [4:0] rs2,
    input [4:0] rs1, input [2:0] f3);
    enc_s = {imm[11:5], rs2, rs1, f3, imm[4:0], 7'b0100011};
  endfunction
  function automatic [31:0] enc_b(input integer imm, input [4:0] rs2,
    input [4:0] rs1, input [2:0] f3);
    enc_b = {imm[12], imm[10:5], rs2, rs1, f3,
             imm[4:1], imm[11], 7'b1100011};
  endfunction
  function automatic [31:0] enc_u(input [19:0] imm20, input [4:0] rd);
    enc_u = {imm20, rd, 7'b0110111};
  endfunction

  always #5 clk = ~clk;

  initial begin
    clk = 1'b0;
    reset = 1'b1;
    ext_irq = 1'b0;
    gpio_in = 32'b0;
    uart_tx_ready = 1'b1;
    overflow_seen = 1'b0;
    irq_sent = 1'b0;
    timeout_cycles = 0;
    #1;

    dut.u_imem.mem[0]  = enc_i(-1, 5'd0, 3'b000, 5'd2, 7'b0010011); // x2=-1
    dut.u_imem.mem[1]  = enc_i(1, 5'd0, 3'b000, 5'd3, 7'b0010011);  // x3=1
    dut.u_imem.mem[2]  = enc_r(7'b0, 5'd3, 5'd2, 3'b101, 5'd1);     // SRL=max positive
    dut.u_imem.mem[3]  = enc_r(7'b0, 5'd3, 5'd1, 3'b000, 5'd4);     // overflow, x4 unchanged
    dut.u_imem.mem[4]  = enc_i(5, 5'd0, 3'b000, 5'd5, 7'b0010011);  // loop count
    dut.u_imem.mem[5]  = enc_i(0, 5'd0, 3'b000, 5'd6, 7'b0010011);
    dut.u_imem.mem[6]  = enc_i(1, 5'd6, 3'b000, 5'd6, 7'b0010011);  // loop body
    dut.u_imem.mem[7]  = enc_i(-1, 5'd5, 3'b000, 5'd5, 7'b0010011);
    dut.u_imem.mem[8]  = enc_b(-8, 5'd0, 5'd5, 3'b001);             // BNE -> index 6
    dut.u_imem.mem[9]  = enc_b(8, 5'd3, 5'd3, 3'b000);              // taken BEQ
    dut.u_imem.mem[10] = enc_r(7'b0, 5'd3, 5'd1, 3'b000, 5'd4);     // wrong-path overflow
    dut.u_imem.mem[11] = enc_u(20'h10000, 5'd10);                   // DMEM base
    dut.u_imem.mem[12] = enc_s(0, 5'd6, 5'd10, 3'b010);             // store miss
    dut.u_imem.mem[13] = enc_i(0, 5'd10, 3'b010, 5'd11, 7'b0000011);// load miss
    dut.u_imem.mem[14] = enc_i(0, 5'd10, 3'b010, 5'd12, 7'b0000011);// load hit
    dut.u_imem.mem[15] = enc_i(1, 5'd12, 3'b000, 5'd13, 7'b0010011);// load-use
    dut.u_imem.mem[16] = enc_i(7, 5'd0, 3'b000, 5'd14, 7'b0010011);
    dut.u_imem.mem[17] = enc_i(8, 5'd0, 3'b000, 5'd15, 7'b0010011);// IRQ wait loop
    dut.u_imem.mem[18] = enc_i(-1, 5'd15, 3'b000, 5'd15, 7'b0010011);
    dut.u_imem.mem[19] = enc_b(-4, 5'd0, 5'd15, 3'b001);
    dut.u_imem.mem[20] = enc_i(-16, 5'd0, 3'b000, 5'd19, 7'b0010011);
    dut.u_imem.mem[21] = enc_s(0, 5'd3, 5'd19, 3'b010);             // PASS

    dut.u_imem.mem[64] = enc_i(1, 5'd20, 3'b000, 5'd20, 7'b0010011);// handler count
    dut.u_imem.mem[65] = 32'h3020_0073;                             // MRET

    repeat (4) @(posedge clk);
    reset <= 1'b0;
  end

  always @(posedge clk) begin
    if (!reset) begin
      timeout_cycles <= timeout_cycles + 1;
      if (dut.u_cpu.overflow_debug) overflow_seen <= 1'b1;

      if (!irq_sent && dut.cpu_dmem_req && !dut.cpu_dmem_ready) begin
        ext_irq <= 1'b1;
        irq_sent <= 1'b1;
      end else begin
        ext_irq <= 1'b0;
      end

      if (tohost_valid) begin
        if (tohost_data !== 32'd1) $fatal(1, "TOHOST=%h", tohost_data);
        if (!overflow_seen) $fatal(1, "overflow pulse not observed");
        if (dut.u_cpu.u_regfile.regs[4] !== 32'd0) $fatal(1, "faulting ADD committed");
        if (dut.u_cpu.u_regfile.regs[6] !== 32'd5) $fatal(1, "loop result mismatch");
        if (dut.u_cpu.u_regfile.regs[11] !== 32'd5) $fatal(1, "D-cache miss load mismatch");
        if (dut.u_cpu.u_regfile.regs[12] !== 32'd5) $fatal(1, "D-cache hit load mismatch");
        if (dut.u_cpu.u_regfile.regs[13] !== 32'd6) $fatal(1, "load-use result mismatch");
        if (dut.u_cpu.u_regfile.regs[20] !== 32'd2) $fatal(1, "handler count mismatch");
        if (exception_count !== 32'd1) $fatal(1, "exception count=%0d", exception_count);
        if (interrupt_count !== 32'd1) $fatal(1, "interrupt count=%0d", interrupt_count);
        if (csr_mcause !== 32'h8000_000B) $fatal(1, "mcause=%h", csr_mcause);
        if (icache_miss_count == 0 || icache_hit_count == 0) $fatal(1, "I-cache stats invalid");
        if (dcache_miss_count < 2 || dcache_hit_count == 0) $fatal(1, "D-cache stats invalid");
        if (branch_count < 10) $fatal(1, "branch count=%0d", branch_count);
        if (branch_mispredict_count == 0 || branch_mispredict_count >= branch_count)
          $fatal(1, "predictor stats branch=%0d miss=%0d", branch_count, branch_mispredict_count);
        $display("PASS tb_extended_system cycles=%0d instret=%0d I$=%0d/%0d D$=%0d/%0d branch=%0d miss=%0d",
          cycle_count, instret_count, icache_hit_count, icache_miss_count,
          dcache_hit_count, dcache_miss_count, branch_count, branch_mispredict_count);
        $finish;
      end
      if (timeout_cycles > 1000) $fatal(1, "timeout");
    end
  end
endmodule
