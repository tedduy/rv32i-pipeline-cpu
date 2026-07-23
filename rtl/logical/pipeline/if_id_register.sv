// =============================================================================
// IF/ID Pipeline Register
// =============================================================================
// Stores data between Instruction Fetch (IF) and Instruction Decode (ID) stages
// Includes stall and flush capabilities for hazard handling
// =============================================================================

module if_id_register #(
    parameter N = 32
)(
    input  logic             i_clk,
    input  logic             i_arst_n,
    input  logic             i_stall,      // Stall signal from hazard unit
    input  logic             i_flush,      // Flush signal for branch/jump
    
    // Inputs from IF stage
    input  logic             i_valid,
    input  logic             i_access_fault,
    input  logic [N-1:0]     i_pc,
    input  logic [N-1:0]     i_instruction,
    input  logic [N-1:0]     i_raw_instruction,
    input  logic             i_compressed,
    
    // Outputs to ID stage
    output logic             o_valid,
    output logic             o_access_fault,
    output logic [N-1:0]     o_pc,
    output logic [N-1:0]     o_instruction,
    output logic [N-1:0]     o_raw_instruction,
    output logic             o_compressed
);

    // Keep the decoded instruction benign while the stage is invalid. Some
    // decode controls feed pipeline control before the valid bit is consumed,
    // so an uninitialized instruction could otherwise propagate X values.
    always_ff @(posedge i_clk or negedge i_arst_n) begin
        if (!i_arst_n) begin
            o_valid        <= 1'b0;
            o_access_fault <= 1'b0;
            o_instruction  <= 32'h0000_0013;
            o_compressed   <= 1'b0;
        end else if (i_flush) begin
            o_valid        <= 1'b0;
            o_access_fault <= 1'b0;
            o_instruction  <= 32'h0000_0013;
            o_compressed   <= 1'b0;
        end else if (!i_stall) begin
            o_valid        <= i_valid;
            o_access_fault <= i_access_fault;
            o_instruction  <= i_instruction;
            o_compressed   <= i_compressed;
        end
    end

    // PC and raw instruction are consumed only on valid exception/commit
    // paths. Keep them off reset and flush so 64 payload flops can use the
    // smaller non-resettable cells without adding logic to the decode path.
    always_ff @(posedge i_clk) begin
        if (!i_stall) begin
            o_pc              <= i_pc;
            o_raw_instruction <= i_raw_instruction;
        end
    end

endmodule
