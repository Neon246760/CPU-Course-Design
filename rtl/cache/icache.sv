module icache #(
  parameter integer LINES = 64,
  parameter logic ENABLE = 1'b1
) (
  input  logic        clk,
  input  logic        reset,
  input  logic        cpu_req,
  input  logic [31:0] cpu_addr,
  output logic        cpu_ready,
  output logic [31:0] cpu_rdata,
  output logic        mem_req,
  output logic [31:0] mem_addr,
  input  logic        mem_ready,
  input  logic [31:0] mem_rdata,
  output logic [31:0] hit_count,
  output logic [31:0] miss_count
);
  generate
    if (!ENABLE) begin : g_bypass
      always_comb begin
        cpu_ready = mem_ready;
        cpu_rdata = mem_rdata;
        mem_req = cpu_req;
        mem_addr = cpu_addr;
      end
      assign hit_count = 32'b0;
      assign miss_count = 32'b0;
    end else begin : g_cache
      localparam integer INDEX_BITS = $clog2(LINES);
      localparam integer TAG_LSB = INDEX_BITS + 4;
      typedef enum logic [1:0] {IDLE, REFILL, RESP} state_t;
      state_t state;
      logic valid [0:LINES-1];
      logic [31-TAG_LSB:0] tags [0:LINES-1];
      logic [31:0] data [0:LINES-1][0:3];
      logic [31:0] miss_addr;
      logic [INDEX_BITS-1:0] miss_index;
      logic [31-TAG_LSB:0] miss_tag;
      logic [1:0] refill_word;
      logic [INDEX_BITS-1:0] cpu_index;
      logic [31-TAG_LSB:0] cpu_tag;
      logic hit;
      integer i;

      always_comb begin
        cpu_index = cpu_addr[TAG_LSB-1:4];
        cpu_tag = cpu_addr[31:TAG_LSB];
        hit = valid[cpu_index] && (tags[cpu_index] == cpu_tag);
        cpu_ready = 1'b0;
        cpu_rdata = 32'b0;
        mem_req = 1'b0;
        mem_addr = 32'b0;

        if (state == IDLE) begin
          if (cpu_req && hit) begin
            cpu_ready = 1'b1;
            cpu_rdata = data[cpu_index][cpu_addr[3:2]];
          end
        end else if (state == REFILL) begin
          mem_req = 1'b1;
          mem_addr = {miss_addr[31:4], 4'b0} + {28'b0, refill_word, 2'b0};
        end else begin
          if (cpu_req && (cpu_addr == miss_addr)) begin
            cpu_ready = 1'b1;
            cpu_rdata = data[miss_index][miss_addr[3:2]];
          end
        end
      end

      always_ff @(posedge clk) begin
        if (reset) begin
          state <= IDLE;
          miss_addr <= 32'b0;
          miss_index <= '0;
          miss_tag <= '0;
          refill_word <= 2'b0;
          hit_count <= 32'b0;
          miss_count <= 32'b0;
          for (i = 0; i < LINES; i = i + 1) begin
            valid[i] <= 1'b0;
            tags[i] <= '0;
          end
        end else begin
          case (state)
            IDLE: begin
              if (cpu_req) begin
                if (hit) begin
                  hit_count <= hit_count + 32'd1;
                end else begin
                  miss_count <= miss_count + 32'd1;
                  miss_addr <= cpu_addr;
                  miss_index <= cpu_index;
                  miss_tag <= cpu_tag;
                  refill_word <= 2'b0;
                  state <= REFILL;
                end
              end
            end
            REFILL: begin
              if (mem_ready) begin
                data[miss_index][refill_word] <= mem_rdata;
                if (refill_word == 2'd3) begin
                  tags[miss_index] <= miss_tag;
                  valid[miss_index] <= 1'b1;
                  state <= RESP;
                end else begin
                  refill_word <= refill_word + 2'd1;
                end
              end
            end
            default: state <= IDLE;
          endcase
        end
      end
    end
  endgenerate
endmodule
