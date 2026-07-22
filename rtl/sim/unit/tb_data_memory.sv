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
  data_memory #(
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

  // Drive synchronous-memory controls away from the active clock edge. This
  // avoids a testbench/DUT scheduling race when VCS executes both processes in
  // the same simulation region.
  task write_mem(
    input [N-1:0] write_addr,
    input [N-1:0] write_data,
    input [3:0]   write_strobe
  );
    @(negedge clk);
    we = 1;
    re = 0;
    addr = write_addr;
    wdata = write_data;
    wstrb = write_strobe;
    @(posedge clk);
    #1;
  endtask

  task read_and_check(
    input [N-1:0] read_addr,
    input [N-1:0] expected,
    input string  test_name
  );
    @(negedge clk);
    we = 0;
    re = 1;
    addr = read_addr;
    @(posedge clk);
    check_read(expected, test_name);
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
    repeat (2) @(posedge clk);
    @(negedge clk);
    arst_n = 1;

    // Task 2: Test word write and read
    $display("\n--- Task 2: Word Write and Read ---");
    write_mem(32'h00000010, 32'hABCD1234, 4'b1111);
    read_and_check(32'h00000010, 32'hABCD1234, "Word write/read at 0x10");
    write_mem(32'h00000020, 32'h12345678, 4'b1111);
    read_and_check(32'h00000020, 32'h12345678, "Word write/read at 0x20");

    // Task 3: Test byte write and read
    $display("\n--- Task 3: Byte Write and Read ---");
    // Write 4 bytes individually to build a word
    write_mem(32'h00000030, 32'h000000AB, 4'b0001);
    write_mem(32'h00000031, 32'h0000CD00, 4'b0010);
    write_mem(32'h00000032, 32'h00EF0000, 4'b0100);
    write_mem(32'h00000033, 32'h12000000, 4'b1000);
    read_and_check(32'h00000030, 32'h12EFCDAB,
                   "Byte writes, read word from 0x30");

    // Task 4: Test halfword write and read
    $display("\n--- Task 4: Halfword Write and Read ---");
    // Write lower halfword
    write_mem(32'h00000040, 32'h0000BEEF, 4'b0011);
    write_mem(32'h00000042, 32'hCAFE0000, 4'b1100);
    read_and_check(32'h00000040, 32'hCAFEBEEF,
                   "Halfword writes, read word from 0x40");

    // Task 5: Test multiple addresses
    $display("\n--- Task 5: Multiple Addresses ---");
    write_mem(32'h00000050, 32'h11111111, 4'b1111);
    write_mem(32'h00000054, 32'h22222222, 4'b1111);
    write_mem(32'h00000058, 32'h33333333, 4'b1111);
    read_and_check(32'h00000050, 32'h11111111, "Read from 0x50");
    read_and_check(32'h00000054, 32'h22222222, "Read from 0x54");
    read_and_check(32'h00000058, 32'h33333333, "Read from 0x58");

    // Task 6: Test read enable
    $display("\n--- Task 6: Read Enable Test ---");
    @(negedge clk);
    we = 0; re = 0; addr = 32'h00000050;
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
