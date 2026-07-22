module mux2to1 #(
  parameter N = 32
)(
  input  logic [N-1:0] i_a,   // input 0
  input  logic [N-1:0] i_b,   // input 1
  input  logic         i_sel, // select: 0 → a, 1 → b
  output logic [N-1:0] o_y    // output
);

  always_comb begin
    case (i_sel)
      1'b0: o_y = i_a;
      1'b1: o_y = i_b;
      default: o_y = '0;
    endcase
  end

endmodule
