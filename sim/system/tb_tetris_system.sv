`timescale 1ns/1ps

module tb_tetris_system;
  logic clk;
  logic reset;
  logic [31:0] gpio_in;
  logic lcd_game_row_write;
  logic [4:0] lcd_game_row_index;
  logic [9:0] lcd_game_row_data;
  logic lcd_game_refresh;
  logic buzzer_trigger;
  logic [31:0] exception_count;
  integer cycles;
  integer row_writes;
  integer stage;
  integer quiet_cycles;
  integer buzzer_triggers;
  logic [9:0] expected_row;
  logic saw_new_piece;
  logic saw_locked_piece;

  soc_top #(
    .IMEM_WORDS(2048),
    .DMEM_WORDS(2048),
    .IMEM_INIT_FILE("tetris.mem"),
    .ENABLE_ICACHE(1'b0),
    .ENABLE_DCACHE(1'b0),
    .ENABLE_BRANCH_PREDICTION(1'b0)
  ) dut (
    .clk(clk),
    .reset(reset),
    .ext_irq(1'b0),
    .gpio_in(gpio_in),
    .uart_tx_ready(1'b1),
    .lcd_tx_ready(1'b1),
    .lcd_initialized(1'b1),
    .lcd_game_row_write(lcd_game_row_write),
    .lcd_game_row_index(lcd_game_row_index),
    .lcd_game_row_data(lcd_game_row_data),
    .lcd_game_refresh(lcd_game_refresh),
    .buzzer_trigger(buzzer_trigger),
    .exception_count(exception_count)
  );

  always #5 clk = ~clk;

  initial begin
    clk = 1'b0;
    reset = 1'b1;
    gpio_in = 32'h0000_0001; // SW0 starts the game.
    cycles = 0;
    row_writes = 0;
    stage = 0;
    quiet_cycles = 0;
    buzzer_triggers = 0;
    saw_new_piece = 1'b0;
    saw_locked_piece = 1'b0;
    repeat (4) @(posedge clk);
    reset <= 1'b0;
  end

  always @(posedge clk) begin
    if (!reset) begin
      cycles <= cycles + 1;
      if (buzzer_trigger)
        buzzer_triggers <= buzzer_triggers + 1;
      if (lcd_game_row_write) begin
        if (lcd_game_row_index !== row_writes[4:0])
          $fatal(1, "Tetris row order expected=%0d actual=%0d",
                 row_writes, lcd_game_row_index);

        if (stage <= 4) begin
          expected_row = 10'b0;
          if ((stage == 0) && (lcd_game_row_index == 5'd1))
            expected_row = 10'h078; // Initial horizontal I at x=3.
          if ((stage == 1) && (lcd_game_row_index == 5'd1))
            expected_row = 10'h03C; // PB1 moved it one cell left.
          if ((stage == 2) && (lcd_game_row_index == 5'd1))
            expected_row = 10'h078; // D-pad right returned it to x=3.
          if ((stage == 3) && (lcd_game_row_index < 5'd4))
            expected_row = 10'h010; // D-pad up rotated it vertically.
          if ((stage == 4) && (lcd_game_row_index >= 5'd1) &&
              (lcd_game_row_index <= 5'd4))
            expected_row = 10'h010; // D-pad down moved it one row.
          if ((stage == 4) && (lcd_game_row_index == 5'd19))
            expected_row = 10'h3EF; // Bottom row awaits the vertical I cell.
          if (lcd_game_row_data !== expected_row)
            $fatal(1, "Tetris stage=%0d row=%0d expected=%h actual=%h",
                   stage, lcd_game_row_index, expected_row,
                   lcd_game_row_data);
        end else if (stage == 5) begin
          if ((lcd_game_row_index == 5'd0) &&
              (lcd_game_row_data == 10'h030))
            saw_new_piece <= 1'b1;
          if ((lcd_game_row_index == 5'd19) &&
              (lcd_game_row_data == 10'h010))
            saw_locked_piece <= 1'b1;
        end else begin
          $fatal(1, "Soft-drop leaked into the next piece");
        end
        row_writes <= row_writes + 1;
      end

      if (lcd_game_refresh) begin
        if (row_writes != 20)
          $fatal(1, "Tetris uploaded %0d rows before refresh", row_writes);
        if (exception_count != 0)
          $fatal(1, "Tetris raised %0d CPU exceptions", exception_count);
        row_writes <= 0;
        if (stage == 0) begin
          gpio_in[9] <= 1'b1;  // PB1: left
          stage <= 1;
        end else if (stage == 1) begin
          gpio_in[9] <= 1'b0;
          gpio_in[12] <= 1'b1; // PB4: physical D-pad right
          stage <= 2;
        end else if (stage == 2) begin
          gpio_in[12] <= 1'b0;
          gpio_in[11] <= 1'b1; // PB3: physical D-pad up / rotate
          stage <= 3;
        end else if (stage == 3) begin
          gpio_in[11] <= 1'b0;
          // Arrange a nearly full bottom row. The vertical I piece completes
          // it, exercising firmware -> MMIO -> buzzer trigger on line clear.
          dut.u_dmem.mem[19] <= 32'h0000_03EF;
          gpio_in[8] <= 1'b1;  // PB0: physical D-pad down
          stage <= 4;
        end else if (stage == 4) begin
          // Keep down held until the I piece locks. The O piece that follows
          // must remain at its spawn position until the key is released.
          stage <= 5;
        end else if (stage == 5) begin
          if (saw_new_piece && saw_locked_piece) begin
            stage <= 6;
            quiet_cycles <= 0;
          end else begin
            saw_new_piece <= 1'b0;
            saw_locked_piece <= 1'b0;
          end
        end
      end

      if (stage == 6) begin
        quiet_cycles <= quiet_cycles + 1;
        if (quiet_cycles == 10000) begin
          if (buzzer_triggers != 1)
            $fatal(1, "expected one line-clear beep, got %0d", buzzer_triggers);
          $display("PASS tb_tetris_system cycles=%0d directions/drop-release/line-clear-beep",
                   cycles);
          $finish;
        end
      end

      if (cycles > 200000)
        $fatal(1, "Tetris timeout stage=%0d rows=%0d exceptions=%0d",
               stage, row_writes, exception_count);
    end
  end
endmodule
