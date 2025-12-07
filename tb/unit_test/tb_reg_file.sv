`timescale 1ns/1ps

module tb_reg_file;

  // Parameters
  parameter N = 32;
  parameter DEPTH = 32;
  parameter CLK_PERIOD = 10;

  // DUT signals
  logic clk;
  logic arst_n;
  logic we;
  logic [4:0] raddr1, raddr2, waddr;
  logic [N-1:0] wdata;
  logic [N-1:0] rdata1, rdata2;

  // Instantiate DUT
  Reg_File #(
    .N(N),
    .DEPTH(DEPTH),
    .X1_INIT(32'h00000010),
    .X2_INIT(32'h00000020),
    .X4_INIT(32'h00000040),
    .X5_INIT(32'h00000050)
  ) dut (
    .i_clk(clk),
    .i_arst_n(arst_n),
    .i_we(we),
    .i_raddr1(raddr1),
    .i_raddr2(raddr2),
    .i_waddr(waddr),
    .i_wdata(wdata),
    .o_rdata1(rdata1),
    .o_rdata2(rdata2)
  );

  // Clock generation
  initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  // Test counter
  int test_count = 0;
  int pass_count = 0;

  // Task: Check read result
  task check_read(input [N-1:0] expected1, expected2, input string test_name);
    test_count++;
    if (rdata1 === expected1 && rdata2 === expected2) begin
      $display("[PASS] %s: rdata1=0x%h, rdata2=0x%h", test_name, rdata1, rdata2);
      pass_count++;
    end else begin
      $display("[FAIL] %s: Expected (0x%h, 0x%h), Got (0x%h, 0x%h)", 
               test_name, expected1, expected2, rdata1, rdata2);
    end
  endtask

  // Main test
  initial begin
    $display("=== Register File Test ===");
    
    // Initialize
    arst_n = 0;
    we = 0;
    raddr1 = 0; raddr2 = 0; waddr = 0; wdata = 0;
    
    // Task 1: Test reset
    $display("\n--- Task 1: Reset Test ---");
    @(posedge clk);
    arst_n = 1;
    @(posedge clk);
    
    // Task 2: Test x0 always returns 0
    $display("\n--- Task 2: x0 Always Zero ---");
    raddr1 = 0; raddr2 = 0;
    #1 check_read(32'h0, 32'h0, "Read x0");
    
    // Try to write x0 (should not work)
    @(posedge clk);
    we = 1; waddr = 0; wdata = 32'hDEADBEEF;
    @(posedge clk);
    we = 0; raddr1 = 0;
    #1 check_read(32'h0, 32'h0, "x0 remains 0 after write attempt");

    // Task 3: Test write and read
    $display("\n--- Task 3: Write and Read ---");
    @(posedge clk);
    we = 1; waddr = 5'd3; wdata = 32'hABCD1234;
    @(posedge clk);
    we = 0; raddr1 = 5'd3;
    #1 check_read(32'hABCD1234, 32'h0, "Write and read x3");
    
    @(posedge clk);
    we = 1; waddr = 5'd7; wdata = 32'h12345678;
    @(posedge clk);
    we = 0; raddr1 = 5'd7;
    #1 check_read(32'h12345678, 32'h0, "Write and read x7");

    // Task 4: Test dual read ports
    $display("\n--- Task 4: Dual Read Ports ---");
    raddr1 = 5'd3; raddr2 = 5'd7;
    #1 check_read(32'hABCD1234, 32'h12345678, "Read x3 and x7 simultaneously");

    // Task 5: Test initial values
    $display("\n--- Task 5: Initial Values ---");
    raddr1 = 5'd1; raddr2 = 5'd2;
    #1 check_read(32'h00000010, 32'h00000020, "Check x1 and x2 init values");
    
    raddr1 = 5'd4; raddr2 = 5'd5;
    #1 check_read(32'h00000040, 32'h00000050, "Check x4 and x5 init values");

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
