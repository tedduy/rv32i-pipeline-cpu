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

    rv32i_top #(
        .HART_ID(TEST_HART_ID)
    ) dut (
        .i_clk               (clk),
        .i_arst_n            (arst_n),
        .i_irq_software      (1'b0),
        .i_irq_timer         (1'b0),
        .i_irq_external      (1'b0),
        .o_imem_valid        (imem_valid),
        .o_imem_addr         (imem_addr),
        .i_imem_rdata        (imem_rdata),
        .i_imem_ready        (1'b1),
        .o_dmem_valid        (dmem_valid),
        .o_dmem_read         (dmem_read),
        .o_dmem_write        (dmem_write),
        .o_dmem_addr         (dmem_addr),
        .o_dmem_wdata        (dmem_wdata),
        .o_dmem_wstrb        (dmem_wstrb),
        .i_dmem_rdata        (32'b0),
        .i_dmem_ready        (1'b1),
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

            // A CSRRW always attempts a write, even with rs1=x0. Writing a
            // read-only machine-identification CSR must raise illegal instruction.
            32'h0000_0024: imem_rdata = 32'hf110_1073; // csrw  mvendorid, x0
            32'h0000_0028: imem_rdata = 32'h0070_0513; // addi  x10, x0, 7

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

        wait (dut.id_regfile.regs[10] == 32'd7);
        repeat (3) @(posedge clk);
        #1;

        if (dut.id_regfile.regs[1] !== 32'h4000_0100)
            $fatal(1, "misa=%08h, expected RV32I value 40000100",
                   dut.id_regfile.regs[1]);
        if (dut.id_regfile.regs[2] !== 32'b0 ||
            dut.id_regfile.regs[3] !== 32'b0 ||
            dut.id_regfile.regs[4] !== 32'b0 ||
            dut.id_regfile.regs[6] !== 32'b0)
            $fatal(1, "Default machine identification/configuration values are not zero");
        if (dut.id_regfile.regs[5] !== TEST_HART_ID)
            $fatal(1, "mhartid=%08h, expected %08h",
                   dut.id_regfile.regs[5], TEST_HART_ID);
        if (dut.id_regfile.regs[8] !== 32'd2)
            $fatal(1, "Read-only CSR write produced mcause=%08h, expected 2",
                   dut.id_regfile.regs[8]);
        if (dut.id_regfile.regs[9] !== 32'h0000_0028)
            $fatal(1, "Trap handler produced resume PC=%08h, expected 00000028",
                   dut.id_regfile.regs[9]);

        $display("*** MACHINE IDENTIFICATION CSR TEST PASSED ***");
        $display("RV32I misa, identification CSRs, mhartid parameter and RO trap verified");
        $finish;
    end

    initial begin
        repeat (120) @(posedge clk);
        $fatal(1, "Timeout waiting for machine identification CSR test");
    end

endmodule
