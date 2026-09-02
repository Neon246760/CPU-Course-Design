if {$argc != 2} {
  error "usage: vivado -mode batch -source sim/run_test.tcl -tclargs <top> <tb-file>"
}

set test_name [lindex $argv 0]
set tb_relative [lindex $argv 1]
set script_dir [file dirname [file normalize [info script]]]
set root_dir [file normalize [file join $script_dir ..]]
set build_dir [file join $root_dir build $test_name]
set tb_source [file join $root_dir $tb_relative]

set rtl_sources [list [file join $root_dir rtl decode control_word_pkg.sv]]
foreach source_dir {decode execute regfile memory cache predictor exception core peripheral soc board} {
  foreach source_file [glob [file join $root_dir rtl $source_dir *.sv]] {
    if {[file tail $source_file] ne "control_word_pkg.sv"} {
      lappend rtl_sources $source_file
    }
  }
}

create_project -force $test_name $build_dir -part xc7a35tcsg324-1
set_property target_language Verilog [current_project]
set_property source_mgmt_mode None [current_project]
add_files -norecurse $rtl_sources
add_files -norecurse [file join $root_dir firmware bringup.mem]
set_property file_type SystemVerilog [get_files -of_objects [get_filesets sources_1] *.sv]
add_files -fileset sim_1 -norecurse $tb_source
set_property file_type SystemVerilog [get_files -of_objects [get_filesets sim_1] *.sv]
set_property top $test_name [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
set_property xsim.simulate.runtime all [get_filesets sim_1]
launch_simulation
close_sim

set sim_log [file join $build_dir ${test_name}.sim sim_1 behav xsim simulate.log]
if {[file exists $sim_log]} {
  set log_fd [open $sim_log r]
  set log_text [read $log_fd]
  close $log_fd
  if {[string first "PASS " $log_text] == -1} {
    error "simulation failed or did not report PASS; inspect $sim_log"
  }
}
