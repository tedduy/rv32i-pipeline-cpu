`timescale 1ns/1ps

module tb_load_store_unit;

  // Parameters
  parameter N = 32;

  // DUT signals
  logic [2:0]   mem_type;
  logic         mem_read;
  logic         mem_write;
  logic [1:0]   byte_offset;
  logic [N-1:0] mem_read_data;
  logic [N-1:0] store_data;
  logic [N-1:0] load_data;
  logic [N-1:0] o_store_data;
  logic [3:0]   byte_enable;

  // Memory types
  localparam [2:0]
    MEM_BYTE   = 3'b000,
    MEM_HALF   = 3'b001,
    MEM_WORD   = 3'b010,
    MEM_BYTE_U = 3'b100,
    MEM_HALF_U = 3'b101;

  // Instantiate DUT
  load_store_unit #(.N(N)) dut (
    .i_mem_type(mem_type),
    .i_mem_read(mem_read),
    .i_mem_write(mem_write),
    .i_byte_offset(byte_offset),
    .i_mem_read_data(mem_read_data),
    .i_store_data(store_data),
    .o_load_data(load_data),
    .o_store_data(o_store_data),
    .o_byte_enable(byte_enable)
  );

  // Test counter
  int test_count = 0;
  int pass_count = 0;

  // Task: Check load result
  task check_load(input [N-1:0] expected, input string test_name);
    #1;
    test_count++;
    if (load_data === expected) begin
      $display("[PASS] %s: load_data = 0x%h", test_name, load_data);
      pass_count++;
    end else begin
      $display("[FAIL] %s: Expected 0x%h, Got 0x%h", test_name, expected, load_data);
    end
  endtask

  // Task: Check store result
  task check_store(input [N-1:0] expected_data, input [3:0] expected_be, input string test_name);
    #1;
    test_count++;
    if (o_store_data === expected_data && byte_enable === expected_be) begin
      $display("[PASS] %s: store_data=0x%h, byte_enable=%b", test_name, o_store_data, byte_enable);
      pass_count++;
    end else begin
      $display("[FAIL] %s: Expected (0x%h, %b), Got (0x%h, %b)", 
               test_name, expected_data, expected_be, o_store_data, byte_enable);
    end
  endtask

  // Main test
  initial begin
    $display("=== Load/Store Unit Test ===");
    
    mem_read = 0; mem_write = 0;
    
    // Task 1: Test LB (Load Byte - signed)
    $display("\n--- Task 1: LB (Load Byte - signed) ---");
    mem_read = 1'b1; mem_type = MEM_BYTE;
    mem_read_data = 32'h12345678;
    
    byte_offset = 2'b00;
    check_load(32'h00000078, "LB: byte 0 (positive)");
    
    mem_read_data = 32'h123456FF;
    byte_offset = 2'b00;
    check_load(32'hFFFFFFFF, "LB: byte 0 (negative, sign-extended)");
    
    mem_read_data = 32'h12345678;
    byte_offset = 2'b01;
    check_load(32'h00000056, "LB: byte 1");

    // Task 2: Test LBU (Load Byte Unsigned)
    $display("\n--- Task 2: LBU (Load Byte Unsigned) ---");
    mem_type = MEM_BYTE_U;
    mem_read_data = 32'h123456FF;
    byte_offset = 2'b00;
    check_load(32'h000000FF, "LBU: byte 0 (no sign extension)");

    // Task 3: Test LH (Load Halfword - signed)
    $display("\n--- Task 3: LH (Load Halfword - signed) ---");
    mem_type = MEM_HALF;
    mem_read_data = 32'h12345678;
    byte_offset = 2'b00;
    check_load(32'h00005678, "LH: halfword 0 (positive)");
    
    mem_read_data = 32'h1234FFFF;
    byte_offset = 2'b00;
    check_load(32'hFFFFFFFF, "LH: halfword 0 (negative, sign-extended)");
    
    mem_read_data = 32'h12345678;
    byte_offset = 2'b10;
    check_load(32'h00001234, "LH: halfword 1");

    // Task 4: Test LHU (Load Halfword Unsigned)
    $display("\n--- Task 4: LHU (Load Halfword Unsigned) ---");
    mem_type = MEM_HALF_U;
    mem_read_data = 32'h1234FFFF;
    byte_offset = 2'b00;
    check_load(32'h0000FFFF, "LHU: halfword 0 (no sign extension)");

    // Task 5: Test LW (Load Word)
    $display("\n--- Task 5: LW (Load Word) ---");
    mem_type = MEM_WORD;
    mem_read_data = 32'hABCD1234;
    byte_offset = 2'b00;
    check_load(32'hABCD1234, "LW: full word");

    // Task 6: Test SB (Store Byte)
    $display("\n--- Task 6: SB (Store Byte) ---");
    mem_read = 1'b0; mem_write = 1'b1;
    mem_type = MEM_BYTE;
    store_data = 32'h000000AB;
    
    byte_offset = 2'b00;
    check_store(32'h000000AB, 4'b0001, "SB: byte 0");
    
    byte_offset = 2'b01;
    check_store(32'h0000AB00, 4'b0010, "SB: byte 1");
    
    byte_offset = 2'b10;
    check_store(32'h00AB0000, 4'b0100, "SB: byte 2");
    
    byte_offset = 2'b11;
    check_store(32'hAB000000, 4'b1000, "SB: byte 3");

    // Task 7: Test SH (Store Halfword)
    $display("\n--- Task 7: SH (Store Halfword) ---");
    mem_type = MEM_HALF;
    store_data = 32'h0000ABCD;
    
    byte_offset = 2'b00;
    check_store(32'h0000ABCD, 4'b0011, "SH: halfword 0");
    
    byte_offset = 2'b10;
    check_store(32'hABCD0000, 4'b1100, "SH: halfword 1");

    // Task 8: Test SW (Store Word)
    $display("\n--- Task 8: SW (Store Word) ---");
    mem_type = MEM_WORD;
    store_data = 32'h12345678;
    byte_offset = 2'b00;
    check_store(32'h12345678, 4'b1111, "SW: full word");

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
