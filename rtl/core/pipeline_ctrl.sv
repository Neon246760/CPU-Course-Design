module pipeline_ctrl (
  input  logic reset,
  input  logic redirect_raw,
  input  logic dmem_wait,
  input  logic load_use,
  output logic redirect_accept,
  output logic hold_backend,
  output logic hold_frontend,
  output logic bubble_id_ex,
  output logic flush_if_id,
  output logic flush_id_ex
);
  always_comb begin
    redirect_accept = 1'b0;
    hold_backend = 1'b0;
    hold_frontend = 1'b0;
    bubble_id_ex = 1'b0;
    flush_if_id = 1'b0;
    flush_id_ex = 1'b0;

    if (!reset) begin
      // An older incomplete memory operation freezes EX.  A redirect generated
      // by the younger EX instruction is accepted after the memory completes.
      if (dmem_wait) begin
        hold_backend = 1'b1;
        hold_frontend = 1'b1;
      end else if (redirect_raw) begin
        redirect_accept = 1'b1;
        flush_if_id = 1'b1;
        flush_id_ex = 1'b1;
      end else if (load_use) begin
        hold_frontend = 1'b1;
        bubble_id_ex = 1'b1;
      end
    end
  end
endmodule
