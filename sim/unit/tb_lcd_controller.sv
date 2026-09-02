`timescale 1ns/1ps

module tb_lcd_controller;
  logic clk;
  logic reset;
  logic tx_valid;
  logic tx_rs;
  logic [7:0] tx_data;
  logic reinit_req;
  logic clear_req;
  logic tx_ready;
  logic initialized;
  logic lcd_cs_n;
  logic lcd_rst_n;
  logic lcd_sck;
  logic lcd_mosi;
  logic lcd_rs;
  logic [7:0] captured;
  logic last_rs;
  integer captured_bits;
  integer transfers;
  integer timeout;

  lcd_controller #(
    .RESET_LOW_CYCLES(2),
    .POWER_WAIT_CYCLES(3),
    .DELAY_200MS_CYCLES(2),
    .DELAY_10MS_CYCLES(1),
    .SPI_HALF_PERIOD_CYCLES(1),
    .CLEAR_PAGES(2),
    .CLEAR_BYTES_PER_PAGE(4)
  ) dut (
    .clk(clk), .reset(reset), .tx_valid(tx_valid), .tx_rs(tx_rs),
    .tx_data(tx_data), .reinit_req(reinit_req), .clear_req(clear_req),
    .tx_ready(tx_ready), .initialized(initialized), .lcd_cs_n(lcd_cs_n),
    .lcd_rst_n(lcd_rst_n), .lcd_sck(lcd_sck), .lcd_mosi(lcd_mosi),
    .lcd_rs(lcd_rs)
  );

  always #5 clk = ~clk;

  always @(posedge lcd_sck) begin
    if (!lcd_cs_n) begin
      captured = {captured[6:0], lcd_mosi};
      captured_bits = captured_bits + 1;
      last_rs = lcd_rs;
      if (captured_bits == 8) begin
        transfers = transfers + 1;
        captured_bits = 0;
      end
    end
  end

  initial begin
    clk = 1'b0;
    reset = 1'b1;
    tx_valid = 1'b0;
    tx_rs = 1'b0;
    tx_data = 8'b0;
    reinit_req = 1'b0;
    clear_req = 1'b0;
    captured = 8'b0;
    last_rs = 1'b0;
    captured_bits = 0;
    transfers = 0;
    timeout = 0;
    repeat (3) @(posedge clk);
    reset <= 1'b0;

    while (!initialized && timeout < 5000) begin
      @(posedge clk);
      timeout = timeout + 1;
    end
    if (!initialized) $fatal(1, "LCD controller initialization timeout");
    if (transfers != 36)
      $fatal(1, "Expected 36 init/clear transfers, got %0d", transfers);

    @(negedge clk);
    tx_rs <= 1'b1;
    tx_data <= 8'hA5;
    tx_valid <= 1'b1;
    @(negedge clk);
    tx_valid <= 1'b0;
    wait (tx_ready);
    if (transfers != 37 || captured !== 8'hA5 || last_rs !== 1'b1)
      $fatal(1, "LCD user transfer failed count=%0d data=%h rs=%b",
             transfers, captured, last_rs);

    @(negedge clk);
    clear_req <= 1'b1;
    @(negedge clk);
    clear_req <= 1'b0;
    wait (!initialized);
    wait (initialized);
    if (transfers != 51)
      $fatal(1, "LCD clear transfer count=%0d", transfers);

    $display("PASS tb_lcd_controller");
    $finish;
  end
endmodule
