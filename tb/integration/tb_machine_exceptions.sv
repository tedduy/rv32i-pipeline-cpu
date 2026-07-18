`timescale 1ns/1ps

module tb_machine_exceptions;

    logic        clk;
    logic        arst_n;
    logic [31:0] imem_addr, imem_rdata;
    logic        dmem_valid;
    logic        commit_valid;
    logic [31:0] commit_pc;
    integer      trap_count;

    rv32i_top dut (
        .i_clk               (clk),
        .i_arst_n            (arst_n),
        .i_irq_software      (1'b0),
        .i_irq_timer         (1'b0),
        .i_irq_external      (1'b0),
        .o_imem_valid        (),
        .o_imem_addr         (imem_addr),
        .i_imem_rdata        (imem_rdata),
        .i_imem_ready        (1'b1),
        .i_imem_error        (1'b0),
        .o_dmem_valid        (dmem_valid),
        .o_dmem_read         (),
        .o_dmem_write        (),
        .o_dmem_addr         (),
        .o_dmem_wdata        (),
        .o_dmem_wstrb        (),
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
            32'h0000_0000: imem_rdata = 32'h1000_0093; // addi  x1, x0, 0x100
            32'h0000_0004: imem_rdata = 32'h3050_9073; // csrw  mtvec, x1
            32'h0000_0008: imem_rdata = 32'hffff_ffff; // illegal instruction
            32'h0000_000c: imem_rdata = 32'h0010_0513; // addi  x10, x0, 1
            32'h0000_0010: imem_rdata = 32'h0020_2103; // lw    x2, 2(x0)
            32'h0000_0014: imem_rdata = 32'h0011_0593; // addi  x11, x2, 1
            32'h0000_0018: imem_rdata = 32'h00a0_2123; // sw    x10, 2(x0)
            32'h0000_001c: imem_rdata = 32'h0010_0613; // addi  x12, x0, 1
            32'h0000_0020: imem_rdata = 32'h0020_0693; // addi  x13, x0, 2
            32'h0000_0024: imem_rdata = 32'h0006_8067; // jalr  x0, x13, 0
            32'h0000_0028: imem_rdata = 32'h0010_0713; // addi  x14, x0, 1
            32'h0000_002c: imem_rdata = 32'h0000_006f; // jal   x0, 0

            // Generic handler records trap state, skips the faulting
            // instruction, increments x7, and returns.
            32'h0000_0100: imem_rdata = 32'h3420_2273; // csrrs x4, mcause, x0
            32'h0000_0104: imem_rdata = 32'h3430_22f3; // csrrs x5, mtval, x0
            32'h0000_0108: imem_rdata = 32'h3410_2373; // csrrs x6, mepc, x0
            32'h0000_010c: imem_rdata = 32'h0043_0313; // addi  x6, x6, 4
            32'h0000_0110: imem_rdata = 32'h3413_1073; // csrw  mepc, x6
            32'h0000_0114: imem_rdata = 32'h0013_8393; // addi  x7, x7, 1
            32'h0000_0118: imem_rdata = 32'h3020_0073; // mret
            default:       imem_rdata = 32'h0000_0013; // nop
        endcase
    end

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always_ff @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            trap_count <= 0;
        end else begin
            if (dmem_valid)
                $fatal(1, "Misaligned memory operation reached data bus");

            if (commit_valid && ((commit_pc == 32'h0000_0008) ||
                                 (commit_pc == 32'h0000_0010) ||
                                 (commit_pc == 32'h0000_0018) ||
                                 (commit_pc == 32'h0000_0024)))
                $fatal(1, "Faulting instruction at PC %08h retired", commit_pc);

            if (dut.trap_enter) begin
                unique case (trap_count)
                    0: if (dut.ex_pc !== 32'h0000_0008 ||
                           dut.trap_cause !== 32'd2 ||
                           dut.trap_value !== 32'hffff_ffff)
                           $fatal(1, "Bad illegal-instruction exception");
                    1: if (dut.ex_pc !== 32'h0000_0010 ||
                           dut.trap_cause !== 32'd4 || dut.trap_value !== 32'd2)
                           $fatal(1, "Bad load-address-misaligned exception");
                    2: if (dut.ex_pc !== 32'h0000_0018 ||
                           dut.trap_cause !== 32'd6 || dut.trap_value !== 32'd2)
                           $fatal(1, "Bad store-address-misaligned exception");
                    3: if (dut.ex_pc !== 32'h0000_0024 ||
                           dut.trap_cause !== 32'd0 || dut.trap_value !== 32'd2)
                           $fatal(1, "Bad instruction-address-misaligned exception");
                    default: $fatal(1, "Unexpected extra exception");
                endcase
                trap_count <= trap_count + 1;
            end
        end
    end

    initial begin
        arst_n = 1'b0;
        repeat (3) @(posedge clk);
        @(negedge clk);
        arst_n = 1'b1;

        wait (dut.id_regfile.regs[14] == 32'd1);
        repeat (3) @(posedge clk);
        #1;

        if (trap_count !== 4)
            $fatal(1, "Observed %0d exceptions, expected 4", trap_count);
        if (dut.id_regfile.regs[7] !== 32'd4)
            $fatal(1, "Trap handler ran %0d times, expected 4",
                   dut.id_regfile.regs[7]);
        if (dut.id_regfile.regs[2] !== 32'd32)
            $fatal(1, "Faulting load modified x2=%08h, expected reset value 00000020",
                   dut.id_regfile.regs[2]);
        if (dut.id_regfile.regs[10] !== 32'd1 ||
            dut.id_regfile.regs[11] !== 32'd33 ||
            dut.id_regfile.regs[12] !== 32'd1 ||
            dut.id_regfile.regs[14] !== 32'd1)
            $fatal(1, "Resume results x10=%08h x11=%08h x12=%08h x14=%08h",
                   dut.id_regfile.regs[10], dut.id_regfile.regs[11],
                   dut.id_regfile.regs[12], dut.id_regfile.regs[14]);

        $display("*** MACHINE EXCEPTION TEST PASSED ***");
        $display("Illegal, load/store misalignment, and instruction misalignment verified");
        $finish;
    end

    initial begin
        repeat (180) @(posedge clk);
        $fatal(1, "Timeout waiting for exception test to complete");
    end

endmodule
