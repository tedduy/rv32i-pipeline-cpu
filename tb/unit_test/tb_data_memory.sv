`timescale 1ns/1ps

module tb_data_memory;

  // Parameters
  parameter N = 32;
  parameter BYTES = 256;
  parameter CLK_PERIOD = 10;

  // DUT signals
  logic clk;
  logic arst_n;
  logic we;
  logic re;
  logic [N-1:0] addr;
  logic [N-1:0] wdata;
  logic [3:0]   wstrb;
  logic [N-1:0] rdata;

  // Instantiate DUT
  Data_Memory #(
    .N(N),
    .BYTES(BYTES)
  ) dut (
    .i_clk(clk),
    .i_arst_n(arst_n),
    .i_we(we),
    .i_re(re),
    .i_addr(addr),
    .i_wdata(wdata),
    .i_wstrb(wstrb),
    .o_rdata(rdata)
  );

  // Clock generation
  initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end

  // Test counter
  int test_count = 0;
  int pass_count = 0;

  // Task: Check read data
  task check_read(input [N-1:0] expected, input string test_name);
    #1;
    test_count++;
    if (rdata === expected) begin
      $display("[PASS] %s: rdata = 0x%h", test_name, rdata);
      pass_count++;
    end else begin
      $display("[FAIL] %s: Expected 0x%h, Got 0x%h", test_name, expected, rdata);
    end
  endtask

  // Main test
  initial begin
    $display("=== Data Memory Test ===");
    
    // Initialize
    arst_n = 0;
    we = 0;
    re = 0;
    addr = 0;
    wdata = 0;
    wstrb = 0;
    
    // Task 1: Test reset
    $display("\n--- Task 1: Reset Test ---");
    @(posedge clk);
    arst_n = 1;
    @(posedge clk);

    // Task 2: Test word write and read
    $display("\n--- Task 2: Word Write and Read ---");
    we = 1; addr = 32'h00000010; wdata = 32'hABCD1234; wstrb = 4'b1111;
    @(posedge clk);
    we = 0; re = 1;
    @(posedge clk);
    check_read(32'hABCD1234, "Word write/read at 0x10");
    
    we = 1; re = 0; addr = 32'h00000020; wdata = 32'h12345678; wstrb = 4'b1111;
    @(posedge clk);
    we = 0; re = 1;
    @(posedge clk);
    check_read(32'h12345678, "Word write/read at 0x20");

    // Task 3: Test byte write and read
    $display("\n--- Task 3: Byte Write and Read ---");
    // Write 4 bytes individually to build a word
    we = 1; re = 0; addr = 32'h00000030; wdata = 32'h000000AB; wstrb = 4'b0001;
    @(posedge clk);
    we = 1; addr = 32'h00000031; wdata = 32'h000000CD; wstrb = 4'b0001;
    @(posedge clk);
    we = 1; addr = 32'h00000032; wdata = 32'h000000EF; wstrb = 4'b0001;
    @(posedge clk);
    we = 1; addr = 32'h00000033; wdata = 32'h00000012; wstrb = 4'b0001;
    @(posedge clk);
    
    // Read back the full word
    we = 0; re = 1; addr = 32'h00000030;
    @(posedge clk);
    check_read(32'h12EFCDAB, "Byte writes, read word from 0x30");

    // Task 4: Test halfword write and read
    $display("\n--- Task 4: Halfword Write and Read ---");
    // Write lower halfword
    we = 1; re = 0; addr = 32'h00000040; wdata = 32'h0000BEEF; wstrb = 4'b0011;
    @(posedge clk);
    // Write upper halfword
    we = 1; addr = 32'h00000042; wdata = 32'h0000CAFE; wstrb = 4'b0011;
    @(posedge clk);
    
    // Read back the full word
    we = 0; re = 1; addr = 32'h00000040;
    @(posedge clk);
    check_read(32'hCAFEBEEF, "Halfword writes, read word from 0x40");

    // Task 5: Test multiple addresses
    $display("\n--- Task 5: Multiple Addresses ---");
    we = 1; re = 0; addr = 32'h00000050; wdata = 32'h11111111; wstrb = 4'b1111;
    @(posedge clk);
    we = 1; addr = 32'h00000054; wdata = 32'h22222222; wstrb = 4'b1111;
    @(posedge clk);
    we = 1; addr = 32'h00000058; wdata = 32'h33333333; wstrb = 4'b1111;
    @(posedge clk);
    
    we = 0; re = 1; addr = 32'h00000050;
    @(posedge clk);
    check_read(32'h11111111, "Read from 0x50");
    
    addr = 32'h00000054;
    @(posedge clk);
    check_read(32'h22222222, "Read from 0x54");
    
    addr = 32'h00000058;
    @(posedge clk);
    check_read(32'h33333333, "Read from 0x58");

    // Task 6: Test read enable
    $display("\n--- Task 6: Read Enable Test ---");
    re = 0; addr = 32'h00000050;
    @(posedge clk);
    check_read(32'h00000000, "Read disabled returns 0");

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
