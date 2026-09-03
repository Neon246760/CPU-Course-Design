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
  input  logic       demo_req,
  input  logic       game_row_write,
  input  logic [4:0] game_row_index,
  input  logic [9:0] game_row_data,
  input  logic       game_refresh_req,
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
    DEMO_SEND,
    GAME_SEND,
    IDLE
  } state_t;

  typedef enum logic [2:0] {
    AFTER_INIT,
    AFTER_CLEAR,
    AFTER_USER,
    AFTER_DEMO,
    AFTER_GAME
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
  logic [1:0] demo_phase;
  logic [3:0] demo_char;
  logic [2:0] demo_column;
  logic       demo_plane;
  logic [9:0] game_rows [0:19];
  logic [3:0] game_page;
  logic [3:0] game_cell;
  logic [3:0] game_pixel_column;
  logic       game_plane;
  logic [1:0] game_phase;
  logic [7:0] game_column_data;
  integer game_i;

  // 5x7 vertical-column glyphs for "WJL ZXH QBA". Each column is sent
  // twice because the ST7571 4-gray page format stores two bit planes.
  function automatic logic [7:0] demo_glyph_column(
    input logic [3:0] char_index,
    input logic [2:0] column
  );
    begin
      demo_glyph_column = 8'h00;
      if (column < 5) begin
        case (char_index)
          4'd0: case (column) // W
            0: demo_glyph_column = 8'h7F; 1: demo_glyph_column = 8'h40;
            2: demo_glyph_column = 8'h38; 3: demo_glyph_column = 8'h40;
            4: demo_glyph_column = 8'h7F;
          endcase
          4'd1: case (column) // J
            0: demo_glyph_column = 8'h20; 1: demo_glyph_column = 8'h40;
            2: demo_glyph_column = 8'h40; 3: demo_glyph_column = 8'h3F;
            4: demo_glyph_column = 8'h01;
          endcase
          4'd2: case (column) // L
            0: demo_glyph_column = 8'h7F; 1: demo_glyph_column = 8'h01;
            2: demo_glyph_column = 8'h01; 3: demo_glyph_column = 8'h01;
            4: demo_glyph_column = 8'h01;
          endcase
          4'd4: case (column) // Z
            0: demo_glyph_column = 8'h61; 1: demo_glyph_column = 8'h51;
            2: demo_glyph_column = 8'h49; 3: demo_glyph_column = 8'h45;
            4: demo_glyph_column = 8'h43;
          endcase
          4'd5: case (column) // X
            0: demo_glyph_column = 8'h63; 1: demo_glyph_column = 8'h14;
            2: demo_glyph_column = 8'h08; 3: demo_glyph_column = 8'h14;
            4: demo_glyph_column = 8'h63;
          endcase
          4'd6: case (column) // H
            0: demo_glyph_column = 8'h7F; 1: demo_glyph_column = 8'h08;
            2: demo_glyph_column = 8'h08; 3: demo_glyph_column = 8'h08;
            4: demo_glyph_column = 8'h7F;
          endcase
          4'd8: case (column) // Q
            0: demo_glyph_column = 8'h3E; 1: demo_glyph_column = 8'h41;
            2: demo_glyph_column = 8'h51; 3: demo_glyph_column = 8'h21;
            4: demo_glyph_column = 8'h5E;
          endcase
          4'd9: case (column) // B
            0: demo_glyph_column = 8'h7F; 1: demo_glyph_column = 8'h49;
            2: demo_glyph_column = 8'h49; 3: demo_glyph_column = 8'h49;
            4: demo_glyph_column = 8'h36;
          endcase
          4'd10: case (column) // A
            0: demo_glyph_column = 8'h3F; 1: demo_glyph_column = 8'h48;
            2: demo_glyph_column = 8'h48; 3: demo_glyph_column = 8'h48;
            4: demo_glyph_column = 8'h3F;
          endcase
          default: demo_glyph_column = 8'h00; // spaces at 3 and 7
        endcase
      end
    end
  endfunction

  // Two board rows share one 8-pixel LCD page. A cell is 10x4 pixels;
  // columns 0 and 9 stay clear to form a visible grid between blocks.
  always_comb begin
    game_column_data = 8'h00;
    if ((game_pixel_column != 0) && (game_pixel_column != 9)) begin
      if (game_rows[{game_page, 1'b0}][game_cell])
        game_column_data[3:0] = 4'hF;
      if (game_rows[{game_page, 1'b0} + 1'b1][game_cell])
        game_column_data[7:4] = 4'hF;
    end
  end

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
                    !tx_valid && !clear_req && !demo_req &&
                    !game_refresh_req && !reinit_req;

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
      demo_phase <= 2'b0;
      demo_char <= 4'b0;
      demo_column <= 3'b0;
      demo_plane <= 1'b0;
      game_page <= 4'b0;
      game_cell <= 4'b0;
      game_pixel_column <= 4'b0;
      game_plane <= 1'b0;
      game_phase <= 2'b0;
      for (game_i = 0; game_i < 20; game_i = game_i + 1)
        game_rows[game_i] <= 10'b0;
      initialized <= 1'b0;
      lcd_rst_n <= 1'b0;
    end else begin
      spi_start <= 1'b0;
      if (game_row_write && (game_row_index < 20))
        game_rows[game_row_index] <= game_row_data;

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

          DEMO_SEND: begin
            if (spi_ready) begin
              spi_rs <= (demo_phase == 2'd3);
              case (demo_phase)
                2'd0: spi_data <= 8'hB6; // vertically centered page
                2'd1: spi_data <= 8'h11; // column 31 high nibble
                2'd2: spi_data <= 8'h0F; // column 31 low nibble
                default: spi_data <= demo_glyph_column(demo_char,
                                                        demo_column);
              endcase
              spi_start <= 1'b1;
              continuation <= AFTER_DEMO;
              state <= TRANSFER_WAIT_BUSY;
            end
          end

          GAME_SEND: begin
            if (spi_ready) begin
              spi_rs <= (game_phase == 2'd3);
              case (game_phase)
                2'd0: spi_data <= 8'hB3 + game_page;
                2'd1: spi_data <= 8'h10;
                2'd2: spi_data <= 8'h0E;
                default: spi_data <= game_column_data;
              endcase
              spi_start <= 1'b1;
              continuation <= AFTER_GAME;
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

                AFTER_DEMO: begin
                  if (demo_phase != 2'd3) begin
                    demo_phase <= demo_phase + 1'b1;
                    state <= DEMO_SEND;
                  end else if (!demo_plane) begin
                    demo_plane <= 1'b1;
                    state <= DEMO_SEND;
                  end else begin
                    demo_plane <= 1'b0;
                    if (demo_column == 3'd5) begin
                      demo_column <= 3'b0;
                      if (demo_char == 4'd10) begin
                        state <= IDLE;
                      end else begin
                        demo_char <= demo_char + 1'b1;
                        state <= DEMO_SEND;
                      end
                    end else begin
                      demo_column <= demo_column + 1'b1;
                      state <= DEMO_SEND;
                    end
                  end
                end

                AFTER_GAME: begin
                  if (game_phase != 2'd3) begin
                    game_phase <= game_phase + 1'b1;
                    state <= GAME_SEND;
                  end else if (!game_plane) begin
                    game_plane <= 1'b1;
                    state <= GAME_SEND;
                  end else begin
                    game_plane <= 1'b0;
                    if (game_pixel_column == 4'd9) begin
                      game_pixel_column <= 4'b0;
                      if (game_cell == 4'd9) begin
                        game_cell <= 4'b0;
                        game_phase <= 2'b0;
                        if (game_page == 4'd9) begin
                          state <= IDLE;
                        end else begin
                          game_page <= game_page + 1'b1;
                          state <= GAME_SEND;
                        end
                      end else begin
                        game_cell <= game_cell + 1'b1;
                        state <= GAME_SEND;
                      end
                    end else begin
                      game_pixel_column <= game_pixel_column + 1'b1;
                      state <= GAME_SEND;
                    end
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
            end else if (demo_req) begin
              demo_phase <= 2'b0;
              demo_char <= 4'b0;
              demo_column <= 3'b0;
              demo_plane <= 1'b0;
              state <= DEMO_SEND;
            end else if (game_refresh_req) begin
              game_page <= 4'b0;
              game_cell <= 4'b0;
              game_pixel_column <= 4'b0;
              game_plane <= 1'b0;
              game_phase <= 2'b0;
              state <= GAME_SEND;
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
