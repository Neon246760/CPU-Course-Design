## EES-338 / XC7A35T-1CSG324C

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

## 100 MHz board clock and active-low reset
set_property -dict {PACKAGE_PIN T5 IOSTANDARD LVCMOS33} [get_ports sys_clk]
create_clock -period 10.000 -name sys_clk -waveform {0.000 5.000} [get_ports sys_clk]
set_property -dict {PACKAGE_PIN P15 IOSTANDARD LVCMOS33} [get_ports reset_n]

## Switches SW0..SW7
set_property -dict {PACKAGE_PIN R1 IOSTANDARD LVCMOS33} [get_ports {sw[0]}]
set_property -dict {PACKAGE_PIN N4 IOSTANDARD LVCMOS33} [get_ports {sw[1]}]
set_property -dict {PACKAGE_PIN M4 IOSTANDARD LVCMOS33} [get_ports {sw[2]}]
set_property -dict {PACKAGE_PIN R2 IOSTANDARD LVCMOS33} [get_ports {sw[3]}]
set_property -dict {PACKAGE_PIN P2 IOSTANDARD LVCMOS33} [get_ports {sw[4]}]
set_property -dict {PACKAGE_PIN P3 IOSTANDARD LVCMOS33} [get_ports {sw[5]}]
set_property -dict {PACKAGE_PIN P4 IOSTANDARD LVCMOS33} [get_ports {sw[6]}]
set_property -dict {PACKAGE_PIN P5 IOSTANDARD LVCMOS33} [get_ports {sw[7]}]

## Push buttons PB0..PB4; low when idle, high when pressed
set_property -dict {PACKAGE_PIN R11 IOSTANDARD LVCMOS33} [get_ports {key[0]}]
set_property -dict {PACKAGE_PIN R17 IOSTANDARD LVCMOS33} [get_ports {key[1]}]
set_property -dict {PACKAGE_PIN R15 IOSTANDARD LVCMOS33} [get_ports {key[2]}]
set_property -dict {PACKAGE_PIN V1 IOSTANDARD LVCMOS33} [get_ports {key[3]}]
set_property -dict {PACKAGE_PIN U4 IOSTANDARD LVCMOS33} [get_ports {key[4]}]

## LEDs; high lights the LED
set_property -dict {PACKAGE_PIN K2 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN J2 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN J3 IOSTANDARD LVCMOS33} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN H4 IOSTANDARD LVCMOS33} [get_ports {led[3]}]
set_property -dict {PACKAGE_PIN J4 IOSTANDARD LVCMOS33} [get_ports {led[4]}]
set_property -dict {PACKAGE_PIN G3 IOSTANDARD LVCMOS33} [get_ports {led[5]}]
set_property -dict {PACKAGE_PIN G4 IOSTANDARD LVCMOS33} [get_ports {led[6]}]
set_property -dict {PACKAGE_PIN F6 IOSTANDARD LVCMOS33} [get_ports {led[7]}]

## On-board buzzer; high drives the N-channel MOSFET gate
set_property -dict {PACKAGE_PIN G13 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW} [get_ports buzzer]

## CP2102 USB-UART (FPGA TX goes to CP2102 RX)
set_property -dict {PACKAGE_PIN T4 IOSTANDARD LVCMOS33} [get_ports uart_txd]
set_property -dict {PACKAGE_PIN N5 IOSTANDARD LVCMOS33} [get_ports uart_rxd]

## On-board ST7571 LCD; parallel pins are reused for four-wire SPI
set_property -dict {PACKAGE_PIN V9 IOSTANDARD LVCMOS33} [get_ports lcd_wr]
set_property -dict {PACKAGE_PIN U7 IOSTANDARD LVCMOS33} [get_ports lcd_rd]
set_property -dict {PACKAGE_PIN T1 IOSTANDARD LVCMOS33} [get_ports {lcd_d[0]}]
set_property -dict {PACKAGE_PIN M6 IOSTANDARD LVCMOS33} [get_ports {lcd_d[1]}]
set_property -dict {PACKAGE_PIN N6 IOSTANDARD LVCMOS33} [get_ports {lcd_d[2]}]
set_property -dict {PACKAGE_PIN R6 IOSTANDARD LVCMOS33} [get_ports {lcd_d[3]}]
set_property -dict {PACKAGE_PIN R5 IOSTANDARD LVCMOS33} [get_ports {lcd_d[4]}]
set_property -dict {PACKAGE_PIN V7 IOSTANDARD LVCMOS33} [get_ports {lcd_d[5]}]
set_property -dict {PACKAGE_PIN V6 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW} [get_ports {lcd_d[6]}]
set_property -dict {PACKAGE_PIN U9 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW} [get_ports {lcd_d[7]}]
set_property -dict {PACKAGE_PIN U6 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW} [get_ports lcd_cs_n]
set_property -dict {PACKAGE_PIN R7 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW} [get_ports lcd_rst_n]
set_property -dict {PACKAGE_PIN T6 IOSTANDARD LVCMOS33 DRIVE 8 SLEW SLOW} [get_ports lcd_rs]

## Only the asynchronous board inputs need explicit timing exceptions.
set_false_path -from [get_ports {reset_n sw[*] key[*] uart_rxd}]
