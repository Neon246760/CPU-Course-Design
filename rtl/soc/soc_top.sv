module soc_top #(
  parameter integer IMEM_WORDS = 16384,
  parameter integer DMEM_WORDS = 16384,
  parameter IMEM_INIT_FILE = "",
  parameter DMEM_INIT_FILE = "",
  parameter logic ENABLE_ICACHE = 1'b1,
  parameter logic ENABLE_DCACHE = 1'b1,
  parameter logic ENABLE_BRANCH_PREDICTION = 1'b1
) (
  input  logic        clk,
  input  logic        reset,
  input  logic        ext_irq,
  input  logic [31:0] gpio_in,
  input  logic        uart_tx_ready,
  input  logic        lcd_tx_ready,
  input  logic        lcd_initialized,
  output logic [31:0] gpio_out,
  output logic        uart_tx_valid,
  output logic [7:0]  uart_tx_data,
  output logic        lcd_tx_valid,
  output logic        lcd_tx_rs,
  output logic [7:0]  lcd_tx_data,
  output logic        lcd_reinit,
  output logic        lcd_clear,
  output logic        tohost_valid,
  output logic [31:0] tohost_data,
  output logic [31:0] cycle_count,
  output logic [31:0] instret_count,
  output logic [31:0] stall_data_count,
  output logic [31:0] stall_fetch_count,
  output logic [31:0] stall_memory_count,
  output logic [31:0] control_flush_count,
  output logic [31:0] branch_count,
  output logic [31:0] branch_mispredict_count,
  output logic [31:0] icache_hit_count,
  output logic [31:0] icache_miss_count,
  output logic [31:0] dcache_hit_count,
  output logic [31:0] dcache_miss_count,
  output logic [31:0] interrupt_count,
  output logic [31:0] exception_count,
  output logic [31:0] csr_mepc,
  output logic [31:0] csr_mcause
);
  logic cpu_imem_req;
  logic [31:0] cpu_imem_addr;
  logic cpu_imem_ready;
  logic [31:0] cpu_imem_rdata;
  logic mem_imem_req;
  logic [31:0] mem_imem_addr;
  logic mem_imem_ready;
  logic [31:0] mem_imem_rdata;

  logic cpu_dmem_req;
  logic [31:0] cpu_dmem_addr;
  logic cpu_dmem_write;
  logic [31:0] cpu_dmem_wdata;
  logic [3:0] cpu_dmem_wstrb;
  logic cpu_dmem_ready;
  logic [31:0] cpu_dmem_rdata;
  logic bus_req;
  logic [31:0] bus_addr;
  logic bus_write;
  logic [31:0] bus_wdata;
  logic [3:0] bus_wstrb;
  logic bus_ready;
  logic [31:0] bus_rdata;

  logic ram_selected;
  logic ram_ready;
  logic [31:0] ram_rdata;
  logic select_dmem;
  logic select_gpio_out;
  logic select_gpio_in;
  logic select_uart_tx;
  logic select_uart_status;
  logic select_lcd_cmd;
  logic select_lcd_data;
  logic select_lcd_status;
  logic select_lcd_control;
  logic select_tohost;
  logic select_reserved;
  logic retire_valid;
  logic [31:0] retire_pc;
  logic [31:0] retire_instr;
  logic overflow_debug;
  logic illegal_instr_debug;
  logic misaligned_debug;

  cpu_core #(
    .ENABLE_BRANCH_PREDICTION(ENABLE_BRANCH_PREDICTION)
  ) u_cpu (
    .clk(clk), .reset(reset), .ext_irq(ext_irq),
    .imem_req(cpu_imem_req), .imem_addr(cpu_imem_addr),
    .imem_ready(cpu_imem_ready), .imem_rdata(cpu_imem_rdata),
    .dmem_req(cpu_dmem_req), .dmem_addr(cpu_dmem_addr),
    .dmem_write(cpu_dmem_write), .dmem_wdata(cpu_dmem_wdata),
    .dmem_wstrb(cpu_dmem_wstrb), .dmem_ready(cpu_dmem_ready),
    .dmem_rdata(cpu_dmem_rdata),
    .retire_valid(retire_valid), .retire_pc(retire_pc),
    .retire_instr(retire_instr),
    .cycle_count(cycle_count), .instret_count(instret_count),
    .stall_data_count(stall_data_count),
    .stall_fetch_count(stall_fetch_count),
    .stall_memory_count(stall_memory_count),
    .control_flush_count(control_flush_count),
    .branch_count(branch_count),
    .branch_mispredict_count(branch_mispredict_count),
    .interrupt_count(interrupt_count), .exception_count(exception_count),
    .csr_mepc(csr_mepc), .csr_mcause(csr_mcause),
    .overflow_debug(overflow_debug),
    .illegal_instr_debug(illegal_instr_debug),
    .misaligned_debug(misaligned_debug)
  );

  icache #(.LINES(64), .ENABLE(ENABLE_ICACHE)) u_icache (
    .clk(clk), .reset(reset),
    .cpu_req(cpu_imem_req), .cpu_addr(cpu_imem_addr),
    .cpu_ready(cpu_imem_ready), .cpu_rdata(cpu_imem_rdata),
    .mem_req(mem_imem_req), .mem_addr(mem_imem_addr),
    .mem_ready(mem_imem_ready), .mem_rdata(mem_imem_rdata),
    .hit_count(icache_hit_count), .miss_count(icache_miss_count)
  );

  instruction_memory #(.WORDS(IMEM_WORDS), .INIT_FILE(IMEM_INIT_FILE)) u_imem (
    .clk(clk), .reset(reset),
    .req(mem_imem_req), .addr(mem_imem_addr),
    .ready(mem_imem_ready), .rdata(mem_imem_rdata)
  );

  dcache #(.LINES(64), .ENABLE(ENABLE_DCACHE)) u_dcache (
    .clk(clk), .reset(reset),
    .cpu_req(cpu_dmem_req), .cpu_addr(cpu_dmem_addr),
    .cpu_write(cpu_dmem_write), .cpu_wdata(cpu_dmem_wdata),
    .cpu_wstrb(cpu_dmem_wstrb), .cpu_ready(cpu_dmem_ready),
    .cpu_rdata(cpu_dmem_rdata),
    .mem_req(bus_req), .mem_addr(bus_addr), .mem_write(bus_write),
    .mem_wdata(bus_wdata), .mem_wstrb(bus_wstrb),
    .mem_ready(bus_ready), .mem_rdata(bus_rdata),
    .hit_count(dcache_hit_count), .miss_count(dcache_miss_count)
  );

  address_decoder u_address_decoder (
    .addr(bus_addr), .select_dmem(select_dmem),
    .select_gpio_out(select_gpio_out), .select_gpio_in(select_gpio_in),
    .select_uart_tx(select_uart_tx),
    .select_uart_status(select_uart_status),
    .select_lcd_cmd(select_lcd_cmd),
    .select_lcd_data(select_lcd_data),
    .select_lcd_status(select_lcd_status),
    .select_lcd_control(select_lcd_control),
    .select_tohost(select_tohost), .select_reserved(select_reserved)
  );

  data_memory #(.WORDS(DMEM_WORDS), .INIT_FILE(DMEM_INIT_FILE)) u_dmem (
    .clk(clk), .reset(reset),
    .req(bus_req && select_dmem), .addr(bus_addr),
    .write(bus_write), .wdata(bus_wdata), .wstrb(bus_wstrb),
    .selected(ram_selected), .ready(ram_ready), .rdata(ram_rdata)
  );

  always_comb begin
    bus_ready = 1'b0;
    bus_rdata = 32'b0;
    if (bus_req) begin
      if (select_dmem) begin
        bus_ready = ram_ready;
        bus_rdata = ram_rdata;
      end else if (select_uart_tx) begin
        bus_ready = !bus_write || uart_tx_ready;
      end else if (select_lcd_cmd || select_lcd_data) begin
        bus_ready = !bus_write || lcd_tx_ready;
      end else begin
        bus_ready = 1'b1;
        if (select_gpio_out) bus_rdata = gpio_out;
        else if (select_gpio_in) bus_rdata = gpio_in;
        else if (select_uart_status) bus_rdata = {31'b0, uart_tx_ready};
        else if (select_lcd_status)
          bus_rdata = {30'b0, lcd_initialized, lcd_tx_ready};
      end
    end
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      gpio_out <= 32'b0;
      uart_tx_valid <= 1'b0;
      uart_tx_data <= 8'b0;
      lcd_tx_valid <= 1'b0;
      lcd_tx_rs <= 1'b0;
      lcd_tx_data <= 8'b0;
      lcd_reinit <= 1'b0;
      lcd_clear <= 1'b0;
      tohost_valid <= 1'b0;
      tohost_data <= 32'b0;
    end else begin
      uart_tx_valid <= 1'b0;
      lcd_tx_valid <= 1'b0;
      lcd_reinit <= 1'b0;
      lcd_clear <= 1'b0;
      tohost_valid <= 1'b0;
      if (bus_req && bus_ready && bus_write) begin
        if (select_gpio_out) begin
          if (bus_wstrb[0]) gpio_out[7:0] <= bus_wdata[7:0];
          if (bus_wstrb[1]) gpio_out[15:8] <= bus_wdata[15:8];
          if (bus_wstrb[2]) gpio_out[23:16] <= bus_wdata[23:16];
          if (bus_wstrb[3]) gpio_out[31:24] <= bus_wdata[31:24];
        end
        if (select_uart_tx) begin
          uart_tx_valid <= 1'b1;
          uart_tx_data <= bus_wdata[7:0];
        end
        if (select_lcd_cmd || select_lcd_data) begin
          lcd_tx_valid <= 1'b1;
          lcd_tx_rs <= select_lcd_data;
          lcd_tx_data <= bus_wdata[7:0];
        end
        if (select_lcd_control) begin
          lcd_reinit <= bus_wdata[0];
          lcd_clear <= bus_wdata[1];
        end
        if (select_tohost) begin
          tohost_valid <= 1'b1;
          tohost_data <= bus_wdata;
        end
      end
    end
  end
endmodule
