`timescale 1ns/1ps

module tb_bringup_system;
  logic clk;
  logic reset;
  logic [31:0] gpio_out;
  logic uart_tx_valid;
  logic [7:0] uart_tx_data;
  logic lcd_tx_valid;
  logic lcd_tx_rs;
  logic [7:0] lcd_tx_data;
  logic lcd_reinit;
  logic lcd_clear;
  logic lcd_demo;
  logic tohost_valid;
  logic [31:0] tohost_data;
  logic lcd_initialized;
  logic [31:0] gpio_in;
  logic saw_tohost;
  integer cycles;
  integer uart_bytes;
  integer lcd_commands;
  integer lcd_data_bytes;

  soc_top #(
    .IMEM_WORDS(256),
    .DMEM_WORDS(256),
    .IMEM_INIT_FILE("bringup.mem"),
    .ENABLE_ICACHE(1'b0),
    .ENABLE_DCACHE(1'b0),
    .ENABLE_BRANCH_PREDICTION(1'b0)
  ) dut (
    .clk(clk), .reset(reset), .ext_irq(1'b0), .gpio_in(gpio_in),
    .uart_tx_ready(1'b1),
    .lcd_tx_ready(1'b1),
    .lcd_initialized(lcd_initialized),
    .gpio_out(gpio_out),
    .uart_tx_valid(uart_tx_valid), .uart_tx_data(uart_tx_data),
    .lcd_tx_valid(lcd_tx_valid), .lcd_tx_rs(lcd_tx_rs),
    .lcd_tx_data(lcd_tx_data), .lcd_reinit(lcd_reinit),
    .lcd_clear(lcd_clear), .tohost_valid(tohost_valid),
    .lcd_demo(lcd_demo),
    .tohost_data(tohost_data)
  );

  always #5 clk = ~clk;

  initial begin
    clk = 1'b0;
    reset = 1'b1;
    lcd_initialized = 1'b0;
    gpio_in = 32'b0;
    saw_tohost = 1'b0;
    cycles = 0;
    uart_bytes = 0;
    lcd_commands = 0;
    lcd_data_bytes = 0;
    repeat (4) @(posedge clk);
    reset <= 1'b0;
    repeat (20) @(posedge clk);
    lcd_initialized <= 1'b1;
  end

  always @(posedge clk) begin
    if (!reset) begin
      cycles <= cycles + 1;
      if (uart_tx_valid) uart_bytes <= uart_bytes + 1;
      if (lcd_tx_valid && lcd_tx_rs) lcd_data_bytes <= lcd_data_bytes + 1;
      if (lcd_tx_valid && !lcd_tx_rs) lcd_commands <= lcd_commands + 1;
      if (tohost_valid) begin
        if (tohost_data !== 32'd1) $fatal(1, "Bring-up TOHOST=%h", tohost_data);
        if (gpio_out[7:0] !== 8'hFF) $fatal(1, "Bring-up LED value=%h", gpio_out[7:0]);
        if (uart_bytes != 10) $fatal(1, "Bring-up UART bytes=%0d", uart_bytes);
        if (lcd_commands != 3 || lcd_data_bytes != 256)
          $fatal(1, "Bring-up LCD cmd=%0d data=%0d", lcd_commands, lcd_data_bytes);
        saw_tohost <= 1'b1;
        gpio_in[0] <= 1'b1; // emulate switching SW0 on
      end
      if (lcd_demo) begin
        if (!saw_tohost) $fatal(1, "LCD demo triggered before bring-up PASS");
        $display("PASS tb_bringup_system cycles=%0d SW0 name demo", cycles);
        $finish;
      end
      if (cycles > 10000) $fatal(1, "Bring-up timeout");
    end
  end
endmodule
