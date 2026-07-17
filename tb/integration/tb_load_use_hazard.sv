`timescale 1ns/1ps

// Directed integration test for a load-use dependency:
//   sw   x2, 0(x0)      // memory[0] = 32
//   lw   x3, 0(x0)      // x3 = 32
//   add  x6, x3, x1     // immediately consumes x3; must stall once
//   addi x7, x6, 1      // also checks forwarding after the stall
module tb_load_use_hazard;

    logic        clk;
    logic        arst_n;
    logic [31:0] imem_addr;
    logic [31:0] imem_rdata;
    logic        imem_valid, imem_ready;
    logic        dmem_valid, dmem_ready;
    logic        dmem_read, dmem_write;
    logic [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    logic [3:0]  dmem_wstrb;
    logic        stall;
    integer      stall_cycles;

    rv32i_top dut (
        .i_clk         (clk),
        .i_arst_n      (arst_n),
        .o_imem_addr   (imem_addr),
        .i_imem_rdata  (imem_rdata),
        .o_imem_valid  (imem_valid),
        .i_imem_ready  (imem_ready),
        .o_dmem_valid  (dmem_valid),
        .o_dmem_read   (dmem_read),
        .o_dmem_write  (dmem_write),
        .o_dmem_addr   (dmem_addr),
        .o_dmem_wdata  (dmem_wdata),
        .o_dmem_wstrb  (dmem_wstrb),
        .i_dmem_rdata  (dmem_rdata),
        .i_dmem_ready  (dmem_ready),
        .W_stall       (stall)
    );

    assign imem_ready = 1'b1;
    assign dmem_ready = 1'b1;

    data_memory #(
        .N(32),
        .BYTES(256)
    ) dmem (
        .i_clk   (clk),
        .i_arst_n(arst_n),
        .i_we    (dmem_valid && dmem_write && dmem_ready),
        .i_re    (dmem_valid && dmem_read),
        .i_addr  (dmem_addr),
        .i_wdata (dmem_wdata),
        .i_wstrb (dmem_wstrb),
        .o_rdata (dmem_rdata)
    );

    // Zero-wait-state instruction memory model outside the CPU core.
    always_comb begin
        unique case (imem_addr)
            32'h0000_0000: imem_rdata = 32'h0020_2023; // sw   x2, 0(x0)
            32'h0000_0004: imem_rdata = 32'h0000_2183; // lw   x3, 0(x0)
            32'h0000_0008: imem_rdata = 32'h0011_8333; // add  x6, x3, x1
            32'h0000_000c: imem_rdata = 32'h0013_0393; // addi x7, x6, 1
            default:       imem_rdata = 32'h0000_0013; // nop
        endcase
    end

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always @(posedge clk) begin
        if (!arst_n)
            stall_cycles <= 0;
        else if (stall)
            stall_cycles <= stall_cycles + 1;
    end

    initial begin
        arst_n = 1'b0;
        stall_cycles = 0;
        repeat (3) @(posedge clk);
        arst_n = 1'b1;

        repeat (20) @(posedge clk);
        #1;

        if (stall_cycles != 1)
            $fatal(1, "Expected exactly 1 load-use stall, observed %0d", stall_cycles);

        if (dut.id_regfile.regs[3] !== 32'd32)
            $fatal(1, "LW failed: x3=%08h, expected 00000020", dut.id_regfile.regs[3]);

        if (dut.id_regfile.regs[6] !== 32'd48)
            $fatal(1, "Load-use result failed: x6=%08h, expected 00000030", dut.id_regfile.regs[6]);

        if (dut.id_regfile.regs[7] !== 32'd49)
            $fatal(1, "Post-stall forwarding failed: x7=%08h, expected 00000031", dut.id_regfile.regs[7]);

        $display("*** LOAD-USE HAZARD TEST PASSED ***");
        $display("Observed stall cycles: %0d", stall_cycles);
        $finish;
    end

endmodule
