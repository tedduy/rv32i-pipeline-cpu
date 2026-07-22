module mux4to1 #(
  parameter N = 32
)(
  input  logic [N-1:0] i_d0, i_d1, i_d2, i_d3,
  input  logic [1:0]   i_sel,
  output logic [N-1:0] o_y
);

  always_comb begin
    unique case (i_sel)
      2'b00: o_y = i_d0;
      2'b01: o_y = i_d1;
      2'b10: o_y = i_d2;
      2'b11: o_y = i_d3;
      default: o_y = '0;
    endcase
  end

endmodule
