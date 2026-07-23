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

    always_ff @(posedge i_clk or negedge i_arst_n) begin
        if (!i_arst_n) begin
            // Reset: Insert NOP (ADDI x0, x0, 0)
            o_valid       <= 1'b0;
            o_access_fault <= 1'b0;
            o_pc          <= 32'h0;
            o_instruction <= 32'h00000013;  // NOP
            o_raw_instruction <= 32'h00000013;
            o_compressed  <= 1'b0;
        end
        else if (i_flush) begin
            // Flush: Insert NOP (bubble)
            o_valid       <= 1'b0;
            o_access_fault <= 1'b0;
            o_pc          <= 32'h0;
            o_instruction <= 32'h00000013;  // NOP
            o_raw_instruction <= 32'h00000013;
            o_compressed  <= 1'b0;
        end
        else if (!i_stall) begin
            // Normal operation: Pass data through
            o_valid       <= i_valid;
            o_access_fault <= i_access_fault;
            o_pc          <= i_pc;
            o_instruction <= i_instruction;
            o_raw_instruction <= i_raw_instruction;
            o_compressed  <= i_compressed;
        end
        // If stall: Keep current values (no else clause)
    end

endmodule
