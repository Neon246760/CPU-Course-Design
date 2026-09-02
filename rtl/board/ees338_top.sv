module ees338_top #(
  parameter IMEM_INIT_FILE = "bringup.mem",
  parameter logic ENABLE_ICACHE = 1'b0,
  parameter logic ENABLE_DCACHE = 1'b0,
  parameter logic ENABLE_BRANCH_PREDICTION = 1'b0
) (
  input  logic       sys_clk,
  input  logic       reset_n,
  input  logic [7:0] sw,
  input  logic [4:0] key,
  output logic [7:0] led,
  input  logic       uart_rxd,
  output logic       uart_txd,
  output logic       lcd_wr,
  output logic       lcd_rd,
  output logic [7:0] lcd_d,
  output logic       lcd_cs_n,
  output logic       lcd_rst_n,
  output logic       lcd_rs
);
  logic cpu_clk;
  logic cpu_reset;
  logic clk_locked;
  logic [7:0] sw_meta;
  logic [7:0] sw_sync;
  logic [4:0] key_meta;
  logic [4:0] key_sync;
  logic [31:0] gpio_in;
  logic [31:0] gpio_out;
  logic uart_tx_valid;
  logic [7:0] uart_tx_data;
  logic uart_tx_ready;
  logic uart_busy;
  logic lcd_tx_valid;
  logic lcd_tx_rs;
  logic [7:0] lcd_tx_data;
  logic lcd_tx_ready;
  logic lcd_initialized;
  logic lcd_reinit;
  logic lcd_clear;
  logic lcd_sck;
  logic lcd_mosi;
  logic tohost_valid;
  logic [31:0] tohost_data;
  logic [31:0] tohost_latched;
  logic [24:0] heartbeat_count;
  logic uart_rxd_meta;
  logic uart_rxd_sync;

  clock_reset u_clock_reset (
    .sys_clk(sys_clk),
    .reset_n(reset_n),
    .cpu_clk(cpu_clk),
    .cpu_reset(cpu_reset),
    .locked(clk_locked)
  );

  always_ff @(posedge cpu_clk) begin
    if (cpu_reset) begin
      sw_meta <= 8'b0;
      sw_sync <= 8'b0;
      key_meta <= 5'b0;
      key_sync <= 5'b0;
      uart_rxd_meta <= 1'b1;
      uart_rxd_sync <= 1'b1;
      heartbeat_count <= 25'b0;
      tohost_latched <= 32'b0;
    end else begin
      sw_meta <= sw;
      sw_sync <= sw_meta;
      key_meta <= key;
      key_sync <= key_meta;
      uart_rxd_meta <= uart_rxd;
      uart_rxd_sync <= uart_rxd_meta;
      heartbeat_count <= heartbeat_count + 1'b1;
      if (tohost_valid)
        tohost_latched <= tohost_data;
    end
  end

  assign gpio_in = {19'b0, key_sync, sw_sync};

  uart_tx_phy #(
    .CLOCK_HZ(25_000_000),
    .BAUD_RATE(115_200)
  ) u_uart_tx (
    .clk(cpu_clk),
    .reset(cpu_reset),
    .valid(uart_tx_valid),
    .data(uart_tx_data),
    .ready(uart_tx_ready),
    .txd(uart_txd),
    .busy(uart_busy)
  );

  lcd_controller u_lcd_controller (
    .clk(cpu_clk),
    .reset(cpu_reset),
    .tx_valid(lcd_tx_valid),
    .tx_rs(lcd_tx_rs),
    .tx_data(lcd_tx_data),
    .reinit_req(lcd_reinit),
    .clear_req(lcd_clear),
    .tx_ready(lcd_tx_ready),
    .initialized(lcd_initialized),
    .lcd_cs_n(lcd_cs_n),
    .lcd_rst_n(lcd_rst_n),
    .lcd_sck(lcd_sck),
    .lcd_mosi(lcd_mosi),
    .lcd_rs(lcd_rs)
  );

  assign lcd_wr = 1'b1;
  assign lcd_rd = 1'b1;
  assign lcd_d[5:0] = 6'h3F;
  assign lcd_d[6] = lcd_sck;
  assign lcd_d[7] = lcd_mosi;

  soc_top #(
    .IMEM_WORDS(2048),
    .DMEM_WORDS(2048),
    .IMEM_INIT_FILE(IMEM_INIT_FILE),
    .ENABLE_ICACHE(ENABLE_ICACHE),
    .ENABLE_DCACHE(ENABLE_DCACHE),
    .ENABLE_BRANCH_PREDICTION(ENABLE_BRANCH_PREDICTION)
  ) u_soc (
    .clk(cpu_clk),
    .reset(cpu_reset),
    .ext_irq(key_sync[0]),
    .gpio_in(gpio_in),
    .uart_tx_ready(uart_tx_ready),
    .lcd_tx_ready(lcd_tx_ready),
    .lcd_initialized(lcd_initialized),
    .gpio_out(gpio_out),
    .uart_tx_valid(uart_tx_valid),
    .uart_tx_data(uart_tx_data),
    .lcd_tx_valid(lcd_tx_valid),
    .lcd_tx_rs(lcd_tx_rs),
    .lcd_tx_data(lcd_tx_data),
    .lcd_reinit(lcd_reinit),
    .lcd_clear(lcd_clear),
    .tohost_valid(tohost_valid),
    .tohost_data(tohost_data)
  );

  always_comb begin
    if (sw_sync[7]) begin
      led = {
        (tohost_latched == 32'd1),
        ((tohost_latched != 32'd0) && (tohost_latched != 32'd1)),
        lcd_initialized,
        uart_busy,
        cpu_reset,
        clk_locked,
        key_sync[0],
        heartbeat_count[24]
      };
    end else begin
      led = gpio_out[7:0];
    end
  end
endmodule
