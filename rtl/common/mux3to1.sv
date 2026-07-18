// =============================================================================
// 3-to-1 Multiplexer
// =============================================================================
// Used for data forwarding in pipeline
// =============================================================================

module mux3to1 #(
    parameter N = 32
)(
    input  logic [N-1:0] i_d0,    // Input 0
    input  logic [N-1:0] i_d1,    // Input 1
    input  logic [N-1:0] i_d2,    // Input 2
    input  logic [1:0]   i_sel,   // Select signal
    output logic [N-1:0] o_y      // Output
);

    // The forwarding selector is one-hot encoded: 00=local, 01=WB, 10=MEM.
    // Giving the MEM bit direct priority avoids decoding both select bits on
    // the EX/MEM bypass path.  The reserved 11 value is never generated.
    assign o_y = i_sel[1] ? i_d2 :
                 i_sel[0] ? i_d1 : i_d0;

endmodule
