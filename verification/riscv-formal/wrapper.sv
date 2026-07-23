module rvfi_wrapper (
    input clock,
    input reset,
    `RVFI_OUTPUTS
);
    `rvformal_rand_reg [31:0] imem_rdata;
    `rvformal_rand_reg [31:0] dmem_rdata;

    wire        imem_valid;
    wire [31:0] imem_addr;
    wire        dmem_valid;
    wire        dmem_read;
    wire        dmem_write;
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire [3:0]  dmem_wstrb;
    wire [1:0]  dmem_size;

    rv32i_core dut (
        .i_clk(clock),
        .i_arst_n(!reset),
        .i_irq_software(1'b0),
        .i_irq_timer(1'b0),
        .i_irq_external(1'b0),
        .i_time(64'b0),
        .o_core_sleep(),
        .o_fence_i(),
        .o_imem_valid(imem_valid),
        .o_imem_addr(imem_addr),
        .i_imem_rdata(imem_rdata),
        .i_imem_ready(1'b1),
        .i_imem_error(1'b0),
        .o_dmem_valid(dmem_valid),
        .o_dmem_read(dmem_read),
        .o_dmem_write(dmem_write),
        .o_dmem_addr(dmem_addr),
        .o_dmem_wdata(dmem_wdata),
        .o_dmem_wstrb(dmem_wstrb),
        .o_dmem_size(dmem_size),
        .i_dmem_rdata(dmem_rdata),
        .i_dmem_ready(1'b1),
        .i_dmem_error(1'b0),
        .o_commit_valid(),
        .o_commit_pc(),
        .o_commit_instruction(),
        .o_commit_rd_write(),
        .o_commit_rd_addr(),
        .o_commit_rd_data(),
        .o_commit_mem_write(),
        .o_commit_mem_addr(),
        .o_commit_mem_wdata(),
        .o_commit_mem_wstrb(),
        `RVFI_CONN,
        .o_debug_pc(),
        .o_debug_instruction(),
        .o_debug_rs1_data(),
        .o_debug_rs2_data(),
        .o_debug_alu_operand_b(),
        .o_debug_branch_target(),
        .o_debug_alu_result(),
        .o_debug_wb_data(),
        .o_debug_rd_addr(),
        .o_debug_rd_write(),
        .o_debug_mem_write(),
        .o_debug_mem_read(),
        .o_debug_branch_taken(),
        .o_debug_mem_addr(),
        .o_debug_mem_wdata(),
        .o_debug_mem_rdata(),
        .o_debug_jal(),
        .o_debug_jalr(),
        .o_debug_stall(),
        .o_debug_flush(),
        .o_debug_immediate(),
        .o_debug_alu_uses_immediate()
    );

    // Keep the abstraction honest: the core must never present contradictory
    // native-bus controls, even though responses are unconstrained.
    always @* begin
        if (!reset && dmem_valid) begin
            assert(dmem_read != dmem_write);
            assert(!dmem_read || dmem_wstrb == 4'b0000);
            assert(!dmem_write || dmem_wstrb != 4'b0000);
        end
    end

endmodule
