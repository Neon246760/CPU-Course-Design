module btb #(
  parameter integer ENTRIES = 16
) (
  input  logic                         clk,
  input  logic                         reset,
  input  logic [31:0]                  query_pc,
  output logic                         query_hit,
  output logic [31:0]                  query_target,
  input  logic                         update_enable,
  input  logic [31:0]                  update_pc,
  input  logic [31:0]                  update_target
);
  localparam integer INDEX_BITS = $clog2(ENTRIES);
  localparam integer TAG_LSB = INDEX_BITS + 2;
  logic valid [0:ENTRIES-1];
  logic [31-TAG_LSB:0] tags [0:ENTRIES-1];
  logic [31:0] targets [0:ENTRIES-1];
  logic [INDEX_BITS-1:0] query_index;
  logic [INDEX_BITS-1:0] update_index;
  integer i;

  assign query_index = query_pc[TAG_LSB-1:2];
  assign update_index = update_pc[TAG_LSB-1:2];
  assign query_hit = valid[query_index] &&
                     (tags[query_index] == query_pc[31:TAG_LSB]);
  assign query_target = targets[query_index];

  always_ff @(posedge clk) begin
    if (reset) begin
      for (i = 0; i < ENTRIES; i = i + 1) begin
        valid[i] <= 1'b0;
        tags[i] <= '0;
        targets[i] <= 32'b0;
      end
    end else if (update_enable) begin
      valid[update_index] <= 1'b1;
      tags[update_index] <= update_pc[31:TAG_LSB];
      targets[update_index] <= update_target;
    end
  end
endmodule
