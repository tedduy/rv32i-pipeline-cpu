`timescale 1ns/1ps

module tb_rv32c_fetch_buffer;
    logic        clk;
    logic        arst_n;
    logic        flush;
    logic        consume;
    logic [31:0] pc;
    logic        response_valid;
    logic [31:0] response_data;
    logic        response_error;
    logic [31:0] bus_addr;
    logic        complete;
    logic [31:0] instruction;
    logic [31:0] raw_instruction;
    logic        compressed;
    logic        access_fault;
    int          test_count = 0;
    int          pass_count = 0;

    rv32c_fetch_buffer dut (
        .i_clk(clk),
        .i_arst_n(arst_n),
        .i_flush(flush),
        .i_consume(consume),
        .i_pc(pc),
        .i_response_valid(response_valid),
        .i_response_data(response_data),
        .i_response_error(response_error),
        .o_bus_addr(bus_addr),
        .o_complete(complete),
        .o_instruction(instruction),
        .o_raw_instruction(raw_instruction),
        .o_compressed(compressed),
        .o_access_fault(access_fault)
    );

    always #5 clk = ~clk;

    task automatic check_result(
        input logic        expected_complete,
        input logic [31:0] expected_instruction,
        input logic [31:0] expected_raw_instruction,
        input logic        expected_compressed,
        input logic        expected_fault,
        input string       test_name
    );
        #1;
        test_count++;
        if ((complete === expected_complete) &&
            (instruction === expected_instruction) &&
            (raw_instruction === expected_raw_instruction) &&
            (compressed === expected_compressed) &&
            (access_fault === expected_fault)) begin
            pass_count++;
            $display("[PASS] %s", test_name);
        end else begin
            $display("[FAIL] %s: complete=%b instruction=%08h raw=%08h compressed=%b fault=%b",
                     test_name, complete, instruction, raw_instruction,
                     compressed, access_fault);
        end
    endtask

    initial begin
        clk = 1'b0;
        arst_n = 1'b0;
        flush = 1'b0;
        consume = 1'b0;
        pc = 32'b0;
        response_valid = 1'b0;
        response_data = 32'b0;
        response_error = 1'b0;
        #12;
        arst_n = 1'b1;

        pc = 32'h0000_0000;
        response_valid = 1'b1;
        response_data = 32'h0010_0093;
        check_result(1'b1, 32'h0010_0093, 32'h0010_0093, 1'b0, 1'b0,
                     "aligned 32-bit instruction");

        response_data = 32'hffff_0001;
        check_result(1'b1, 32'h0000_0013, 32'h0000_0001, 1'b1, 1'b0,
                     "compressed low halfword");

        pc = 32'h0000_0002;
        response_data = 32'h0085_ffff;
        check_result(1'b1, 32'h0010_8093, 32'h0000_0085, 1'b1, 1'b0,
                     "compressed upper halfword");

        response_valid = 1'b0;
        @(negedge clk);
        pc = 32'h0000_0002;
        response_data = 32'h0093_ffff;
        response_valid = 1'b1;
        consume = 1'b0;
        check_result(1'b0, 32'h0000_0013, 32'h0000_0013, 1'b0, 1'b0,
                     "cross-word first response waits");
        @(posedge clk);
        #1;
        if (bus_addr !== 32'h0000_0004)
            $fatal(1, "Cross-word second address=%08h, expected 00000004", bus_addr);
        response_data = 32'hffff_0010;
        consume = 1'b1;
        check_result(1'b1, 32'h0010_0093, 32'h0010_0093, 1'b0, 1'b0,
                     "cross-word instruction assembled");
        @(posedge clk);
        #1;
        consume = 1'b0;

        pc = 32'h0000_0010;
        response_error = 1'b1;
        response_data = 32'h0000_0000;
        check_result(1'b1, 32'h0000_0013, 32'h0000_0013, 1'b0, 1'b1,
                     "instruction access fault");

        $display("Total: %0d, Passed: %0d, Failed: %0d",
                 test_count, pass_count, test_count - pass_count);
        if (pass_count == test_count)
            $display("*** ALL TESTS PASSED ***");
        else
            $fatal(1, "RV32C fetch-buffer test failed");
        $finish;
    end
endmodule
