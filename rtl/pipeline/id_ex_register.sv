// =============================================================================
// ID/EX Pipeline Register
// =============================================================================
// Stores data between Instruction Decode (ID) and Execute (EX) stages
// Includes all control signals, register data, immediate, and PC
// =============================================================================

module id_ex_register #(
    parameter N = 32
)(
    input  logic             i_clk,
    input  logic             i_arst_n,
    input  logic             i_stall,      // Hold state while memory is waiting
    input  logic             i_flush,      // Flush signal for branch/jump
    
    // Inputs from ID stage
    input  logic [N-1:0]     i_pc,
    input  logic [N-1:0]     i_rs1_data,
    input  logic [N-1:0]     i_rs2_data,
    input  logic [N-1:0]     i_immediate,
    input  logic [4:0]       i_rs1_addr,
    input  logic [4:0]       i_rs2_addr,
    input  logic [4:0]       i_rd_addr,
    
    // Control signals from ID stage
    input  logic             i_reg_write,
    input  logic             i_mem_read,
    input  logic             i_mem_write,
    input  logic [1:0]       i_wb_sel,
    input  logic [1:0]       i_pc_sel,
    input  logic             i_alu_src,
    input  logic             i_alu_a_sel,
    input  logic [3:0]       i_alu_ctrl,
    input  logic             i_branch_en,
    input  logic [2:0]       i_branch_type,
    input  logic [2:0]       i_mem_type,
    input  logic             i_jal,
    input  logic             i_jalr,
    
    // Outputs to EX stage
    output logic [N-1:0]     o_pc,
    output logic [N-1:0]     o_rs1_data,
    output logic [N-1:0]     o_rs2_data,
    output logic [N-1:0]     o_immediate,
    output logic [4:0]       o_rs1_addr,
    output logic [4:0]       o_rs2_addr,
    output logic [4:0]       o_rd_addr,
    
    // Control signals to EX stage
    output logic             o_reg_write,
    output logic             o_mem_read,
    output logic             o_mem_write,
    output logic [1:0]       o_wb_sel,
    output logic [1:0]       o_pc_sel,
    output logic             o_alu_src,
    output logic             o_alu_a_sel,
    output logic [3:0]       o_alu_ctrl,
    output logic             o_branch_en,
    output logic [2:0]       o_branch_type,
    output logic [2:0]       o_mem_type,
    output logic             o_jal,
    output logic             o_jalr
);

    always_ff @(posedge i_clk or negedge i_arst_n) begin
        if (!i_arst_n) begin
            // Reset: Clear all signals
            o_pc          <= 32'h0;
            o_rs1_data    <= 32'h0;
            o_rs2_data    <= 32'h0;
            o_immediate   <= 32'h0;
            o_rs1_addr    <= 5'h0;
            o_rs2_addr    <= 5'h0;
            o_rd_addr     <= 5'h0;
            
            // Clear control signals
            o_reg_write   <= 1'b0;
            o_mem_read    <= 1'b0;
            o_mem_write   <= 1'b0;
            o_wb_sel      <= 2'b0;
            o_pc_sel      <= 2'b0;
            o_alu_src     <= 1'b0;
            o_alu_a_sel   <= 1'b0;
            o_alu_ctrl    <= 4'h0;
            o_branch_en   <= 1'b0;
            o_branch_type <= 3'b0;
            o_mem_type    <= 3'b0;
            o_jal         <= 1'b0;
            o_jalr        <= 1'b0;
        end
        else if (i_stall) begin
            // Keep all outputs stable until the pending memory transfer finishes.
        end
        else if (i_flush) begin
            // Flush: Insert bubble (clear control signals but keep data)
            o_pc          <= 32'h0;
            o_rs1_data    <= 32'h0;
            o_rs2_data    <= 32'h0;
            o_immediate   <= 32'h0;
            o_rs1_addr    <= 5'h0;
            o_rs2_addr    <= 5'h0;
            o_rd_addr     <= 5'h0;
            
            // Clear control signals (creates NOP)
            o_reg_write   <= 1'b0;
            o_mem_read    <= 1'b0;
            o_mem_write   <= 1'b0;
            o_wb_sel      <= 2'b0;
            o_pc_sel      <= 2'b0;
            o_alu_src     <= 1'b0;
            o_alu_a_sel   <= 1'b0;
            o_alu_ctrl    <= 4'h0;
            o_branch_en   <= 1'b0;
            o_branch_type <= 3'b0;
            o_mem_type    <= 3'b0;
            o_jal         <= 1'b0;
            o_jalr        <= 1'b0;
        end
        else begin
            // Normal operation: Pass data through
            o_pc          <= i_pc;
            o_rs1_data    <= i_rs1_data;
            o_rs2_data    <= i_rs2_data;
            o_immediate   <= i_immediate;
            o_rs1_addr    <= i_rs1_addr;
            o_rs2_addr    <= i_rs2_addr;
            o_rd_addr     <= i_rd_addr;
            
            // Pass control signals
            o_reg_write   <= i_reg_write;
            o_mem_read    <= i_mem_read;
            o_mem_write   <= i_mem_write;
            o_wb_sel      <= i_wb_sel;
            o_pc_sel      <= i_pc_sel;
            o_alu_src     <= i_alu_src;
            o_alu_a_sel   <= i_alu_a_sel;
            o_alu_ctrl    <= i_alu_ctrl;
            o_branch_en   <= i_branch_en;
            o_branch_type <= i_branch_type;
            o_mem_type    <= i_mem_type;
            o_jal         <= i_jal;
            o_jalr        <= i_jalr;
        end
    end

endmodule
