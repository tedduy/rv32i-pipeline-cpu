// =============================================================================
// EX/MEM Pipeline Register
// =============================================================================
// Stores data between Execute (EX) and Memory (MEM) stages
// =============================================================================

module EX_MEM_Register #(
    parameter N = 32
)(
    input  logic             i_clk,
    input  logic             i_arst_n,
    input  logic             i_flush,
    
    // Inputs from EX stage
    input  logic [N-1:0]     i_alu_result,
    input  logic [N-1:0]     i_rs2_data,
    input  logic [N-1:0]     i_pc_branch_target,
    input  logic [N-1:0]     i_jump_target,
    input  logic [N-1:0]     i_return_addr,
    input  logic [N-1:0]     i_immediate,
    input  logic [4:0]       i_rd_addr,
    input  logic             i_branch_taken,
    
    // Control signals from EX stage
    input  logic             i_reg_write,
    input  logic             i_mem_read,
    input  logic             i_mem_write,
    input  logic [1:0]       i_wb_sel,
    input  logic [2:0]       i_mem_type,
    
    // UPDATE: Input JAL & JALR from EX
    input  logic             i_jal, 
    input  logic             i_jalr,
    
    // Outputs to MEM stage
    output logic [N-1:0]     o_alu_result,
    output logic [N-1:0]     o_rs2_data,
    output logic [N-1:0]     o_pc_branch_target,
    output logic [N-1:0]     o_jump_target,
    output logic [N-1:0]     o_return_addr,
    output logic [N-1:0]     o_immediate,
    output logic [4:0]       o_rd_addr,
    output logic             o_branch_taken,
    
    // Control signals to MEM stage
    output logic             o_reg_write,
    output logic             o_mem_read,
    output logic             o_mem_write,
    output logic [1:0]       o_wb_sel,
    output logic [2:0]       o_mem_type,
    
    // UPDATE: Output JAL & JALR to MEM
    output logic             o_jal,
    output logic             o_jalr
);

    always_ff @(posedge i_clk or negedge i_arst_n) begin
        if (!i_arst_n) begin
            // Reset logic
            o_alu_result       <= 32'h0;
            o_rs2_data         <= 32'h0;
            o_pc_branch_target <= 32'h0;
            o_jump_target      <= 32'h0;
            o_return_addr      <= 32'h0;
            o_immediate        <= 32'h0;
            o_rd_addr          <= 5'h0;
            o_branch_taken     <= 1'b0;
            o_reg_write        <= 1'b0;
            o_mem_read         <= 1'b0;
            o_mem_write        <= 1'b0;
            o_wb_sel           <= 2'b0;
            o_mem_type         <= 3'b0;
            
            // UPDATE: Reset JAL/JALR
            o_jal              <= 1'b0;
            o_jalr             <= 1'b0;
        end
        else if (i_flush) begin
            // Flush logic
            o_alu_result       <= 32'h0;
            o_rs2_data         <= 32'h0;
            o_pc_branch_target <= 32'h0;
            o_jump_target      <= 32'h0;
            o_return_addr      <= 32'h0;
            o_immediate        <= 32'h0;
            o_rd_addr          <= 5'h0;
            o_branch_taken     <= 1'b0;
            o_reg_write        <= 1'b0;
            o_mem_read         <= 1'b0;
            o_mem_write        <= 1'b0;
            o_wb_sel           <= 2'b0;
            o_mem_type         <= 3'b0;
            
            // UPDATE: Flush JAL/JALR
            o_jal              <= 1'b0;
            o_jalr             <= 1'b0;
        end
        else begin
            // Normal operation
            o_alu_result       <= i_alu_result;
            o_rs2_data         <= i_rs2_data;
            o_pc_branch_target <= i_pc_branch_target;
            o_jump_target      <= i_jump_target;
            o_return_addr      <= i_return_addr;
            o_immediate        <= i_immediate;
            o_rd_addr          <= i_rd_addr;
            o_branch_taken     <= i_branch_taken;
            o_reg_write        <= i_reg_write;
            o_mem_read         <= i_mem_read;
            o_mem_write        <= i_mem_write;
            o_wb_sel           <= i_wb_sel;
            o_mem_type         <= i_mem_type;
            
            // UPDATE: Pass JAL/JALR
            o_jal              <= i_jal;
            o_jalr             <= i_jalr;
        end
    end

endmodule