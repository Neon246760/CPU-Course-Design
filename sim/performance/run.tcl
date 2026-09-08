set root [file normalize [file join [file dirname [info script]] ../..]]
set out [file join $root build performance]
create_project -force performance $out -part xc7a35tcsg324-1
set_property source_mgmt_mode None [current_project]
add_files -norecurse [file join $root rtl decode control_word_pkg.sv]
foreach d {decode execute regfile memory cache predictor exception core} {
  foreach f [glob [file join $root rtl $d *.sv]] {
    if {[file tail $f] ne "control_word_pkg.sv"} {add_files -norecurse $f}
  }
}
add_files -norecurse [glob [file join $root sim performance legacy *.v]]
set_property include_dirs [list [file join $root sim performance legacy] [file join $root sim performance]] [get_filesets sources_1]
add_files -fileset sim_1 -norecurse [list [file join $root sim performance perf_case.sv] [file join $root sim performance tb_performance.sv]]
set_property include_dirs [list [file join $root sim performance legacy] [file join $root sim performance]] [get_filesets sim_1]
set_property top tb_performance [get_filesets sim_1]
set_property xsim.simulate.runtime all [get_filesets sim_1]
launch_simulation
close_sim
set log [file join $out performance.sim sim_1 behav xsim simulate.log]
set fd [open $log r];set contents [read $fd];close $fd
file copy -force $log [file join $root docs performance raw simulation.log]
if {[string first "PERFORMANCE_ALL_PASS 42" $contents]<0 || [regexp -nocase {fatal:|error:} $contents]} {
  error "Performance suite failed; inspect docs/performance/raw/simulation.log"
}
puts "PERFORMANCE_VALIDATED 42"
close_project
