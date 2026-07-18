`timescale 1ns/1ps

module tb_zmmul;

    logic        clk;
    logic        arst_n;
    logic [31:0] imem_addr;
    logic [31:0] imem_rdata;

    rv32i_core dut (
        .i_clk(clk), .i_arst_n(arst_n),
        .i_irq_software(1'b0), .i_irq_timer(1'b0), .i_irq_external(1'b0),
        .i_time(64'b0), .o_core_sleep(), .o_fence_i(),
        .o_imem_valid(), .o_imem_addr(imem_addr),
        .i_imem_rdata(imem_rdata), .i_imem_ready(1'b1), .i_imem_error(1'b0),
        .o_dmem_valid(), .o_dmem_read(), .o_dmem_write(),
        .o_dmem_addr(), .o_dmem_wdata(), .o_dmem_wstrb(), .o_dmem_size(),
        .i_dmem_rdata(32'b0), .i_dmem_ready(1'b1), .i_dmem_error(1'b0),
        .o_commit_valid(), .o_commit_pc(), .o_commit_instruction(),
        .o_commit_rd_write(), .o_commit_rd_addr(), .o_commit_rd_data(),
        .o_commit_mem_write(), .o_commit_mem_addr(),
        .o_commit_mem_wdata(), .o_commit_mem_wstrb(),
        .W_PC_out(), .instruction(), .W_RD1(), .W_RD2(), .W_m1(), .W_m2(),
        .W_ALUout(), .W_WB_data(), .W_rd_addr(), .W_reg_write(),
        .W_mem_write(), .W_mem_read(), .W_branch_taken(), .W_mem_addr(),
        .W_mem_wdata(), .W_mem_rdata(), .W_jal(), .W_jalr(), .W_stall(),
        .W_flush(), .W_immediate(), .W_ALUSrc()
    );

    always_comb begin
        unique case (imem_addr)
            32'h0000_0000: imem_rdata = 32'hffe0_0093; // addi   x1, x0, -2
            32'h0000_0004: imem_rdata = 32'h0030_0113; // addi   x2, x0, 3
            32'h0000_0008: imem_rdata = 32'h0220_81b3; // mul    x3, x1, x2
            32'h0000_000c: imem_rdata = 32'h0220_9233; // mulh   x4, x1, x2
            32'h0000_0010: imem_rdata = 32'h0220_a2b3; // mulhsu x5, x1, x2
            32'h0000_0014: imem_rdata = 32'h0220_b333; // mulhu  x6, x1, x2
            32'h0000_0018: imem_rdata = 32'h0070_0393; // addi   x7, x0, 7
            32'h0000_001c: imem_rdata = 32'h0090_0413; // addi   x8, x0, 9
            32'h0000_0020: imem_rdata = 32'h0283_84b3; // mul    x9, x7, x8
            32'h0000_0024: imem_rdata = 32'h0014_8513; // addi   x10, x9, 1
            32'h0000_0028: imem_rdata = 32'h0070_0593; // addi   x11, x0, 7
            default:       imem_rdata = 32'h0000_0013;
        endcase
    end

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        arst_n = 1'b0;
        repeat (3) @(posedge clk);
        @(negedge clk);
        arst_n = 1'b1;

        wait (dut.id_regfile.regs[11] == 32'd7);
        repeat (3) @(posedge clk);
        #1;

        if (dut.id_regfile.regs[3] !== 32'hffff_fffa)
            $fatal(1, "MUL result=%08h, expected fffffffa", dut.id_regfile.regs[3]);
        if (dut.id_regfile.regs[4] !== 32'hffff_ffff)
            $fatal(1, "MULH result=%08h, expected ffffffff", dut.id_regfile.regs[4]);
        if (dut.id_regfile.regs[5] !== 32'hffff_ffff)
            $fatal(1, "MULHSU result=%08h, expected ffffffff", dut.id_regfile.regs[5]);
        if (dut.id_regfile.regs[6] !== 32'h0000_0002)
            $fatal(1, "MULHU result=%08h, expected 00000002", dut.id_regfile.regs[6]);
        if (dut.id_regfile.regs[9] !== 32'd63 ||
            dut.id_regfile.regs[10] !== 32'd64)
            $fatal(1, "MUL forwarding failed: x9=%08h x10=%08h",
                   dut.id_regfile.regs[9], dut.id_regfile.regs[10]);

        $display("*** ZMMUL TEST PASSED ***");
        $display("MUL/MULH/MULHSU/MULHU and result forwarding verified");
        $finish;
    end

    initial begin
        repeat (100) @(posedge clk);
        $fatal(1, "Timeout waiting for Zmmul test");
    end

endmodule
