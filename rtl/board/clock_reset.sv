module clock_reset (
  input  logic sys_clk,
  input  logic reset_n,
  output logic cpu_clk,
  output logic cpu_reset,
  output logic locked
);
  logic clkfb_raw;
  logic clkfb;
  logic cpu_clk_raw;
  logic mmcm_locked;
  logic [1:0] reset_pipe;
  logic reset_request_n;
  logic cpu_reset_sync = 1'b1;

  MMCME2_BASE #(
    .BANDWIDTH("OPTIMIZED"),
    .CLKIN1_PERIOD(10.000),
    .DIVCLK_DIVIDE(1),
    .CLKFBOUT_MULT_F(10.000),
    .CLKOUT0_DIVIDE_F(40.000),
    .STARTUP_WAIT("FALSE")
  ) u_mmcm (
    .CLKIN1(sys_clk),
    .CLKFBIN(clkfb),
    .RST(1'b0),
    .PWRDWN(1'b0),
    .CLKFBOUT(clkfb_raw),
    .CLKOUT0(cpu_clk_raw),
    .LOCKED(mmcm_locked)
  );

  BUFG u_clkfb_bufg (
    .I(clkfb_raw),
    .O(clkfb)
  );

  BUFG u_cpu_clk_bufg (
    .I(cpu_clk_raw),
    .O(cpu_clk)
  );

  assign locked = mmcm_locked;
  assign reset_request_n = reset_n && mmcm_locked;

  always_ff @(posedge cpu_clk or negedge reset_request_n) begin
    if (!reset_request_n)
      reset_pipe <= 2'b11;
    else
      reset_pipe <= {reset_pipe[0], 1'b0};
  end

  // Keep the reset seen by the CPU/BRAM fully synchronous.  The first stage
  // still asserts asynchronously, while this final initialized register
  // prevents an async-reset flop from directly driving RAM control pins.
  always_ff @(posedge cpu_clk) begin
    cpu_reset_sync <= reset_pipe[1];
  end

  assign cpu_reset = cpu_reset_sync;
endmodule
