module branch_predictor #(
  parameter integer ENTRIES = 16,
  parameter logic ENABLE = 1'b1
) (
  input  logic        clk,
  input  logic        reset,
  input  logic [31:0] query_pc,
  output logic        predict_taken,
  output logic [31:0] predict_target,
  input  logic        update_enable,
  input  logic [31:0] update_pc,
  input  logic        update_taken,
  input  logic [31:0] update_target
);
  localparam integer INDEX_BITS = $clog2(ENTRIES);
  logic btb_hit;
  logic [31:0] btb_target;
  logic bht_taken;

  btb #(.ENTRIES(ENTRIES)) u_btb (
    .clk(clk), .reset(reset),
    .query_pc(query_pc), .query_hit(btb_hit), .query_target(btb_target),
    .update_enable(update_enable && ENABLE),
    .update_pc(update_pc), .update_target(update_target)
  );

  bht #(.ENTRIES(ENTRIES)) u_bht (
    .clk(clk), .reset(reset),
    .query_index(query_pc[INDEX_BITS+1:2]),
    .predict_taken(bht_taken),
    .update_enable(update_enable && ENABLE),
    .update_index(update_pc[INDEX_BITS+1:2]),
    .update_taken(update_taken)
  );

  always_comb begin
    predict_taken = ENABLE && btb_hit && bht_taken;
    predict_target = btb_target;
  end
endmodule
