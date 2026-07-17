module program_counter #(
    parameter N = 32,
    parameter logic [N-1:0] RESET_VECTOR = '0
)(
    input  logic           i_clk,
    input  logic           i_arst_n,   // Active low reset
    input  logic [N-1:0]   i_PC,       // Next PC value
    output logic [N-1:0]   o_PC        // Current PC value
);
  
  always_ff @(posedge i_clk or negedge i_arst_n) begin
    if(!i_arst_n) o_PC <= RESET_VECTOR;
    else		  o_PC <= i_PC;
  end
  
  
endmodule
