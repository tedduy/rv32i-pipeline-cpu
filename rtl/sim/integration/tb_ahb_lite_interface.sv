`timescale 1ns/1ps

module tb_ahb_lite_interface;

    logic clk, arst_n;

    logic [31:0] iahb_haddr, iahb_hwdata, iahb_hrdata;
    logic [1:0]  iahb_htrans;
    logic        iahb_hwrite, iahb_hready, iahb_hresp;
    logic [2:0]  iahb_hsize, iahb_hburst;
    logic [3:0]  iahb_hprot;
    logic        iahb_hmastlock;

    logic [31:0] dahb_haddr, dahb_hwdata, dahb_hrdata;
    logic [1:0]  dahb_htrans;
    logic        dahb_hwrite, dahb_hready, dahb_hresp;
    logic [2:0]  dahb_hsize, dahb_hburst;
    logic [3:0]  dahb_hprot;
    logic        dahb_hmastlock;

    logic [31:0] instruction_addr;
    logic [31:0] data_addr;
    logic [2:0]  data_size;
    logic        data_write;
    logic        data_response_active;
    integer      data_wait_count;
    integer      data_wait_cycles;
    integer      data_transfer_count;
    integer      i;
    logic [7:0]  data_memory [0:255];

    rv32i_top dut (
        .i_clk(clk),
        .i_arst_n(arst_n),
        .i_irq_software(1'b0),
        .i_irq_timer(1'b0),
        .i_irq_external(1'b0),
        .i_time(64'b0),
        .o_core_sleep(),
        .o_fence_i(),
        .o_iahb_haddr(iahb_haddr),
        .o_iahb_htrans(iahb_htrans),
        .o_iahb_hwrite(iahb_hwrite),
        .o_iahb_hsize(iahb_hsize),
        .o_iahb_hburst(iahb_hburst),
        .o_iahb_hprot(iahb_hprot),
        .o_iahb_hmastlock(iahb_hmastlock),
        .o_iahb_hwdata(iahb_hwdata),
        .i_iahb_hrdata(iahb_hrdata),
        .i_iahb_hready(iahb_hready),
        .i_iahb_hresp(iahb_hresp),
        .o_dahb_haddr(dahb_haddr),
        .o_dahb_htrans(dahb_htrans),
        .o_dahb_hwrite(dahb_hwrite),
        .o_dahb_hsize(dahb_hsize),
        .o_dahb_hburst(dahb_hburst),
        .o_dahb_hprot(dahb_hprot),
        .o_dahb_hmastlock(dahb_hmastlock),
        .o_dahb_hwdata(dahb_hwdata),
        .i_dahb_hrdata(dahb_hrdata),
        .i_dahb_hready(dahb_hready),
        .i_dahb_hresp(dahb_hresp),
        .o_commit_valid(),
        .o_commit_pc(),
        .o_commit_instruction(),
        .o_commit_rd_write(),
        .o_commit_rd_addr(),
        .o_commit_rd_data(),
        .o_commit_mem_write(),
        .o_commit_mem_addr(),
        .o_commit_mem_wdata(),
        .o_commit_mem_wstrb()
    );

    // Zero-wait instruction slave. Address is captured in the AHB address
    // phase; read data is returned in the following data phase.
    assign iahb_hready = 1'b1;
    assign iahb_hresp  = 1'b0;

    always_ff @(posedge clk or negedge arst_n) begin
        if (!arst_n)
            instruction_addr <= '0;
        else if (iahb_htrans[1] && iahb_hready)
            instruction_addr <= iahb_haddr;
    end

    always_comb begin
        unique case (instruction_addr)
            32'h0000_0000: iahb_hrdata = 32'h07f0_0193; // addi x3, x0, 0x7f
            32'h0000_0004: iahb_hrdata = 32'h1000_0213; // addi x4, x0, 0x100
            32'h0000_0008: iahb_hrdata = 32'h0032_00a3; // sb   x3, 1(x4)
            32'h0000_000c: iahb_hrdata = 32'h0012_4283; // lbu  x5, 1(x4)
            32'h0000_0010: iahb_hrdata = 32'h1230_0313; // addi x6, x0, 0x123
            32'h0000_0014: iahb_hrdata = 32'h0062_1123; // sh   x6, 2(x4)
            32'h0000_0018: iahb_hrdata = 32'h0022_5383; // lhu  x7, 2(x4)
            32'h0000_001c: iahb_hrdata = 32'h0072_2223; // sw   x7, 4(x4)
            32'h0000_0020: iahb_hrdata = 32'h0042_2403; // lw   x8, 4(x4)
            32'h0000_0024: iahb_hrdata = 32'h0014_0493; // addi x9, x8, 1
            32'h0000_0028: iahb_hrdata = 32'h0000_006f; // jal  x0, 0
            default:       iahb_hrdata = 32'h0000_0013;
        endcase
    end

    // Data slave inserts two wait cycles into every response.
    assign dahb_hresp = 1'b0;
    always_comb begin
        dahb_hrdata = {
            data_memory[{data_addr[7:2], 2'b00} + 3],
            data_memory[{data_addr[7:2], 2'b00} + 2],
            data_memory[{data_addr[7:2], 2'b00} + 1],
            data_memory[{data_addr[7:2], 2'b00}]
        };
    end

    always_ff @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            dahb_hready         <= 1'b1;
            data_addr           <= '0;
            data_size           <= '0;
            data_write          <= 1'b0;
            data_response_active <= 1'b0;
            data_wait_count     <= 0;
            data_wait_cycles    <= 0;
            data_transfer_count <= 0;
            for (i = 0; i < 256; i = i + 1)
                data_memory[i] <= 8'h00;
        end else if (!data_response_active) begin
            dahb_hready <= 1'b1;
            if (dahb_htrans[1] && dahb_hready) begin
                data_addr            <= dahb_haddr;
                data_size            <= dahb_hsize;
                data_write           <= dahb_hwrite;
                data_response_active <= 1'b1;
                data_wait_count      <= 2;
                dahb_hready          <= 1'b0;

                if ((dahb_haddr == 32'h0000_0101 && dahb_hsize != 3'd0) ||
                    (dahb_haddr == 32'h0000_0102 && dahb_hsize != 3'd1) ||
                    (dahb_haddr == 32'h0000_0104 && dahb_hsize != 3'd2))
                    $fatal(1, "Incorrect HSIZE=%0d for address %08h",
                           dahb_hsize, dahb_haddr);
            end
        end else if (!dahb_hready) begin
            data_wait_cycles <= data_wait_cycles + 1;
            if (data_wait_count > 0)
                data_wait_count <= data_wait_count - 1;
            else
                dahb_hready <= 1'b1;
        end else begin
            if (data_write) begin
                unique case (data_size)
                    3'd0: data_memory[data_addr[7:0]] <=
                              dahb_hwdata[8*data_addr[1:0] +: 8];
                    3'd1: begin
                        data_memory[data_addr[7:0]] <=
                            dahb_hwdata[8*data_addr[1:0] +: 8];
                        data_memory[data_addr[7:0] + 1] <=
                            dahb_hwdata[8*data_addr[1:0] + 8 +: 8];
                    end
                    default: begin
                        data_memory[data_addr[7:0]]     <= dahb_hwdata[7:0];
                        data_memory[data_addr[7:0] + 1] <= dahb_hwdata[15:8];
                        data_memory[data_addr[7:0] + 2] <= dahb_hwdata[23:16];
                        data_memory[data_addr[7:0] + 3] <= dahb_hwdata[31:24];
                    end
                endcase
            end
            data_transfer_count  <= data_transfer_count + 1;
            data_response_active <= 1'b0;
        end
    end

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        arst_n = 1'b0;
        repeat (3) @(posedge clk);
        @(negedge clk);
        arst_n = 1'b1;

        wait (dut.u_core.u_id_regfile.regs[9] == 32'h0000_0124);
        repeat (4) @(posedge clk);
        #1;

        if (dut.u_core.u_id_regfile.regs[5] !== 32'h0000_007f ||
            dut.u_core.u_id_regfile.regs[7] !== 32'h0000_0123 ||
            dut.u_core.u_id_regfile.regs[8] !== 32'h0000_0123)
            $fatal(1, "AHB load/store results are incorrect");
        if (data_transfer_count !== 6 || data_wait_cycles == 0)
            $fatal(1, "AHB transfer/wait coverage: transfers=%0d waits=%0d",
                   data_transfer_count, data_wait_cycles);
        if (iahb_hwrite || iahb_hburst != 3'b000 ||
            iahb_hprot != 4'b0010 || iahb_hmastlock ||
            dahb_hburst != 3'b000 || dahb_hprot != 4'b0011 ||
            dahb_hmastlock)
            $fatal(1, "AHB fixed control outputs are incorrect");

        $display("*** AHB-LITE INTERFACE TEST PASSED ***");
        $display("Byte/halfword/word transfers and wait states verified");
        $finish;
    end

    initial begin
        repeat (600) @(posedge clk);
        $fatal(1, "Timeout waiting for AHB-Lite interface test");
    end

endmodule
