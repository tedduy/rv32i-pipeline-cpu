// =============================================================================
// RV32I 5-Stage Pipeline CPU Top Module
// =============================================================================
// UPDATED: Fixed synchronization for W_jal, W_jalr, W_branch_taken to WB stage
// =============================================================================

module rv32i_top #(
    parameter N = 32,
    parameter IMEM_DEPTH = 256,
    parameter DMEM_BYTES = 256,
    parameter REG_DEPTH = 32
)(
    input  logic i_clk,
    input  logic i_arst_n,
    
    // Debug/Test outputs
    output logic [N-1:0] W_PC_out,
    output logic [N-1:0] instruction,
    output logic [N-1:0] W_RD1,
    output logic [N-1:0] W_RD2,
    output logic [N-1:0] W_m1,
    output logic [N-1:0] W_m2,
    output logic [N-1:0] W_ALUout,
    output logic [N-1:0] W_WB_data,
    output logic [4:0]   W_rd_addr,
    output logic         W_reg_write,
    output logic         W_mem_write,
    output logic         W_mem_read,
    output logic         W_branch_taken, // Đã đồng bộ WB
    output logic [N-1:0] W_mem_addr,
    output logic [N-1:0] W_mem_wdata,
    output logic [N-1:0] W_mem_rdata,
    output logic         W_jal,          // Đã đồng bộ WB
    output logic         W_jalr,         // Đã đồng bộ WB
    // Pipeline control signals
    output logic         W_stall,
    output logic         W_flush,
    // Additional debug signals
    output logic [N-1:0] W_immediate,
    output logic         W_ALUSrc
);

    // ==========================================================================
    // IF Stage Signals
    // ==========================================================================
    logic [N-1:0] if_pc_current, if_pc_next, if_pc_plus_4;
    logic [N-1:0] if_instruction;
    
    // ==========================================================================
    // IF/ID Pipeline Register Signals
    // ==========================================================================
    logic [N-1:0] id_pc, id_instruction;
    
    // ==========================================================================
    // ID Stage Signals
    // ==========================================================================
    logic [4:0]  id_rs1_addr, id_rs2_addr, id_rd_addr;
    logic [N-1:0] id_rs1_data, id_rs2_data;
    logic [N-1:0] id_immediate;
    
    // ID Control signals
    logic        id_reg_write, id_mem_read, id_mem_write;
    logic [2:0]  id_imm_sel;
    logic [1:0]  id_wb_sel, id_pc_sel;
    logic        id_alu_src, id_alu_a_sel;
    logic [3:0]  id_alu_ctrl;
    logic        id_branch_en;
    logic [2:0]  id_branch_type;
    logic [2:0]  id_mem_type;
    logic        id_jal, id_jalr;
    
    // ==========================================================================
    // ID/EX Pipeline Register Signals
    // ==========================================================================
    logic [N-1:0] ex_pc, ex_rs1_data, ex_rs2_data, ex_immediate;
    logic [4:0]   ex_rs1_addr, ex_rs2_addr, ex_rd_addr;
    logic         ex_reg_write, ex_mem_read, ex_mem_write;
    logic [1:0]   ex_wb_sel, ex_pc_sel;
    logic         ex_alu_src, ex_alu_a_sel;
    logic [3:0]   ex_alu_ctrl;
    logic         ex_branch_en;
    logic [2:0]   ex_branch_type, ex_mem_type;
    logic         ex_jal, ex_jalr;
    // Debug: Original register values for tracking
    logic [N-1:0] ex_rd1_orig, ex_rd2_orig;
    
    // ==========================================================================
    // EX Stage Signals
    // ==========================================================================
    logic [N-1:0] ex_alu_operand_a, ex_alu_operand_b;
    logic [N-1:0] ex_alu_operand_a_forwarded, ex_alu_operand_b_forwarded;
    logic [N-1:0] ex_alu_result;
    logic         ex_alu_zero;
    logic [N-1:0] ex_pc_branch_target;
    logic         ex_branch_taken;
    logic [N-1:0] ex_jump_target, ex_return_addr;
    logic [N-1:0] ex_rs2_data_forwarded;  // For store operations
    
    // ==========================================================================
    // EX/MEM Pipeline Register Signals
    // ==========================================================================
    logic [N-1:0] mem_alu_result, mem_rs2_data;
    logic [N-1:0] mem_pc_branch_target, mem_jump_target, mem_return_addr;
    logic [N-1:0] mem_immediate;
    logic [4:0]   mem_rd_addr;
    logic         mem_branch_taken;
    logic         mem_reg_write, mem_mem_read, mem_mem_write;
    logic [1:0]   mem_wb_sel;
    logic [2:0]   mem_mem_type;
    logic         mem_jal, mem_jalr; // <--- UPDATE: Dây nối ở tầng MEM
    // Debug: Original register values for tracking
    logic [N-1:0] mem_rd1_orig, mem_rd2_orig;
    
    // ==========================================================================
    // MEM Stage Signals
    // ==========================================================================
    logic [N-1:0] mem_read_data;
    logic [N-1:0] mem_load_data, mem_store_data;
    logic [3:0]   mem_byte_enable;
    
    // ==========================================================================
    // MEM/WB Pipeline Register Signals
    // ==========================================================================
    logic [N-1:0] wb_alu_result, wb_mem_read_data, wb_return_addr, wb_immediate;
    logic [4:0]   wb_rd_addr;
    logic         wb_reg_write;
    logic [1:0]   wb_wb_sel;
    logic         wb_jal, wb_jalr;         // <--- UPDATE: Dây nối ở tầng WB
    logic         wb_branch_taken;         // <--- UPDATE: Dây nối ở tầng WB
    // Debug: Original register values for tracking
    logic [N-1:0] wb_rd1_orig, wb_rd2_orig;
    
    // ==========================================================================
    // WB Stage Signals
    // ==========================================================================
    logic [N-1:0] wb_data;
    
    // ==========================================================================
    // Hazard Detection Signals
    // ==========================================================================
    logic stall_pc, stall_if_id, flush_id_ex, flush_if_id;
    
    // ==========================================================================
    // Forwarding Signals
    // ==========================================================================
    logic [1:0] forward_a, forward_b;
    
    // ==========================================================================
    // Debug Output Assignments with Pipeline Tracking
    // ==========================================================================
    
    // Pipeline tracking registers for PC
    logic [N-1:0] id_pc_reg, ex_pc_reg, mem_pc_reg, wb_pc_reg;
    
    always_ff @(posedge i_clk or negedge i_arst_n) begin
        if (!i_arst_n) begin
            id_pc_reg  <= '0;
            ex_pc_reg  <= '0;
            mem_pc_reg <= '0;
            wb_pc_reg  <= '0;
        end else begin
            id_pc_reg  <= if_pc_current;
            ex_pc_reg  <= id_pc_reg;
            mem_pc_reg <= ex_pc_reg;
            wb_pc_reg  <= mem_pc_reg;
        end
    end
    
    // Pipeline tracking registers for instruction
    logic [N-1:0] id_inst_reg, ex_inst_reg, mem_inst_reg, wb_inst_reg;
    
    always_ff @(posedge i_clk or negedge i_arst_n) begin
        if (!i_arst_n) begin
            id_inst_reg  <= '0;
            ex_inst_reg  <= '0;
            mem_inst_reg <= '0;
            wb_inst_reg  <= '0;
        end else begin
            id_inst_reg  <= if_instruction;
            ex_inst_reg  <= id_inst_reg;
            mem_inst_reg <= ex_inst_reg;
            wb_inst_reg  <= mem_inst_reg;
        end
    end
    
    // Output synchronized signals from WB stage
    assign W_PC_out       = wb_pc_reg;
    assign instruction    = wb_inst_reg;
    assign W_RD1          = wb_rd1_orig;
    assign W_RD2          = wb_rd2_orig;
    assign W_m1           = ex_alu_operand_b;
    assign W_m2           = ex_pc_branch_target;
    assign W_ALUout       = wb_alu_result;
    assign W_WB_data      = wb_data;
    assign W_rd_addr      = wb_rd_addr;
    assign W_reg_write    = wb_reg_write;
    assign W_mem_write    = mem_mem_write;
    assign W_mem_read     = mem_mem_read;
    
    // UPDATE: Đồng bộ các tín hiệu Debug từ tầng WB
    assign W_branch_taken = wb_branch_taken; 
    assign W_jal          = wb_jal;
    assign W_jalr         = wb_jalr;
    
    assign W_mem_addr     = mem_alu_result;
    assign W_mem_wdata    = mem_store_data;
    assign W_mem_rdata    = mem_load_data;
    assign W_stall        = stall_if_id;
    assign W_flush        = flush_id_ex | flush_if_id;
    assign W_immediate    = wb_immediate;
    assign W_ALUSrc       = ex_alu_src;
    
    // ==========================================================================
    // STAGE 1: INSTRUCTION FETCH (IF)
    // ==========================================================================
    
    // PC + 4 calculation
    adder_N_bit #(.N(N)) if_pc_adder (
        .a(if_pc_current),
        .b(32'd4),
        .sum(if_pc_plus_4)
    );
    
    // PC next selection (from EX stage for branches/jumps)
    logic [31:0] branch_or_plus4;
    assign branch_or_plus4 = ex_branch_taken ? ex_pc_branch_target : if_pc_plus_4;
    
    mux4to1 #(.N(32)) if_pc_mux (
        .i_d0(if_pc_plus_4),
        .i_d1(branch_or_plus4),
        .i_d2(ex_jump_target),
        .i_d3(ex_jump_target),
        .i_sel(ex_pc_sel),
        .o_y(if_pc_next)
    );
    
    // Program Counter (with stall capability)
    Program_Counter #(.N(N)) if_pc_reg (
        .i_clk(i_clk),
        .i_arst_n(i_arst_n),
        .i_PC(stall_pc ? if_pc_current : if_pc_next),
        .o_PC(if_pc_current)
    );
    
    // Instruction Memory
    Instruction_Mem #(
        .N(N),
        .DEPTH(IMEM_DEPTH)
    ) if_imem (
        .i_clk(i_clk),
        .i_arst_n(i_arst_n),
        .i_addr(if_pc_current),
        .o_inst(if_instruction)
    );
    
    // ==========================================================================
    // IF/ID Pipeline Register
    // ==========================================================================
    
    IF_ID_Register #(.N(N)) if_id_reg (
        .i_clk(i_clk),
        .i_arst_n(i_arst_n),
        .i_stall(stall_if_id),
        .i_flush(flush_if_id),
        .i_pc(if_pc_current),
        .i_instruction(if_instruction),
        .o_pc(id_pc),
        .o_instruction(id_instruction)
    );
    
    // ==========================================================================
    // STAGE 2: INSTRUCTION DECODE (ID)
    // ==========================================================================
    
    // Instruction field extraction
    assign id_rs1_addr = id_instruction[19:15];
    assign id_rs2_addr = id_instruction[24:20];
    assign id_rd_addr  = id_instruction[11:7];
    
    // Control Unit
    Control_Unit id_control (
        .i_instruction(id_instruction),
        .o_RegWrite(id_reg_write),
        .o_MemRead(id_mem_read),
        .o_MemWrite(id_mem_write),
        .o_ImmSel(id_imm_sel),
        .o_WBSel(id_wb_sel),
        .o_PCSel(id_pc_sel),
        .o_ALUSrc(id_alu_src),
        .o_ALUASel(id_alu_a_sel),
        .o_ALUCtrl(id_alu_ctrl),
        .o_BranchEn(id_branch_en),
        .o_BranchType(id_branch_type),
        .o_MemType(id_mem_type),
        .o_JAL(id_jal),
        .o_JALR(id_jalr)
    );
    
    // Register File (write happens in WB stage)
    Reg_File #(
        .N(N),
        .DEPTH(REG_DEPTH)
    ) id_regfile (
        .i_clk(i_clk),
        .i_arst_n(i_arst_n),
        .i_we(wb_reg_write),
        .i_raddr1(id_rs1_addr),
        .i_raddr2(id_rs2_addr),
        .i_waddr(wb_rd_addr),
        .i_wdata(wb_data),
        .o_rdata1(id_rs1_data),
        .o_rdata2(id_rs2_data)
    );
    
    // Immediate Generation
    Imm_Gen #(.N(N)) id_immgen (
        .i_inst(id_instruction),
        .o_imm(id_immediate)
    );
    
    // ==========================================================================
    // Hazard Detection Unit
    // ==========================================================================
    
    Hazard_Detection_Unit hazard_unit (
        .i_id_rs1_addr(id_rs1_addr),
        .i_id_rs2_addr(id_rs2_addr),
        .i_ex_rd_addr(ex_rd_addr),
        .i_ex_mem_read(ex_mem_read),
        .i_ex_reg_write(ex_reg_write),
        .i_ex_branch_taken(ex_branch_taken),
        .i_ex_jal(ex_jal),
        .i_ex_jalr(ex_jalr),
        .o_stall_pc(stall_pc),
        .o_stall_if_id(stall_if_id),
        .o_flush_id_ex(flush_id_ex),
        .o_flush_if_id(flush_if_id)
    );
    
    // ==========================================================================
    // ID/EX Pipeline Register
    // ==========================================================================
    
    ID_EX_Register #(.N(N)) id_ex_reg (
        .i_clk(i_clk),
        .i_arst_n(i_arst_n),
        .i_flush(flush_id_ex),
        .i_pc(id_pc),
        .i_rs1_data(id_rs1_data),
        .i_rs2_data(id_rs2_data),
        .i_immediate(id_immediate),
        .i_rs1_addr(id_rs1_addr),
        .i_rs2_addr(id_rs2_addr),
        .i_rd_addr(id_rd_addr),
        .i_reg_write(id_reg_write),
        .i_mem_read(id_mem_read),
        .i_mem_write(id_mem_write),
        .i_wb_sel(id_wb_sel),
        .i_pc_sel(id_pc_sel),
        .i_alu_src(id_alu_src),
        .i_alu_a_sel(id_alu_a_sel),
        .i_alu_ctrl(id_alu_ctrl),
        .i_branch_en(id_branch_en),
        .i_branch_type(id_branch_type),
        .i_mem_type(id_mem_type),
        .i_jal(id_jal),
        .i_jalr(id_jalr),
        .o_pc(ex_pc),
        .o_rs1_data(ex_rs1_data),
        .o_rs2_data(ex_rs2_data),
        .o_immediate(ex_immediate),
        .o_rs1_addr(ex_rs1_addr),
        .o_rs2_addr(ex_rs2_addr),
        .o_rd_addr(ex_rd_addr),
        .o_reg_write(ex_reg_write),
        .o_mem_read(ex_mem_read),
        .o_mem_write(ex_mem_write),
        .o_wb_sel(ex_wb_sel),
        .o_pc_sel(ex_pc_sel),
        .o_alu_src(ex_alu_src),
        .o_alu_a_sel(ex_alu_a_sel),
        .o_alu_ctrl(ex_alu_ctrl),
        .o_branch_en(ex_branch_en),
        .o_branch_type(ex_branch_type),
        .o_mem_type(ex_mem_type),
        .o_jal(ex_jal),
        .o_jalr(ex_jalr)
    );
    
    // Track original RD1/RD2 values through EX stage
    always_ff @(posedge i_clk or negedge i_arst_n) begin
        if (!i_arst_n) begin
            ex_rd1_orig <= '0;
            ex_rd2_orig <= '0;
        end else if (flush_id_ex) begin
            ex_rd1_orig <= '0;
            ex_rd2_orig <= '0;
        end else begin
            ex_rd1_orig <= id_rs1_data;
            ex_rd2_orig <= id_rs2_data;
        end
    end
    
    // ==========================================================================
    // STAGE 3: EXECUTE (EX)
    // ==========================================================================
    
    // Forwarding Unit
    Forwarding_Unit forward_unit (
        .i_ex_rs1_addr(ex_rs1_addr),
        .i_ex_rs2_addr(ex_rs2_addr),
        .i_mem_rd_addr(mem_rd_addr),
        .i_mem_reg_write(mem_reg_write),
        .i_wb_rd_addr(wb_rd_addr),
        .i_wb_reg_write(wb_reg_write),
        .o_forward_a(forward_a),
        .o_forward_b(forward_b)
    );
    
    // Forward rs1_data
    mux3to1 #(.N(N)) ex_forward_a_mux (
        .i_d0(ex_rs1_data),           // No forwarding
        .i_d1(wb_data),                // Forward from WB
        .i_d2(mem_alu_result),         // Forward from MEM
        .i_sel(forward_a),
        .o_y(ex_alu_operand_a_forwarded)
    );
    
    // Forward rs2_data
    mux3to1 #(.N(N)) ex_forward_b_mux (
        .i_d0(ex_rs2_data),           // No forwarding
        .i_d1(wb_data),                // Forward from WB
        .i_d2(mem_alu_result),         // Forward from MEM
        .i_sel(forward_b),
        .o_y(ex_rs2_data_forwarded)
    );
    
    // ALU operand A selection (PC or rs1)
    assign ex_alu_operand_a = ex_alu_a_sel ? ex_pc : ex_alu_operand_a_forwarded;
    
    // ALU operand B selection (immediate or rs2)
    assign ex_alu_operand_b = ex_alu_src ? ex_immediate : ex_rs2_data_forwarded;
    
    // ALU Unit
    ALU_Unit #(.N(N)) ex_alu (
        .i_operand_a(ex_alu_operand_a),
        .i_operand_b(ex_alu_operand_b),
        .i_alu_ctrl(ex_alu_ctrl),
        .o_alu_result(ex_alu_result),
        .o_zero_flag(ex_alu_zero)
    );
    
    // Branch target calculation
    adder_N_bit #(.N(N)) ex_branch_adder (
        .a(ex_pc),
        .b(ex_immediate),
        .sum(ex_pc_branch_target)
    );
    
    // Branch Unit
    Branch_Unit #(.N(N)) ex_branch (
        .i_rs1_data(ex_alu_operand_a_forwarded),
        .i_rs2_data(ex_rs2_data_forwarded),
        .i_branch_type(ex_branch_type),
        .i_branch_enable(ex_branch_en),
        .o_branch_taken(ex_branch_taken)
    );
    
    // Jump Unit
    Jump_Unit #(.N(N)) ex_jump (
        .i_pc(ex_pc),
        .i_rs1_data(ex_alu_operand_a_forwarded),
        .i_immediate(ex_immediate),
        .i_jal(ex_jal),
        .i_jalr(ex_jalr),
        .o_jump_target(ex_jump_target),
        .o_return_addr(ex_return_addr)
    );
    
    // ==========================================================================
    // EX/MEM Pipeline Register
    // ==========================================================================
    
    EX_MEM_Register #(.N(N)) ex_mem_reg (
        .i_clk(i_clk),
        .i_arst_n(i_arst_n),
        .i_flush(1'b0),
        .i_alu_result(ex_alu_result),
        .i_rs2_data(ex_rs2_data_forwarded),
        .i_pc_branch_target(ex_pc_branch_target),
        .i_jump_target(ex_jump_target),
        .i_return_addr(ex_return_addr),
        .i_immediate(ex_immediate),
        .i_rd_addr(ex_rd_addr),
        .i_branch_taken(ex_branch_taken),
        .i_reg_write(ex_reg_write),
        .i_mem_read(ex_mem_read),
        .i_mem_write(ex_mem_write),
        .i_wb_sel(ex_wb_sel),
        .i_mem_type(ex_mem_type),
        
        // UPDATE: Nối tín hiệu JAL, JALR từ EX
        .i_jal(ex_jal),
        .i_jalr(ex_jalr),
        .o_jal(mem_jal),
        .o_jalr(mem_jalr),
        
        .o_alu_result(mem_alu_result),
        .o_rs2_data(mem_rs2_data),
        .o_pc_branch_target(mem_pc_branch_target),
        .o_jump_target(mem_jump_target),
        .o_return_addr(mem_return_addr),
        .o_immediate(mem_immediate),
        .o_rd_addr(mem_rd_addr),
        .o_branch_taken(mem_branch_taken),
        .o_reg_write(mem_reg_write),
        .o_mem_read(mem_mem_read),
        .o_mem_write(mem_mem_write),
        .o_wb_sel(mem_wb_sel),
        .o_mem_type(mem_mem_type)
    );
    
    // Track original RD1/RD2 values through MEM stage
    always_ff @(posedge i_clk or negedge i_arst_n) begin
        if (!i_arst_n) begin
            mem_rd1_orig <= '0;
            mem_rd2_orig <= '0;
        end else begin
            mem_rd1_orig <= ex_rd1_orig;
            mem_rd2_orig <= ex_rd2_orig;
        end
    end
    
    // ==========================================================================
    // STAGE 4: MEMORY ACCESS (MEM)
    // ==========================================================================
    
    // Load/Store Unit
    Load_Store_Unit #(.N(N)) mem_lsu (
        .i_mem_type(mem_mem_type),
        .i_mem_read(mem_mem_read),
        .i_mem_write(mem_mem_write),
        .i_byte_offset(mem_alu_result[1:0]),
        .i_mem_read_data(mem_read_data),
        .i_store_data(mem_rs2_data),
        .o_load_data(mem_load_data),
        .o_store_data(mem_store_data),
        .o_byte_enable(mem_byte_enable)
    );
    
    // Data Memory
    Data_Memory #(
        .N(N),
        .BYTES(DMEM_BYTES)
    ) mem_dmem (
        .i_clk(i_clk),
        .i_arst_n(i_arst_n),
        .i_we(mem_mem_write),
        .i_re(mem_mem_read),
        .i_addr(mem_alu_result),
        .i_wdata(mem_store_data),
        .i_wstrb(mem_byte_enable),
        .o_rdata(mem_read_data)
    );
    
    // ==========================================================================
    // MEM/WB Pipeline Register
    // ==========================================================================
    
    MEM_WB_Register #(.N(N)) mem_wb_reg (
        .i_clk(i_clk),
        .i_arst_n(i_arst_n),
        .i_alu_result(mem_alu_result),
        .i_mem_read_data(mem_load_data),
        .i_return_addr(mem_return_addr),
        .i_immediate(mem_immediate),
        .i_rd_addr(mem_rd_addr),
        .i_reg_write(mem_reg_write),
        .i_wb_sel(mem_wb_sel),
        
        // UPDATE: Chuyền các tín hiệu Debug qua WB
        .i_jal(mem_jal),
        .i_jalr(mem_jalr),
        .i_branch_taken(mem_branch_taken),
        
        .o_jal(wb_jal),
        .o_jalr(wb_jalr),
        .o_branch_taken(wb_branch_taken),
        
        .o_alu_result(wb_alu_result),
        .o_mem_read_data(wb_mem_read_data),
        .o_return_addr(wb_return_addr),
        .o_immediate(wb_immediate),
        .o_rd_addr(wb_rd_addr),
        .o_reg_write(wb_reg_write),
        .o_wb_sel(wb_wb_sel)
    );
    
    // Track original RD1/RD2 values through WB stage
    always_ff @(posedge i_clk or negedge i_arst_n) begin
        if (!i_arst_n) begin
            wb_rd1_orig <= '0;
            wb_rd2_orig <= '0;
        end else begin
            wb_rd1_orig <= mem_rd1_orig;
            wb_rd2_orig <= mem_rd2_orig;
        end
    end
    
    // ==========================================================================
    // STAGE 5: WRITE BACK (WB)
    // ==========================================================================
    
    // Writeback data selection
    mux4to1 #(.N(N)) wb_mux (
        .i_d0(wb_alu_result),      // WB_ALU - ALU result
        .i_d1(wb_mem_read_data),   // WB_MEM - Memory data
        .i_d2(wb_return_addr),     // WB_PC4 - Return address
        .i_d3(wb_immediate),       // WB_IMM - Immediate (LUI)
        .i_sel(wb_wb_sel),
        .o_y(wb_data)
    );

endmodule