module adder_n_bit #(
    parameter N = 32
)(
    input  logic [N-1:0] i_a,
    input  logic [N-1:0] i_b,
    output logic [N-1:0] o_sum
);

    assign o_sum = i_a + i_b;

endmodule
