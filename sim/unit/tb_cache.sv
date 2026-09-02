`timescale 1ns/1ps

module tb_cache;
  logic clk;
  logic reset;

  logic ic_req;
  logic [31:0] ic_addr;
  logic ic_ready;
  logic [31:0] ic_rdata;
  logic im_req;
  logic [31:0] im_addr;
  logic im_ready;
  logic [31:0] im_rdata;
  logic [31:0] ic_hits;
  logic [31:0] ic_misses;

  logic dc_req;
  logic [31:0] dc_addr;
  logic dc_write;
  logic [31:0] dc_wdata;
  logic [3:0] dc_wstrb;
  logic dc_ready;
  logic [31:0] dc_rdata;
  logic dm_req;
  logic [31:0] dm_addr;
  logic dm_write;
  logic [31:0] dm_wdata;
  logic [3:0] dm_wstrb;
  logic dm_ready;
  logic [31:0] dm_rdata;
  logic [31:0] dc_hits;
  logic [31:0] dc_misses;
  logic [31:0] imem [0:255];
  logic [31:0] dmem [0:255];
  integer i;
  integer dm_index;

  icache #(.LINES(4), .ENABLE(1'b1)) u_icache (
    .clk(clk), .reset(reset), .cpu_req(ic_req), .cpu_addr(ic_addr),
    .cpu_ready(ic_ready), .cpu_rdata(ic_rdata), .mem_req(im_req),
    .mem_addr(im_addr), .mem_ready(im_ready), .mem_rdata(im_rdata),
    .hit_count(ic_hits), .miss_count(ic_misses)
  );

  dcache #(.LINES(4), .ENABLE(1'b1)) u_dcache (
    .clk(clk), .reset(reset), .cpu_req(dc_req), .cpu_addr(dc_addr),
    .cpu_write(dc_write), .cpu_wdata(dc_wdata), .cpu_wstrb(dc_wstrb),
    .cpu_ready(dc_ready), .cpu_rdata(dc_rdata), .mem_req(dm_req),
    .mem_addr(dm_addr), .mem_write(dm_write), .mem_wdata(dm_wdata),
    .mem_wstrb(dm_wstrb), .mem_ready(dm_ready), .mem_rdata(dm_rdata),
    .hit_count(dc_hits), .miss_count(dc_misses)
  );

  assign im_ready = im_req;
  assign im_rdata = imem[im_addr[9:2]];
  assign dm_ready = dm_req;

  always_comb begin
    dm_index = (dm_addr - 32'h1000_0000) >> 2;
    if ((dm_addr & 32'hFFFF_0000) == 32'h1000_0000)
      dm_rdata = dmem[dm_index];
    else
      dm_rdata = 32'hDEAD_BEEF;
  end

  always_ff @(posedge clk) begin
    if (dm_req && dm_write &&
        ((dm_addr & 32'hFFFF_0000) == 32'h1000_0000)) begin
      if (dm_wstrb[0]) dmem[dm_index][7:0] <= dm_wdata[7:0];
      if (dm_wstrb[1]) dmem[dm_index][15:8] <= dm_wdata[15:8];
      if (dm_wstrb[2]) dmem[dm_index][23:16] <= dm_wdata[23:16];
      if (dm_wstrb[3]) dmem[dm_index][31:24] <= dm_wdata[31:24];
    end
  end

  always #5 clk = ~clk;

  task automatic ic_read(input logic [31:0] addr, input logic [31:0] expected);
    begin
      @(negedge clk);
      ic_addr = addr;
      ic_req = 1'b1;
      #1;
      while (!ic_ready) begin @(negedge clk); #1; end
      if (ic_rdata !== expected) $fatal(1, "I-cache addr=%h got=%h", addr, ic_rdata);
      @(negedge clk);
      ic_req = 1'b0;
    end
  endtask

  task automatic dc_access(
    input logic write,
    input logic [31:0] addr,
    input logic [31:0] wdata,
    input logic [3:0] wstrb,
    input logic [31:0] expected
  );
    begin
      @(negedge clk);
      dc_write = write;
      dc_addr = addr;
      dc_wdata = wdata;
      dc_wstrb = wstrb;
      dc_req = 1'b1;
      #1;
      while (!dc_ready) begin @(negedge clk); #1; end
      if (!write && dc_rdata !== expected)
        $fatal(1, "D-cache addr=%h got=%h expected=%h", addr, dc_rdata, expected);
      @(negedge clk);
      dc_req = 1'b0;
    end
  endtask

  initial begin
    clk = 1'b0;
    reset = 1'b1;
    ic_req = 1'b0;
    ic_addr = 32'b0;
    dc_req = 1'b0;
    dc_addr = 32'h1000_0000;
    dc_write = 1'b0;
    dc_wdata = 32'b0;
    dc_wstrb = 4'b0;
    for (i = 0; i < 256; i = i + 1) begin
      imem[i] = 32'h1000_0000 + i;
      dmem[i] = 32'h2000_0000 + i;
    end
    dmem[0] = 32'h1122_3344;
    repeat (3) @(posedge clk);
    reset = 1'b0;

    ic_read(32'h0000_0000, 32'h1000_0000); // cold miss
    ic_read(32'h0000_0004, 32'h1000_0001); // same-line hit
    ic_read(32'h0000_0040, 32'h1000_0010); // same-index replacement
    ic_read(32'h0000_0000, 32'h1000_0000); // replaced line misses again
    if (ic_hits < 1 || ic_misses != 3) $fatal(1, "I-cache stats %0d/%0d", ic_hits, ic_misses);

    dc_access(0, 32'h1000_0000, 0, 0, 32'h1122_3344); // load miss
    dc_access(0, 32'h1000_0000, 0, 0, 32'h1122_3344); // load hit
    dc_access(1, 32'h1000_0000, 32'h0000_AA00, 4'b0010, 0); // hit, write-through
    dc_access(0, 32'h1000_0000, 0, 0, 32'h1122_AA44); // updated hit
    dc_access(1, 32'h1000_0040, 32'h5566_7788, 4'b1111, 0); // miss, no allocate
    dc_access(0, 32'h1000_0040, 0, 0, 32'h5566_7788); // must miss and refill
    dc_access(0, 32'h2000_0004, 0, 0, 32'hDEAD_BEEF); // uncached bypass
    if (dc_hits < 3 || dc_misses < 3) $fatal(1, "D-cache stats %0d/%0d", dc_hits, dc_misses);

    $display("PASS tb_cache I$=%0d/%0d D$=%0d/%0d",
             ic_hits, ic_misses, dc_hits, dc_misses);
    $finish;
  end
endmodule
