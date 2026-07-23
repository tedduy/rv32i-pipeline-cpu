`timescale 1ns/1ps

module tb_machine_exceptions;

    logic        clk;
    logic        arst_n;
    logic [31:0] imem_addr, imem_rdata;
    logic        dmem_valid;
    logic        commit_valid;
    logic [31:0] commit_pc;
    logic [31:0] commit_instruction;
    integer      trap_count;

    rv32i_core dut (
        .i_clk               (clk),
        .i_arst_n            (arst_n),
        .i_irq_software      (1'b0),
        .i_irq_timer         (1'b0),
        .i_irq_external      (1'b0),
        .i_time              (64'b0),
        .o_core_sleep        (),
        .o_fence_i           (),
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
        .o_dmem_size         (),
        .i_dmem_rdata        (32'b0),
        .i_dmem_ready        (1'b1),
        .i_dmem_error        (1'b0),
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
            32'h0000_0000: imem_rdata = 32'h1000_0093; // addi  x1, x0, 0x100
            32'h0000_0004: imem_rdata = 32'h3050_9073; // csrw  mtvec, x1
            32'h0000_0008: imem_rdata = 32'hffff_ffff; // illegal instruction
            32'h0000_000c: imem_rdata = 32'h0010_0513; // addi  x10, x0, 1
            32'h0000_0010: imem_rdata = 32'h0020_2103; // lw    x2, 2(x0)
            32'h0000_0014: imem_rdata = 32'h0011_0593; // addi  x11, x2, 1
            32'h0000_0018: imem_rdata = 32'h00a0_2123; // sw    x10, 2(x0)
            32'h0000_001c: imem_rdata = 32'h0010_0613; // addi  x12, x0, 1
            32'h0000_0020: imem_rdata = 32'h02a0_0693; // addi  x13, x0, 0x2a
            32'h0000_0024: imem_rdata = 32'h0006_8067; // jalr  x0, x13, 0
            // Target 0x2a is halfword-aligned. The upper parcel is C.LI x14,1.
            32'h0000_0028: imem_rdata = 32'h4705_0001;
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
                                 (commit_pc == 32'h0000_0018)))
                $fatal(1, "Faulting instruction at PC %08h retired", commit_pc);

            if (commit_valid && (commit_pc == 32'h0000_002a) &&
                (commit_instruction !== 32'h0000_4705))
                $fatal(1, "Compressed commit encoding=%08h, expected 00004705",
                       commit_instruction);

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

        wait (dut.u_id_regfile.regs[14] == 32'd1);
        repeat (3) @(posedge clk);
        #1;

        if (trap_count !== 3)
            $fatal(1, "Observed %0d exceptions, expected 3", trap_count);
        if (dut.u_id_regfile.regs[7] !== 32'd3)
            $fatal(1, "Trap handler ran %0d times, expected 3",
                   dut.u_id_regfile.regs[7]);
        if (dut.u_id_regfile.regs[2] !== 32'd32)
            $fatal(1, "Faulting load modified x2=%08h, expected reset value 00000020",
                   dut.u_id_regfile.regs[2]);
        if (dut.u_id_regfile.regs[10] !== 32'd1 ||
            dut.u_id_regfile.regs[11] !== 32'd33 ||
            dut.u_id_regfile.regs[12] !== 32'd1 ||
            dut.u_id_regfile.regs[14] !== 32'd1)
            $fatal(1, "Resume results x10=%08h x11=%08h x12=%08h x14=%08h",
                   dut.u_id_regfile.regs[10], dut.u_id_regfile.regs[11],
                   dut.u_id_regfile.regs[12], dut.u_id_regfile.regs[14]);

        $display("*** MACHINE EXCEPTION TEST PASSED ***");
        $display("Illegal/load/store traps and a halfword-aligned JALR target verified");
        $finish;
    end

    initial begin
        repeat (180) @(posedge clk);
        $fatal(1, "Timeout waiting for exception test to complete");
    end

endmodule
