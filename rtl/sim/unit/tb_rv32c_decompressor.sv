`timescale 1ns/1ps

module tb_rv32c_decompressor;
    logic [15:0] compressed;
    logic [31:0] instruction;
    logic        illegal;
    int          test_count = 0;
    int          pass_count = 0;

    rv32c_decompressor dut (
        .i_instruction(compressed),
        .o_instruction(instruction),
        .o_illegal(illegal)
    );

    task automatic check(
        input logic [15:0] value,
        input logic [31:0] expected,
        input logic        expected_illegal,
        input string       test_name
    );
        compressed = value;
        #1;
        test_count++;
        if ((instruction === expected) && (illegal === expected_illegal)) begin
            pass_count++;
            $display("[PASS] %s", test_name);
        end else begin
            $display("[FAIL] %s: instruction=%08h illegal=%b, expected=%08h/%b",
                     test_name, instruction, illegal, expected, expected_illegal);
        end
    endtask

    initial begin
        check(16'h0000, 32'h0000_0013, 1'b1, "reserved C.ADDI4SPN");
        check(16'h0001, 32'h0000_0013, 1'b0, "C.NOP");
        check(16'h0085, 32'h0010_8093, 1'b0, "C.ADDI x1, 1");
        check(16'h51fd, 32'hfff0_0193, 1'b0, "C.LI x3, -1");
        check(16'h7001, 32'h0000_0013, 1'b0, "C.LUI rd=x0 hint");
        check(16'h0086, 32'h0010_9093, 1'b0, "C.SLLI x1, 1");
        check(16'h8082, 32'h0000_8067, 1'b0, "C.JR x1");
        check(16'h9082, 32'h0000_80e7, 1'b0, "C.JALR x1");
        check(16'h9002, 32'h0010_0073, 1'b0, "C.EBREAK");
        check(16'h8192, 32'h0040_01b3, 1'b0, "C.MV x3, x4");
        check(16'h9192, 32'h0041_81b3, 1'b0, "C.ADD x3, x4");

        $display("Total: %0d, Passed: %0d, Failed: %0d",
                 test_count, pass_count, test_count - pass_count);
        if (pass_count == test_count)
            $display("*** ALL TESTS PASSED ***");
        else
            $fatal(1, "RV32C decompressor test failed");
        $finish;
    end
endmodule
