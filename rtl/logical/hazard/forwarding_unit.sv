// =============================================================================
// Forwarding Unit (Data Forwarding / Bypassing)
// =============================================================================
// Resolves data hazards by forwarding data from later pipeline stages
// back to the EX stage, avoiding unnecessary stalls
// =============================================================================

module forwarding_unit (
    // Inputs from ID/EX stage (current instruction in EX)
    input  logic [4:0]  i_ex_rs1_addr,
    input  logic [4:0]  i_ex_rs2_addr,
    
    // Inputs from EX/MEM stage (previous instruction in MEM)
    input  logic [4:0]  i_mem_rd_addr,
    input  logic        i_mem_reg_write,
    
    // Inputs from MEM/WB stage (instruction in WB)
    input  logic [4:0]  i_wb_rd_addr,
    input  logic        i_wb_reg_write,
    
    // Outputs: Forwarding control signals
    output logic [1:0]  o_forward_a,    // Forward control for ALU operand A
    output logic [1:0]  o_forward_b     // Forward control for ALU operand B
);

    // ==========================================================================
    // Forwarding Control Encoding
    // ==========================================================================
    // 00: No forwarding (use data from ID/EX register)
    // 01: Forward from MEM/WB stage (WB data)
    // 10: Forward from EX/MEM stage (ALU result or memory address)
    // 11: Reserved (not used)
    // ==========================================================================
    
    logic mem_rs1_match, mem_rs2_match;
    logic wb_rs1_match, wb_rs2_match;
    
    // ==========================================================================
    // Forwarding Logic for ALU Operand A (rs1)
    // ==========================================================================
    // Priority:
    // 1. EX/MEM forwarding (most recent)
    // 2. MEM/WB forwarding (older)
    // 3. No forwarding (use register file data)
    // ==========================================================================
    
    assign mem_rs1_match = i_mem_reg_write && (i_mem_rd_addr != 5'b0) &&
                           (i_mem_rd_addr == i_ex_rs1_addr);
    assign wb_rs1_match = i_wb_reg_write && (i_wb_rd_addr != 5'b0) &&
                          (i_wb_rd_addr == i_ex_rs1_addr);

    // Bit 1 directly controls the fast EX/MEM bypass.  Suppress the older WB
    // match only on bit 0 to preserve newest-result priority.
    assign o_forward_a = {mem_rs1_match, wb_rs1_match && !mem_rs1_match};
    
    // ==========================================================================
    // Forwarding Logic for ALU Operand B (rs2)
    // ==========================================================================
    // Same priority as operand A
    // Note: rs2 is also used for store data in Store instructions
    // ==========================================================================
    
    assign mem_rs2_match = i_mem_reg_write && (i_mem_rd_addr != 5'b0) &&
                           (i_mem_rd_addr == i_ex_rs2_addr);
    assign wb_rs2_match = i_wb_reg_write && (i_wb_rd_addr != 5'b0) &&
                          (i_wb_rd_addr == i_ex_rs2_addr);
    assign o_forward_b = {mem_rs2_match, wb_rs2_match && !mem_rs2_match};

endmodule
