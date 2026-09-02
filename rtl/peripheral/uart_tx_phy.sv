module uart_tx_phy #(
  parameter integer CLOCK_HZ = 25_000_000,
  parameter integer BAUD_RATE = 115_200
) (
  input  logic       clk,
  input  logic       reset,
  input  logic       valid,
  input  logic [7:0] data,
  output logic       ready,
  output logic       txd,
  output logic       busy
);
  localparam integer CLKS_PER_BIT = (CLOCK_HZ + (BAUD_RATE / 2)) / BAUD_RATE;
  localparam integer COUNT_WIDTH = (CLKS_PER_BIT <= 2) ? 1 : $clog2(CLKS_PER_BIT);

  logic [9:0] frame;
  logic [3:0] bit_index;
  logic [COUNT_WIDTH-1:0] baud_count;

  assign ready = !busy && !valid;

  always_ff @(posedge clk) begin
    if (reset) begin
      frame <= 10'h3FF;
      bit_index <= 4'b0;
      baud_count <= '0;
      txd <= 1'b1;
      busy <= 1'b0;
    end else if (!busy) begin
      txd <= 1'b1;
      baud_count <= '0;
      bit_index <= 4'b0;
      if (valid) begin
        frame <= {1'b1, data, 1'b0};
        txd <= 1'b0;
        busy <= 1'b1;
      end
    end else if (baud_count == CLKS_PER_BIT - 1) begin
      baud_count <= '0;
      if (bit_index == 4'd9) begin
        txd <= 1'b1;
        busy <= 1'b0;
      end else begin
        bit_index <= bit_index + 1'b1;
        txd <= frame[bit_index + 1'b1];
      end
    end else begin
      baud_count <= baud_count + 1'b1;
    end
  end
endmodule
