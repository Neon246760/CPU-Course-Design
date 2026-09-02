$vivado = 'D:\Applications\Xilinx\Vivado\2019.2\bin\vivado.bat'
$tests = @(
  @('tb_alu_overflow', 'sim/unit/tb_alu_overflow.sv'),
  @('tb_branch_predictor', 'sim/unit/tb_branch_predictor.sv'),
  @('tb_decode_microcode', 'sim/unit/tb_decode_microcode.sv'),
  @('tb_cache', 'sim/unit/tb_cache.sv'),
  @('tb_uart_tx_phy', 'sim/unit/tb_uart_tx_phy.sv'),
  @('tb_lcd_spi_master', 'sim/unit/tb_lcd_spi_master.sv'),
  @('tb_lcd_controller', 'sim/unit/tb_lcd_controller.sv'),
  @('tb_cpu_core', 'sim/system/tb_cpu_core.sv'),
  @('tb_extended_system', 'sim/system/tb_extended_system.sv'),
  @('tb_bringup_system', 'sim/system/tb_bringup_system.sv')
)

foreach ($test in $tests) {
  & $vivado -mode batch -source sim/run_test.tcl -tclargs $test[0] $test[1]
  if ($LASTEXITCODE -ne 0) {
    throw "Vivado test failed: $($test[0])"
  }
}
