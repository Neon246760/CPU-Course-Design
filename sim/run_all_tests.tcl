set script_dir [file dirname [file normalize [info script]]]
set root_dir [file normalize [file join $script_dir ..]]
set part_name xc7a35tcsg324-1
set test_sources [list \
  [file join $root_dir sim unit tb_alu_overflow.sv] \
  [file join $root_dir sim unit tb_branch_predictor.sv] \
  [file join $root_dir sim unit tb_decode_microcode.sv] \
  [file join $root_dir sim unit tb_cache.sv] \
  [file join $root_dir sim unit tb_uart_tx_phy.sv] \
  [file join $root_dir sim unit tb_lcd_spi_master.sv] \
  [file join $root_dir sim unit tb_lcd_controller.sv] \
  [file join $root_dir sim unit tb_ees338_key_debounce.sv] \
  [file join $root_dir sim system tb_cpu_core.sv] \
  [file join $root_dir sim system tb_extended_system.sv] \
  [file join $root_dir sim system tb_bringup_system.sv] \
  [file join $root_dir sim system tb_tetris_system.sv]]

set rtl_sources [list [file join $root_dir rtl decode control_word_pkg.sv]]
foreach source_dir {decode execute regfile memory cache predictor exception core peripheral soc board} {
  foreach source_file [glob [file join $root_dir rtl $source_dir *.sv]] {
    if {[file tail $source_file] ne "control_word_pkg.sv"} {
      lappend rtl_sources $source_file
    }
  }
}

foreach tb_source $test_sources {
  set test_name [file rootname [file tail $tb_source]]
  set build_dir [file join $root_dir build $test_name]
  create_project -force $test_name $build_dir -part $part_name
  set_property target_language Verilog [current_project]
  set_property source_mgmt_mode None [current_project]
  add_files -norecurse $rtl_sources
  add_files -norecurse [file join $root_dir firmware bringup.mem]
  add_files -norecurse [file join $root_dir firmware tetris.mem]
  set_property file_type SystemVerilog [get_files -of_objects [get_filesets sources_1] *.sv]
  add_files -fileset sim_1 -norecurse $tb_source
  set_property file_type SystemVerilog [get_files -of_objects [get_filesets sim_1] *.sv]
  set_property top $test_name [get_filesets sim_1]
  set_property top_lib xil_defaultlib [get_filesets sim_1]
  set_property xsim.simulate.runtime all [get_filesets sim_1]
  launch_simulation
  close_sim
  close_project
}

puts "ALL TESTBENCHES COMPLETED"
