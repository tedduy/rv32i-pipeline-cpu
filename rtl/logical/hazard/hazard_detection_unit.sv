// =============================================================================
// Hazard Detection Unit
// =============================================================================
// Detects data hazards and generates stall signals
// Primary focus: Load-Use hazards (when a load instruction is followed by
// an instruction that uses the loaded data)
// =============================================================================

module hazard_detection_unit (
    // Inputs from ID stage (current instruction being decoded)
    input  logic [4:0]  i_id_rs1_addr,
    input  logic [4:0]  i_id_rs2_addr,
    
    // Register read intent from ID stage
    input  logic        i_id_rs1_read,
    input  logic        i_id_rs2_read,
    input  logic        i_id_mem_write,  // 1 if ID instruction is a store
    
    // Inputs from EX stage (instruction currently in execute)
    input  logic [4:0]  i_ex_rd_addr,
    input  logic        i_ex_mem_read,
    input  logic        i_ex_reg_write,
    
    // Branch/Jump signals from EX stage
    input  logic        i_ex_branch_taken,
    input  logic        i_ex_jal,
    input  logic        i_ex_jalr,
    
    // Outputs
    output logic        o_stall_pc,      // Stall PC (keep current PC)
    output logic        o_stall_if_id,   // Stall IF/ID register
    output logic        o_flush_id_ex,   // Flush ID/EX register (insert bubble)
    output logic        o_flush_if_id    // Flush IF/ID register (for branch/jump)
);

    logic load_use_hazard;
    logic control_hazard;
    
    // ==========================================================================
    // Load-Use Hazard Detection
    // ==========================================================================
    // Occurs when:
    // 1. Current EX stage instruction is a LOAD (mem_read = 1)
    // 2. Current EX stage instruction writes to a register (reg_write = 1)
    // 3. Current ID stage instruction actually reads from that register
    //    (either rs1_read=1 and rs1 matches, or rs2_read=1 and rs2 matches)
    // 4. The destination register is not x0
    // 5. EXCEPTION: If the ID instruction is a STORE (mem_write=1), and it
    //    only depends on the load for its data to store (rs2 matches), we DO
    //    NOT stall. The store data will be forwarded in the MEM stage.
    //    (If it depends on rs1 for the address, we still must stall).
    //
    // Solution: Stall for 1 cycle
    // ==========================================================================
    
    always_comb begin
        load_use_hazard = 1'b0;
        
        // Check if EX stage has a load instruction
        if (i_ex_mem_read && i_ex_reg_write && (i_ex_rd_addr != 5'b0)) begin
            // Check if ID stage actually reads from EX's destination register
            if ((i_id_rs1_addr == i_ex_rd_addr) && i_id_rs1_read) begin
                load_use_hazard = 1'b1;
            end else if ((i_id_rs2_addr == i_ex_rd_addr) && i_id_rs2_read && !i_id_mem_write) begin
                load_use_hazard = 1'b1;
            end
        end
    end
    
    // ==========================================================================
    // Control Hazard Detection (Branch/Jump taken)
    // ==========================================================================
    // Occurs when:
    // 1. A branch is taken in EX stage
    // 2. A JAL or JALR instruction is in EX stage
    //
    // Solution: Flush IF/ID and ID/EX stages (2 bubbles)
    // ==========================================================================
    
    always_comb begin
        control_hazard = i_ex_branch_taken || i_ex_jal || i_ex_jalr;
    end
    
    // ==========================================================================
    // Output Signal Generation
    // ==========================================================================
    
    always_comb begin
        // Default: No stall or flush
        o_stall_pc    = 1'b0;
        o_stall_if_id = 1'b0;
        o_flush_id_ex = 1'b0;
        o_flush_if_id = 1'b0;
        
        // Load-Use Hazard: Stall pipeline
        if (load_use_hazard) begin
            o_stall_pc    = 1'b1;  // Keep current PC
            o_stall_if_id = 1'b1;  // Keep current IF/ID register
            o_flush_id_ex = 1'b1;  // Insert bubble in ID/EX (NOP)
        end
        
        // Control Hazard: Flush wrong-path instructions
        if (control_hazard) begin
            o_flush_if_id = 1'b1;  // Flush IF/ID (instruction after branch)
            o_flush_id_ex = 1'b1;  // Flush ID/EX (instruction in decode)
        end
    end

endmodule
