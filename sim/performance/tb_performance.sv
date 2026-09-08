`timescale 1ns/1ps
module tb_performance;
  wire [41:0] done;
  perf_case #(.NAME("alu_independent"), .CONFIG(0), .N(194), .STORES(0)) c0(.done(done[0]));
  perf_case #(.NAME("alu_independent"), .CONFIG(1), .N(194), .STORES(0)) c1(.done(done[1]));
  perf_case #(.NAME("alu_independent"), .CONFIG(2), .N(194), .STORES(0)) c2(.done(done[2]));
  perf_case #(.NAME("alu_independent"), .CONFIG(3), .N(194), .STORES(0)) c3(.done(done[3]));
  perf_case #(.NAME("alu_independent"), .CONFIG(4), .N(194), .STORES(0)) c4(.done(done[4]));
  perf_case #(.NAME("alu_independent"), .CONFIG(5), .N(194), .STORES(0)) c5(.done(done[5]));
  perf_case #(.NAME("raw_chain"), .CONFIG(0), .N(194), .STORES(0)) c6(.done(done[6]));
  perf_case #(.NAME("raw_chain"), .CONFIG(1), .N(194), .STORES(0)) c7(.done(done[7]));
  perf_case #(.NAME("raw_chain"), .CONFIG(2), .N(194), .STORES(0)) c8(.done(done[8]));
  perf_case #(.NAME("raw_chain"), .CONFIG(3), .N(194), .STORES(0)) c9(.done(done[9]));
  perf_case #(.NAME("raw_chain"), .CONFIG(4), .N(194), .STORES(0)) c10(.done(done[10]));
  perf_case #(.NAME("raw_chain"), .CONFIG(5), .N(194), .STORES(0)) c11(.done(done[11]));
  perf_case #(.NAME("branch_loop"), .CONFIG(0), .N(386), .STORES(0)) c12(.done(done[12]));
  perf_case #(.NAME("branch_loop"), .CONFIG(1), .N(386), .STORES(0)) c13(.done(done[13]));
  perf_case #(.NAME("branch_loop"), .CONFIG(2), .N(386), .STORES(0)) c14(.done(done[14]));
  perf_case #(.NAME("branch_loop"), .CONFIG(3), .N(386), .STORES(0)) c15(.done(done[15]));
  perf_case #(.NAME("branch_loop"), .CONFIG(4), .N(386), .STORES(0)) c16(.done(done[16]));
  perf_case #(.NAME("branch_loop"), .CONFIG(5), .N(386), .STORES(0)) c17(.done(done[17]));
  perf_case #(.NAME("branch_steady"), .CONFIG(0), .N(6002), .STORES(0)) c18(.done(done[18]));
  perf_case #(.NAME("branch_steady"), .CONFIG(1), .N(6002), .STORES(0)) c19(.done(done[19]));
  perf_case #(.NAME("branch_steady"), .CONFIG(2), .N(6002), .STORES(0)) c20(.done(done[20]));
  perf_case #(.NAME("branch_steady"), .CONFIG(3), .N(6002), .STORES(0)) c21(.done(done[21]));
  perf_case #(.NAME("branch_steady"), .CONFIG(4), .N(6002), .STORES(0)) c22(.done(done[22]));
  perf_case #(.NAME("branch_steady"), .CONFIG(5), .N(6002), .STORES(0)) c23(.done(done[23]));
  perf_case #(.NAME("load_use_sum"), .CONFIG(0), .N(786), .STORES(0)) c24(.done(done[24]));
  perf_case #(.NAME("load_use_sum"), .CONFIG(1), .N(786), .STORES(0)) c25(.done(done[25]));
  perf_case #(.NAME("load_use_sum"), .CONFIG(2), .N(786), .STORES(0)) c26(.done(done[26]));
  perf_case #(.NAME("load_use_sum"), .CONFIG(3), .N(786), .STORES(0)) c27(.done(done[27]));
  perf_case #(.NAME("load_use_sum"), .CONFIG(4), .N(786), .STORES(0)) c28(.done(done[28]));
  perf_case #(.NAME("load_use_sum"), .CONFIG(5), .N(786), .STORES(0)) c29(.done(done[29]));
  perf_case #(.NAME("memory_copy"), .CONFIG(0), .N(227), .STORES(32)) c30(.done(done[30]));
  perf_case #(.NAME("memory_copy"), .CONFIG(1), .N(227), .STORES(32)) c31(.done(done[31]));
  perf_case #(.NAME("memory_copy"), .CONFIG(2), .N(227), .STORES(32)) c32(.done(done[32]));
  perf_case #(.NAME("memory_copy"), .CONFIG(3), .N(227), .STORES(32)) c33(.done(done[33]));
  perf_case #(.NAME("memory_copy"), .CONFIG(4), .N(227), .STORES(32)) c34(.done(done[34]));
  perf_case #(.NAME("memory_copy"), .CONFIG(5), .N(227), .STORES(32)) c35(.done(done[35]));
  perf_case #(.NAME("legacy_sort5"), .CONFIG(0), .N(116), .STORES(12)) c36(.done(done[36]));
  perf_case #(.NAME("legacy_sort5"), .CONFIG(1), .N(116), .STORES(12)) c37(.done(done[37]));
  perf_case #(.NAME("legacy_sort5"), .CONFIG(2), .N(116), .STORES(12)) c38(.done(done[38]));
  perf_case #(.NAME("legacy_sort5"), .CONFIG(3), .N(116), .STORES(12)) c39(.done(done[39]));
  perf_case #(.NAME("legacy_sort5"), .CONFIG(4), .N(116), .STORES(12)) c40(.done(done[40]));
  perf_case #(.NAME("legacy_sort5"), .CONFIG(5), .N(116), .STORES(12)) c41(.done(done[41]));
  initial begin wait (&done); #10; $display("PERFORMANCE_ALL_PASS 42"); $finish; end
  initial begin #2000000; $fatal(1,"global timeout"); end
endmodule
