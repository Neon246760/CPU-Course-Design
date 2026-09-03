module address_decoder (
  input  logic [31:0] addr,
  output logic        select_dmem,
  output logic        select_gpio_out,
  output logic        select_gpio_in,
  output logic        select_uart_tx,
  output logic        select_uart_status,
  output logic        select_lcd_cmd,
  output logic        select_lcd_data,
  output logic        select_lcd_status,
  output logic        select_lcd_control,
  output logic        select_lcd_game_row,
  output logic        select_lcd_game_refresh,
  output logic        select_buzzer,
  output logic        select_tohost,
  output logic        select_reserved
);
  always_comb begin
    select_dmem = (addr >= 32'h1000_0000) && (addr <= 32'h1000_FFFF);
    select_gpio_out = (addr == 32'h2000_0000);
    select_gpio_in = (addr == 32'h2000_0004);
    select_uart_tx = (addr == 32'h2000_0010);
    select_uart_status = (addr == 32'h2000_0014);
    select_lcd_cmd = (addr == 32'h2000_0020);
    select_lcd_data = (addr == 32'h2000_0024);
    select_lcd_status = (addr == 32'h2000_0028);
    select_lcd_control = (addr == 32'h2000_002C);
    select_lcd_game_row = (addr == 32'h2000_0030);
    select_lcd_game_refresh = (addr == 32'h2000_0034);
    select_buzzer = (addr == 32'h2000_0038);
    select_tohost = (addr == 32'hFFFF_FFF0);
    select_reserved = !(select_dmem || select_gpio_out || select_gpio_in ||
                        select_uart_tx || select_uart_status ||
                        select_lcd_cmd || select_lcd_data ||
                        select_lcd_status || select_lcd_control ||
                        select_lcd_game_row || select_lcd_game_refresh ||
                        select_buzzer || select_tohost);
  end
endmodule
