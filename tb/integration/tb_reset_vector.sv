`timescale 1ns/1ps

module tb_reset_vector;

    localparam logic [31:0] RESET_VECTOR = 32'h0000_1000;

    logic        clk;
    logic        arst_n;
    logic        imem_valid;
    logic [31:0] imem_addr;
    logic [31:0] imem_rdata;
    logic        first_fetch_seen;

    logic        dmem_valid;
    logic        dmem_read, dmem_write;
    logic [31:0] dmem_addr, dmem_wdata;
    logic [3:0]  dmem_wstrb;

    rv32i_core #(
        .RESET_VECTOR(RESET_VECTOR)
    ) dut (
        .i_clk          (clk),
        .i_arst_n       (arst_n),
        .i_irq_software (1'b0),
        .i_irq_timer    (1'b0),
        .i_irq_external (1'b0),
        .o_core_sleep   (),
        .o_imem_valid   (imem_valid),
        .o_imem_addr    (imem_addr),
        .i_imem_rdata   (imem_rdata),
        .i_imem_ready   (1'b1),
        .i_imem_error   (1'b0),
        .o_dmem_valid   (dmem_valid),
        .o_dmem_read    (dmem_read),
        .o_dmem_write   (dmem_write),
        .o_dmem_addr    (dmem_addr),
        .o_dmem_wdata   (dmem_wdata),
        .o_dmem_wstrb   (dmem_wstrb),
        .o_dmem_size    (),
        .i_dmem_rdata   (32'b0),
        .i_dmem_ready   (1'b1),
        .i_dmem_error   (1'b0),
        .o_commit_valid (),
        .o_commit_pc    (),
        .o_commit_instruction(),
        .o_commit_rd_write(),
        .o_commit_rd_addr(),
        .o_commit_rd_data(),
        .o_commit_mem_write(),
        .o_commit_mem_addr(),
        .o_commit_mem_wdata(),
        .o_commit_mem_wstrb(),
        .W_PC_out       (),
        .instruction    (),
        .W_RD1          (),
        .W_RD2          (),
        .W_m1           (),
        .W_m2           (),
        .W_ALUout       (),
        .W_WB_data      (),
        .W_rd_addr      (),
        .W_reg_write    (),
        .W_mem_write    (),
        .W_mem_read     (),
        .W_branch_taken (),
        .W_mem_addr     (),
        .W_mem_wdata    (),
        .W_mem_rdata    (),
        .W_jal          (),
        .W_jalr         (),
        .W_stall        (),
        .W_flush        (),
        .W_immediate    (),
        .W_ALUSrc       ()
    );

    always_comb begin
        unique case (imem_addr)
            32'h0000_1000: imem_rdata = 32'h0050_0193; // addi x3, x0, 5
            32'h0000_1004: imem_rdata = 32'h0071_8313; // addi x6, x3, 7
            32'h0000_1008: imem_rdata = 32'h0061_83b3; // add  x7, x3, x6
            default:       imem_rdata = 32'h0000_0013; // nop
        endcase
    end

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always_ff @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            first_fetch_seen <= 1'b0;
        end else if (imem_valid && !first_fetch_seen) begin
            if (imem_addr !== RESET_VECTOR)
                $fatal(1, "First fetch address=%08h, expected reset vector=%08h",
                       imem_addr, RESET_VECTOR);
            first_fetch_seen <= 1'b1;
        end
    end

    initial begin
        arst_n = 1'b0;
        repeat (3) @(posedge clk);
        @(negedge clk);
        arst_n = 1'b1;

        repeat (20) @(posedge clk);
        #1;

        if (!first_fetch_seen)
            $fatal(1, "No instruction fetch observed after reset");
        if (dut.id_regfile.regs[3] !== 32'd5)
            $fatal(1, "x3=%08h, expected 00000005", dut.id_regfile.regs[3]);
        if (dut.id_regfile.regs[6] !== 32'd12)
            $fatal(1, "x6=%08h, expected 0000000c", dut.id_regfile.regs[6]);
        if (dut.id_regfile.regs[7] !== 32'd17)
            $fatal(1, "x7=%08h, expected 00000011", dut.id_regfile.regs[7]);

        $display("*** RESET VECTOR TEST PASSED ***");
        $display("Boot address: 0x%08h", RESET_VECTOR);
        $finish;
    end

endmodule
