set root [file normalize [file join [file dirname [info script]] ../..]]
set common [list [file join $root rtl decode control_word_pkg.sv]]
foreach d {decode execute regfile core predictor exception memory} {
  foreach f [glob [file join $root rtl $d *.sv]] {
    if {[file tail $f] ne "control_word_pkg.sv"} {lappend common $f}
  }
}
foreach f [glob [file join $root sim performance legacy *.v]] {lappend common $f}
lappend common [file join $root sim performance perf_synth_wrappers.sv]
foreach top {perf_legacy_synth_top perf_pipeline_synth_top} {
  set out [file join $root build performance implementation $top]
  file mkdir $out
  create_project -force $top $out -part xc7a35tcsg324-1
  set_property source_mgmt_mode None [current_project]
  add_files -norecurse $common
  set_property include_dirs [list [file join $root sim performance legacy] [file join $root sim performance]] [get_filesets sources_1]
  synth_design -top $top -part xc7a35tcsg324-1
  create_clock -name perf_clk -period 2.000 [get_ports clk]
  set_false_path -from [get_ports reset]
  opt_design
  place_design
  phys_opt_design
  route_design
  report_timing_summary -delay_type min_max -max_paths 20 -file [file join $out timing_summary.rpt]
  report_timing -delay_type max -max_paths 20 -sort_by group -file [file join $out timing_paths.rpt]
  report_utilization -file [file join $out utilization.rpt]
  write_checkpoint -force [file join $out routed.dcp]
  close_project
}
