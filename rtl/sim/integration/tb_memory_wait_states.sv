`timescale 1ns/1ps

// Integration test for instruction and data valid/ready handshakes.
module tb_memory_wait_states;

    logic        clk;
    logic        arst_n;
    integer      cycle_count;
    integer      imem_wait_cycles;
    integer      dmem_wait_cycles;

    logic        imem_valid, imem_ready;
    logic [31:0] imem_addr, imem_rdata;

    logic        dmem_valid, dmem_ready;
    logic        dmem_read, dmem_write;
    logic [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    logic [3:0]  dmem_wstrb;

    logic        dmem_seen;
    integer      dmem_delay;
    logic        imem_waiting, dmem_waiting;
    logic [31:0] held_imem_addr;
    logic [31:0] held_dmem_addr, held_dmem_wdata;
    logic [3:0]  held_dmem_wstrb;
    logic        held_dmem_read, held_dmem_write;

    rv32i_core dut (
        .i_clk         (clk),
        .i_arst_n      (arst_n),
        .i_irq_software(1'b0),
        .i_irq_timer   (1'b0),
        .i_irq_external(1'b0),
        .i_time        (64'b0),
        .o_core_sleep  (),
        .o_fence_i     (),
        .o_imem_valid  (imem_valid),
        .o_imem_addr   (imem_addr),
        .i_imem_rdata  (imem_rdata),
        .i_imem_ready  (imem_ready),
        .i_imem_error  (1'b0),
        .o_dmem_valid  (dmem_valid),
        .o_dmem_read   (dmem_read),
        .o_dmem_write  (dmem_write),
        .o_dmem_addr   (dmem_addr),
        .o_dmem_wdata  (dmem_wdata),
        .o_dmem_wstrb  (dmem_wstrb),
        .o_dmem_size   (),
        .i_dmem_rdata  (dmem_rdata),
        .i_dmem_ready  (dmem_ready),
        .i_dmem_error  (1'b0),
        .o_commit_valid(),
        .o_commit_pc(),
        .o_commit_instruction(),
        .o_commit_rd_write(),
        .o_commit_rd_addr(),
        .o_commit_rd_data(),
        .o_commit_mem_write(),
        .o_commit_mem_addr(),
        .o_commit_mem_wdata(),
        .o_commit_mem_wstrb(),
        .o_debug_pc      (),
        .o_debug_instruction   (),
        .o_debug_rs1_data         (),
        .o_debug_rs2_data         (),
        .o_debug_alu_operand_b          (),
        .o_debug_branch_target          (),
        .o_debug_alu_result      (),
        .o_debug_wb_data     (),
        .o_debug_rd_addr     (),
        .o_debug_rd_write   (),
        .o_debug_mem_write   (),
        .o_debug_mem_read    (),
        .o_debug_branch_taken(),
        .o_debug_mem_addr    (),
        .o_debug_mem_wdata   (),
        .o_debug_mem_rdata   (),
        .o_debug_jal         (),
        .o_debug_jalr        (),
        .o_debug_stall       (),
        .o_debug_flush       (),
        .o_debug_immediate   (),
        .o_debug_alu_uses_immediate      ()
    );

    // Program:
    //   addi x3, x0, 5
    //   addi x6, x0, 7
    //   add  x7, x3, x6
    //   sw   x7, 0(x0)
    //   lw   x8, 0(x0)
    //   addi x9, x8, 1
    always_comb begin
        unique case (imem_addr)
            32'h0000_0000: imem_rdata = 32'h0050_0193;
            32'h0000_0004: imem_rdata = 32'h0070_0313;
            32'h0000_0008: imem_rdata = 32'h0061_83b3;
            32'h0000_000c: imem_rdata = 32'h0070_2023;
            32'h0000_0010: imem_rdata = 32'h0000_2403;
            32'h0000_0014: imem_rdata = 32'h0014_0493;
            default:       imem_rdata = 32'h0000_0013;
        endcase
    end

    // Insert one instruction wait-state every four testbench cycles.
    always_comb begin
        imem_ready = !imem_valid || (cycle_count[1:0] != 2'b01);
    end

    // Each data request waits for two cycles before it is accepted.
    always_ff @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            dmem_ready <= 1'b0;
            dmem_seen  <= 1'b0;
            dmem_delay <= 0;
        end else if (!dmem_valid) begin
            dmem_ready <= 1'b0;
            dmem_seen  <= 1'b0;
            dmem_delay <= 0;
        end else if (!dmem_seen) begin
            dmem_ready <= 1'b0;
            dmem_seen  <= 1'b1;
            dmem_delay <= 2;
        end else if (dmem_delay > 0) begin
            dmem_ready <= 1'b0;
            dmem_delay <= dmem_delay - 1;
        end else if (!dmem_ready) begin
            dmem_ready <= 1'b1;
        end else begin
            // The transfer was accepted on this edge. Prepare for a possible
            // back-to-back request on the following cycle.
            dmem_ready <= 1'b0;
            dmem_seen  <= 1'b0;
        end
    end

    // A valid request must remain stable for every cycle in which ready is low.
    always_ff @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            imem_waiting    <= 1'b0;
            dmem_waiting    <= 1'b0;
            held_imem_addr  <= '0;
            held_dmem_addr  <= '0;
            held_dmem_wdata <= '0;
            held_dmem_wstrb <= '0;
            held_dmem_read  <= 1'b0;
            held_dmem_write <= 1'b0;
        end else begin
            if (imem_valid && !imem_ready) begin
                if (imem_waiting && imem_addr !== held_imem_addr)
                    $fatal(1, "Instruction address changed while waiting");
                held_imem_addr <= imem_addr;
                imem_waiting   <= 1'b1;
            end else begin
                imem_waiting <= 1'b0;
            end

            if (dmem_valid && !dmem_ready) begin
                if (dmem_waiting &&
                    (dmem_addr  !== held_dmem_addr  ||
                     dmem_wdata !== held_dmem_wdata ||
                     dmem_wstrb !== held_dmem_wstrb ||
                     dmem_read  !== held_dmem_read  ||
                     dmem_write !== held_dmem_write))
                    $fatal(1, "Data request changed while waiting");
                held_dmem_addr  <= dmem_addr;
                held_dmem_wdata <= dmem_wdata;
                held_dmem_wstrb <= dmem_wstrb;
                held_dmem_read  <= dmem_read;
                held_dmem_write <= dmem_write;
                dmem_waiting    <= 1'b1;
            end else begin
                dmem_waiting <= 1'b0;
            end
        end
    end

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

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always_ff @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            cycle_count      <= 0;
            imem_wait_cycles <= 0;
            dmem_wait_cycles <= 0;
        end else begin
            cycle_count <= cycle_count + 1;
            if (imem_valid && !imem_ready)
                imem_wait_cycles <= imem_wait_cycles + 1;
            if (dmem_valid && !dmem_ready)
                dmem_wait_cycles <= dmem_wait_cycles + 1;
        end
    end

    initial begin
        arst_n = 1'b0;
        repeat (3) @(posedge clk);
        @(negedge clk);
        arst_n = 1'b1;

        repeat (100) @(posedge clk);
        #1;

        if (imem_wait_cycles == 0)
            $fatal(1, "Instruction interface did not exercise any wait-state");
        if (dmem_wait_cycles < 4)
            $fatal(1, "Data interface wait-state coverage too low: %0d", dmem_wait_cycles);

        if (dut.u_id_regfile.regs[7] !== 32'd12)
            $fatal(1, "Arithmetic before memory failed: x7=%08h", dut.u_id_regfile.regs[7]);
        if (dut.u_id_regfile.regs[8] !== 32'd12)
            $fatal(1, "Delayed load failed: x8=%08h", dut.u_id_regfile.regs[8]);
        if (dut.u_id_regfile.regs[9] !== 32'd13)
            $fatal(1, "Post-load dependency failed: x9=%08h", dut.u_id_regfile.regs[9]);

        $display("*** MEMORY WAIT-STATE TEST PASSED ***");
        $display("Instruction wait cycles: %0d", imem_wait_cycles);
        $display("Data wait cycles:        %0d", dmem_wait_cycles);
        $finish;
    end

endmodule
