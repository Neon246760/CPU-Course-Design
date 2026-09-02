`timescale 1ns/1ps

module tb_branch_predictor;
  logic clk;
  logic reset;
  logic [31:0] query_pc;
  logic predict_taken;
  logic [31:0] predict_target;
  logic update_enable;
  logic [31:0] update_pc;
  logic update_taken;
  logic [31:0] update_target;

  branch_predictor #(.ENTRIES(16), .ENABLE(1'b1)) dut (
    .clk(clk), .reset(reset), .query_pc(query_pc),
    .predict_taken(predict_taken), .predict_target(predict_target),
    .update_enable(update_enable), .update_pc(update_pc),
    .update_taken(update_taken), .update_target(update_target)
  );

  always #5 clk = ~clk;

  task automatic update(input logic taken, input logic [31:0] target);
    begin
      update_enable = 1'b1;
      update_taken = taken;
      update_target = target;
      @(posedge clk);
      #1;
      update_enable = 1'b0;
    end
  endtask

  initial begin
    clk = 1'b0;
    reset = 1'b1;
    query_pc = 32'h0000_0040;
    update_pc = 32'h0000_0040;
    update_enable = 1'b0;
    update_taken = 1'b0;
    update_target = 32'h0000_0020;
    repeat (2) @(posedge clk);
    reset = 1'b0;
    #1;
    if (predict_taken !== 1'b0) $fatal(1, "cold predictor must not take");

    update(1'b1, 32'h0000_0020);
    if (!predict_taken || predict_target !== 32'h0000_0020)
      $fatal(1, "taken training failed");
    update(1'b1, 32'h0000_0020);
    if (!predict_taken) $fatal(1, "strong taken training failed");
    update(1'b0, 32'h0000_0020);
    if (!predict_taken) $fatal(1, "single miss should remain weak taken");
    update(1'b0, 32'h0000_0020);
    if (predict_taken) $fatal(1, "not-taken training failed");

    query_pc = 32'h0000_1040;
    #1;
    if (predict_taken) $fatal(1, "BTB tag conflict produced false hit");
    $display("PASS tb_branch_predictor");
    $finish;
  end
endmodule
