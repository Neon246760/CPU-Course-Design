module instruction_memory #(
  parameter logic [31:0] BASE_ADDR = 32'h0000_0000,
  parameter integer WORDS = 16384,
  parameter INIT_FILE = ""
) (
  input  logic        clk,
  input  logic        reset,
  input  logic        req,
  input  logic [31:0] addr,
  output logic        ready,
  output logic [31:0] rdata
);
  typedef enum logic [1:0] {IDLE, RESPOND, TURNAROUND} state_t;

  (* ram_style = "block" *) logic [31:0] mem [0:WORDS-1];
  state_t state;
  localparam integer ADDR_WIDTH = $clog2(WORDS);
  logic [ADDR_WIDTH-1:0] word_index;
  integer i;

  assign word_index = (addr - BASE_ADDR) >> 2;

  initial begin
    for (i = 0; i < WORDS; i = i + 1) mem[i] = 32'h0000_0013;
    if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
  end

  assign ready = (state == RESPOND);

  always_ff @(posedge clk) begin
    if (reset) begin
      state <= IDLE;
    end else begin
      case (state)
        IDLE: begin
          if (req) begin
            rdata <= mem[word_index];
            state <= RESPOND;
          end
        end
        RESPOND: state <= TURNAROUND;
        default: state <= IDLE;
      endcase
    end
  end
endmodule
