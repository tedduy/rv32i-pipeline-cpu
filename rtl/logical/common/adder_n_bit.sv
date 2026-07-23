module adder_n_bit #(
    parameter N = 32,
    parameter logic USE_CARRY_SELECT = 1'b0,
    parameter integer BLOCK_WIDTH = 8
)(
    input  logic [N-1:0] i_a,
    input  logic [N-1:0] i_b,
    output logic [N-1:0] o_sum
);

    generate
        if (!USE_CARRY_SELECT) begin : g_parallel_prefix
            assign o_sum = i_a + i_b;
        end else begin : g_carry_select
            localparam integer BLOCK_COUNT =
                (N + BLOCK_WIDTH - 1) / BLOCK_WIDTH;

            for (genvar block_index = 0;
                 block_index < BLOCK_COUNT;
                 block_index = block_index + 1) begin : g_block
                localparam integer BLOCK_LSB = block_index * BLOCK_WIDTH;
                localparam integer THIS_WIDTH =
                    ((BLOCK_LSB + BLOCK_WIDTH) <= N)
                    ? BLOCK_WIDTH : (N - BLOCK_LSB);
                logic [THIS_WIDTH:0] sum_carry_0;
                logic [THIS_WIDTH:0] sum_carry_1;
                logic                  carry_in;

                if (block_index == 0) begin : g_first_carry
                    assign carry_in = 1'b0;
                end else begin : g_chained_carry
                    assign carry_in =
                        g_block[block_index-1].g_carry_out.carry_out;
                end

                assign sum_carry_0 =
                    {1'b0, i_a[BLOCK_LSB +: THIS_WIDTH]} +
                    {1'b0, i_b[BLOCK_LSB +: THIS_WIDTH]};
                assign sum_carry_1 =
                    {1'b0, i_a[BLOCK_LSB +: THIS_WIDTH]} +
                    {1'b0, i_b[BLOCK_LSB +: THIS_WIDTH]} +
                    {{THIS_WIDTH{1'b0}}, 1'b1};

                assign o_sum[BLOCK_LSB +: THIS_WIDTH] =
                    carry_in
                    ? sum_carry_1[THIS_WIDTH-1:0]
                    : sum_carry_0[THIS_WIDTH-1:0];
                if (block_index < BLOCK_COUNT - 1) begin : g_carry_out
                    logic carry_out;
                    assign carry_out =
                        carry_in
                        ? sum_carry_1[THIS_WIDTH]
                        : sum_carry_0[THIS_WIDTH];
                end
            end
        end
    endgenerate

endmodule
