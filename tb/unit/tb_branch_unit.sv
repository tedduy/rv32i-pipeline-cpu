`timescale 1ns/1ps

module tb_branch_unit;

  // Parameters
  parameter N = 32;

  // DUT signals
  logic [N-1:0] rs1_data;
  logic [N-1:0] rs2_data;
  logic [2:0]   branch_type;
  logic         branch_enable;
  logic         branch_taken;

  // Branch types
  localparam [2:0]
    BRANCH_BEQ  = 3'b000,
    BRANCH_BNE  = 3'b001,
    BRANCH_BLT  = 3'b100,
    BRANCH_BGE  = 3'b101,
    BRANCH_BLTU = 3'b110,
    BRANCH_BGEU = 3'b111;

  // Instantiate DUT
  branch_unit #(.N(N)) dut (
    .i_rs1_data(rs1_data),
    .i_rs2_data(rs2_data),
    .i_branch_type(branch_type),
    .i_branch_enable(branch_enable),
    .o_branch_taken(branch_taken)
  );

  // Test counter
  int test_count = 0;
  int pass_count = 0;

  // Task: Check branch result
  task check_branch(input expected, input string test_name);
    #1;
    test_count++;
    if (branch_taken === expected) begin
      $display("[PASS] %s: branch_taken = %b", test_name, branch_taken);
      pass_count++;
    end else begin
      $display("[FAIL] %s: Expected %b, Got %b", test_name, expected, branch_taken);
    end
  endtask

  // Main test
  initial begin
    $display("=== Branch Unit Test ===");
    
    branch_enable = 1'b1;
    
    // Task 1: Test BEQ (Branch if Equal)
    $display("\n--- Task 1: BEQ (Branch if Equal) ---");
    branch_type = BRANCH_BEQ;
    rs1_data = 32'd100; rs2_data = 32'd100;
    check_branch(1'b1, "BEQ: 100 == 100 (taken)");
    
    rs1_data = 32'd100; rs2_data = 32'd50;
    check_branch(1'b0, "BEQ: 100 == 50 (not taken)");

    // Task 2: Test BNE (Branch if Not Equal)
    $display("\n--- Task 2: BNE (Branch if Not Equal) ---");
    branch_type = BRANCH_BNE;
    rs1_data = 32'd100; rs2_data = 32'd50;
    check_branch(1'b1, "BNE: 100 != 50 (taken)");
    
    rs1_data = 32'd100; rs2_data = 32'd100;
    check_branch(1'b0, "BNE: 100 != 100 (not taken)");

    // Task 3: Test BLT (Branch if Less Than - signed)
    $display("\n--- Task 3: BLT (Branch if Less Than - signed) ---");
    branch_type = BRANCH_BLT;
    rs1_data = -32'sd10; rs2_data = 32'd5;
    check_branch(1'b1, "BLT: -10 < 5 (taken)");
    
    rs1_data = 32'd10; rs2_data = 32'd5;
    check_branch(1'b0, "BLT: 10 < 5 (not taken)");
    
    rs1_data = -32'sd10; rs2_data = -32'sd20;
    check_branch(1'b0, "BLT: -10 < -20 (not taken)");

    rs1_data = 32'h80000000; rs2_data = 32'h7fffffff;
    check_branch(1'b1, "BLT: INT_MIN < INT_MAX (taken)");

    // Task 4: Test BGE (Branch if Greater or Equal - signed)
    $display("\n--- Task 4: BGE (Branch if Greater or Equal - signed) ---");
    branch_type = BRANCH_BGE;
    rs1_data = 32'd10; rs2_data = 32'd5;
    check_branch(1'b1, "BGE: 10 >= 5 (taken)");
    
    rs1_data = 32'd10; rs2_data = 32'd10;
    check_branch(1'b1, "BGE: 10 >= 10 (taken)");
    
    rs1_data = -32'sd10; rs2_data = 32'd5;
    check_branch(1'b0, "BGE: -10 >= 5 (not taken)");

    rs1_data = 32'h7fffffff; rs2_data = 32'h80000000;
    check_branch(1'b1, "BGE: INT_MAX >= INT_MIN (taken)");

    // Task 5: Test BLTU (Branch if Less Than - unsigned)
    $display("\n--- Task 5: BLTU (Branch if Less Than - unsigned) ---");
    branch_type = BRANCH_BLTU;
    rs1_data = 32'd5; rs2_data = 32'd10;
    check_branch(1'b1, "BLTU: 5 < 10 (taken)");
    
    rs1_data = 32'hFFFFFFFF; rs2_data = 32'd10;
    check_branch(1'b0, "BLTU: 0xFFFFFFFF < 10 (not taken, unsigned)");

    rs1_data = 32'h00000000; rs2_data = 32'hffffffff;
    check_branch(1'b1, "BLTU: 0 < UINT_MAX (taken)");

    // Task 6: Test BGEU (Branch if Greater or Equal - unsigned)
    $display("\n--- Task 6: BGEU (Branch if Greater or Equal - unsigned) ---");
    branch_type = BRANCH_BGEU;
    rs1_data = 32'd10; rs2_data = 32'd5;
    check_branch(1'b1, "BGEU: 10 >= 5 (taken)");
    
    rs1_data = 32'hFFFFFFFF; rs2_data = 32'd10;
    check_branch(1'b1, "BGEU: 0xFFFFFFFF >= 10 (taken, unsigned)");

    rs1_data = 32'h80000000; rs2_data = 32'h80000000;
    check_branch(1'b1, "BGEU: equal high-bit operands (taken)");

    // Task 7: Test branch_enable = 0
    $display("\n--- Task 7: Branch Enable = 0 ---");
    branch_enable = 1'b0;
    branch_type = BRANCH_BEQ;
    rs1_data = 32'd100; rs2_data = 32'd100;
    check_branch(1'b0, "Branch disabled (not taken even if condition met)");

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
