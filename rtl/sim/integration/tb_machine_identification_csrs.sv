`timescale 1ns/1ps

module tb_machine_identification_csrs;

    localparam logic [31:0] TEST_HART_ID = 32'h0000_002a;

    logic        clk;
    logic        arst_n;
    logic        imem_valid;
    logic [31:0] imem_addr, imem_rdata;
    logic        dmem_valid, dmem_read, dmem_write;
    logic [31:0] dmem_addr, dmem_wdata;
    logic [3:0]  dmem_wstrb;

    rv32i_core #(
        .HART_ID(TEST_HART_ID)
    ) dut (
        .i_clk               (clk),
        .i_arst_n            (arst_n),
        .i_irq_software      (1'b0),
        .i_irq_timer         (1'b0),
        .i_irq_external      (1'b0),
        .i_time              (64'b0),
        .o_core_sleep        (),
        .o_fence_i           (),
        .o_imem_valid        (imem_valid),
        .o_imem_addr         (imem_addr),
        .i_imem_rdata        (imem_rdata),
        .i_imem_ready        (1'b1),
        .i_imem_error        (1'b0),
        .o_dmem_valid        (dmem_valid),
        .o_dmem_read         (dmem_read),
        .o_dmem_write        (dmem_write),
        .o_dmem_addr         (dmem_addr),
        .o_dmem_wdata        (dmem_wdata),
        .o_dmem_wstrb        (dmem_wstrb),
        .o_dmem_size         (),
        .i_dmem_rdata        (32'b0),
        .i_dmem_ready        (1'b1),
        .i_dmem_error        (1'b0),
        .o_commit_valid      (),
        .o_commit_pc         (),
        .o_commit_instruction(),
        .o_commit_rd_write   (),
        .o_commit_rd_addr    (),
        .o_commit_rd_data    (),
        .o_commit_mem_write  (),
        .o_commit_mem_addr   (),
        .o_commit_mem_wdata  (),
        .o_commit_mem_wstrb  (),
        .o_debug_pc            (),
        .o_debug_instruction         (),
        .o_debug_rs1_data               (),
        .o_debug_rs2_data               (),
        .o_debug_alu_operand_b                (),
        .o_debug_branch_target                (),
        .o_debug_alu_result            (),
        .o_debug_wb_data           (),
        .o_debug_rd_addr           (),
        .o_debug_rd_write         (),
        .o_debug_mem_write         (),
        .o_debug_mem_read          (),
        .o_debug_branch_taken      (),
        .o_debug_mem_addr          (),
        .o_debug_mem_wdata         (),
        .o_debug_mem_rdata         (),
        .o_debug_jal               (),
        .o_debug_jalr              (),
        .o_debug_stall             (),
        .o_debug_flush             (),
        .o_debug_immediate         (),
        .o_debug_alu_uses_immediate            ()
    );

    always_comb begin
        unique case (imem_addr)
            32'h0000_0000: imem_rdata = 32'h1000_0393; // addi  x7, x0, 0x100
            32'h0000_0004: imem_rdata = 32'h3053_9073; // csrw  mtvec, x7
            // misa has a read/write CSR address, but its fields are immutable:
            // this write is legal and ignored rather than trapping.
            32'h0000_0008: imem_rdata = 32'h3010_1073; // csrw  misa, x0
            32'h0000_000c: imem_rdata = 32'h3010_20f3; // csrr  x1, misa
            32'h0000_0010: imem_rdata = 32'hf110_2173; // csrr  x2, mvendorid
            32'h0000_0014: imem_rdata = 32'hf120_21f3; // csrr  x3, marchid
            32'h0000_0018: imem_rdata = 32'hf130_2273; // csrr  x4, mimpid
            32'h0000_001c: imem_rdata = 32'hf140_22f3; // csrr  x5, mhartid
            32'h0000_0020: imem_rdata = 32'hf150_2373; // csrr  x6, mconfigptr

            // mstatush is present on RV32. Unsupported WARL fields read zero,
            // and writes must be accepted rather than raising an exception.
            32'h0000_0024: imem_rdata = 32'h3100_9073; // csrw  mstatush, x1
            32'h0000_0028: imem_rdata = 32'h3100_25f3; // csrr  x11, mstatush
            32'h0000_002c: imem_rdata = 32'h0050_0613; // addi  x12, x0, 5
            32'h0000_0030: imem_rdata = 32'h3206_1073; // csrw  mcountinhibit, x12
            32'h0000_0034: imem_rdata = 32'h3200_26f3; // csrr  x13, mcountinhibit
            32'h0000_0038: imem_rdata = 32'h3200_1073; // csrw  mcountinhibit, x0

            // A CSRRW always attempts a write, even with rs1=x0. Writing a
            // read-only machine-identification CSR must raise illegal instruction.
            32'h0000_003c: imem_rdata = 32'hf110_1073; // csrw  mvendorid, x0
            32'h0000_0040: imem_rdata = 32'h0070_0513; // addi  x10, x0, 7

            32'h0000_0100: imem_rdata = 32'h3420_2473; // csrr  x8, mcause
            32'h0000_0104: imem_rdata = 32'h3410_24f3; // csrr  x9, mepc
            32'h0000_0108: imem_rdata = 32'h0044_8493; // addi  x9, x9, 4
            32'h0000_010c: imem_rdata = 32'h3414_9073; // csrw  mepc, x9
            32'h0000_0110: imem_rdata = 32'h3020_0073; // mret
            default:       imem_rdata = 32'h0000_0013; // nop
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

        wait (dut.u_id_regfile.regs[10] == 32'd7);
        repeat (3) @(posedge clk);
        #1;

        if (dut.u_id_regfile.regs[1] !== 32'h4000_0104)
            $fatal(1, "misa=%08h, expected RV32IC value 40000104",
                   dut.u_id_regfile.regs[1]);
        if (dut.u_id_regfile.regs[2] !== 32'b0 ||
            dut.u_id_regfile.regs[3] !== 32'b0 ||
            dut.u_id_regfile.regs[4] !== 32'b0 ||
            dut.u_id_regfile.regs[6] !== 32'b0)
            $fatal(1, "Default machine identification/configuration values are not zero");
        if (dut.u_id_regfile.regs[5] !== TEST_HART_ID)
            $fatal(1, "mhartid=%08h, expected %08h",
                   dut.u_id_regfile.regs[5], TEST_HART_ID);
        if (dut.u_id_regfile.regs[11] !== 32'b0)
            $fatal(1, "mstatush=%08h, expected unsupported WARL fields to read zero",
                   dut.u_id_regfile.regs[11]);
        if (dut.u_id_regfile.regs[13] !== 32'h0000_0005)
            $fatal(1, "mcountinhibit=%08h, expected implemented CY/IR bits",
                   dut.u_id_regfile.regs[13]);
        if (dut.u_id_regfile.regs[8] !== 32'd2)
            $fatal(1, "Read-only CSR write produced mcause=%08h, expected 2",
                   dut.u_id_regfile.regs[8]);
        if (dut.u_id_regfile.regs[9] !== 32'h0000_0040)
            $fatal(1, "Trap handler produced resume PC=%08h, expected 00000040",
                   dut.u_id_regfile.regs[9]);

        $display("*** MACHINE IDENTIFICATION CSR TEST PASSED ***");
        $display("RV32I misa, identification CSRs, mhartid parameter and RO trap verified");
        $finish;
    end

    initial begin
        repeat (120) @(posedge clk);
        $fatal(1, "Timeout waiting for machine identification CSR test");
    end

endmodule
