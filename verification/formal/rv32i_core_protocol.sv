module rv32i_core_protocol_formal;

    (* gclk *) logic formal_timestep;
    logic i_clk = 1'b0;
    logic i_arst_n = 1'b0;
    logic [2:0] startup_half_cycles = 3'd0;

    always @(posedge formal_timestep) begin
        i_clk <= !i_clk;
        if (startup_half_cycles != 3'd7)
            startup_half_cycles <= startup_half_cycles + 3'd1;
        // Deassert reset on a falling clock edge after three rising edges.
        if (startup_half_cycles == 3'd5)
            i_arst_n <= 1'b1;
    end

    (* anyseq *) logic [31:0] i_imem_rdata;
    (* anyseq *) logic        i_imem_ready;
    (* anyseq *) logic [31:0] i_dmem_rdata;
    (* anyseq *) logic        i_dmem_ready;

    logic        o_core_sleep;
    logic        o_imem_valid;
    logic [31:0] o_imem_addr;
    logic        o_dmem_valid;
    logic        o_dmem_read;
    logic        o_dmem_write;
    logic [31:0] o_dmem_addr;
    logic [31:0] o_dmem_wdata;
    logic [3:0]  o_dmem_wstrb;
    logic [1:0]  o_dmem_size;
    logic        o_commit_valid;
    logic [31:0] o_commit_pc;
    logic        o_commit_rd_write;
    logic [4:0]  o_commit_rd_addr;
    logic        o_commit_mem_write;
    logic [3:0]  o_commit_mem_wstrb;

    rv32i_core dut (
        .i_clk(i_clk),
        .i_arst_n(i_arst_n),
        .i_irq_software(1'b0),
        .i_irq_timer(1'b0),
        .i_irq_external(1'b0),
        .i_time(64'b0),
        .o_core_sleep(o_core_sleep),
        .o_fence_i(),
        .o_imem_valid(o_imem_valid),
        .o_imem_addr(o_imem_addr),
        .i_imem_rdata(i_imem_rdata),
        .i_imem_ready(i_imem_ready),
        .i_imem_error(1'b0),
        .o_dmem_valid(o_dmem_valid),
        .o_dmem_read(o_dmem_read),
        .o_dmem_write(o_dmem_write),
        .o_dmem_addr(o_dmem_addr),
        .o_dmem_wdata(o_dmem_wdata),
        .o_dmem_wstrb(o_dmem_wstrb),
        .o_dmem_size(o_dmem_size),
        .i_dmem_rdata(i_dmem_rdata),
        .i_dmem_ready(i_dmem_ready),
        .i_dmem_error(1'b0),
        .o_commit_valid(o_commit_valid),
        .o_commit_pc(o_commit_pc),
        .o_commit_instruction(),
        .o_commit_rd_write(o_commit_rd_write),
        .o_commit_rd_addr(o_commit_rd_addr),
        .o_commit_rd_data(),
        .o_commit_mem_write(o_commit_mem_write),
        .o_commit_mem_addr(),
        .o_commit_mem_wdata(),
        .o_commit_mem_wstrb(o_commit_mem_wstrb),
        .o_debug_pc(),
        .o_debug_instruction(),
        .o_debug_rs1_data(),
        .o_debug_rs2_data(),
        .o_debug_alu_operand_b(),
        .o_debug_branch_target(),
        .o_debug_alu_result(),
        .o_debug_wb_data(),
        .o_debug_rd_addr(),
        .o_debug_rd_write(),
        .o_debug_mem_write(),
        .o_debug_mem_read(),
        .o_debug_branch_taken(),
        .o_debug_mem_addr(),
        .o_debug_mem_wdata(),
        .o_debug_mem_rdata(),
        .o_debug_jal(),
        .o_debug_jalr(),
        .o_debug_stall(),
        .o_debug_flush(),
        .o_debug_immediate(),
        .o_debug_alu_uses_immediate()
    );

    logic past_valid = 1'b0;

    always @(posedge i_clk) begin
        past_valid <= 1'b1;

        if (!i_arst_n) begin
            assert(!o_imem_valid);
            assert(!o_dmem_valid);
            assert(!o_commit_valid);
        end else begin
            assert(!o_core_sleep || !o_imem_valid);
            assert(!o_commit_rd_write || o_commit_valid);
            assert(!o_commit_rd_write || o_commit_rd_addr != 5'd0);
            assert(!o_commit_mem_write || o_commit_valid);
            assert(!o_commit_valid || o_commit_pc[0] == 1'b0);

            if (o_dmem_valid) begin
                assert(o_dmem_read != o_dmem_write);
                assert(!o_dmem_read || o_dmem_wstrb == 4'b0000);
                assert(!o_dmem_write || o_dmem_wstrb != 4'b0000);
                if (o_dmem_size == 2'd2)
                    assert(o_dmem_addr[1:0] == 2'b00);
                if (o_dmem_size == 2'd1)
                    assert(o_dmem_addr[0] == 1'b0);
            end

            if (o_commit_mem_write)
                assert(o_commit_mem_wstrb != 4'b0000);
        end

        if (past_valid && i_arst_n && $past(i_arst_n)) begin
            if ($past(o_imem_valid && !i_imem_ready)) begin
                assert(o_imem_valid);
                assert(o_imem_addr == $past(o_imem_addr));
            end

            if ($past(o_dmem_valid && !i_dmem_ready)) begin
                assert(o_dmem_valid);
                assert(o_dmem_read == $past(o_dmem_read));
                assert(o_dmem_write == $past(o_dmem_write));
                assert(o_dmem_addr == $past(o_dmem_addr));
                assert(o_dmem_wdata == $past(o_dmem_wdata));
                assert(o_dmem_wstrb == $past(o_dmem_wstrb));
                assert(o_dmem_size == $past(o_dmem_size));
            end
        end

        cover(i_arst_n && o_commit_valid);
        cover(i_arst_n && o_dmem_valid);
    end

endmodule
