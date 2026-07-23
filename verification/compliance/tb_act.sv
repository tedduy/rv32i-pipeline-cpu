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

    logic        commit_valid;
    logic [31:0] commit_pc;
    logic [31:0] commit_instruction;
    integer      commit_count;
    logic [31:0] last_commit_pc;
    logic [31:0] last_commit_instruction;
    integer      trap_count;
    logic [31:0] last_trap_pc;
    logic [31:0] last_trap_cause;
    logic [31:0] last_trap_value;
    logic [31:0] first_trap_pc;
    logic [31:0] first_trap_cause;
    logic [31:0] first_trap_value;
    integer      store_count;
    logic [31:0] last_store_addr;
    logic [31:0] last_store_data;
    logic [31:0] commit_pc_history [0:15];
    logic [31:0] commit_inst_history [0:15];
    integer      commit_history_index;

    string       mem_hex;
    string       test_name;
    integer      max_cycles;
    integer      cycle_count;
    logic [63:0] time_counter;
    integer      i;
    logic [31:0] dmem_word_addr;

    tdrv32_core #(
        .RESET_VECTOR(32'h0000_0000)
    ) dut (
        .i_clk                 (clk),
        .i_arst_n              (arst_n),
        .i_irq_software        (1'b0),
        .i_irq_timer           (1'b0),
        .i_irq_external        (1'b0),
        .i_time                (time_counter),
        .o_core_sleep          (),
        .o_fence_i             (),
        .o_imem_valid          (imem_valid),
        .o_imem_addr           (imem_addr),
        .i_imem_rdata          (imem_rdata),
        .i_imem_ready          (1'b1),
        .i_imem_error          (1'b0),
        .o_dmem_valid          (dmem_valid),
        .o_dmem_read           (dmem_read),
        .o_dmem_write          (dmem_write),
        .o_dmem_addr           (dmem_addr),
        .o_dmem_wdata          (dmem_wdata),
        .o_dmem_wstrb          (dmem_wstrb),
        .o_dmem_size           (),
        .i_dmem_rdata          (dmem_rdata),
        .i_dmem_ready          (1'b1),
        .i_dmem_error          (1'b0),
        .o_commit_valid        (commit_valid),
        .o_commit_pc           (commit_pc),
        .o_commit_instruction  (commit_instruction),
        .o_commit_rd_write     (),
        .o_commit_rd_addr      (),
        .o_commit_rd_data      (),
        .o_commit_mem_write    (),
        .o_commit_mem_addr     (),
        .o_commit_mem_wdata    (),
        .o_commit_mem_wstrb    (),
        .o_debug_pc              (),
        .o_debug_instruction           (),
        .o_debug_rs1_data                 (),
        .o_debug_rs2_data                 (),
        .o_debug_alu_operand_b                  (),
        .o_debug_branch_target                  (),
        .o_debug_alu_result              (),
        .o_debug_wb_data             (),
        .o_debug_rd_addr             (),
        .o_debug_rd_write           (),
        .o_debug_mem_write           (),
        .o_debug_mem_read            (),
        .o_debug_branch_taken        (),
        .o_debug_mem_addr            (),
        .o_debug_mem_wdata           (),
        .o_debug_mem_rdata           (),
        .o_debug_jal                 (),
        .o_debug_jalr                (),
        .o_debug_stall               (),
        .o_debug_flush               (),
        .o_debug_immediate           (),
        .o_debug_alu_uses_immediate              ()
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always_ff @(posedge clk or negedge arst_n) begin
        if (!arst_n)
            time_counter <= 64'b0;
        else
            time_counter <= time_counter + 64'd1;
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
                    $display("ACT4 diagnostic: commits=%0d last_pc=%08x last_inst=%08x",
                             commit_count, last_commit_pc, last_commit_instruction);
                    $display("ACT4 pipeline: IF=%08x ID=%08x EX=%08x MEM=%08x WB=%08x",
                             dut.if_pc_current, dut.id_pc, dut.ex_pc, dut.mem_pc, dut.wb_pc);
                    $display("ACT4 traps: count=%0d first_pc=%08x cause=%08x value=%08x",
                             trap_count, first_trap_pc,
                             first_trap_cause, first_trap_value);
                    $display("ACT4 last 16 retired instructions (oldest to newest):");
                    for (integer hist_idx = 0; hist_idx < 16; hist_idx = hist_idx + 1) begin
                        $display("  pc=%08x inst=%08x",
                                 commit_pc_history[(commit_history_index + hist_idx) & 15],
                                 commit_inst_history[(commit_history_index + hist_idx) & 15]);
                    end
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
            commit_count <= 0;
            last_commit_pc <= 32'b0;
            last_commit_instruction <= 32'b0;
            trap_count <= 0;
            last_trap_pc <= 32'b0;
            last_trap_cause <= 32'b0;
            last_trap_value <= 32'b0;
            first_trap_pc <= 32'b0;
            first_trap_cause <= 32'b0;
            first_trap_value <= 32'b0;
            store_count <= 0;
            last_store_addr <= 32'b0;
            last_store_data <= 32'b0;
            commit_history_index <= 0;
            for (integer hist_idx = 0; hist_idx < 16; hist_idx = hist_idx + 1) begin
                commit_pc_history[hist_idx] <= 32'b0;
                commit_inst_history[hist_idx] <= 32'b0;
            end
        end else begin
            cycle_count <= cycle_count + 1;
            if (commit_valid) begin
                commit_count <= commit_count + 1;
                last_commit_pc <= commit_pc;
                last_commit_instruction <= commit_instruction;
                commit_pc_history[commit_history_index] <= commit_pc;
                commit_inst_history[commit_history_index] <= commit_instruction;
                commit_history_index <= (commit_history_index + 1) & 15;
            end
            if (dut.trap_enter) begin
                trap_count <= trap_count + 1;
                last_trap_pc <= dut.ex_pc;
                last_trap_cause <= dut.trap_cause;
                last_trap_value <= dut.trap_value;
                if (trap_count == 0) begin
                    first_trap_pc <= dut.ex_pc;
                    first_trap_cause <= dut.trap_cause;
                    first_trap_value <= dut.trap_value;
                end
            end
            if (dmem_valid && dmem_write) begin
                store_count <= store_count + 1;
                last_store_addr <= dmem_addr;
                last_store_data <= dmem_wdata;
            end
            if (cycle_count >= max_cycles) begin
                $display("ACT4 diagnostic: commits=%0d last_pc=%08x last_inst=%08x",
                         commit_count, last_commit_pc, last_commit_instruction);
                $display("ACT4 pipeline: IF=%08x ID=%08x EX=%08x MEM=%08x WB=%08x",
                         dut.if_pc_current, dut.id_pc, dut.ex_pc, dut.mem_pc, dut.wb_pc);
                $display("ACT4 traps: count=%0d last_pc=%08x cause=%08x value=%08x mtvec=%08x",
                         trap_count, last_trap_pc, last_trap_cause,
                         last_trap_value, dut.csr_mtvec);
                $display("ACT4 first trap: pc=%08x cause=%08x value=%08x",
                         first_trap_pc, first_trap_cause, first_trap_value);
                $display("ACT4 stores: count=%0d last_addr=%08x last_data=%08x",
                         store_count, last_store_addr, last_store_data);
                $display("ACT4 last 16 retired instructions (oldest to newest):");
                for (integer hist_idx = 0; hist_idx < 16; hist_idx = hist_idx + 1) begin
                    $display("  pc=%08x inst=%08x",
                             commit_pc_history[(commit_history_index + hist_idx) & 15],
                             commit_inst_history[(commit_history_index + hist_idx) & 15]);
                end
                $fatal(1, "ACT4 timeout after %0d cycles: %s", max_cycles, test_name);
            end
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
        @(negedge clk);
        arst_n = 1'b1;
    end

endmodule
