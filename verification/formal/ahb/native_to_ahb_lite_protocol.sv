module native_to_ahb_lite_protocol_formal;

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

    (* anyseq *) logic        i_native_valid;
    (* anyseq *) logic        i_native_write;
    (* anyseq *) logic [31:0] i_native_addr;
    (* anyseq *) logic [31:0] i_native_wdata;
    (* anyseq *) logic [1:0]  i_native_size;
    (* anyseq *) logic [31:0] i_hrdata;
    (* anyseq *) logic        i_hready;
    (* anyseq *) logic        i_hresp;

    logic [31:0] o_native_rdata;
    logic        o_native_ready;
    logic        o_native_error;
    logic        o_busy;
    logic [31:0] o_haddr;
    logic [1:0]  o_htrans;
    logic        o_hwrite;
    logic [2:0]  o_hsize;
    logic [2:0]  o_hburst;
    logic [3:0]  o_hprot;
    logic        o_hmastlock;
    logic [31:0] o_hwdata;

    native_to_ahb_lite dut (
        .i_clk(i_clk),
        .i_arst_n(i_arst_n),
        .i_native_valid(i_native_valid),
        .i_native_write(i_native_write),
        .i_native_addr(i_native_addr),
        .i_native_wdata(i_native_wdata),
        .i_native_size(i_native_size),
        .o_native_rdata(o_native_rdata),
        .o_native_ready(o_native_ready),
        .o_native_error(o_native_error),
        .o_busy(o_busy),
        .o_haddr(o_haddr),
        .o_htrans(o_htrans),
        .o_hwrite(o_hwrite),
        .o_hsize(o_hsize),
        .o_hburst(o_hburst),
        .o_hprot(o_hprot),
        .o_hmastlock(o_hmastlock),
        .o_hwdata(o_hwdata),
        .i_hrdata(i_hrdata),
        .i_hready(i_hready),
        .i_hresp(i_hresp)
    );

    logic past_valid = 1'b0;

    always @(posedge i_clk) begin
        past_valid <= 1'b1;

        assume(i_native_size <= 2'd2);
        if (!i_arst_n)
            assume(!i_native_valid);

        assert(o_htrans == 2'b00 || o_htrans == 2'b10);
        assert(o_hburst == 3'b000);
        assert(o_hprot == 4'b0011);
        assert(!o_hmastlock);
        assert(o_native_rdata == i_hrdata);
        assert(o_native_ready == (o_busy && i_hready));
        assert(o_native_error == (o_native_ready && i_hresp));

        if (!i_arst_n) begin
            assert(!o_busy);
            assert(!o_native_ready);
            assert(o_htrans == 2'b00);
        end else begin
            if (o_busy)
                assert(o_htrans == 2'b00);
            if (o_htrans == 2'b10)
                assert(o_hsize <= 3'd2);
        end

        if (past_valid && i_arst_n && $past(i_arst_n)) begin
            if ($past(i_native_valid && !o_native_ready)) begin
                assume(i_native_valid);
                assume(i_native_write == $past(i_native_write));
                assume(i_native_addr == $past(i_native_addr));
                assume(i_native_wdata == $past(i_native_wdata));
                assume(i_native_size == $past(i_native_size));
            end

            if ($past(o_htrans == 2'b10 && !i_hready)) begin
                assert(o_htrans == 2'b10);
                assert(o_haddr == $past(o_haddr));
                assert(o_hwrite == $past(o_hwrite));
                assert(o_hsize == $past(o_hsize));
            end

            if ($past(o_busy && !i_hready)) begin
                assert(o_busy);
                assert(o_haddr == $past(o_haddr));
                assert(o_hwdata == $past(o_hwdata));
            end

            if ($past(o_busy && i_hready))
                assert(!o_busy);

            if (!$past(o_busy) && o_busy) begin
                assert($past(o_htrans == 2'b10));
                assert($past(i_hready));
            end
        end

        cover(i_arst_n && o_native_ready && !o_native_error);
        cover(i_arst_n && o_native_ready && o_native_error);
        cover(i_arst_n && o_busy && !i_hready);
    end

endmodule
