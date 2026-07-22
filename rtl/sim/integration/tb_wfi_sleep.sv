`timescale 1ns/1ps

module tb_wfi_sleep;

    logic clk, arst_n;
    logic irq_external;
    logic core_sleep;
    logic imem_valid;
    logic [31:0] imem_addr, imem_rdata;
    logic commit_valid;
    logic [31:0] commit_instruction;
    integer wfi_retire_count;

    rv32i_core dut (
        .i_clk(clk),
        .i_arst_n(arst_n),
        .i_irq_software(1'b0),
        .i_irq_timer(1'b0),
        .i_irq_external(irq_external),
        .i_time(64'b0),
        .o_core_sleep(core_sleep),
        .o_fence_i(),
        .o_imem_valid(imem_valid),
        .o_imem_addr(imem_addr),
        .i_imem_rdata(imem_rdata),
        .i_imem_ready(1'b1),
        .i_imem_error(1'b0),
        .o_dmem_valid(),
        .o_dmem_read(),
        .o_dmem_write(),
        .o_dmem_addr(),
        .o_dmem_wdata(),
        .o_dmem_wstrb(),
        .o_dmem_size(),
        .i_dmem_rdata('0),
        .i_dmem_ready(1'b1),
        .i_dmem_error(1'b0),
        .o_commit_valid(commit_valid),
        .o_commit_pc(),
        .o_commit_instruction(commit_instruction),
        .o_commit_rd_write(),
        .o_commit_rd_addr(),
        .o_commit_rd_data(),
        .o_commit_mem_write(),
        .o_commit_mem_addr(),
        .o_commit_mem_wdata(),
        .o_commit_mem_wstrb(),
        .o_debug_pc(), .o_debug_instruction(), .o_debug_rs1_data(), .o_debug_rs2_data(), .o_debug_alu_operand_b(), .o_debug_branch_target(),
        .o_debug_alu_result(), .o_debug_wb_data(), .o_debug_rd_addr(), .o_debug_rd_write(),
        .o_debug_mem_write(), .o_debug_mem_read(), .o_debug_branch_taken(), .o_debug_mem_addr(),
        .o_debug_mem_wdata(), .o_debug_mem_rdata(), .o_debug_jal(), .o_debug_jalr(), .o_debug_stall(),
        .o_debug_flush(), .o_debug_immediate(), .o_debug_alu_uses_immediate()
    );

    always_comb begin
        unique case (imem_addr)
            32'h0000_0000: imem_rdata = 32'h1000_0093; // addi  x1, x0, 0x100
            32'h0000_0004: imem_rdata = 32'h3050_9073; // csrw  mtvec, x1
            32'h0000_0008: imem_rdata = 32'h0000_1137; // lui   x2, 0x1
            32'h0000_000c: imem_rdata = 32'h0011_5113; // srli  x2, x2, 1
            32'h0000_0010: imem_rdata = 32'h3041_1073; // csrw  mie, x2 (MEIE)
            32'h0000_0014: imem_rdata = 32'h1050_0073; // wfi (MIE=0)
            32'h0000_0018: imem_rdata = 32'h0010_0513; // addi  x10, x0, 1
            32'h0000_001c: imem_rdata = 32'h3004_6073; // csrsi mstatus, 8
            32'h0000_0020: imem_rdata = 32'h1050_0073; // wfi (MIE=1)
            32'h0000_0024: imem_rdata = 32'h0010_0613; // addi  x12, x0, 1
            32'h0000_0028: imem_rdata = 32'h0000_006f; // jal   x0, 0

            32'h0000_0100: imem_rdata = 32'h0015_8593; // addi x11, x11, 1
            32'h0000_0104: imem_rdata = 32'h3020_0073; // mret
            default:       imem_rdata = 32'h0000_0013;
        endcase
    end

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always_ff @(posedge clk or negedge arst_n) begin
        if (!arst_n)
            wfi_retire_count <= 0;
        else begin
            if (core_sleep && imem_valid)
                $fatal(1, "Instruction request remained active while sleeping");
            if (commit_valid && commit_instruction == 32'h1050_0073)
                wfi_retire_count <= wfi_retire_count + 1;
        end
    end

    initial begin
        arst_n = 1'b0;
        irq_external = 1'b0;
        repeat (3) @(posedge clk);
        @(negedge clk);
        arst_n = 1'b1;

        // A locally-enabled interrupt wakes WFI even with global MIE clear,
        // but it must not enter the handler.
        wait (core_sleep);
        repeat (2) @(posedge clk);
        irq_external = 1'b1;
        wait (!core_sleep);
        @(negedge clk);
        irq_external = 1'b0;
        wait (dut.u_id_regfile.regs[10] == 32'd1);
        if (dut.u_id_regfile.regs[11] !== 32'd0)
            $fatal(1, "Interrupt trapped while global MIE was clear");

        // With global MIE set, wake-up is followed by a machine interrupt.
        wait (core_sleep);
        repeat (2) @(posedge clk);
        irq_external = 1'b1;
        wait (dut.trap_enter && dut.irq_take);
        // Keep the level-sensitive request asserted through the rising edge
        // on which the core records mepc/mcause and redirects to mtvec.
        @(posedge clk);
        @(negedge clk);
        irq_external = 1'b0;
        wait (dut.u_id_regfile.regs[12] == 32'd1);
        repeat (4) @(posedge clk);
        #1;

        if (dut.u_id_regfile.regs[11] !== 32'd1)
            $fatal(1, "Interrupt handler count x11=%0d, expected 1",
                   dut.u_id_regfile.regs[11]);
        if (wfi_retire_count !== 2)
            $fatal(1, "Retired %0d WFI instructions, expected 2",
                   wfi_retire_count);

        $display("*** WFI SLEEP/WAKE TEST PASSED ***");
        $display("Wake-up with global interrupts disabled/enabled verified");
        $finish;
    end

    initial begin
        repeat (300) @(posedge clk);
        $fatal(1, "Timeout waiting for WFI sleep/wake test");
    end

endmodule
