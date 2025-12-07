`timescale 1ns/1ps

module tb_alu_unit;

  // Parameters
  parameter N = 32;
  parameter CLK_PERIOD = 10;

  // DUT signals
  logic [N-1:0] operand_a;
  logic [N-1:0] operand_b;
  logic [3:0]   alu_ctrl;
  logic [N-1:0] alu_result;
  logic         zero_flag;

  // ALU control codes
  localparam [3:0]
    ALU_ADD  = 4'b0000,
    ALU_SUB  = 4'b0001,
    ALU_AND  = 4'b0010,
    ALU_OR   = 4'b0011,
    ALU_XOR  = 4'b0100,
    ALU_SLT  = 4'b0101,
    ALU_SLTU = 4'b0110,
    ALU_SLL  = 4'b0111,
    ALU_SRL  = 4'b1000,
    ALU_SRA  = 4'b1001;

  // Instantiate DUT
  ALU_Unit #(.N(N)) dut (
    .i_operand_a(operand_a),
    .i_operand_b(operand_b),
    .i_alu_ctrl(alu_ctrl),
    .o_alu_result(alu_result),
    .o_zero_flag(zero_flag)
  );

  // Test counter
  int test_count = 0;
  int pass_count = 0;

  // Task: Check result
  task check_result(input [N-1:0] expected, input string test_name);
    test_count++;
    if (alu_result === expected) begin
      $display("[PASS] %s: Result = 0x%h", test_name, alu_result);
      pass_count++;
    end else begin
      $display("[FAIL] %s: Expected 0x%h, Got 0x%h", test_name, expected, alu_result);
    end
  endtask

  // Main test
  initial begin
    $display("=== ALU Unit Test ===");
    
    // Task 1: Test arithmetic operations
    $display("\n--- Task 1: Arithmetic Operations ---");
    operand_a = 32'd15; operand_b = 32'd10; alu_ctrl = ALU_ADD; #1;
    check_result(32'd25, "ADD: 15 + 10");
    
    operand_a = 32'd20; operand_b = 32'd8; alu_ctrl = ALU_SUB; #1;
    check_result(32'd12, "SUB: 20 - 8");

    // Task 2: Test logical operations
    $display("\n--- Task 2: Logical Operations ---");
    operand_a = 32'hF0F0; operand_b = 32'h0FF0; alu_ctrl = ALU_AND; #1;
    check_result(32'h00F0, "AND: 0xF0F0 & 0x0FF0");
    
    operand_a = 32'hF000; operand_b = 32'h0F00; alu_ctrl = ALU_OR; #1;
    check_result(32'hFF00, "OR: 0xF000 | 0x0F00");
    
    operand_a = 32'hFFFF; operand_b = 32'hF0F0; alu_ctrl = ALU_XOR; #1;
    check_result(32'h0F0F, "XOR: 0xFFFF ^ 0xF0F0");

    // Task 3: Test comparison operations
    $display("\n--- Task 3: Comparison Operations ---");
    operand_a = -32'sd5; operand_b = 32'd10; alu_ctrl = ALU_SLT; #1;
    check_result(32'd1, "SLT: -5 < 10 (signed)");
    
    operand_a = 32'd5; operand_b = 32'd10; alu_ctrl = ALU_SLTU; #1;
    check_result(32'd1, "SLTU: 5 < 10 (unsigned)");

    // Task 4: Test shift operations
    $display("\n--- Task 4: Shift Operations ---");
    operand_a = 32'h00000001; operand_b = 32'd4; alu_ctrl = ALU_SLL; #1;
    check_result(32'h00000010, "SLL: 1 << 4");
    
    operand_a = 32'h80000000; operand_b = 32'd4; alu_ctrl = ALU_SRL; #1;
    check_result(32'h08000000, "SRL: 0x80000000 >> 4 (logical)");
    
    operand_a = 32'h80000000; operand_b = 32'd4; alu_ctrl = ALU_SRA; #1;
    check_result(32'hF8000000, "SRA: 0x80000000 >> 4 (arithmetic)");

    // Task 5: Test zero flag
    $display("\n--- Task 5: Zero Flag ---");
    operand_a = 32'd10; operand_b = 32'd10; alu_ctrl = ALU_SUB; #1;
    if (zero_flag === 1'b1) begin
      $display("[PASS] Zero flag set when result is 0");
      pass_count++; test_count++;
    end else begin
      $display("[FAIL] Zero flag not set when result is 0");
      test_count++;
    end

    // Summary
    $display("\n=== Test Summary ===");
    $display("Total: %0d, Passed: %0d, Failed: %0d", test_count, pass_count, test_count - pass_count);
    
    if (pass_count == test_count)
      $display("*** ALL TESTS PASSED ***");
    else
      $display("*** SOME TESTS FAILED ***");
    
    $finish;
  end

endmodule
