`timescale 1ns/1ps

module tb_fence_i;

    logic clk, arst_n;
    logic imem_valid;
    logic [31:0] imem_addr, imem_rdata;
    logic fence_i;
    logic patch_active;
    logic commit_valid;
    logic [31:0] commit_instruction;
    integer fence_pulse_count;
    integer fence_retire_count;

    rv32i_core dut (
        .i_clk(clk),
        .i_arst_n(arst_n),
        .i_irq_software(1'b0),
        .i_irq_timer(1'b0),
        .i_irq_external(1'b0),
        .o_core_sleep(),
        .o_fence_i(fence_i),
        .o_imem_valid(imem_valid),
        .o_imem_addr(imem_addr),
        .i_imem_rdata(imem_rdata),
        .i_imem_ready(1'b1),
        .i_imem_error(1'b0),
        .o_dmem_valid(), .o_dmem_read(), .o_dmem_write(),
        .o_dmem_addr(), .o_dmem_wdata(), .o_dmem_wstrb(), .o_dmem_size(),
        .i_dmem_rdata('0), .i_dmem_ready(1'b1), .i_dmem_error(1'b0),
        .o_commit_valid(commit_valid),
        .o_commit_pc(),
        .o_commit_instruction(commit_instruction),
        .o_commit_rd_write(), .o_commit_rd_addr(), .o_commit_rd_data(),
        .o_commit_mem_write(), .o_commit_mem_addr(),
        .o_commit_mem_wdata(), .o_commit_mem_wstrb(),
        .W_PC_out(), .instruction(), .W_RD1(), .W_RD2(), .W_m1(), .W_m2(),
        .W_ALUout(), .W_WB_data(), .W_rd_addr(), .W_reg_write(),
        .W_mem_write(), .W_mem_read(), .W_branch_taken(), .W_mem_addr(),
        .W_mem_wdata(), .W_mem_rdata(), .W_jal(), .W_jalr(), .W_stall(),
        .W_flush(), .W_immediate(), .W_ALUSrc()
    );

    // PC 0x8 is fetched with the old instruction before FENCE.I reaches EX.
    // The model applies the code patch at the FENCE.I execution edge; correct
    // pipeline invalidation must then refetch PC 0x8 and execute the new value.
    always_comb begin
        unique case (imem_addr)
            32'h0000_0000: imem_rdata = 32'h0010_0093; // addi x1, x0, 1
            32'h0000_0004: imem_rdata = 32'h0000_100f; // fence.i
            32'h0000_0008: imem_rdata = patch_active ? 32'h0090_0513
                                                     : 32'h0070_0513;
            32'h0000_000c: imem_rdata = 32'h0010_0593; // addi x11, x0, 1
            32'h0000_0010: imem_rdata = 32'h0000_006f; // jal x0, 0
            default:       imem_rdata = 32'h0000_0013;
        endcase
    end

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always_ff @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            patch_active      <= 1'b0;
            fence_pulse_count <= 0;
            fence_retire_count <= 0;
        end else begin
            if (fence_i) begin
                patch_active      <= 1'b1;
                fence_pulse_count <= fence_pulse_count + 1;
            end
            if (commit_valid && commit_instruction == 32'h0000_100f)
                fence_retire_count <= fence_retire_count + 1;
        end
    end

    initial begin
        arst_n = 1'b0;
        repeat (3) @(posedge clk);
        @(negedge clk);
        arst_n = 1'b1;

        wait (dut.id_regfile.regs[11] == 32'd1);
        repeat (4) @(posedge clk);
        #1;

        if (dut.id_regfile.regs[10] !== 32'd9)
            $fatal(1, "Stale prefetched instruction executed: x10=%0d, expected 9",
                   dut.id_regfile.regs[10]);
        if (fence_pulse_count !== 1 || fence_retire_count !== 1)
            $fatal(1, "FENCE.I pulse/retire counts are %0d/%0d, expected 1/1",
                   fence_pulse_count, fence_retire_count);

        $display("*** FENCE.I TEST PASSED ***");
        $display("Prefetched instruction invalidation and refetch verified");
        $finish;
    end

    initial begin
        repeat (120) @(posedge clk);
        $fatal(1, "Timeout waiting for FENCE.I test");
    end

endmodule
