`timescale 1ns/1ps

// Verifies precise instruction, load and store access-fault exceptions from
// the native memory interfaces.
module tb_bus_access_faults;

    logic        clk;
    logic        arst_n;
    logic        imem_valid, imem_error;
    logic [31:0] imem_addr, imem_rdata;
    logic        dmem_valid, dmem_read, dmem_write, dmem_error;
    logic [31:0] dmem_addr, dmem_wdata;
    logic [3:0]  dmem_wstrb;
    logic        commit_valid, commit_mem_write;
    logic [31:0] commit_pc;
    integer      trap_count;

    rv32i_core dut (
        .i_clk               (clk),
        .i_arst_n            (arst_n),
        .i_irq_software      (1'b0),
        .i_irq_timer         (1'b0),
        .i_irq_external      (1'b0),
        .o_imem_valid        (imem_valid),
        .o_imem_addr         (imem_addr),
        .i_imem_rdata        (imem_rdata),
        .i_imem_ready        (1'b1),
        .i_imem_error        (imem_error),
        .o_dmem_valid        (dmem_valid),
        .o_dmem_read         (dmem_read),
        .o_dmem_write        (dmem_write),
        .o_dmem_addr         (dmem_addr),
        .o_dmem_wdata        (dmem_wdata),
        .o_dmem_wstrb        (dmem_wstrb),
        .o_dmem_size         (),
        .i_dmem_rdata        (32'hdead_beef),
        .i_dmem_ready        (1'b1),
        .i_dmem_error        (dmem_error),
        .o_commit_valid      (commit_valid),
        .o_commit_pc         (commit_pc),
        .o_commit_instruction(),
        .o_commit_rd_write   (),
        .o_commit_rd_addr    (),
        .o_commit_rd_data    (),
        .o_commit_mem_write  (commit_mem_write),
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
        imem_error = imem_valid && (imem_addr == 32'h0000_0080);
        dmem_error = dmem_valid &&
                     ((dmem_addr == 32'h0000_0200) ||
                      (dmem_addr == 32'h0000_0204));

        unique case (imem_addr)
            32'h0000_0000: imem_rdata = 32'h1000_0093; // addi x1, x0, 0x100
            32'h0000_0004: imem_rdata = 32'h3050_9073; // csrw mtvec, x1
            32'h0000_0008: imem_rdata = 32'h0780_006f; // jal  x0, 0x80

            // The response for 0x80 is marked as an instruction access fault.
            32'h0000_0080: imem_rdata = 32'h0000_0013; // value must not execute
            32'h0000_0084: imem_rdata = 32'h0010_0513; // addi x10, x0, 1
            32'h0000_0088: imem_rdata = 32'h2000_0113; // addi x2, x0, 0x200
            32'h0000_008c: imem_rdata = 32'h0001_2583; // lw   x11, 0(x2)
            32'h0000_0090: imem_rdata = 32'h0010_0613; // addi x12, x0, 1
            32'h0000_0094: imem_rdata = 32'h00a1_2223; // sw   x10, 4(x2)
            32'h0000_0098: imem_rdata = 32'h0010_0693; // addi x13, x0, 1
            32'h0000_009c: imem_rdata = 32'h0000_006f; // jal  x0, 0

            // Generic handler skips the faulting instruction and returns.
            32'h0000_0100: imem_rdata = 32'h3420_2273; // csrr x4, mcause
            32'h0000_0104: imem_rdata = 32'h3430_22f3; // csrr x5, mtval
            32'h0000_0108: imem_rdata = 32'h3410_2373; // csrr x6, mepc
            32'h0000_010c: imem_rdata = 32'h0043_0313; // addi x6, x6, 4
            32'h0000_0110: imem_rdata = 32'h3413_1073; // csrw mepc, x6
            32'h0000_0114: imem_rdata = 32'h0013_8393; // addi x7, x7, 1
            32'h0000_0118: imem_rdata = 32'h3020_0073; // mret
            default:       imem_rdata = 32'h0000_0013;
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
            if (commit_valid && ((commit_pc == 32'h0000_0080) ||
                                 (commit_pc == 32'h0000_008c) ||
                                 (commit_pc == 32'h0000_0094)))
                $fatal(1, "Faulting instruction at PC %08h retired", commit_pc);
            if (commit_mem_write)
                $fatal(1, "Faulting store was reported as committed");

            if (dut.trap_enter) begin
                unique case (trap_count)
                    0: if (dut.trap_pc !== 32'h0000_0080 ||
                           dut.trap_cause !== 32'd1 ||
                           dut.trap_value !== 32'h0000_0080)
                           $fatal(1, "Bad instruction access fault");
                    1: if (dut.trap_pc !== 32'h0000_008c ||
                           dut.trap_cause !== 32'd5 ||
                           dut.trap_value !== 32'h0000_0200)
                           $fatal(1, "Bad load access fault");
                    2: if (dut.trap_pc !== 32'h0000_0094 ||
                           dut.trap_cause !== 32'd7 ||
                           dut.trap_value !== 32'h0000_0204)
                           $fatal(1, "Bad store access fault");
                    default: $fatal(1, "Unexpected extra access fault");
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

        wait (dut.id_regfile.regs[13] == 32'd1);
        repeat (4) @(posedge clk);
        #1;

        if (trap_count !== 3 || dut.id_regfile.regs[7] !== 32'd3)
            $fatal(1, "Observed %0d traps, handler count x7=%0d",
                   trap_count, dut.id_regfile.regs[7]);
        if (dut.id_regfile.regs[11] !== 32'd0)
            $fatal(1, "Faulting load modified x11=%08h", dut.id_regfile.regs[11]);
        if (dut.id_regfile.regs[10] !== 32'd1 ||
            dut.id_regfile.regs[12] !== 32'd1 ||
            dut.id_regfile.regs[13] !== 32'd1)
            $fatal(1, "Execution did not resume after access faults");

        $display("*** BUS ACCESS-FAULT TEST PASSED ***");
        $display("Instruction/load/store access faults are precise");
        $finish;
    end

    initial begin
        repeat (250) @(posedge clk);
        $fatal(1, "Timeout waiting for bus access-fault test");
    end

endmodule
