`timescale 1ns/1ps
`include "perf_paths.vh"

// CONFIG 0=legacy, 1=pipeline ideal RAM, 2=sync RAM, 3=sync+I/D cache,
// 4=sync+prediction, 5=sync+I/D cache+prediction. All execute identical bytes.
module perf_case #(
  parameter NAME="legacy_sort5", parameter integer CONFIG=0,
  parameter integer N=116, parameter integer STORES=12
)(output logic done);
  localparam DIR={`PERF_ROOT,"/sim/performance/programs/",NAME,"/"};
  logic clk=0, reset=1;
  always #5 clk=~clk;
  wire rv, store_fire, branch_event, mispredict_event;
  wire [31:0] rpc, rins, store_addr, store_data;
  wire [31:0] state_regs[0:31], state_mem[0:255];
  wire [31:0] hc, hi, sd, sf, sm, cf, hb, hm, ih, im, dh, dm, exc, irq;
  logic [31:0] exp_pc[0:N-1], exp_instr[0:N-1], exp_rd[0:N-1], exp_value[0:N-1];
  logic [31:0] exp_regs[0:31], exp_mem[0:255];
  logic [31:0] exp_store_addr[0:(STORES>0?STORES:1)-1];
  logic [31:0] exp_store_value[0:(STORES>0?STORES:1)-1];
  integer cycles=0, retired=0, stores=0, measured_branches=0, measured_mispredict=0;
  integer trace_fd, result_fd, commit_index, k;
  initial begin
    done=0;
    $readmemh({DIR,"pc.mem"},exp_pc); $readmemh({DIR,"instr.mem"},exp_instr);
    $readmemh({DIR,"rd.mem"},exp_rd); $readmemh({DIR,"value.mem"},exp_value);
    $readmemh({DIR,"regs.mem"},exp_regs); $readmemh({DIR,"final_dmem.mem"},exp_mem);
    $readmemh({DIR,"store_addr.mem"},exp_store_addr); $readmemh({DIR,"store_value.mem"},exp_store_value);
    trace_fd=$fopen($sformatf("%s/docs/performance/raw/%s_%0d.trace.csv",`PERF_ROOT,NAME,CONFIG),"w");
    if (!trace_fd) $fatal(1,"cannot open trace");
    $fdisplay(trace_fd,"cycle,index,pc,instruction,rd,value");
    repeat(4) @(posedge clk);
    @(negedge clk); reset=0;
  end
  generate
    if (CONFIG==0) begin : g_legacy
      wire mem_we;
      perf_legacy_cpu_top #(.IMEM_FILE({DIR,"imem.mem"}),.DMEM_FILE({DIR,"dmem.mem"})) u_cpu(
        .clk(clk),.rst_n(!reset),.dbg_pc(rpc),.dbg_instr(rins),
        .dbg_mem_we(mem_we),.dbg_mem_addr(store_addr),.dbg_mem_wdata(store_data));
      assign rv=!reset; assign store_fire=mem_we&&!reset;
      assign branch_event=(rins[6:0]==7'h63)&&(rpc!=exp_pc[N-1]);
      assign mispredict_event=0;
      assign hc=0;assign hi=0;assign sd=0;assign sf=0;assign sm=0;assign cf=0;
      assign hb=0;assign hm=0;assign ih=0;assign im=0;assign dh=0;assign dm=0;assign exc=0;assign irq=0;
      for(genvar r=0;r<32;r++) assign state_regs[r]=u_cpu.u_rf.regs[r];
      for(genvar r=0;r<256;r++) assign state_mem[r]=u_cpu.u_dmem.mem[r];
    end else begin : g_pipe
      wire ireq,iready,dreq,dready,dwrite;
      wire [31:0] ia,idata,da,dw,dr;
      wire [3:0] ds;
      cpu_core #(.ENABLE_BRANCH_PREDICTION(CONFIG==4||CONFIG==5)) u_cpu(
        .clk(clk),.reset(reset),.ext_irq(1'b0),
        .imem_req(ireq),.imem_addr(ia),.imem_ready(iready),.imem_rdata(idata),
        .dmem_req(dreq),.dmem_addr(da),.dmem_write(dwrite),.dmem_wdata(dw),.dmem_wstrb(ds),.dmem_ready(dready),.dmem_rdata(dr),
        .retire_valid(rv),.retire_pc(rpc),.retire_instr(rins),
        .cycle_count(hc),.instret_count(hi),.stall_data_count(sd),.stall_fetch_count(sf),.stall_memory_count(sm),
        .control_flush_count(cf),.branch_count(hb),.branch_mispredict_count(hm),.exception_count(exc),.interrupt_count(irq));
      assign store_fire=dreq&&dready&&dwrite;
      assign store_addr=da;assign store_data=dw;
      assign branch_event=u_cpu.predictor_update&&u_cpu.is_branch&&(u_cpu.id_ex.pc!=exp_pc[N-1]);
      assign mispredict_event=branch_event&&u_cpu.branch_mispredict;
      for(genvar r=0;r<32;r++) assign state_regs[r]=u_cpu.u_regfile.regs[r];
      if(CONFIG==1) begin : g_ideal
        logic [31:0] imem[0:255],dmem[0:255];
        initial begin $readmemh({DIR,"imem.mem"},imem); $readmemh({DIR,"dmem.mem"},dmem); end
        assign iready=ireq;assign idata=imem[ia[9:2]];
        assign dready=dreq;assign dr=dmem[da[9:2]];
        assign ih=0;assign im=0;assign dh=0;assign dm=0;
        always @(posedge clk) if(!reset&&dreq&&dwrite) begin
          if(ds!=4'b1111) $fatal(1,"unexpected byte store");
          dmem[da[9:2]]<=dw;
        end
        for(genvar r=0;r<256;r++) assign state_mem[r]=dmem[r];
      end else begin : g_sync
        wire mi_req,mi_ready,md_req,md_ready,md_write;
        wire [31:0] mi_addr,mi_data,md_addr,md_wdata,md_rdata;
        wire [3:0] md_strobe;
        icache #(.LINES(64),.ENABLE(CONFIG==3||CONFIG==5)) u_icache(
          .clk(clk),.reset(reset),.cpu_req(ireq),.cpu_addr(ia),.cpu_ready(iready),.cpu_rdata(idata),
          .mem_req(mi_req),.mem_addr(mi_addr),.mem_ready(mi_ready),.mem_rdata(mi_data),.hit_count(ih),.miss_count(im));
        instruction_memory #(.WORDS(256),.INIT_FILE({DIR,"imem.mem"})) u_imem(
          .clk(clk),.reset(reset),.req(mi_req),.addr(mi_addr),.ready(mi_ready),.rdata(mi_data));
        // Existing parameters map the benchmark data RAM to legacy address zero.
        // Only the memory map changes; CPU, cache logic and handshake FSMs are unmodified.
        dcache #(.LINES(64),.ENABLE(CONFIG==3||CONFIG==5),.CACHEABLE_BASE(32'b0)) u_dcache(
          .clk(clk),.reset(reset),.cpu_req(dreq),.cpu_addr(da),.cpu_write(dwrite),.cpu_wdata(dw),.cpu_wstrb(ds),
          .cpu_ready(dready),.cpu_rdata(dr),.mem_req(md_req),.mem_addr(md_addr),.mem_write(md_write),.mem_wdata(md_wdata),
          .mem_wstrb(md_strobe),.mem_ready(md_ready),.mem_rdata(md_rdata),.hit_count(dh),.miss_count(dm));
        data_memory #(.BASE_ADDR(32'b0),.WORDS(256),.INIT_FILE({DIR,"dmem.mem"})) u_dmem(
          .clk(clk),.reset(reset),.req(md_req),.addr(md_addr),.write(md_write),.wdata(md_wdata),.wstrb(md_strobe),.ready(md_ready),.rdata(md_rdata));
        for(genvar r=0;r<256;r++) assign state_mem[r]=u_dmem.mem[r];
      end
      always @(posedge clk) if(!reset&&!done) begin
        if (ireq && ia>=1024) $fatal(1,"instruction out of range");
        if (dreq && (da>=1024 || da[1:0]!=0)) $fatal(1,"data out of range");
      end
    end
  endgenerate

  always @(posedge clk) if(!reset&&!done) begin
    cycles=cycles+1;
    if(branch_event) measured_branches=measured_branches+1;
    if(mispredict_event) measured_mispredict=measured_mispredict+1;
    if(store_fire) begin
      if(stores>=STORES) $fatal(1,"%s cfg%0d extra store",NAME,CONFIG);
      if(store_addr!==exp_store_addr[stores] || store_data!==exp_store_value[stores])
        $fatal(1,"%s cfg%0d store %0d mismatch",NAME,CONFIG,stores);
      stores=stores+1;
    end
    if(rv) begin
      if(retired>=N || rpc!==exp_pc[retired] || rins!==exp_instr[retired])
        $fatal(1,"%s cfg%0d retirement %0d mismatch pc=%h expected=%h",NAME,CONFIG,retired,rpc,exp_pc[retired]);
      commit_index=retired;retired=retired+1;
      $fdisplay(trace_fd,"%0d,%0d,%08h,%08h,%0d,%08h",cycles,commit_index,rpc,rins,exp_rd[commit_index],exp_value[commit_index]);
      #1;
      if(exp_rd[commit_index]!=0 && state_regs[exp_rd[commit_index]]!==exp_value[commit_index])
        $fatal(1,"%s cfg%0d retirement %0d register value mismatch",NAME,CONFIG,commit_index);
      if(retired==N) begin
        for(k=0;k<32;k=k+1) if(state_regs[k]!==exp_regs[k]) $fatal(1,"%s cfg%0d final x%0d mismatch",NAME,CONFIG,k);
        for(k=0;k<256;k=k+1) if(state_mem[k]!==exp_mem[k]) $fatal(1,"%s cfg%0d final mem[%0d] mismatch",NAME,CONFIG,k);
        if(stores!=STORES) $fatal(1,"missing store");
        if(exc!==0 || irq!==0) $fatal(1,"unexpected trap");
        if(CONFIG!=0 && (hc!==cycles || hi!==retired)) $fatal(1,"hardware counters disagree with monitor");
        result_fd=$fopen($sformatf("%s/docs/performance/raw/%s_%0d.csv",`PERF_ROOT,NAME,CONFIG),"w");
        if(!result_fd) $fatal(1,"cannot open results");
        $fdisplay(result_fd,"workload,config,cycles,instret,stall_data,stall_fetch,stall_memory,flush,hw_branches,hw_mispredict,measured_branches,measured_mispredict,icache_hits,icache_misses,dcache_hits,dcache_misses,stores");
        $fdisplay(result_fd,"%s,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",NAME,CONFIG,cycles,retired,sd,sf,sm,cf,hb,hm,measured_branches,measured_mispredict,ih,im,dh,dm,stores);
        $fclose(result_fd);$fclose(trace_fd);
        $display("PERF_PASS %s cfg=%0d cycles=%0d instret=%0d stores=%0d",NAME,CONFIG,cycles,retired,stores);
        done=1;
      end
    end
    if(cycles>100000) $fatal(1,"case timeout");
  end
endmodule
