module data_memory #(
  parameter logic [31:0] BASE_ADDR = 32'h1000_0000,
  parameter integer WORDS = 16384,
  parameter INIT_FILE = ""
) (
  input  logic        clk,
  input  logic        reset,
  input  logic        req,
  input  logic [31:0] addr,
  input  logic        write,
  input  logic [31:0] wdata,
  input  logic [3:0]  wstrb,
  output logic        selected,
  output logic        ready,
  output logic [31:0] rdata
);
  typedef enum logic [1:0] {IDLE, RESPOND, TURNAROUND} state_t;

  (* ram_style = "block" *) logic [31:0] mem [0:WORDS-1];
  state_t state;
  localparam integer ADDR_WIDTH = $clog2(WORDS);
  logic [ADDR_WIDTH-1:0] word_index;

  assign word_index = (addr - BASE_ADDR) >> 2;

  initial begin
    if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
  end

  always_comb begin
    selected = (addr >= BASE_ADDR) &&
               (addr < (BASE_ADDR + (WORDS * 4)));
    ready = (state == RESPOND);
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      state <= IDLE;
    end else begin
      case (state)
        IDLE: begin
          if (req) begin
            rdata <= mem[word_index];
            if (write) begin
              if (wstrb[0]) mem[word_index][7:0] <= wdata[7:0];
              if (wstrb[1]) mem[word_index][15:8] <= wdata[15:8];
              if (wstrb[2]) mem[word_index][23:16] <= wdata[23:16];
              if (wstrb[3]) mem[word_index][31:24] <= wdata[31:24];
            end
            state <= RESPOND;
          end
        end
        RESPOND: state <= TURNAROUND;
        default: state <= IDLE;
      endcase
    end
  end
endmodule
