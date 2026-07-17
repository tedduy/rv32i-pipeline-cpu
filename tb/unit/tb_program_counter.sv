`timescale 1ns/1ps

module tb_program_counter;

  // Parameters
  parameter N = 32;
  parameter CLK_PERIOD = 10;

  // DUT signals
  logic clk;
  logic arst_n;
  logic [N-1:0] i_PC;
  logic [N-1:0] o_PC;

  // Instantiate DUT
  program_counter #(.N(N)) dut (
    .i_clk(clk),
    .i_arst_n(arst_n),
    .i_PC(i_PC),
    .o_PC(o_PC)
  );

  // Clock generation
  initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  // Test counter
  int test_count = 0;
  int pass_count = 0;

  // Task: Check PC value
  task check_pc(input [N-1:0] expected, input string test_name);
    test_count++;
    if (o_PC === expected) begin
      $display("[PASS] %s: PC = 0x%h", test_name, o_PC);
      pass_count++;
    end else begin
      $display("[FAIL] %s: Expected 0x%h, Got 0x%h", test_name, expected, o_PC);
    end
  endtask

  // Main test
  initial begin
    $display("=== Program Counter Test ===");
    
    // Task 1: Test reset
    $display("\n--- Task 1: Reset Test ---");
    arst_n = 0;
    i_PC = 32'hDEADBEEF;
    @(posedge clk);
    #1 check_pc(32'h00000000, "Reset: PC = 0");
    
    // Task 2: Test PC update
    $display("\n--- Task 2: PC Update ---");
    arst_n = 1;
    i_PC = 32'h00001000;
    @(posedge clk);
    #1 check_pc(32'h00001000, "Update: PC = 0x1000");
    
    i_PC = 32'h00001004;
    @(posedge clk);
    #1 check_pc(32'h00001004, "Update: PC = 0x1004");
    
    i_PC = 32'h00001008;
    @(posedge clk);
    #1 check_pc(32'h00001008, "Update: PC = 0x1008");

    // Task 3: Test sequential increment
    $display("\n--- Task 3: Sequential Increment ---");
    i_PC = 32'h00002000;
    @(posedge clk);
    #1 check_pc(32'h00002000, "Sequential: PC = 0x2000");
    
    i_PC = o_PC + 4;
    @(posedge clk);
    #1 check_pc(32'h00002004, "Sequential: PC = 0x2004");
    
    i_PC = o_PC + 4;
    @(posedge clk);
    #1 check_pc(32'h00002008, "Sequential: PC = 0x2008");

    // Task 4: Test jump (non-sequential)
    $display("\n--- Task 4: Jump (Non-sequential) ---");
    i_PC = 32'h00005000;
    @(posedge clk);
    #1 check_pc(32'h00005000, "Jump: PC = 0x5000");
    
    i_PC = 32'h00001000;
    @(posedge clk);
    #1 check_pc(32'h00001000, "Jump back: PC = 0x1000");

    // Task 5: Test reset during operation
    $display("\n--- Task 5: Reset During Operation ---");
    i_PC = 32'h00003000;
    @(posedge clk);
    arst_n = 0;
    @(posedge clk);
    #1 check_pc(32'h00000000, "Reset during operation: PC = 0");

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
