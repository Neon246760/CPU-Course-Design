module bht #(
  parameter integer ENTRIES = 16
) (
  input  logic                         clk,
  input  logic                         reset,
  input  logic [$clog2(ENTRIES)-1:0]   query_index,
  output logic                         predict_taken,
  input  logic                         update_enable,
  input  logic [$clog2(ENTRIES)-1:0]   update_index,
  input  logic                         update_taken
);
  logic [1:0] counters [0:ENTRIES-1];
  integer i;

  assign predict_taken = counters[query_index][1];

  always_ff @(posedge clk) begin
    if (reset) begin
      for (i = 0; i < ENTRIES; i = i + 1) counters[i] <= 2'b01;
    end else if (update_enable) begin
      if (update_taken) begin
        if (counters[update_index] != 2'b11)
          counters[update_index] <= counters[update_index] + 2'b01;
      end else begin
        if (counters[update_index] != 2'b00)
          counters[update_index] <= counters[update_index] - 2'b01;
      end
    end
  end
endmodule
