set script_dir [file dirname [file normalize [info script]]]
set root_dir [file normalize [file join $script_dir ..]]
set output_dir [file join $root_dir build ees338]
set part_name xc7a35tcsg324-1
if {$argc >= 1} {
  set part_name [lindex $argv 0]
}
file mkdir $output_dir
puts "INFO: implementation target part is $part_name"

read_verilog -sv [file join $root_dir rtl decode control_word_pkg.sv]
foreach source_dir {decode execute regfile memory cache predictor exception core peripheral soc board} {
  foreach source_file [glob [file join $root_dir rtl $source_dir *.sv]] {
    if {[file tail $source_file] ne "control_word_pkg.sv"} {
      read_verilog -sv $source_file
    }
  }
}
read_mem [file join $root_dir firmware bringup.mem]
read_xdc [file join $root_dir constraints ees338.xdc]

synth_design -top ees338_top -part $part_name
opt_design
place_design
phys_opt_design
route_design

report_utilization -file [file join $output_dir utilization.rpt]
report_io -file [file join $output_dir io.rpt]
report_drc -file [file join $output_dir drc.rpt]
report_timing_summary -file [file join $output_dir timing_summary.rpt]
report_route_status -file [file join $output_dir route_status.rpt]
write_checkpoint -force [file join $output_dir ees338_top_routed.dcp]
write_bitstream -force [file join $output_dir ees338_top.bit]
