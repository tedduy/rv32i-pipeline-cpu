module MEM_WB_Register #(parameter N = 32)(
    input  logic         i_clk,
    input  logic         i_arst_n,
    
    // Inputs cũ
    input  logic [N-1:0] i_alu_result,
    input  logic [N-1:0] i_mem_read_data,
    input  logic [N-1:0] i_return_addr,
    input  logic [N-1:0] i_immediate,
    input  logic [4:0]   i_rd_addr,
    input  logic         i_reg_write,
    input  logic [1:0]   i_wb_sel,
    
    // --- THÊM MỚI Ở ĐÂY ---
    input  logic         i_jal,
    input  logic         i_jalr,
    input  logic         i_branch_taken, // <--- Quan trọng
    
    // Outputs cũ
    output logic [N-1:0] o_alu_result,
    output logic [N-1:0] o_mem_read_data,
    output logic [N-1:0] o_return_addr,
    output logic [N-1:0] o_immediate,
    output logic [4:0]   o_rd_addr,
    output logic         o_reg_write,
    output logic [1:0]   o_wb_sel,
    
    // --- THÊM MỚI Ở ĐÂY ---
    output logic         o_jal,
    output logic         o_jalr,
    output logic         o_branch_taken  // <--- Quan trọng
);

    always_ff @(posedge i_clk or negedge i_arst_n) begin
        if (!i_arst_n) begin
            // ... (Reset các biến cũ) ...
            o_alu_result    <= '0;
            o_mem_read_data <= '0;
            o_return_addr   <= '0;
            o_immediate     <= '0;
            o_rd_addr       <= '0;
            o_reg_write     <= '0;
            o_wb_sel        <= '0;
            
            // Reset biến mới
            o_jal           <= 1'b0;
            o_jalr          <= 1'b0;
            o_branch_taken  <= 1'b0; // <--- Reset
        end else begin
            // ... (Gán các biến cũ) ...
            o_alu_result    <= i_alu_result;
            o_mem_read_data <= i_mem_read_data;
            o_return_addr   <= i_return_addr;
            o_immediate     <= i_immediate;
            o_rd_addr       <= i_rd_addr;
            o_reg_write     <= i_reg_write;
            o_wb_sel        <= i_wb_sel;
            
            // Gán biến mới
            o_jal           <= i_jal;
            o_jalr          <= i_jalr;
            o_branch_taken  <= i_branch_taken; // <--- Pass through
        end
    end
endmodule