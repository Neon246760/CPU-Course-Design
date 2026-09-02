set script_dir [file dirname [file normalize [info script]]]
set root_dir [file normalize [file join $script_dir ..]]
set build_dir [file join $root_dir build vivado_sim]

create_project -force cpu_core_sim $build_dir -part xc7a35tcsg324-1
set_property target_language Verilog [current_project]
set_property source_mgmt_mode None [current_project]

set rtl_sources [list [file join $root_dir rtl decode control_word_pkg.sv]]
foreach source_file [glob [file join $root_dir rtl decode *.sv]] {
  if {[file tail $source_file] ne "control_word_pkg.sv"} {
    lappend rtl_sources $source_file
  }
}
foreach source_dir {execute regfile memory cache predictor exception core peripheral soc board} {
  foreach source_file [glob [file join $root_dir rtl $source_dir *.sv]] {
    lappend rtl_sources $source_file
  }
}
add_files -norecurse $rtl_sources
add_files -norecurse [file join $root_dir firmware bringup.mem]
set_property file_type SystemVerilog [get_files -of_objects [get_filesets sources_1] *.sv]

set tb_source [file join $root_dir sim system tb_extended_system.sv]
add_files -fileset sim_1 -norecurse $tb_source
set_property file_type SystemVerilog [get_files -of_objects [get_filesets sim_1] *.sv]

set_property top tb_extended_system [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
set_property xsim.simulate.runtime all [get_filesets sim_1]
launch_simulation
