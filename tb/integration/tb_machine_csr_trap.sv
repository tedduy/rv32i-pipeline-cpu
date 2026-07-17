`timescale 1ns/1ps

module tb_machine_csr_trap;

    logic        clk;
    logic        arst_n;
    logic        imem_valid;
    logic [31:0] imem_addr, imem_rdata;
    logic        dmem_valid, dmem_read, dmem_write;
    logic [31:0] dmem_addr, dmem_wdata;
    logic [3:0]  dmem_wstrb;
    logic        commit_valid;
    logic [31:0] commit_pc, commit_instruction;
    integer      commit_count;

    rv32i_top dut (
        .i_clk               (clk),
        .i_arst_n            (arst_n),
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
        .o_commit_valid      (commit_valid),
        .o_commit_pc         (commit_pc),
        .o_commit_instruction(commit_instruction),
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
            // Main program
            32'h0000_0000: imem_rdata = 32'h1000_0093; // addi   x1, x0, 0x100
            32'h0000_0004: imem_rdata = 32'h3050_9073; // csrw   mtvec, x1
            32'h0000_0008: imem_rdata = 32'h3401_d2f3; // csrrwi x5, mscratch, 3
            32'h0000_000c: imem_rdata = 32'h3400_2373; // csrrs  x6, mscratch, x0
            32'h0000_0010: imem_rdata = 32'h0050_0113; // addi   x2, x0, 5
            32'h0000_0014: imem_rdata = 32'h0000_0073; // ecall
            32'h0000_0018: imem_rdata = 32'h0070_0193; // addi   x3, x0, 7

            // Machine trap handler: skip ECALL and return to PC 0x18.
            32'h0000_0100: imem_rdata = 32'h3410_2273; // csrrs  x4, mepc, x0
            32'h0000_0104: imem_rdata = 32'h0042_0213; // addi   x4, x4, 4
            32'h0000_0108: imem_rdata = 32'h3412_1073; // csrw   mepc, x4
            32'h0000_010c: imem_rdata = 32'h3020_0073; // mret
            default:       imem_rdata = 32'h0000_0013; // nop
        endcase
    end

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always_ff @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            commit_count <= 0;
        end else if (commit_valid) begin
            if (commit_instruction == 32'h0000_0073)
                $fatal(1, "ECALL incorrectly appeared on commit interface");
            commit_count <= commit_count + 1;
        end
    end

    initial begin
        arst_n = 1'b0;
        repeat (3) @(posedge clk);
        @(negedge clk);
        arst_n = 1'b1;

        wait (dut.id_regfile.regs[3] == 32'd7);
        repeat (3) @(posedge clk);
        #1;

        if (dut.id_regfile.regs[2] !== 32'd5)
            $fatal(1, "x2=%08h, expected 00000005", dut.id_regfile.regs[2]);
        if (dut.id_regfile.regs[3] !== 32'd7)
            $fatal(1, "MRET did not return to PC 0x18");
        if (dut.id_regfile.regs[4] !== 32'h0000_0018)
            $fatal(1, "Trap handler computed mepc=%08h, expected 00000018",
                   dut.id_regfile.regs[4]);
        if (dut.id_regfile.regs[5] !== 32'd0)
            $fatal(1, "CSRRWI did not return old mscratch value");
        if (dut.id_regfile.regs[6] !== 32'd3)
            $fatal(1, "CSRRS read mscratch=%08h, expected 00000003",
                   dut.id_regfile.regs[6]);
        if (dut.machine_csrs.mcause !== 32'd11)
            $fatal(1, "mcause=%08h, expected machine ECALL cause 11",
                   dut.machine_csrs.mcause);
        if (dut.machine_csrs.mepc !== 32'h0000_0018)
            $fatal(1, "mepc=%08h, expected handler-updated value 00000018",
                   dut.machine_csrs.mepc);

        $display("*** MACHINE CSR/TRAP TEST PASSED ***");
        $display("ECALL entered mtvec, handler updated mepc, and MRET resumed execution");
        $finish;
    end

    initial begin
        repeat (80) @(posedge clk);
        $fatal(1, "Timeout waiting for CSR/trap flow to complete");
    end

endmodule
