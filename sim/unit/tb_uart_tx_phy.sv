`timescale 1ns/1ps

module tb_uart_tx_phy;
  logic clk;
  logic reset;
  logic valid;
  logic [7:0] data;
  logic ready;
  logic txd;
  logic busy;
  logic [9:0] expected;
  integer bit_number;

  uart_tx_phy #(
    .CLOCK_HZ(100),
    .BAUD_RATE(10)
  ) dut (
    .clk(clk), .reset(reset), .valid(valid), .data(data),
    .ready(ready), .txd(txd), .busy(busy)
  );

  always #5 clk = ~clk;

  initial begin
    clk = 1'b0;
    reset = 1'b1;
    valid = 1'b0;
    data = 8'hA5;
    expected = {1'b1, 8'hA5, 1'b0};
    repeat (3) @(posedge clk);
    reset <= 1'b0;
    @(negedge clk);
    if (!ready) $fatal(1, "UART was not ready");
    valid <= 1'b1;
    @(negedge clk);
    valid <= 1'b0;

    for (bit_number = 0; bit_number < 10; bit_number = bit_number + 1) begin
      repeat (5) @(posedge clk);
      if (txd !== expected[bit_number])
        $fatal(1, "UART bit %0d expected %b got %b",
               bit_number, expected[bit_number], txd);
      repeat (5) @(posedge clk);
    end

    wait (!busy);
    if (txd !== 1'b1 || !ready) $fatal(1, "UART did not return idle");
    $display("PASS tb_uart_tx_phy");
    $finish;
  end
endmodule
