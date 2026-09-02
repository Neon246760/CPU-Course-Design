module load_store_unit (
  input  logic [31:0] address,
  input  logic [31:0] store_data,
  input  logic [31:0] read_word,
  input  control_word_pkg::mem_size_t mem_size,
  input  logic        load_unsigned,
  output logic [31:0] write_data,
  output logic [3:0]  write_strobe,
  output logic [31:0] load_data,
  output logic        misaligned
);
  import control_word_pkg::*;
  logic [7:0] selected_byte;
  logic [15:0] selected_half;

  always_comb begin
    write_data = 32'b0;
    write_strobe = 4'b0000;
    load_data = 32'b0;
    misaligned = 1'b0;

    unique case (address[1:0])
      2'b00: selected_byte = read_word[7:0];
      2'b01: selected_byte = read_word[15:8];
      2'b10: selected_byte = read_word[23:16];
      default: selected_byte = read_word[31:24];
    endcase
    selected_half = address[1] ? read_word[31:16] : read_word[15:0];

    unique case (mem_size)
      MEM_BYTE: begin
        write_strobe = 4'b0001 << address[1:0];
        write_data = {24'b0, store_data[7:0]} << (8 * address[1:0]);
        load_data = load_unsigned ? {24'b0, selected_byte} :
                                    {{24{selected_byte[7]}}, selected_byte};
      end
      MEM_HALF: begin
        misaligned = address[0];
        write_strobe = address[1] ? 4'b1100 : 4'b0011;
        write_data = address[1] ? {store_data[15:0], 16'b0} :
                                  {16'b0, store_data[15:0]};
        load_data = load_unsigned ? {16'b0, selected_half} :
                                    {{16{selected_half[15]}}, selected_half};
      end
      default: begin
        misaligned = |address[1:0];
        write_strobe = 4'b1111;
        write_data = store_data;
        load_data = read_word;
      end
    endcase
  end
endmodule
