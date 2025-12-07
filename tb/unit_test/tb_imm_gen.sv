`timescale 1ns/1ps

module tb_imm_gen;

  // Parameters
  parameter N = 32;

  // DUT signals
  logic [31:0] inst;
  logic [N-1:0] imm;

  // Instantiate DUT
  Imm_Gen #(.N(N)) dut (
    .i_inst(inst),
    .o_imm(imm)
  );

  // Test counter
  int test_count = 0;
  int pass_count = 0;

  // Task: Check immediate result
  task check_imm(input [N-1:0] expected, input string test_name);
    #1;
    test_count++;
    if (imm === expected) begin
      $display("[PASS] %s: imm = 0x%h", test_name, imm);
      pass_count++;
    end else begin
      $display("[FAIL] %s: Expected 0x%h, Got 0x%h", test_name, expected, imm);
    end
  endtask

  // Main test
  initial begin
    $display("=== Immediate Generation Test ===");
    
    // Task 1: Test I-type immediate (ADDI, LOAD, JALR)
    $display("\n--- Task 1: I-type Immediate ---");
    // ADDI x1, x2, 100 -> imm[11:0] = 100 = 0x064
    inst = {12'h064, 5'd2, 3'b000, 5'd1, 7'b0010011};
    check_imm(32'h00000064, "I-type: positive immediate (100)");
    
    // ADDI x1, x2, -50 -> imm[11:0] = -50 = 0xFCE (sign-extended)
    inst = {12'hFCE, 5'd2, 3'b000, 5'd1, 7'b0010011};
    check_imm(32'hFFFFFFCE, "I-type: negative immediate (-50)");

    // Task 2: Test S-type immediate (STORE)
    $display("\n--- Task 2: S-type Immediate ---");
    // SW x3, 20(x2) -> imm = 20 = 0x014
    inst = {7'h00, 5'd3, 5'd2, 3'b010, 5'h14, 7'b0100011};
    check_imm(32'h00000014, "S-type: positive immediate (20)");
    
    // SW x3, -8(x2) -> imm = -8 = 0xFF8
    inst = {7'h7F, 5'd3, 5'd2, 3'b010, 5'h18, 7'b0100011};
    check_imm(32'hFFFFFFF8, "S-type: negative immediate (-8)");

    // Task 3: Test B-type immediate (BRANCH)
    $display("\n--- Task 3: B-type Immediate ---");
    // BEQ x1, x2, 8 -> imm = 8 = 0x008
    // B-type format: imm[12|10:5] rs2 rs1 funct3 imm[4:1|11] opcode
    // 8 = 0b00000001000 -> [12]=0, [10:5]=000000, [4:1]=0100, [11]=0
    inst = {1'b0, 6'b000000, 5'd2, 5'd1, 3'b000, 4'b0100, 1'b0, 7'b1100011};
    check_imm(32'h00000008, "B-type: positive offset (8)");
    
    // BEQ x1, x2, -4 -> imm = -4 = 0xFFFFFFFC
    // -4 = 0b111111111100 -> [12]=1, [10:5]=111111, [4:1]=1110, [11]=1
    inst = {1'b1, 6'b111111, 5'd2, 5'd1, 3'b000, 4'b1110, 1'b1, 7'b1100011};
    check_imm(32'hFFFFFFFC, "B-type: negative offset (-4)");

    // Task 4: Test U-type immediate (LUI, AUIPC)
    $display("\n--- Task 4: U-type Immediate ---");
    // LUI x1, 0x12345 -> imm = 0x12345000
    inst = {20'h12345, 5'd1, 7'b0110111};
    check_imm(32'h12345000, "U-type: LUI immediate");
    
    // AUIPC x2, 0xFFFFF -> imm = 0xFFFFF000 (negative)
    inst = {20'hFFFFF, 5'd2, 7'b0010111};
    check_imm(32'hFFFFF000, "U-type: AUIPC immediate");

    // Task 5: Test J-type immediate (JAL)
    $display("\n--- Task 5: J-type Immediate ---");
    // JAL x1, 256 -> imm = 256 = 0x100
    // J-type format: imm[20|10:1|11|19:12] rd opcode
    // 256 = 0b00000100000000 -> [20]=0, [10:1]=0010000000, [11]=0, [19:12]=00000000
    inst = {1'b0, 10'b0010000000, 1'b0, 8'b00000000, 5'd1, 7'b1101111};
    check_imm(32'h00000100, "J-type: positive offset (256)");
    
    // JAL x1, -4 -> imm = -4 = 0xFFFFFFFC
    // -4 = 0b11111111111111111100 -> [20]=1, [10:1]=1111111110, [11]=1, [19:12]=11111111
    inst = {1'b1, 10'b1111111110, 1'b1, 8'b11111111, 5'd1, 7'b1101111};
    check_imm(32'hFFFFFFFC, "J-type: negative offset (-4)");

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
