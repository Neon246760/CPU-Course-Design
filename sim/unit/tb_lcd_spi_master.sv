`timescale 1ns/1ps

module tb_lcd_spi_master;
  logic clk;
  logic reset;
  logic start;
  logic rs_in;
  logic [7:0] data_in;
  logic ready;
  logic cs_n;
  logic sck;
  logic mosi;
  logic rs_out;
  logic [7:0] captured;
  integer captured_bits;

  lcd_spi_master #(.HALF_PERIOD_CYCLES(2)) dut (
    .clk(clk), .reset(reset), .start(start), .rs_in(rs_in),
    .data_in(data_in), .ready(ready), .cs_n(cs_n), .sck(sck),
    .mosi(mosi), .rs_out(rs_out)
  );

  always #5 clk = ~clk;

  always @(posedge sck) begin
    if (!cs_n) begin
      captured = {captured[6:0], mosi};
      captured_bits = captured_bits + 1;
      if (rs_out !== 1'b1) $fatal(1, "LCD RS changed during transfer");
    end
  end

  initial begin
    clk = 1'b0;
    reset = 1'b1;
    start = 1'b0;
    rs_in = 1'b1;
    data_in = 8'hA5;
    captured = 8'b0;
    captured_bits = 0;
    repeat (3) @(posedge clk);
    reset <= 1'b0;
    @(negedge clk);
    start <= 1'b1;
    @(negedge clk);
    start <= 1'b0;
    wait (!ready);
    wait (ready);
    @(posedge clk);
    if (captured_bits != 8 || captured !== 8'hA5)
      $fatal(1, "LCD SPI captured bits=%0d data=%h", captured_bits, captured);
    if (!cs_n || sck) $fatal(1, "LCD SPI did not return idle");
    $display("PASS tb_lcd_spi_master");
    $finish;
  end
endmodule
