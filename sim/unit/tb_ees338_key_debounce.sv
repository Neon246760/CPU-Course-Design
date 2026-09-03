`timescale 1ns/1ps

module tb_ees338_key_debounce;
  logic sys_clk;
  logic reset_n;
  logic [7:0] sw;
  logic [4:0] key;
  logic [7:0] led;
  logic uart_txd;
  logic lcd_wr;
  logic lcd_rd;
  logic [7:0] lcd_d;
  logic lcd_cs_n;
  logic lcd_rst_n;
  logic lcd_rs;
  logic buzzer;

  ees338_top #(
    .KEY_DEBOUNCE_CYCLES(4),
    .BUZZER_BEEP_CYCLES(12),
    .BUZZER_HALF_PERIOD_CYCLES(2)
  ) dut (
    .sys_clk(sys_clk),
    .reset_n(reset_n),
    .sw(sw),
    .key(key),
    .led(led),
    .uart_rxd(1'b1),
    .uart_txd(uart_txd),
    .lcd_wr(lcd_wr),
    .lcd_rd(lcd_rd),
    .lcd_d(lcd_d),
    .lcd_cs_n(lcd_cs_n),
    .lcd_rst_n(lcd_rst_n),
    .lcd_rs(lcd_rs),
    .buzzer(buzzer)
  );

  always #5 sys_clk = ~sys_clk;

  task automatic cpu_cycles(input integer count);
    repeat (count) @(posedge dut.cpu_clk);
  endtask

  initial begin
    sys_clk = 1'b0;
    reset_n = 1'b0;
    sw = 8'b0;
    key = 5'b0;

    wait (dut.clk_locked === 1'b1);
    reset_n = 1'b1;
    wait (dut.cpu_reset === 1'b0);
    cpu_cycles(2);

    // Alternating levels shorter than the threshold must not create a press.
    key[1] = 1'b1;
    cpu_cycles(2);
    key[1] = 1'b0;
    cpu_cycles(2);
    key[1] = 1'b1;
    cpu_cycles(2);
    key[1] = 1'b0;
    cpu_cycles(2);
    if (dut.key_sync[1] !== 1'b0)
      $fatal(1, "bounce was incorrectly accepted as a press");

    // Only a continuously stable press is exposed to GPIO and the firmware.
    key[1] = 1'b1;
    cpu_cycles(8);
    if (dut.key_sync[1] !== 1'b1)
      $fatal(1, "stable press was not accepted");

    // Release bounce is filtered in the same way.
    key[1] = 1'b0;
    cpu_cycles(2);
    key[1] = 1'b1;
    cpu_cycles(2);
    key[1] = 1'b0;
    cpu_cycles(2);
    key[1] = 1'b1;
    cpu_cycles(2);
    if (dut.key_sync[1] !== 1'b1)
      $fatal(1, "release bounce was incorrectly accepted");

    key[1] = 1'b0;
    cpu_cycles(8);
    if (dut.key_sync[1] !== 1'b0)
      $fatal(1, "stable release was not accepted");

    // The SoC pulse starts a finite square-wave beep and returns low.
    force dut.buzzer_trigger = 1'b1;
    cpu_cycles(1);
    #1;
    force dut.buzzer_trigger = 1'b0;
    cpu_cycles(2);
    #1;
    if (buzzer !== 1'b0)
      $fatal(1, "buzzer did not toggle after trigger");
    cpu_cycles(2);
    #1;
    if (buzzer !== 1'b1)
      $fatal(1, "buzzer square wave has the wrong half-period");
    cpu_cycles(12);
    #1;
    if (buzzer !== 1'b0)
      $fatal(1, "buzzer did not stop low after the beep interval");
    release dut.buzzer_trigger;

    $display("PASS tb_ees338_key_debounce debounce and buzzer pulse");
    $finish;
  end
endmodule
