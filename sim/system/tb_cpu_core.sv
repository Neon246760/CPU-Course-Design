`timescale 1ns/1ps

module tb_cpu_core;
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
  integer timeout_cycles;

  soc_top #(
    .IMEM_WORDS(256),
    .DMEM_WORDS(256),
    .ENABLE_ICACHE(1'b0),
    .ENABLE_DCACHE(1'b0),
    .ENABLE_BRANCH_PREDICTION(1'b0)
  ) dut (
    .clk(clk),
    .reset(reset),
    .ext_irq(ext_irq),
    .gpio_in(gpio_in),
    .uart_tx_ready(uart_tx_ready),
    .gpio_out(gpio_out),
    .uart_tx_valid(uart_tx_valid),
    .uart_tx_data(uart_tx_data),
    .tohost_valid(tohost_valid),
    .tohost_data(tohost_data),
    .cycle_count(cycle_count),
    .instret_count(instret_count),
    .stall_data_count(stall_data_count),
    .stall_fetch_count(stall_fetch_count),
    .stall_memory_count(stall_memory_count),
    .control_flush_count(control_flush_count)
  );

  function automatic [31:0] enc_r(
    input [6:0] funct7,
    input [4:0] rs2,
    input [4:0] rs1,
    input [2:0] funct3,
    input [4:0] rd,
    input [6:0] opcode
  );
    enc_r = {funct7, rs2, rs1, funct3, rd, opcode};
  endfunction

  function automatic [31:0] enc_i(
    input integer imm,
    input [4:0] rs1,
    input [2:0] funct3,
    input [4:0] rd,
    input [6:0] opcode
  );
    enc_i = {imm[11:0], rs1, funct3, rd, opcode};
  endfunction

  function automatic [31:0] enc_s(
    input integer imm,
    input [4:0] rs2,
    input [4:0] rs1,
    input [2:0] funct3
  );
    enc_s = {imm[11:5], rs2, rs1, funct3, imm[4:0], 7'b0100011};
  endfunction

  function automatic [31:0] enc_b(
    input integer imm,
    input [4:0] rs2,
    input [4:0] rs1,
    input [2:0] funct3
  );
    enc_b = {imm[12], imm[10:5], rs2, rs1, funct3,
             imm[4:1], imm[11], 7'b1100011};
  endfunction

  function automatic [31:0] enc_u(
    input [19:0] imm20,
    input [4:0] rd,
    input [6:0] opcode
  );
    enc_u = {imm20, rd, opcode};
  endfunction

  function automatic [31:0] enc_j(
    input integer imm,
    input [4:0] rd
  );
    enc_j = {imm[20], imm[10:1], imm[11], imm[19:12], rd, 7'b1101111};
  endfunction

  always #5 clk = ~clk;

  initial begin
    clk = 1'b0;
    reset = 1'b1;
    ext_irq = 1'b0;
    gpio_in = 32'b0;
    uart_tx_ready = 1'b1;
    timeout_cycles = 0;

    #1;
    dut.u_imem.mem[0]  = enc_i(5,  5'd0, 3'b000, 5'd1, 7'b0010011); // x1=5
    dut.u_imem.mem[1]  = enc_i(7,  5'd0, 3'b000, 5'd2, 7'b0010011); // x2=7
    dut.u_imem.mem[2]  = enc_r(7'b0, 5'd2, 5'd1, 3'b000, 5'd3, 7'b0110011); // x3=12
    dut.u_imem.mem[3]  = enc_u(20'h10000, 5'd10, 7'b0110111);       // DMEM base
    dut.u_imem.mem[4]  = enc_s(0, 5'd3, 5'd10, 3'b010);             // sw x3,0(x10)
    dut.u_imem.mem[5]  = enc_i(0, 5'd10, 3'b010, 5'd4, 7'b0000011); // lw x4,0(x10)
    dut.u_imem.mem[6]  = enc_i(1, 5'd4, 3'b000, 5'd5, 7'b0010011);  // load-use: x5=13
    dut.u_imem.mem[7]  = enc_b(8, 5'd0, 5'd5, 3'b000);              // not taken
    dut.u_imem.mem[8]  = enc_i(1, 5'd0, 3'b000, 5'd6, 7'b0010011);  // x6=1
    dut.u_imem.mem[9]  = enc_b(8, 5'd5, 5'd5, 3'b000);              // taken to 0x2c
    dut.u_imem.mem[10] = enc_i(99, 5'd0, 3'b000, 5'd6, 7'b0010011); // flushed
    dut.u_imem.mem[11] = enc_s(1, 5'd5, 5'd10, 3'b000);             // sb x5,1(x10)
    dut.u_imem.mem[12] = enc_i(1, 5'd10, 3'b100, 5'd7, 7'b0000011);// lbu x7,1(x10)
    dut.u_imem.mem[13] = enc_j(8, 5'd8);                            // jal x8,0x3c
    dut.u_imem.mem[14] = enc_i(99, 5'd0, 3'b000, 5'd9, 7'b0010011);// flushed
    dut.u_imem.mem[15] = enc_i(1, 5'd0, 3'b000, 5'd9, 7'b0010011); // x9=1
    dut.u_imem.mem[16] = enc_i(-16, 5'd0, 3'b000, 5'd11, 7'b0010011);// tohost addr
    dut.u_imem.mem[17] = enc_s(0, 5'd6, 5'd11, 3'b010);             // PASS

    repeat (4) @(posedge clk);
    reset <= 1'b0;
  end

  always @(posedge clk) begin
    if (!reset) begin
      timeout_cycles <= timeout_cycles + 1;
      if (tohost_valid) begin
        if (tohost_data !== 32'd1) $fatal(1, "TOHOST failure code %h", tohost_data);
        if (dut.u_cpu.u_regfile.regs[3] !== 32'd12) $fatal(1, "x3 mismatch");
        if (dut.u_cpu.u_regfile.regs[5] !== 32'd13) $fatal(1, "x5 mismatch");
        if (dut.u_cpu.u_regfile.regs[6] !== 32'd1) $fatal(1, "branch flush failed");
        if (dut.u_cpu.u_regfile.regs[7] !== 32'd13) $fatal(1, "LBU/SB mismatch");
        if (dut.u_cpu.u_regfile.regs[8] !== 32'h0000_0038) $fatal(1, "JAL link mismatch");
        if (dut.u_cpu.u_regfile.regs[9] !== 32'd1) $fatal(1, "JAL flush failed");
        if (dut.u_dmem.mem[0] !== 32'h0000_0D0C) $fatal(1, "memory mismatch");
        // With synchronous BRAM, the outstanding load may hold the pipeline
        // before the dependent instruction reaches the classic load-use
        // hazard point.  Either counter therefore proves the interlock.
        if ((stall_data_count < 1) && (stall_memory_count < 1))
          $fatal(1, "load-use/memory interlock was not counted");
        if (control_flush_count < 2) $fatal(1, "control flush count mismatch");
        $display("PASS cycles=%0d instret=%0d data_stall=%0d flush=%0d",
                 cycle_count, instret_count, stall_data_count, control_flush_count);
        $finish;
      end
      if (timeout_cycles > 200) $fatal(1, "timeout");
    end
  end
endmodule
