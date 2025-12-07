`timescale 1ns/1ps

module tb_jump_unit;

  // Parameters
  parameter N = 32;

  // DUT signals
  logic [N-1:0] pc;
  logic [N-1:0] rs1_data;
  logic [N-1:0] immediate;
  logic         jal;
  logic         jalr;
  logic [N-1:0] jump_target;
  logic [N-1:0] return_addr;

  // Instantiate DUT
  Jump_Unit #(.N(N)) dut (
    .i_pc(pc),
    .i_rs1_data(rs1_data),
    .i_immediate(immediate),
    .i_jal(jal),
    .i_jalr(jalr),
    .o_jump_target(jump_target),
    .o_return_addr(return_addr)
  );

  // Test counter
  int test_count = 0;
  int pass_count = 0;

  // Task: Check jump result
  task check_jump(input [N-1:0] expected_target, expected_return, input string test_name);
    #1;
    test_count++;
    if (jump_target === expected_target && return_addr === expected_return) begin
      $display("[PASS] %s: target=0x%h, return=0x%h", test_name, jump_target, return_addr);
      pass_count++;
    end else begin
      $display("[FAIL] %s: Expected (0x%h, 0x%h), Got (0x%h, 0x%h)", 
               test_name, expected_target, expected_return, jump_target, return_addr);
    end
  endtask

  // Main test
  initial begin
    $display("=== Jump Unit Test ===");
    
    // Task 1: Test JAL (Jump and Link)
    $display("\n--- Task 1: JAL (Jump and Link) ---");
    pc = 32'h00001000; immediate = 32'h00000100; jal = 1'b1; jalr = 1'b0; rs1_data = 32'h0;
    check_jump(32'h00001100, 32'h00001004, "JAL: PC + offset");
    
    pc = 32'h00002000; immediate = 32'hFFFFFFF0; jal = 1'b1; jalr = 1'b0;
    check_jump(32'h00001FF0, 32'h00002004, "JAL: PC + negative offset");

    // Task 2: Test JALR (Jump and Link Register)
    $display("\n--- Task 2: JALR (Jump and Link Register) ---");
    pc = 32'h00001000; rs1_data = 32'h00002000; immediate = 32'h00000010; jal = 1'b0; jalr = 1'b1;
    check_jump(32'h00002010, 32'h00001004, "JALR: rs1 + offset");
    
    pc = 32'h00001000; rs1_data = 32'h00003000; immediate = 32'hFFFFFFFC; jalr = 1'b1; jal = 1'b0;
    check_jump(32'h00002FFC, 32'h00001004, "JALR: rs1 + negative offset");
    
    // Test LSB clearing (target & ~1)
    pc = 32'h00001000; rs1_data = 32'h00002001; immediate = 32'h00000000; jalr = 1'b1; jal = 1'b0;
    check_jump(32'h00002000, 32'h00001004, "JALR: LSB cleared (odd address)");

    // Task 3: Test no jump (sequential)
    $display("\n--- Task 3: No Jump (Sequential) ---");
    pc = 32'h00001000; jal = 1'b0; jalr = 1'b0; rs1_data = 32'h0; immediate = 32'h0;
    check_jump(32'h00001004, 32'h00001004, "No jump: PC + 4");

    // Task 4: Test return address always PC+4
    $display("\n--- Task 4: Return Address Always PC+4 ---");
    pc = 32'h00005000; immediate = 32'h00001000; jal = 1'b1; jalr = 1'b0;
    #1;
    test_count++;
    if (return_addr === 32'h00005004) begin
      $display("[PASS] Return address is always PC+4");
      pass_count++;
    end else begin
      $display("[FAIL] Return address should be 0x00005004, got 0x%h", return_addr);
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
