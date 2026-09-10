`timescale 1ns/1ps

// 定向"相关处理"波形测试: 让五级流水真正逐拍推进, 从而使三类相关场景真实出现。
//
//   1) 双源前递   : forward_a / forward_b (EX/MEM 与 MEM/WB 两条通路)
//   2) load-use   : load_use / bubble_id_ex / hold_frontend (PC 与 IF/ID 保持)
//   3) 分支冲刷   : redirect_accept / flush_if_id / flush_id_ex (错误路径作废)
//
// 为什么需要单独的 testbench:
//   tb_cpu_core 走的是板级 SoC 配置, 指令存储器为同步 BRAM,
//   一次取指需要 3 个周期(IDLE->RESPOND->TURNAROUND), 相邻指令间隔被拉开,
//   生产者早已写回, 因而前递与 load-use 逻辑不会被激活。
//   本 tb 直接驱动 cpu_core, 使用"当拍响应"(ready = req)的存储器模型,
//   使流水线填满, 三类相关场景才会出现, 用于波形证据与定向回归。
//
// 运行:
//   vivado -mode batch -source sim/run_test.tcl -tclargs tb_pipeline_hazard sim/system/tb_pipeline_hazard.sv

module tb_pipeline_hazard;
  localparam integer IMEM_WORDS = 64;
  localparam integer DMEM_WORDS = 64;

  logic clk;
  logic reset;
  logic ext_irq;

  logic        imem_req;
  logic [31:0] imem_addr;
  logic        imem_ready;
  logic [31:0] imem_rdata;

  logic        dmem_req;
  logic [31:0] dmem_addr;
  logic        dmem_write;
  logic [31:0] dmem_wdata;
  logic [3:0]  dmem_wstrb;
  logic        dmem_ready;
  logic [31:0] dmem_rdata;

  logic        retire_valid;
  logic [31:0] retire_pc;
  logic [31:0] retire_instr;
  logic [31:0] cycle_count;
  logic [31:0] instret_count;
  logic [31:0] stall_data_count;
  logic [31:0] stall_fetch_count;
  logic [31:0] stall_memory_count;
  logic [31:0] control_flush_count;
  logic [31:0] branch_count;
  logic [31:0] branch_mispredict_count;

  logic [31:0] imem_mem [0:IMEM_WORDS-1];
  logic [31:0] dmem_mem [0:DMEM_WORDS-1];

  integer timeout;
  integer forward_events;
  integer load_use_events;
  integer redirect_events;

  // 指令存储器: 当拍响应, 流水线可以逐拍取指
  assign imem_ready = imem_req;
  assign imem_rdata = imem_mem[imem_addr[8:2]];

  // 数据存储器: 当拍读, 上升沿按字节写
  assign dmem_ready = dmem_req;
  assign dmem_rdata = dmem_mem[dmem_addr[8:2]];

  always_ff @(posedge clk) begin
    if (dmem_req && dmem_write && dmem_ready) begin
      if (dmem_wstrb[0]) dmem_mem[dmem_addr[8:2]][7:0]   <= dmem_wdata[7:0];
      if (dmem_wstrb[1]) dmem_mem[dmem_addr[8:2]][15:8]  <= dmem_wdata[15:8];
      if (dmem_wstrb[2]) dmem_mem[dmem_addr[8:2]][23:16] <= dmem_wdata[23:16];
      if (dmem_wstrb[3]) dmem_mem[dmem_addr[8:2]][31:24] <= dmem_wdata[31:24];
    end
  end

  cpu_core #(
    .ENABLE_BRANCH_PREDICTION(1'b0)
  ) dut (
    .clk(clk), .reset(reset), .ext_irq(ext_irq),
    .imem_req(imem_req), .imem_addr(imem_addr),
    .imem_ready(imem_ready), .imem_rdata(imem_rdata),
    .dmem_req(dmem_req), .dmem_addr(dmem_addr), .dmem_write(dmem_write),
    .dmem_wdata(dmem_wdata), .dmem_wstrb(dmem_wstrb),
    .dmem_ready(dmem_ready), .dmem_rdata(dmem_rdata),
    .retire_valid(retire_valid), .retire_pc(retire_pc), .retire_instr(retire_instr),
    .cycle_count(cycle_count), .instret_count(instret_count),
    .stall_data_count(stall_data_count), .stall_fetch_count(stall_fetch_count),
    .stall_memory_count(stall_memory_count), .control_flush_count(control_flush_count),
    .branch_count(branch_count), .branch_mispredict_count(branch_mispredict_count)
  );

  always #5 clk = ~clk;

  // ---- 编码函数(与 tb_cpu_core 保持一致) ----
  function automatic [31:0] enc_r(
    input [6:0] funct7, input [4:0] rs2, input [4:0] rs1,
    input [2:0] funct3, input [4:0] rd, input [6:0] opcode
  );
    enc_r = {funct7, rs2, rs1, funct3, rd, opcode};
  endfunction

  function automatic [31:0] enc_i(
    input integer imm, input [4:0] rs1, input [2:0] funct3,
    input [4:0] rd, input [6:0] opcode
  );
    enc_i = {imm[11:0], rs1, funct3, rd, opcode};
  endfunction

  function automatic [31:0] enc_s(
    input integer imm, input [4:0] rs2, input [4:0] rs1, input [2:0] funct3
  );
    enc_s = {imm[11:5], rs2, rs1, funct3, imm[4:0], 7'b0100011};
  endfunction

  function automatic [31:0] enc_b(
    input integer imm, input [4:0] rs2, input [4:0] rs1, input [2:0] funct3
  );
    enc_b = {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], 7'b1100011};
  endfunction

  function automatic [31:0] enc_u(input [19:0] imm20, input [4:0] rd, input [6:0] opcode);
    enc_u = {imm20, rd, opcode};
  endfunction

  function automatic [31:0] enc_j(input integer imm, input [4:0] rd);
    enc_j = {imm[20], imm[10:1], imm[11], imm[19:12], rd, 7'b1101111};
  endfunction

  // ---- 事件监视: 直接把三类相关场景发生的周期打到控制台, 便于定位波形 ----
  always @(posedge clk) begin
    if (!reset) begin
      if ((dut.forward_a != 2'b00) || (dut.forward_b != 2'b00)) begin
        forward_events = forward_events + 1;
        $display("EVENT cycle=%0d FORWARD  forward_a=%0b forward_b=%0b (bit10=EX/MEM, bit01=MEM/WB)",
                 cycle_count, dut.forward_a, dut.forward_b);
      end
      if (dut.load_use) begin
        load_use_events = load_use_events + 1;
        $display("EVENT cycle=%0d LOAD_USE (hold_frontend=%0b bubble_id_ex=%0b)",
                 cycle_count, dut.hold_frontend, dut.bubble_id_ex);
      end
      if (dut.redirect_accept) begin
        redirect_events = redirect_events + 1;
        $display("EVENT cycle=%0d REDIRECT (flush_if_id=%0b flush_id_ex=%0b)",
                 cycle_count, dut.flush_if_id, dut.flush_id_ex);
      end
    end
  end

  initial begin
    clk = 1'b0;
    reset = 1'b1;
    ext_irq = 1'b0;
    timeout = 0;
    forward_events = 0;
    load_use_events = 0;
    redirect_events = 0;

    for (integer i = 0; i < IMEM_WORDS; i = i + 1) imem_mem[i] = enc_i(0, 5'd0, 3'b000, 5'd0, 7'b0010011);
    for (integer i = 0; i < DMEM_WORDS; i = i + 1) dmem_mem[i] = 32'b0;

    #1;
    // 0x00
    imem_mem[0]  = enc_i(5,  5'd0, 3'b000, 5'd1,  7'b0010011); // x1 = 5
    // 0x04
    imem_mem[1]  = enc_i(7,  5'd0, 3'b000, 5'd2,  7'b0010011); // x2 = 7
    // 0x08
    imem_mem[2]  = enc_r(7'b0, 5'd2, 5'd1, 3'b000, 5'd3, 7'b0110011); // x3 = 12 ← 双源前递
    // 0x0c
    imem_mem[3]  = enc_u(20'h10000, 5'd10, 7'b0110111);        // x10 = DMEM base
    // 0x10
    imem_mem[4]  = enc_i(42, 5'd0, 3'b000, 5'd4,  7'b0010011); // x4 = 42
    // 0x14
    imem_mem[5]  = enc_s(0, 5'd4, 5'd10, 3'b010);              // sw x4,0(x10) ← store-data 前递
    // 0x18
    imem_mem[6]  = enc_i(0, 5'd10, 3'b010, 5'd5,  7'b0000011); // lw x5,0(x10)
    // 0x1c
    imem_mem[7]  = enc_i(1, 5'd5, 3'b000, 5'd6,  7'b0010011);  // x6 = x5+1 ← load-use 停顿
    // 0x20
    imem_mem[8]  = enc_b(8, 5'd6, 5'd6, 3'b000);               // beq x6,x6 → taken, 跳到 0x28
    // 0x24
    imem_mem[9]  = enc_i(99, 5'd0, 3'b000, 5'd9, 7'b0010011);  // 错误路径, 应被冲刷
    // 0x28
    imem_mem[10] = enc_j(8, 5'd8);                             // jal x8, → 0x30
    // 0x2c
    imem_mem[11] = enc_i(99, 5'd0, 3'b000, 5'd9, 7'b0010011);  // 错误路径, 应被冲刷
    // 0x30
    imem_mem[12] = enc_i(1, 5'd0, 3'b000, 5'd7, 7'b0010011);   // x7 = 1
    // 0x34 之后为默认 NOP(addi x0,x0,0), 不再产生跳转,
    // 以免死循环中的 JAL 反复触发重定向而污染"控制冲刷 = 2"的统计。

    repeat (3) @(posedge clk);
    reset <= 1'b0;

    for (timeout = 0; timeout < 26; timeout = timeout + 1) @(posedge clk);
    @(negedge clk);

    if (dut.u_regfile.regs[1] !== 32'd5)   $fatal(1, "x1 mismatch");
    if (dut.u_regfile.regs[2] !== 32'd7)   $fatal(1, "x2 mismatch");
    if (dut.u_regfile.regs[3] !== 32'd12)  $fatal(1, "x3 mismatch (dual forwarding)");
    if (dut.u_regfile.regs[4] !== 32'd42)  $fatal(1, "x4 mismatch");
    if (dut.u_regfile.regs[5] !== 32'd42)  $fatal(1, "x5 mismatch (store->load)");
    if (dut.u_regfile.regs[6] !== 32'd43)  $fatal(1, "x6 mismatch (load-use)");
    if (dut.u_regfile.regs[7] !== 32'd1)   $fatal(1, "x7 mismatch (wrong path executed?)");
    if (dut.u_regfile.regs[8] !== 32'h0000_002c) $fatal(1, "x8 mismatch (jal link)");
    if (dut.u_regfile.regs[9] !== 32'd0)   $fatal(1, "x9 mismatch (flushed instruction wrote rd)");
    if (dmem_mem[0] !== 32'd42)            $fatal(1, "dmem[0] mismatch");

    if (forward_events == 0)  $fatal(1, "no forwarding event observed");
    if (load_use_events == 0) $fatal(1, "no load-use stall observed");
    if (redirect_events == 0) $fatal(1, "no redirect/flush observed");

    $display("PASS cycles=%0d instret=%0d data_stall=%0d flush=%0d forward_events=%0d load_use_events=%0d redirect_events=%0d",
             cycle_count, instret_count, stall_data_count, control_flush_count,
             forward_events, load_use_events, redirect_events);
    $finish;
  end
endmodule
