`timescale 1ns/1ps

module tb_machine_external_interrupt;

    logic        clk;
    logic        arst_n;
    logic        irq_external;
    logic        imem_valid;
    logic [31:0] imem_addr, imem_rdata;
    logic        commit_valid;
    logic [31:0] commit_pc;
    integer      interrupted_pc_commits;

    rv32i_core dut (
        .i_clk               (clk),
        .i_arst_n            (arst_n),
        .i_irq_software      (1'b0),
        .i_irq_timer         (1'b0),
        .i_irq_external      (irq_external),
        .i_time              (64'b0),
        .o_core_sleep        (),
        .o_fence_i           (),
        .o_imem_valid        (imem_valid),
        .o_imem_addr         (imem_addr),
        .i_imem_rdata        (imem_rdata),
        .i_imem_ready        (1'b1),
        .i_imem_error        (1'b0),
        .o_dmem_valid        (),
        .o_dmem_read         (),
        .o_dmem_write        (),
        .o_dmem_addr         (),
        .o_dmem_wdata        (),
        .o_dmem_wstrb        (),
        .o_dmem_size         (),
        .i_dmem_rdata        (32'b0),
        .i_dmem_ready        (1'b1),
        .i_dmem_error        (1'b0),
        .o_commit_valid      (commit_valid),
        .o_commit_pc         (commit_pc),
        .o_commit_instruction(),
        .o_commit_rd_write   (),
        .o_commit_rd_addr    (),
        .o_commit_rd_data    (),
        .o_commit_mem_write  (),
        .o_commit_mem_addr   (),
        .o_commit_mem_wdata  (),
        .o_commit_mem_wstrb  (),
        .W_PC_out            (),
        .instruction         (),
        .W_RD1               (),
        .W_RD2               (),
        .W_m1                (),
        .W_m2                (),
        .W_ALUout            (),
        .W_WB_data           (),
        .W_rd_addr           (),
        .W_reg_write         (),
        .W_mem_write         (),
        .W_mem_read          (),
        .W_branch_taken      (),
        .W_mem_addr          (),
        .W_mem_wdata         (),
        .W_mem_rdata         (),
        .W_jal               (),
        .W_jalr              (),
        .W_stall             (),
        .W_flush             (),
        .W_immediate         (),
        .W_ALUSrc            ()
    );

    always_comb begin
        unique case (imem_addr)
            // Configure direct mtvec, enable MEIE, then enable global MIE.
            32'h0000_0000: imem_rdata = 32'h1000_0313; // addi  x6, x0, 0x100
            32'h0000_0004: imem_rdata = 32'h3053_1073; // csrw  mtvec, x6
            32'h0000_0008: imem_rdata = 32'h0080_0093; // addi  x1, x0, 8
            32'h0000_000c: imem_rdata = 32'h0080_9093; // slli  x1, x1, 8
            32'h0000_0010: imem_rdata = 32'h3040_9073; // csrw  mie, x1 (MEIE)
            32'h0000_0014: imem_rdata = 32'h3004_6073; // csrsi mstatus, 8 (MIE)

            // This instruction must be squashed on interrupt and replayed once.
            32'h0000_0018: imem_rdata = 32'h0010_0113; // addi  x2, x0, 1
            32'h0000_001c: imem_rdata = 32'h0011_8193; // addi  x3, x3, 1
            32'h0000_0020: imem_rdata = 32'h0070_0393; // addi  x7, x0, 7
            32'h0000_0024: imem_rdata = 32'h0000_006f; // jal   x0, 0

            // Machine external interrupt handler.
            32'h0000_0100: imem_rdata = 32'h3410_2273; // csrrs x4, mepc, x0
            32'h0000_0104: imem_rdata = 32'h0090_0293; // addi  x5, x0, 9
            32'h0000_0108: imem_rdata = 32'h3020_0073; // mret
            default:       imem_rdata = 32'h0000_0013; // nop
        endcase
    end

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always_ff @(posedge clk or negedge arst_n) begin
        if (!arst_n)
            interrupted_pc_commits <= 0;
        else if (commit_valid && commit_pc == 32'h0000_0018)
            interrupted_pc_commits <= interrupted_pc_commits + 1;
    end

    // Model a level-sensitive peripheral request. It remains asserted until
    // the trap is accepted, then the peripheral clears its pending condition.
    initial begin
        irq_external = 1'b1;
        wait (dut.machine_csrs.mcause == 32'h8000_000b);
        @(negedge clk);
        irq_external = 1'b0;
    end

    initial begin
        arst_n = 1'b0;
        repeat (3) @(posedge clk);
        @(negedge clk);
        arst_n = 1'b1;

        wait (dut.id_regfile.regs[7] == 32'd7);
        repeat (3) @(posedge clk);
        #1;

        if (dut.machine_csrs.mcause !== 32'h8000_000b)
            $fatal(1, "mcause=%08h, expected machine external interrupt",
                   dut.machine_csrs.mcause);
        if (dut.id_regfile.regs[4] !== 32'h0000_0018)
            $fatal(1, "Handler read mepc=%08h, expected 00000018",
                   dut.id_regfile.regs[4]);
        if (dut.id_regfile.regs[5] !== 32'd9)
            $fatal(1, "Interrupt handler did not execute");
        if (dut.id_regfile.regs[2] !== 32'd1 || dut.id_regfile.regs[3] !== 32'd1)
            $fatal(1, "Interrupted instruction stream did not resume correctly");
        if (interrupted_pc_commits !== 1)
            $fatal(1, "PC 0x18 retired %0d times, expected exactly once",
                   interrupted_pc_commits);
        if (!dut.machine_csrs.mstatus_mie)
            $fatal(1, "MRET did not restore mstatus.MIE");

        $display("*** MACHINE EXTERNAL INTERRUPT TEST PASSED ***");
        $display("Interrupt was masked, taken precisely, and returned with MRET");
        $finish;
    end

    initial begin
        repeat (100) @(posedge clk);
        $fatal(1, "Timeout waiting for external interrupt flow to complete");
    end

endmodule
