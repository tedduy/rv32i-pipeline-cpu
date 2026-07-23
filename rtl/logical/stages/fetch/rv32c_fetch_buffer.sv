// Converts an aligned 32-bit instruction-memory response stream into one
// canonical RV32 instruction at the requested halfword-aligned PC.  A 32-bit
// instruction beginning in the upper half of a bus word is assembled using a
// second aligned read.
module rv32c_fetch_buffer #(
    parameter N = 32
)(
    input  logic         i_clk,
    input  logic         i_arst_n,
    input  logic         i_flush,
    input  logic         i_consume,
    input  logic [N-1:0] i_pc,

    input  logic         i_response_valid,
    input  logic [31:0]  i_response_data,
    input  logic         i_response_error,

    output logic [N-1:0] o_bus_addr,
    output logic         o_complete,
    output logic [31:0]  o_instruction,
    output logic [31:0]  o_raw_instruction,
    output logic         o_compressed,
    output logic         o_access_fault
);

    logic        cross_pending_q;
    logic [15:0] first_half_q;
    logic        first_error_q;
    logic [15:0] compressed_parcel;
    logic [31:0] decompressed_instruction;
    logic        decompressed_illegal;
    logic        starts_cross_word;

    assign o_bus_addr = cross_pending_q
                      ? {i_pc[N-1:2], 2'b00} + {{(N-3){1'b0}}, 3'd4}
                      : {i_pc[N-1:2], 2'b00};

    assign compressed_parcel = i_pc[1] ? i_response_data[31:16]
                                             : i_response_data[15:0];
    assign starts_cross_word = !cross_pending_q && i_pc[1] &&
                               (i_response_data[17:16] == 2'b11);

    rv32c_decompressor u_decompressor (
        .i_instruction(compressed_parcel),
        .o_instruction(decompressed_instruction),
        .o_illegal(decompressed_illegal)
    );

    always_comb begin
        o_complete     = 1'b0;
        o_instruction  = 32'h0000_0013;
        o_raw_instruction = 32'h0000_0013;
        o_compressed   = 1'b0;
        o_access_fault = 1'b0;

        if (i_response_valid) begin
            if (cross_pending_q) begin
                o_complete     = 1'b1;
                o_instruction  = {i_response_data[15:0], first_half_q};
                o_raw_instruction = {i_response_data[15:0], first_half_q};
                o_access_fault = first_error_q || i_response_error;
            end else if (i_response_error) begin
                o_complete     = 1'b1;
                o_access_fault = 1'b1;
            end else if (!starts_cross_word) begin
                o_complete = 1'b1;
                if (compressed_parcel[1:0] != 2'b11) begin
                    o_compressed  = 1'b1;
                    o_raw_instruction = {16'b0, compressed_parcel};
                    // Feed an illegal 32-bit encoding to the normal decoder so
                    // compressed reserved encodings take the standard illegal
                    // instruction trap path.
                    o_instruction = decompressed_illegal
                                  ? {16'b0, compressed_parcel}
                                  : decompressed_instruction;
                end else begin
                    o_instruction = i_response_data;
                    o_raw_instruction = i_response_data;
                end
            end
        end
    end

    always_ff @(posedge i_clk or negedge i_arst_n) begin
        if (!i_arst_n) begin
            cross_pending_q <= 1'b0;
            first_half_q    <= '0;
            first_error_q   <= 1'b0;
        end else if (i_flush) begin
            cross_pending_q <= 1'b0;
            first_error_q   <= 1'b0;
        end else if (!cross_pending_q) begin
            if (i_response_valid && !i_response_error && starts_cross_word) begin
                cross_pending_q <= 1'b1;
                first_half_q    <= i_response_data[31:16];
                first_error_q   <= i_response_error;
            end
        end else if (i_response_valid && i_consume) begin
            cross_pending_q <= 1'b0;
            first_error_q   <= 1'b0;
        end
    end

endmodule
