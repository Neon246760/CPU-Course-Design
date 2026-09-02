module lcd_spi_master #(
  parameter integer HALF_PERIOD_CYCLES = 6
) (
  input  logic       clk,
  input  logic       reset,
  input  logic       start,
  input  logic       rs_in,
  input  logic [7:0] data_in,
  output logic       ready,
  output logic       cs_n,
  output logic       sck,
  output logic       mosi,
  output logic       rs_out
);
  localparam integer DIV_WIDTH = (HALF_PERIOD_CYCLES <= 2) ?
                                 1 : $clog2(HALF_PERIOD_CYCLES);

  logic busy;
  logic [7:0] shift_reg;
  logic [2:0] bit_index;
  logic [DIV_WIDTH-1:0] divider;

  assign ready = !busy;

  always_ff @(posedge clk) begin
    if (reset) begin
      busy <= 1'b0;
      shift_reg <= 8'b0;
      bit_index <= 3'b0;
      divider <= '0;
      cs_n <= 1'b1;
      sck <= 1'b0;
      mosi <= 1'b0;
      rs_out <= 1'b0;
    end else if (!busy) begin
      cs_n <= 1'b1;
      sck <= 1'b0;
      divider <= '0;
      if (start) begin
        busy <= 1'b1;
        shift_reg <= data_in;
        bit_index <= 3'd7;
        cs_n <= 1'b0;
        mosi <= data_in[7];
        rs_out <= rs_in;
      end
    end else if (divider == HALF_PERIOD_CYCLES - 1) begin
      divider <= '0;
      if (!sck) begin
        sck <= 1'b1;
      end else begin
        sck <= 1'b0;
        if (bit_index == 3'd0) begin
          busy <= 1'b0;
          cs_n <= 1'b1;
        end else begin
          bit_index <= bit_index - 1'b1;
          shift_reg <= {shift_reg[6:0], 1'b0};
          mosi <= shift_reg[6];
        end
      end
    end else begin
      divider <= divider + 1'b1;
    end
  end
endmodule
