`include "perf_paths.vh"

// Static-timing comparison wrappers. Both include the same 256x32-bit
// asynchronous instruction/data memories initialized by the legacy sort image.
module perf_legacy_synth_top(
  input logic clk, input logic reset,
  output logic [31:0] observe
);
  wire [31:0] pc,instr,addr,wdata; wire we;
  (* dont_touch = "yes" *) perf_legacy_cpu_top #(
    .IMEM_FILE({`PERF_ROOT,"/sim/performance/programs/legacy_sort5/imem.mem"}),
    .DMEM_FILE({`PERF_ROOT,"/sim/performance/programs/legacy_sort5/dmem.mem"})
  ) u_cpu(.clk(clk),.rst_n(!reset),.dbg_pc(pc),.dbg_instr(instr),
          .dbg_mem_we(we),.dbg_mem_addr(addr),.dbg_mem_wdata(wdata));
  assign observe=pc^instr^addr^wdata^{31'b0,we};
endmodule

module perf_pipeline_synth_top(
  input logic clk, input logic reset,
  output logic [31:0] observe
);
  wire ireq,dreq,dwrite,rv; wire [31:0] ia,ir,da,dw,dr,rpc,rins;
  wire [3:0] ds; logic [31:0] imem[0:255],dmem[0:255];
  initial begin
    $readmemh({`PERF_ROOT,"/sim/performance/programs/legacy_sort5/imem.mem"},imem);
    $readmemh({`PERF_ROOT,"/sim/performance/programs/legacy_sort5/dmem.mem"},dmem);
  end
  (* dont_touch = "yes" *) cpu_core #(.ENABLE_BRANCH_PREDICTION(1'b0)) u_cpu(
    .clk(clk),.reset(reset),.ext_irq(1'b0),
    .imem_req(ireq),.imem_addr(ia),.imem_ready(ireq),.imem_rdata(imem[ia[9:2]]),
    .dmem_req(dreq),.dmem_addr(da),.dmem_write(dwrite),.dmem_wdata(dw),.dmem_wstrb(ds),
    .dmem_ready(dreq),.dmem_rdata(dmem[da[9:2]]),
    .retire_valid(rv),.retire_pc(rpc),.retire_instr(rins));
  always_ff @(posedge clk) if(!reset&&dreq&&dwrite) begin
    if(ds[0])dmem[da[9:2]][7:0]<=dw[7:0];
    if(ds[1])dmem[da[9:2]][15:8]<=dw[15:8];
    if(ds[2])dmem[da[9:2]][23:16]<=dw[23:16];
    if(ds[3])dmem[da[9:2]][31:24]<=dw[31:24];
  end
  assign observe=ia^ir^da^dw^dr^rpc^rins^{29'b0,rv,dwrite,dreq};
endmodule
