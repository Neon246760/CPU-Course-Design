module lcd_controller #(
  parameter integer RESET_LOW_CYCLES = 25_000,
  parameter integer POWER_WAIT_CYCLES = 3_000_000,
  parameter integer DELAY_200MS_CYCLES = 5_000_000,
  parameter integer DELAY_10MS_CYCLES = 250_000,
  parameter integer SPI_HALF_PERIOD_CYCLES = 6,
  parameter integer CLEAR_PAGES = 16,
  parameter integer CLEAR_BYTES_PER_PAGE = 256
) (
  input  logic       clk,
  input  logic       reset,
  input  logic       tx_valid,
  input  logic       tx_rs,
  input  logic [7:0] tx_data,
  input  logic       reinit_req,
  input  logic       clear_req,
  output logic       tx_ready,
  output logic       initialized,
  output logic       lcd_cs_n,
  output logic       lcd_rst_n,
  output logic       lcd_sck,
  output logic       lcd_mosi,
  output logic       lcd_rs
);
  typedef enum logic [3:0] {
    RESET_LOW,
    POWER_WAIT,
    INIT_SEND,
    TRANSFER_WAIT_BUSY,
    TRANSFER_WAIT_DONE,
    INIT_DELAY,
    CLEAR_SEND,
    IDLE
  } state_t;

  typedef enum logic [1:0] {
    AFTER_INIT,
    AFTER_CLEAR,
    AFTER_USER
  } continuation_t;

  state_t state;
  continuation_t continuation;
  logic spi_start;
  logic spi_ready;
  logic spi_rs;
  logic [7:0] spi_data;
  logic [5:0] init_index;
  logic [4:0] clear_page;
  logic [8:0] clear_byte;
  logic [1:0] clear_phase;
  logic [31:0] delay_count;

  function automatic logic [7:0] init_byte(input logic [5:0] index);
    case (index)
      6'd0:  init_byte = 8'h2C;
      6'd1:  init_byte = 8'h2E;
      6'd2:  init_byte = 8'h2F;
      6'd3:  init_byte = 8'hAE;
      6'd4:  init_byte = 8'h38;
      6'd5:  init_byte = 8'hB8;
      6'd6:  init_byte = 8'hC8;
      6'd7:  init_byte = 8'hA0;
      6'd8:  init_byte = 8'h44;
      6'd9:  init_byte = 8'h00;
      6'd10: init_byte = 8'h40;
      6'd11: init_byte = 8'h00;
      6'd12: init_byte = 8'hAB;
      6'd13: init_byte = 8'h67;
      6'd14: init_byte = 8'h26;
      6'd15: init_byte = 8'h81;
      6'd16: init_byte = 8'h36;
      6'd17: init_byte = 8'h54;
      6'd18: init_byte = 8'hF3;
      6'd19: init_byte = 8'h04;
      6'd20: init_byte = 8'h93;
      default: init_byte = 8'hAF;
    endcase
  endfunction

  lcd_spi_master #(
    .HALF_PERIOD_CYCLES(SPI_HALF_PERIOD_CYCLES)
  ) u_spi (
    .clk(clk),
    .reset(reset),
    .start(spi_start),
    .rs_in(spi_rs),
    .data_in(spi_data),
    .ready(spi_ready),
    .cs_n(lcd_cs_n),
    .sck(lcd_sck),
    .mosi(lcd_mosi),
    .rs_out(lcd_rs)
  );

  assign tx_ready = (state == IDLE) && spi_ready &&
                    !tx_valid && !clear_req && !reinit_req;

  always_ff @(posedge clk) begin
    if (reset) begin
      state <= RESET_LOW;
      continuation <= AFTER_INIT;
      spi_start <= 1'b0;
      spi_rs <= 1'b0;
      spi_data <= 8'b0;
      init_index <= 6'b0;
      clear_page <= 5'b0;
      clear_byte <= 9'b0;
      clear_phase <= 2'b0;
      delay_count <= 32'b0;
      initialized <= 1'b0;
      lcd_rst_n <= 1'b0;
    end else begin
      spi_start <= 1'b0;

      if (reinit_req) begin
        state <= RESET_LOW;
        init_index <= 6'b0;
        delay_count <= 32'b0;
        initialized <= 1'b0;
        lcd_rst_n <= 1'b0;
      end else begin
        case (state)
          RESET_LOW: begin
            lcd_rst_n <= 1'b0;
            initialized <= 1'b0;
            if (delay_count + 1 >= RESET_LOW_CYCLES) begin
              delay_count <= 32'b0;
              lcd_rst_n <= 1'b1;
              state <= POWER_WAIT;
            end else begin
              delay_count <= delay_count + 1'b1;
            end
          end

          POWER_WAIT: begin
            lcd_rst_n <= 1'b1;
            if (delay_count + 1 >= POWER_WAIT_CYCLES) begin
              delay_count <= 32'b0;
              init_index <= 6'b0;
              state <= INIT_SEND;
            end else begin
              delay_count <= delay_count + 1'b1;
            end
          end

          INIT_SEND: begin
            if (spi_ready) begin
              spi_rs <= 1'b0;
              spi_data <= init_byte(init_index);
              spi_start <= 1'b1;
              continuation <= AFTER_INIT;
              state <= TRANSFER_WAIT_BUSY;
            end
          end

          CLEAR_SEND: begin
            if (spi_ready) begin
              spi_rs <= (clear_phase == 2'd3);
              case (clear_phase)
                2'd0: spi_data <= 8'hB0 + clear_page[3:0];
                2'd1: spi_data <= 8'h10;
                2'd2: spi_data <= 8'h00;
                default: spi_data <= 8'h00;
              endcase
              spi_start <= 1'b1;
              continuation <= AFTER_CLEAR;
              state <= TRANSFER_WAIT_BUSY;
            end
          end

          TRANSFER_WAIT_BUSY: begin
            if (!spi_ready)
              state <= TRANSFER_WAIT_DONE;
          end

          TRANSFER_WAIT_DONE: begin
            if (spi_ready) begin
              case (continuation)
                AFTER_INIT: begin
                  if (init_index == 6'd0 || init_index == 6'd1) begin
                    delay_count <= 32'b0;
                    state <= INIT_DELAY;
                  end else if (init_index == 6'd2) begin
                    delay_count <= 32'b0;
                    state <= INIT_DELAY;
                  end else if (init_index == 6'd21) begin
                    clear_page <= 5'b0;
                    clear_byte <= 9'b0;
                    clear_phase <= 2'b0;
                    state <= CLEAR_SEND;
                  end else begin
                    init_index <= init_index + 1'b1;
                    state <= INIT_SEND;
                  end
                end

                AFTER_CLEAR: begin
                  if (clear_phase != 2'd3) begin
                    clear_phase <= clear_phase + 1'b1;
                    state <= CLEAR_SEND;
                  end else if (clear_byte + 1 >= CLEAR_BYTES_PER_PAGE) begin
                    clear_byte <= 9'b0;
                    clear_phase <= 2'b0;
                    if (clear_page + 1 >= CLEAR_PAGES) begin
                      initialized <= 1'b1;
                      state <= IDLE;
                    end else begin
                      clear_page <= clear_page + 1'b1;
                      state <= CLEAR_SEND;
                    end
                  end else begin
                    clear_byte <= clear_byte + 1'b1;
                    state <= CLEAR_SEND;
                  end
                end

                default: state <= IDLE;
              endcase
            end
          end

          INIT_DELAY: begin
            if (((init_index == 6'd0 || init_index == 6'd1) &&
                 (delay_count + 1 >= DELAY_200MS_CYCLES)) ||
                ((init_index == 6'd2) &&
                 (delay_count + 1 >= DELAY_10MS_CYCLES))) begin
              delay_count <= 32'b0;
              init_index <= init_index + 1'b1;
              state <= INIT_SEND;
            end else begin
              delay_count <= delay_count + 1'b1;
            end
          end

          default: begin
            if (clear_req) begin
              initialized <= 1'b0;
              clear_page <= 5'b0;
              clear_byte <= 9'b0;
              clear_phase <= 2'b0;
              state <= CLEAR_SEND;
            end else if (tx_valid && spi_ready) begin
              spi_rs <= tx_rs;
              spi_data <= tx_data;
              spi_start <= 1'b1;
              continuation <= AFTER_USER;
              state <= TRANSFER_WAIT_BUSY;
            end
          end
        endcase
      end
    end
  end
endmodule
