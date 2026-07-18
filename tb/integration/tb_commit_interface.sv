`timescale 1ns/1ps

// Verifies that the architectural commit interface reports instructions in
// program order and exposes their register/memory side effects.
module tb_commit_interface;

    logic        clk;
    logic        arst_n;
    logic        imem_valid;
    logic [31:0] imem_addr, imem_rdata;
    logic        dmem_valid, dmem_read, dmem_write;
    logic [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    logic [3:0]  dmem_wstrb;

    logic        commit_valid;
    logic [31:0] commit_pc, commit_instruction;
    logic        commit_rd_write;
    logic [4:0]  commit_rd_addr;
    logic [31:0] commit_rd_data;
    logic        commit_mem_write;
    logic [31:0] commit_mem_addr, commit_mem_wdata;
    logic [3:0]  commit_mem_wstrb;

    integer commit_count;

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
        .i_imem_error        (1'b0),
        .o_dmem_valid        (dmem_valid),
        .o_dmem_read         (dmem_read),
        .o_dmem_write        (dmem_write),
        .o_dmem_addr         (dmem_addr),
        .o_dmem_wdata        (dmem_wdata),
        .o_dmem_wstrb        (dmem_wstrb),
        .o_dmem_size         (),
        .i_dmem_rdata        (dmem_rdata),
        .i_dmem_ready        (1'b1),
        .i_dmem_error        (1'b0),
        .o_commit_valid      (commit_valid),
        .o_commit_pc         (commit_pc),
        .o_commit_instruction(commit_instruction),
        .o_commit_rd_write   (commit_rd_write),
        .o_commit_rd_addr    (commit_rd_addr),
        .o_commit_rd_data    (commit_rd_data),
        .o_commit_mem_write  (commit_mem_write),
        .o_commit_mem_addr   (commit_mem_addr),
        .o_commit_mem_wdata  (commit_mem_wdata),
        .o_commit_mem_wstrb  (commit_mem_wstrb),
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

    data_memory #(
        .N(32),
        .BYTES(256)
    ) dmem (
        .i_clk   (clk),
        .i_arst_n(arst_n),
        .i_we    (dmem_valid && dmem_write),
        .i_re    (dmem_valid && dmem_read),
        .i_addr  (dmem_addr),
        .i_wdata (dmem_wdata),
        .i_wstrb (dmem_wstrb),
        .o_rdata (dmem_rdata)
    );

    always_comb begin
        unique case (imem_addr)
            32'h0000_0000: imem_rdata = 32'h0050_0193; // addi x3, x0, 5
            32'h0000_0004: imem_rdata = 32'h0071_8313; // addi x6, x3, 7
            32'h0000_0008: imem_rdata = 32'h0060_2023; // sw   x6, 0(x0)
            32'h0000_000c: imem_rdata = 32'h0000_2383; // lw   x7, 0(x0)
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
            unique case (commit_count)
                0: begin
                    if (commit_pc !== 32'h0000_0000 ||
                        commit_instruction !== 32'h0050_0193 ||
                        !commit_rd_write || commit_rd_addr !== 5'd3 ||
                        commit_rd_data !== 32'd5 || commit_mem_write)
                        $fatal(1, "Bad commit 0: addi x3, x0, 5");
                end
                1: begin
                    if (commit_pc !== 32'h0000_0004 ||
                        commit_instruction !== 32'h0071_8313 ||
                        !commit_rd_write || commit_rd_addr !== 5'd6 ||
                        commit_rd_data !== 32'd12 || commit_mem_write)
                        $fatal(1, "Bad commit 1: addi x6, x3, 7");
                end
                2: begin
                    if (commit_pc !== 32'h0000_0008 ||
                        commit_instruction !== 32'h0060_2023 ||
                        commit_rd_write || !commit_mem_write ||
                        commit_mem_addr !== 32'd0 ||
                        commit_mem_wdata !== 32'd12 ||
                        commit_mem_wstrb !== 4'b1111)
                        $fatal(1, "Bad commit 2: sw x6, 0(x0)");
                end
                3: begin
                    if (commit_pc !== 32'h0000_000c ||
                        commit_instruction !== 32'h0000_2383 ||
                        !commit_rd_write || commit_rd_addr !== 5'd7 ||
                        commit_rd_data !== 32'd12 || commit_mem_write)
                        $fatal(1, "Bad commit 3: lw x7, 0(x0)");

                    $display("*** COMMIT INTERFACE TEST PASSED ***");
                    $display("Four instructions retired in order with correct side effects");
                    $finish;
                end
                default: $fatal(1, "Unexpected extra commit before test completion");
            endcase

            commit_count <= commit_count + 1;
        end
    end

    initial begin
        arst_n = 1'b0;
        repeat (3) @(posedge clk);
        @(negedge clk);
        arst_n = 1'b1;

        repeat (30) @(posedge clk);
        $fatal(1, "Timeout: observed only %0d commits", commit_count);
    end

endmodule
