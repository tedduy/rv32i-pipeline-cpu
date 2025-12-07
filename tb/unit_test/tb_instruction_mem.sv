`timescale 1ns/1ps

module tb_instruction_mem;

  // Parameters
  parameter N = 32;
  parameter DEPTH = 77;
  parameter CLK_PERIOD = 10;

  // DUT signals
  logic clk;
  logic arst_n;
  logic [N-1:0] addr;
  logic [N-1:0] inst;

  // Instantiate DUT
  Instruction_Mem #(
    .N(N),
    .DEPTH(DEPTH)
  ) dut (
    .i_clk(clk),
    .i_arst_n(arst_n),
    .i_addr(addr),
    .o_inst(inst)
  );

  // Clock generation
  initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  // Test counter
  int test_count = 0;
  int pass_count = 0;

  // Task: Check instruction
  task check_inst(input [N-1:0] expected, input string test_name);
    #1;
    test_count++;
    if (inst === expected) begin
      $display("[PASS] %s: inst = 0x%h", test_name, inst);
      pass_count++;
    end else begin
      $display("[FAIL] %s: Expected 0x%h, Got 0x%h", test_name, expected, inst);
    end
  endtask

  // Main test
  initial begin
    $display("=== Instruction Memory Test ===");
    
    // Initialize
    arst_n = 0;
    addr = 0;
    
    // Task 1: Test reset
    $display("\n--- Task 1: Reset Test ---");
    @(posedge clk);
    arst_n = 1;
    @(posedge clk);
    addr = 32'h00000000;
    @(posedge clk);
    check_inst(32'h00000000, "Address 0x00: NOP");

    // Task 2: Test sequential read
    $display("\n--- Task 2: Sequential Read ---");
    addr = 32'h00000004; // Word address 1
    @(posedge clk);
    check_inst(32'h002081b3, "Address 0x04: ADD x3, x1, x2");
    
    addr = 32'h00000008; // Word address 2
    @(posedge clk);
    check_inst(32'h40520333, "Address 0x08: SUB x6, x4, x5");
    
    addr = 32'h0000000C; // Word address 3
    @(posedge clk);
    check_inst(32'h004091b3, "Address 0x0C: SLL x3, x1, x4");

    // Task 3: Test random access
    $display("\n--- Task 3: Random Access ---");
    addr = 32'h00000050; // Word address 20
    @(posedge clk);
    check_inst(32'h0050f1b3, "Address 0x50: AND x3, x1, x5");
    
    addr = 32'h00000110; // Word address 68
    @(posedge clk);
    check_inst(32'h123450b7, "Address 0x110: LUI x1, 0x12345");
    
    addr = 32'h00000120; // Word address 72
    @(posedge clk);
    check_inst(32'h008000ef, "Address 0x120: JAL x1, 8");

    // Task 4: Test boundary addresses
    $display("\n--- Task 4: Boundary Addresses ---");
    addr = 32'h00000000; // First address
    @(posedge clk);
    check_inst(32'h00000000, "First address: 0x00");
    
    addr = 32'h00000130; // Last address (76*4 = 304 = 0x130)
    @(posedge clk);
    check_inst(32'h00000013, "Last address: 0x130");

    // Task 5: Test word alignment
    $display("\n--- Task 5: Word Alignment ---");
    addr = 32'h00000004;
    @(posedge clk);
    #1;
    test_count++;
    if (inst === 32'h002081b3) begin
      $display("[PASS] Word-aligned access works correctly");
      pass_count++;
    end else begin
      $display("[FAIL] Word-aligned access failed");
    end

    // Summary
    @(posedge clk);
    $display("\n=== Test Summary ===");
    $display("Total: %0d, Passed: %0d, Failed: %0d", test_count, pass_count, test_count - pass_count);
    
    if (pass_count == test_count)
      $display("*** ALL TESTS PASSED ***");
    else
      $display("*** SOME TESTS FAILED ***");
    
    $finish;
  end

endmodule
