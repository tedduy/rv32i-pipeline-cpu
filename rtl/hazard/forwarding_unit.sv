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
    
    parameter [1:0]
        FWD_NONE   = 2'b00,  // No forwarding
        FWD_MEM_WB = 2'b01,  // Forward from MEM/WB
        FWD_EX_MEM = 2'b10;  // Forward from EX/MEM
    
    // ==========================================================================
    // Forwarding Logic for ALU Operand A (rs1)
    // ==========================================================================
    // Priority:
    // 1. EX/MEM forwarding (most recent)
    // 2. MEM/WB forwarding (older)
    // 3. No forwarding (use register file data)
    // ==========================================================================
    
    always_comb begin
        o_forward_a = FWD_NONE;
        
        // EX hazard: Forward from EX/MEM stage (highest priority)
        if (i_mem_reg_write && (i_mem_rd_addr != 5'b0) && (i_mem_rd_addr == i_ex_rs1_addr)) begin
            o_forward_a = FWD_EX_MEM;
        end
        // MEM hazard: Forward from MEM/WB stage
        else if (i_wb_reg_write && (i_wb_rd_addr != 5'b0) && (i_wb_rd_addr == i_ex_rs1_addr)) begin
            o_forward_a = FWD_MEM_WB;
        end
    end
    
    // ==========================================================================
    // Forwarding Logic for ALU Operand B (rs2)
    // ==========================================================================
    // Same priority as operand A
    // Note: rs2 is also used for store data in Store instructions
    // ==========================================================================
    
    always_comb begin
        o_forward_b = FWD_NONE;
        
        // EX hazard: Forward from EX/MEM stage (highest priority)
        if (i_mem_reg_write && (i_mem_rd_addr != 5'b0) && (i_mem_rd_addr == i_ex_rs2_addr)) begin
            o_forward_b = FWD_EX_MEM;
        end
        // MEM hazard: Forward from MEM/WB stage
        else if (i_wb_reg_write && (i_wb_rd_addr != 5'b0) && (i_wb_rd_addr == i_ex_rs2_addr)) begin
            o_forward_b = FWD_MEM_WB;
        end
    end

endmodule
