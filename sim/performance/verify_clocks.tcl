set root [file normalize [file join [file dirname [info script]] ../..]]
foreach item {
  {perf_legacy_synth_top 12.000}
  {perf_pipeline_synth_top 11.000}
} {
  lassign $item top period
  set dir [file join $root build performance implementation $top]
  open_checkpoint [file join $dir routed.dcp]
  create_clock -name perf_clk -period $period [get_ports clk]
  report_timing_summary -delay_type min_max -max_paths 20 -file [file join $dir timing_closed_summary.rpt]
  set wns [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
  if {$wns < 0} {error "$top fails verification period $period ns: WNS=$wns"}
  puts "TIMING_CLOSED $top period_ns=$period wns_ns=$wns"
  close_design
}
