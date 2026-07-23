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
    // Drive a benign value for the reserved or unknown selector rather than
    // allowing an X to spread into address, branch, and MDU datapaths.
    always_comb begin
        case (i_sel)
            2'b00:   o_y = i_d0;
            2'b01:   o_y = i_d1;
            2'b10:   o_y = i_d2;
            // i_sel=3 is excluded by the forwarding controller.
            /* verilator coverage_off */
            default: o_y = '0;
            /* verilator coverage_on */
        endcase
    end

endmodule
