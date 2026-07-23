module mem_wb_register #(parameter N = 32)(
    input  logic         i_clk,
    input  logic         i_arst_n,
    input  logic         i_stall,

    input  logic         i_valid,
    input  logic [N-1:0] i_pc,
    input  logic [N-1:0] i_instruction,
    
    // Datapath and control inputs from MEM
    input  logic [N-1:0] i_alu_result,
    input  logic [N-1:0] i_wb_data,
    input  logic [N-1:0] i_immediate,
    input  logic [4:0]   i_rd_addr,
    input  logic         i_reg_write,
    input  logic         i_mem_write,
    input  logic [N-1:0] i_mem_addr,
    input  logic [N-1:0] i_mem_wdata,
    input  logic [3:0]   i_mem_wstrb,
    
    // Retired control-flow information
    input  logic         i_jal,
    input  logic         i_jalr,
    input  logic         i_branch_taken,
    
    // Datapath and control outputs to WB
    output logic         o_valid,
    output logic [N-1:0] o_pc,
    output logic [N-1:0] o_instruction,
    output logic [N-1:0] o_alu_result,
    output logic [N-1:0] o_wb_data,
    output logic [N-1:0] o_immediate,
    output logic [4:0]   o_rd_addr,
    output logic         o_reg_write,
    output logic         o_mem_write,
    output logic [N-1:0] o_mem_addr,
    output logic [N-1:0] o_mem_wdata,
    output logic [3:0]   o_mem_wstrb,
    
    // Retired control-flow information
    output logic         o_jal,
    output logic         o_jalr,
    output logic         o_branch_taken
);

    // Only architectural control state needs a defined reset value. Keeping
    // these signals benign guarantees that uninitialized payload data cannot
    // cause a register-file write, memory write, or valid retirement.
    always_ff @(posedge i_clk or negedge i_arst_n) begin
        if (!i_arst_n) begin
            o_valid         <= 1'b0;
            o_reg_write     <= 1'b0;
            o_mem_write     <= 1'b0;
            o_jal           <= 1'b0;
            o_jalr          <= 1'b0;
            o_branch_taken  <= 1'b0;
        end else if (!i_stall) begin
            o_valid         <= i_valid;
            o_reg_write     <= i_reg_write;
            o_mem_write     <= i_mem_write;
            o_jal           <= i_jal;
            o_jalr          <= i_jalr;
            o_branch_taken  <= i_branch_taken;
        end
    end

    // Payload is meaningful only when o_valid is asserted. Do not reset these
    // registers so synthesis can use smaller non-resettable flops. They retain
    // exactly the same clock-enable/hold behavior as the control registers.
    always_ff @(posedge i_clk) begin
        if (!i_stall) begin
            o_pc            <= i_pc;
            o_instruction   <= i_instruction;
            o_alu_result    <= i_alu_result;
            o_wb_data       <= i_wb_data;
            o_immediate     <= i_immediate;
            o_rd_addr       <= i_rd_addr;
            o_mem_addr      <= i_mem_addr;
            o_mem_wdata     <= i_mem_wdata;
            o_mem_wstrb     <= i_mem_wstrb;
        end
    end
endmodule
