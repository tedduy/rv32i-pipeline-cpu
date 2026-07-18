`timescale 1ns/1ps

module tb_native_to_ahb_lite;

    logic clk, arst_n;
    logic native_valid, native_write, native_ready, native_error;
    logic [31:0] native_addr, native_wdata, native_rdata;
    logic [1:0] native_size;
    logic [31:0] haddr, hwdata, hrdata;
    logic [1:0] htrans;
    logic hwrite, hready, hresp, hmastlock;
    logic busy;
    logic [2:0] hsize, hburst;
    logic [3:0] hprot;

    native_to_ahb_lite dut (
        .i_clk(clk), .i_arst_n(arst_n),
        .i_native_valid(native_valid), .i_native_write(native_write),
        .i_native_addr(native_addr), .i_native_wdata(native_wdata),
        .i_native_size(native_size), .o_native_rdata(native_rdata),
        .o_native_ready(native_ready), .o_native_error(native_error),
        .o_busy(busy),
        .o_haddr(haddr), .o_htrans(htrans), .o_hwrite(hwrite),
        .o_hsize(hsize), .o_hburst(hburst), .o_hprot(hprot),
        .o_hmastlock(hmastlock), .o_hwdata(hwdata),
        .i_hrdata(hrdata), .i_hready(hready), .i_hresp(hresp)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        arst_n      = 1'b0;
        native_valid = 1'b0;
        native_write = 1'b0;
        native_addr  = '0;
        native_wdata = '0;
        native_size  = 2'd2;
        hrdata        = '0;
        hready        = 1'b1;
        hresp         = 1'b0;
        repeat (3) @(posedge clk);
        @(negedge clk);
        arst_n = 1'b1;

        // Read address phase.
        native_valid = 1'b1;
        native_addr  = 32'h1234_5678;
        native_size  = 2'd1;
        #1;
        if (htrans !== 2'b10 || haddr !== native_addr || hwrite ||
            hsize !== 3'd1 || hburst !== 3'b000 || hmastlock)
            $fatal(1, "Bad AHB read address phase");
        @(posedge clk);
        #1;

        // Hold the response for two wait cycles.
        hready = 1'b0;
        repeat (2) begin
            @(posedge clk);
            #1;
            if (native_ready)
                $fatal(1, "Native request completed during AHB wait-state");
        end
        @(negedge clk);
        hrdata = 32'ha5a5_5a5a;
        hresp  = 1'b1;
        hready = 1'b1;
        #1;
        if (!native_ready || !native_error || native_rdata !== hrdata)
            $fatal(1, "AHB error response was not returned to native bus");
        @(posedge clk);
        @(negedge clk);
        native_valid = 1'b0;
        hresp = 1'b0;

        // Write transfer and data phase.
        native_valid = 1'b1;
        native_write = 1'b1;
        native_addr  = 32'h0000_0103;
        native_wdata = 32'h7f00_0000;
        native_size  = 2'd0;
        #1;
        if (htrans !== 2'b10 || !hwrite || hsize !== 3'd0)
            $fatal(1, "Bad AHB write address phase");
        @(posedge clk);
        #1;
        if (hwdata !== 32'h7f00_0000 || !native_ready || native_error)
            $fatal(1, "Bad AHB write data/response phase");
        @(posedge clk);
        @(negedge clk);
        native_valid = 1'b0;

        $display("*** NATIVE TO AHB-LITE BRIDGE TEST PASSED ***");
        $finish;
    end

    initial begin
        repeat (80) @(posedge clk);
        $fatal(1, "Timeout waiting for native-to-AHB test");
    end

endmodule
