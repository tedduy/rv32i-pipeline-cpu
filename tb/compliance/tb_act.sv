`timescale 1ns/1ps

module tb_act;

    localparam int unsigned RAM_BYTES   = 1024 * 1024;
    localparam logic [31:0] UART_ADDR   = 32'h1000_0000;
    localparam logic [31:0] STATUS_ADDR = 32'h2000_0000;

    logic        clk;
    logic        arst_n;
    logic [7:0]  memory [0:RAM_BYTES-1];

    logic        imem_valid;
    logic [31:0] imem_addr;
    logic [31:0] imem_rdata;
    logic        dmem_valid;
    logic        dmem_read;
    logic        dmem_write;
    logic [31:0] dmem_addr;
    logic [31:0] dmem_wdata;
    logic [3:0]  dmem_wstrb;
    logic [31:0] dmem_rdata;

    string       mem_hex;
    string       test_name;
    integer      max_cycles;
    integer      cycle_count;
    integer      i;
    logic [31:0] dmem_word_addr;

    rv32i_top #(
        .RESET_VECTOR(32'h0000_0000)
    ) dut (
        .i_clk                 (clk),
        .i_arst_n              (arst_n),
        .i_irq_software        (1'b0),
        .i_irq_timer           (1'b0),
        .i_irq_external        (1'b0),
        .o_imem_valid          (imem_valid),
        .o_imem_addr           (imem_addr),
        .i_imem_rdata          (imem_rdata),
        .i_imem_ready          (1'b1),
        .o_dmem_valid          (dmem_valid),
        .o_dmem_read           (dmem_read),
        .o_dmem_write          (dmem_write),
        .o_dmem_addr           (dmem_addr),
        .o_dmem_wdata          (dmem_wdata),
        .o_dmem_wstrb          (dmem_wstrb),
        .i_dmem_rdata          (dmem_rdata),
        .i_dmem_ready          (1'b1),
        .o_commit_valid        (),
        .o_commit_pc           (),
        .o_commit_instruction  (),
        .o_commit_rd_write     (),
        .o_commit_rd_addr      (),
        .o_commit_rd_data      (),
        .o_commit_mem_write    (),
        .o_commit_mem_addr     (),
        .o_commit_mem_wdata    (),
        .o_commit_mem_wstrb    (),
        .W_PC_out              (),
        .instruction           (),
        .W_RD1                 (),
        .W_RD2                 (),
        .W_m1                  (),
        .W_m2                  (),
        .W_ALUout              (),
        .W_WB_data             (),
        .W_rd_addr             (),
        .W_reg_write           (),
        .W_mem_write           (),
        .W_mem_read            (),
        .W_branch_taken        (),
        .W_mem_addr            (),
        .W_mem_wdata           (),
        .W_mem_rdata           (),
        .W_jal                 (),
        .W_jalr                (),
        .W_stall               (),
        .W_flush               (),
        .W_immediate           (),
        .W_ALUSrc              ()
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always_comb begin
        imem_rdata = 32'h0000_0013;
        if ((imem_addr <= RAM_BYTES - 4) && (imem_addr[1:0] == 2'b00)) begin
            imem_rdata = {memory[imem_addr + 3], memory[imem_addr + 2],
                          memory[imem_addr + 1], memory[imem_addr]};
        end

        dmem_word_addr = {dmem_addr[31:2], 2'b00};
        dmem_rdata = 32'b0;
        if (dmem_read && (dmem_word_addr <= RAM_BYTES - 4)) begin
            dmem_rdata = {memory[dmem_word_addr + 3], memory[dmem_word_addr + 2],
                          memory[dmem_word_addr + 1], memory[dmem_word_addr]};
        end
    end

    // Plain always is intentional: the byte RAM is initialized by the initial
    // block and subsequently written here, so always_ff's single-driver rule
    // does not apply to this testbench memory model.
    always @(posedge clk) begin
        if (arst_n && dmem_valid && dmem_write) begin
            if (dmem_addr == UART_ADDR) begin
                $write("%c", dmem_wdata[7:0]);
            end else if (dmem_addr == STATUS_ADDR) begin
                if (dmem_wdata == 32'd1) begin
                    $display("RVCP-SUMMARY: TEST PASSED - Test File \"%s\"", test_name);
                    $finish;
                end else begin
                    $display("RVCP-SUMMARY: TEST FAILED - Test File \"%s\"", test_name);
                    $fatal(1, "ACT4 self-check reported failure code %0d", dmem_wdata);
                end
            end else if (dmem_word_addr <= RAM_BYTES - 4) begin
                if (dmem_wstrb[0]) memory[dmem_word_addr]     <= dmem_wdata[7:0];
                if (dmem_wstrb[1]) memory[dmem_word_addr + 1] <= dmem_wdata[15:8];
                if (dmem_wstrb[2]) memory[dmem_word_addr + 2] <= dmem_wdata[23:16];
                if (dmem_wstrb[3]) memory[dmem_word_addr + 3] <= dmem_wdata[31:24];
            end
        end
    end

    always_ff @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            cycle_count <= 0;
        end else begin
            cycle_count <= cycle_count + 1;
            if (cycle_count >= max_cycles)
                $fatal(1, "ACT4 timeout after %0d cycles: %s", max_cycles, test_name);
        end
    end

    initial begin
        arst_n = 1'b0;
        max_cycles = 1_000_000;
        test_name = "unknown";

        if (!$value$plusargs("MEM_HEX=%s", mem_hex))
            $fatal(1, "Missing +MEM_HEX=<ELF byte-memory file>");
        void'($value$plusargs("TEST_NAME=%s", test_name));
        void'($value$plusargs("MAX_CYCLES=%d", max_cycles));

        for (i = 0; i < RAM_BYTES; i = i + 1)
            memory[i] = 8'b0;
        $readmemh(mem_hex, memory);

        repeat (4) @(posedge clk);
        arst_n = 1'b1;
    end

endmodule
