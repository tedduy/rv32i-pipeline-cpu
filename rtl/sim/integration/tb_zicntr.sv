`timescale 1ns/1ps

module tb_zicntr;

    localparam logic [31:0] COUNTER_HIGH = 32'h1234_5678;
    localparam logic [31:0] TIME_HIGH    = 32'h89ab_cdef;

    logic        clk;
    logic        arst_n;
    logic [63:0] time_counter;
    logic        imem_valid;
    logic [31:0] imem_addr;
    logic [31:0] imem_rdata;

    rv32i_core dut (
        .i_clk(clk),
        .i_arst_n(arst_n),
        .i_irq_software(1'b0),
        .i_irq_timer(1'b0),
        .i_irq_external(1'b0),
        .i_time(time_counter),
        .o_core_sleep(),
        .o_fence_i(),
        .o_imem_valid(imem_valid),
        .o_imem_addr(imem_addr),
        .i_imem_rdata(imem_rdata),
        .i_imem_ready(1'b1),
        .i_imem_error(1'b0),
        .o_dmem_valid(), .o_dmem_read(), .o_dmem_write(),
        .o_dmem_addr(), .o_dmem_wdata(), .o_dmem_wstrb(), .o_dmem_size(),
        .i_dmem_rdata(32'b0), .i_dmem_ready(1'b1), .i_dmem_error(1'b0),
        .o_commit_valid(), .o_commit_pc(), .o_commit_instruction(),
        .o_commit_rd_write(), .o_commit_rd_addr(), .o_commit_rd_data(),
        .o_commit_mem_write(), .o_commit_mem_addr(),
        .o_commit_mem_wdata(), .o_commit_mem_wstrb(),
        .o_debug_pc(), .o_debug_instruction(), .o_debug_rs1_data(), .o_debug_rs2_data(), .o_debug_alu_operand_b(), .o_debug_branch_target(),
        .o_debug_alu_result(), .o_debug_wb_data(), .o_debug_rd_addr(), .o_debug_rd_write(),
        .o_debug_mem_write(), .o_debug_mem_read(), .o_debug_branch_taken(), .o_debug_mem_addr(),
        .o_debug_mem_wdata(), .o_debug_mem_rdata(), .o_debug_jal(), .o_debug_jalr(), .o_debug_stall(),
        .o_debug_flush(), .o_debug_immediate(), .o_debug_alu_uses_immediate()
    );

    always_comb begin
        unique case (imem_addr)
            32'h0000_0000: imem_rdata = 32'hc000_20f3; // csrr x1, cycle
            32'h0000_0004: imem_rdata = 32'h0000_0013; // nop
            32'h0000_0008: imem_rdata = 32'h0000_0013; // nop
            32'h0000_000c: imem_rdata = 32'h0000_0013; // nop
            32'h0000_0010: imem_rdata = 32'hc000_2173; // csrr x2, cycle
            32'h0000_0014: imem_rdata = 32'hc020_21f3; // csrr x3, instret
            32'h0000_0018: imem_rdata = 32'h0000_0013; // nop
            32'h0000_001c: imem_rdata = 32'h0000_0013; // nop
            32'h0000_0020: imem_rdata = 32'h0000_0013; // nop
            32'h0000_0024: imem_rdata = 32'hc020_2273; // csrr x4, instret
            32'h0000_0028: imem_rdata = 32'hc010_22f3; // csrr x5, time
            32'h0000_002c: imem_rdata = 32'hc810_2373; // csrr x6, timeh
            32'h0000_0030: imem_rdata = 32'h1234_53b7; // lui  x7, 0x12345
            32'h0000_0034: imem_rdata = 32'h6783_8393; // addi x7, x7, 0x678
            32'h0000_0038: imem_rdata = 32'hb803_9073; // csrw mcycleh, x7
            32'h0000_003c: imem_rdata = 32'hc800_2473; // csrr x8, cycleh
            32'h0000_0040: imem_rdata = 32'hb823_9073; // csrw minstreth, x7
            32'h0000_0044: imem_rdata = 32'hc820_24f3; // csrr x9, instreth
            32'h0000_0048: imem_rdata = 32'h0070_0513; // addi x10, x0, 7
            default:       imem_rdata = 32'h0000_0013;
        endcase
    end

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always_ff @(posedge clk or negedge arst_n) begin
        if (!arst_n)
            time_counter <= {TIME_HIGH, 32'b0};
        else
            time_counter <= time_counter + 64'd1;
    end

    initial begin
        arst_n = 1'b0;
        repeat (3) @(posedge clk);
        @(negedge clk);
        arst_n = 1'b1;

        wait (dut.u_id_regfile.regs[10] == 32'd7);
        repeat (3) @(posedge clk);
        #1;

        if (dut.u_id_regfile.regs[2] <= dut.u_id_regfile.regs[1])
            $fatal(1, "cycle did not increase: first=%08h second=%08h",
                   dut.u_id_regfile.regs[1], dut.u_id_regfile.regs[2]);
        if ((dut.u_id_regfile.regs[4] - dut.u_id_regfile.regs[3]) !== 32'd4)
            $fatal(1, "instret delta=%0d, expected four preceding instructions",
                   dut.u_id_regfile.regs[4] - dut.u_id_regfile.regs[3]);
        if (dut.u_id_regfile.regs[5] == 32'b0)
            $fatal(1, "time CSR did not reflect the advancing platform timebase");
        if (dut.u_id_regfile.regs[6] !== TIME_HIGH)
            $fatal(1, "timeh=%08h, expected %08h",
                   dut.u_id_regfile.regs[6], TIME_HIGH);
        if (dut.u_id_regfile.regs[8] !== COUNTER_HIGH)
            $fatal(1, "cycleh=%08h, expected %08h",
                   dut.u_id_regfile.regs[8], COUNTER_HIGH);
        if (dut.u_id_regfile.regs[9] !== COUNTER_HIGH)
            $fatal(1, "instreth=%08h, expected %08h",
                   dut.u_id_regfile.regs[9], COUNTER_HIGH);

        $display("*** ZICNTR TEST PASSED ***");
        $display("cycle/time/instret and RV32 high-half shadows verified");
        $finish;
    end

    initial begin
        repeat (150) @(posedge clk);
        $fatal(1, "Timeout waiting for Zicntr test");
    end

endmodule
