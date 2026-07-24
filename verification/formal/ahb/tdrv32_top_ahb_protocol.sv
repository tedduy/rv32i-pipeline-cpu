module tdrv32_top_ahb_protocol_formal;

    (* gclk *) logic formal_timestep;
    logic i_clk = 1'b0;
    logic i_arst_n = 1'b0;
    logic [2:0] startup_half_cycles = 3'd0;

    always @(posedge formal_timestep) begin
        i_clk <= !i_clk;
        if (startup_half_cycles != 3'd7)
            startup_half_cycles <= startup_half_cycles + 3'd1;
        if (startup_half_cycles == 3'd5)
            i_arst_n <= 1'b1;
    end

    (* anyseq *) logic [31:0] i_iahb_hrdata;
    (* anyseq *) logic        i_iahb_hready;
    (* anyseq *) logic        i_iahb_hresp;
    (* anyseq *) logic [31:0] i_dahb_hrdata;
    (* anyseq *) logic        i_dahb_hready;
    (* anyseq *) logic        i_dahb_hresp;

    logic        o_core_sleep;
    logic [31:0] o_iahb_haddr;
    logic [1:0]  o_iahb_htrans;
    logic        o_iahb_hwrite;
    logic [2:0]  o_iahb_hsize;
    logic [2:0]  o_iahb_hburst;
    logic [3:0]  o_iahb_hprot;
    logic        o_iahb_hmastlock;
    logic [31:0] o_iahb_hwdata;
    logic [31:0] o_dahb_haddr;
    logic [1:0]  o_dahb_htrans;
    logic        o_dahb_hwrite;
    logic [2:0]  o_dahb_hsize;
    logic [2:0]  o_dahb_hburst;
    logic [3:0]  o_dahb_hprot;
    logic        o_dahb_hmastlock;
    logic [31:0] o_dahb_hwdata;

    tdrv32_top dut (
        .i_clk(i_clk),
        .i_arst_n(i_arst_n),
        .i_irq_software(1'b0),
        .i_irq_timer(1'b0),
        .i_irq_external(1'b0),
        .i_time(64'b0),
        .o_core_sleep(o_core_sleep),
        .o_fence_i(),
        .o_iahb_haddr(o_iahb_haddr),
        .o_iahb_htrans(o_iahb_htrans),
        .o_iahb_hwrite(o_iahb_hwrite),
        .o_iahb_hsize(o_iahb_hsize),
        .o_iahb_hburst(o_iahb_hburst),
        .o_iahb_hprot(o_iahb_hprot),
        .o_iahb_hmastlock(o_iahb_hmastlock),
        .o_iahb_hwdata(o_iahb_hwdata),
        .i_iahb_hrdata(i_iahb_hrdata),
        .i_iahb_hready(i_iahb_hready),
        .i_iahb_hresp(i_iahb_hresp),
        .o_dahb_haddr(o_dahb_haddr),
        .o_dahb_htrans(o_dahb_htrans),
        .o_dahb_hwrite(o_dahb_hwrite),
        .o_dahb_hsize(o_dahb_hsize),
        .o_dahb_hburst(o_dahb_hburst),
        .o_dahb_hprot(o_dahb_hprot),
        .o_dahb_hmastlock(o_dahb_hmastlock),
        .o_dahb_hwdata(o_dahb_hwdata),
        .i_dahb_hrdata(i_dahb_hrdata),
        .i_dahb_hready(i_dahb_hready),
        .i_dahb_hresp(i_dahb_hresp),
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

    logic past_valid = 1'b0;

    always @(posedge i_clk) begin
        past_valid <= 1'b1;

        assert(o_iahb_htrans == 2'b00 || o_iahb_htrans == 2'b10);
        assert(o_dahb_htrans == 2'b00 || o_dahb_htrans == 2'b10);
        assert(o_iahb_hburst == 3'b000);
        assert(o_dahb_hburst == 3'b000);
        assert(o_iahb_hprot == 4'b0010);
        assert(o_dahb_hprot == 4'b0011);
        assert(!o_iahb_hmastlock);
        assert(!o_dahb_hmastlock);
        assert(!o_iahb_hwrite);
        assert(o_iahb_hsize == 3'b010);
        if (o_dahb_htrans == 2'b10)
            assert(o_dahb_hsize <= 3'd2);

        if (!i_arst_n) begin
            assert(o_iahb_htrans == 2'b00);
            assert(o_dahb_htrans == 2'b00);
            assert(!o_core_sleep);
        end

        if (o_core_sleep) begin
            assert(o_iahb_htrans == 2'b00);
            assert(o_dahb_htrans == 2'b00);
        end

        if (past_valid && i_arst_n && $past(i_arst_n)) begin
            if ($past(o_iahb_htrans == 2'b10 && !i_iahb_hready)) begin
                assert(o_iahb_htrans == 2'b10);
                assert(o_iahb_haddr == $past(o_iahb_haddr));
                assert(o_iahb_hwrite == $past(o_iahb_hwrite));
                assert(o_iahb_hsize == $past(o_iahb_hsize));
            end

            if ($past(o_dahb_htrans == 2'b10 && !i_dahb_hready)) begin
                assert(o_dahb_htrans == 2'b10);
                assert(o_dahb_haddr == $past(o_dahb_haddr));
                assert(o_dahb_hwrite == $past(o_dahb_hwrite));
                assert(o_dahb_hsize == $past(o_dahb_hsize));
            end
        end

        cover(i_arst_n && o_iahb_htrans == 2'b10);
        cover(i_arst_n && o_dahb_htrans == 2'b10);
    end

endmodule
