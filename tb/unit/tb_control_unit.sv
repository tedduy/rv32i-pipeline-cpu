`timescale 1ns/1ps

module tb_control_unit;

  // DUT signals
  logic [31:0] instruction;
  logic        RegWrite;
  logic        MemRead;
  logic        MemWrite;
  logic [2:0]  ImmSel;
  logic [1:0]  WBSel;
  logic [1:0]  PCSel;
  logic        ALUSrc;
  logic        ALUASel;
  logic [3:0]  ALUCtrl;
  logic        BranchEn;
  logic [2:0]  BranchType;
  logic [2:0]  MemType;
  logic        JAL;
  logic        JALR;
  logic        CsrEn;
  logic [1:0]  CsrOp;
  logic        CsrImm;
  logic        Ecall;
  logic        Ebreak;
  logic        Mret;
  logic        Wfi;
  logic        FenceI;
  logic        Illegal;

  // Instantiate DUT
  control_unit dut (
    .i_instruction(instruction),
    .o_RegWrite(RegWrite),
    .o_MemRead(MemRead),
    .o_MemWrite(MemWrite),
    .o_ImmSel(ImmSel),
    .o_WBSel(WBSel),
    .o_PCSel(PCSel),
    .o_ALUSrc(ALUSrc),
    .o_ALUASel(ALUASel),
    .o_ALUCtrl(ALUCtrl),
    .o_BranchEn(BranchEn),
    .o_BranchType(BranchType),
    .o_MemType(MemType),
    .o_JAL(JAL),
    .o_JALR(JALR),
    .o_CsrEn(CsrEn),
    .o_CsrOp(CsrOp),
    .o_CsrImm(CsrImm),
    .o_Ecall(Ecall),
    .o_Ebreak(Ebreak),
    .o_Mret(Mret),
    .o_Wfi(Wfi),
    .o_FenceI(FenceI),
    .o_Illegal(Illegal)
  );

  // Test counter
  int test_count = 0;
  int pass_count = 0;

  // Task: Check control signals
  task check_signals(
    input        exp_RegWrite, exp_MemRead, exp_MemWrite,
    input [2:0]  exp_ImmSel,
    input [1:0]  exp_WBSel, exp_PCSel,
    input        exp_ALUSrc, exp_ALUASel,
    input [3:0]  exp_ALUCtrl,
    input        exp_BranchEn,
    input        exp_JAL, exp_JALR,
    input string test_name
  );
    #1;
    test_count++;
    if (RegWrite === exp_RegWrite && MemRead === exp_MemRead && MemWrite === exp_MemWrite &&
        ImmSel === exp_ImmSel && WBSel === exp_WBSel && PCSel === exp_PCSel &&
        ALUSrc === exp_ALUSrc && ALUASel === exp_ALUASel && ALUCtrl === exp_ALUCtrl &&
        BranchEn === exp_BranchEn && JAL === exp_JAL && JALR === exp_JALR &&
        !Illegal) begin
      $display("[PASS] %s", test_name);
      pass_count++;
    end else begin
      $display("[FAIL] %s", test_name);
      $display("  RegWrite: %b (exp %b), MemRead: %b (exp %b), MemWrite: %b (exp %b)",
               RegWrite, exp_RegWrite, MemRead, exp_MemRead, MemWrite, exp_MemWrite);
      $display("  ALUSrc: %b (exp %b), ALUCtrl: %b (exp %b), WBSel: %b (exp %b)",
               ALUSrc, exp_ALUSrc, ALUCtrl, exp_ALUCtrl, WBSel, exp_WBSel);
    end
  endtask

  // Main test
  initial begin
    $display("=== Control Unit Test ===");
    
    // Task 1: Test R-type instructions
    $display("\n--- Task 1: R-type Instructions ---");
    // ADD x1, x2, x3
    instruction = {7'b0000000, 5'd3, 5'd2, 3'b000, 5'd1, 7'b0110011};
    check_signals(1'b1, 1'b0, 1'b0, 3'b000, 2'b00, 2'b00, 1'b0, 1'b0, 4'b0000, 1'b0, 1'b0, 1'b0, "ADD");
    
    // SUB x1, x2, x3
    instruction = {7'b0100000, 5'd3, 5'd2, 3'b000, 5'd1, 7'b0110011};
    check_signals(1'b1, 1'b0, 1'b0, 3'b000, 2'b00, 2'b00, 1'b0, 1'b0, 4'b0001, 1'b0, 1'b0, 1'b0, "SUB");
    
    // AND x1, x2, x3
    instruction = {7'b0000000, 5'd3, 5'd2, 3'b111, 5'd1, 7'b0110011};
    check_signals(1'b1, 1'b0, 1'b0, 3'b000, 2'b00, 2'b00, 1'b0, 1'b0, 4'b0010, 1'b0, 1'b0, 1'b0, "AND");
    
    // OR x1, x2, x3
    instruction = {7'b0000000, 5'd3, 5'd2, 3'b110, 5'd1, 7'b0110011};
    check_signals(1'b1, 1'b0, 1'b0, 3'b000, 2'b00, 2'b00, 1'b0, 1'b0, 4'b0011, 1'b0, 1'b0, 1'b0, "OR");

    // Zmmul instructions use funct7=0000001 and funct3=000..011.
    instruction = {7'b0000001, 5'd3, 5'd2, 3'b000, 5'd1, 7'b0110011};
    check_signals(1'b1, 1'b0, 1'b0, 3'b000, 2'b00, 2'b00, 1'b0, 1'b0, 4'b1010, 1'b0, 1'b0, 1'b0, "MUL");

    instruction = {7'b0000001, 5'd3, 5'd2, 3'b001, 5'd1, 7'b0110011};
    check_signals(1'b1, 1'b0, 1'b0, 3'b000, 2'b00, 2'b00, 1'b0, 1'b0, 4'b1011, 1'b0, 1'b0, 1'b0, "MULH");

    instruction = {7'b0000001, 5'd3, 5'd2, 3'b010, 5'd1, 7'b0110011};
    check_signals(1'b1, 1'b0, 1'b0, 3'b000, 2'b00, 2'b00, 1'b0, 1'b0, 4'b1100, 1'b0, 1'b0, 1'b0, "MULHSU");

    instruction = {7'b0000001, 5'd3, 5'd2, 3'b011, 5'd1, 7'b0110011};
    check_signals(1'b1, 1'b0, 1'b0, 3'b000, 2'b00, 2'b00, 1'b0, 1'b0, 4'b1101, 1'b0, 1'b0, 1'b0, "MULHU");

    // Zmmul does not include DIV or the other funct3=100..111 M operations.
    instruction = {7'b0000001, 5'd3, 5'd2, 3'b100, 5'd1, 7'b0110011};
    #1;
    test_count++;
    if (Illegal) begin
      $display("[PASS] DIV remains illegal without full M extension");
      pass_count++;
    end else begin
      $display("[FAIL] DIV decoded as legal under Zmmul");
    end

    // Task 2: Test I-type ALU instructions
    $display("\n--- Task 2: I-type ALU Instructions ---");
    // ADDI x1, x2, 100
    instruction = {12'd100, 5'd2, 3'b000, 5'd1, 7'b0010011};
    check_signals(1'b1, 1'b0, 1'b0, 3'b000, 2'b00, 2'b00, 1'b1, 1'b0, 4'b0000, 1'b0, 1'b0, 1'b0, "ADDI");
    
    // ANDI x1, x2, 0xFF
    instruction = {12'hFF, 5'd2, 3'b111, 5'd1, 7'b0010011};
    check_signals(1'b1, 1'b0, 1'b0, 3'b000, 2'b00, 2'b00, 1'b1, 1'b0, 4'b0010, 1'b0, 1'b0, 1'b0, "ANDI");

    // Task 3: Test Load instructions
    $display("\n--- Task 3: Load Instructions ---");
    // LW x1, 0(x2)
    instruction = {12'd0, 5'd2, 3'b010, 5'd1, 7'b0000011};
    check_signals(1'b1, 1'b1, 1'b0, 3'b000, 2'b01, 2'b00, 1'b1, 1'b0, 4'b0000, 1'b0, 1'b0, 1'b0, "LW");
    
    // LB x1, 4(x2)
    instruction = {12'd4, 5'd2, 3'b000, 5'd1, 7'b0000011};
    check_signals(1'b1, 1'b1, 1'b0, 3'b000, 2'b01, 2'b00, 1'b1, 1'b0, 4'b0000, 1'b0, 1'b0, 1'b0, "LB");

    // Task 4: Test Store instructions
    $display("\n--- Task 4: Store Instructions ---");
    // SW x3, 0(x2)
    instruction = {7'd0, 5'd3, 5'd2, 3'b010, 5'd0, 7'b0100011};
    check_signals(1'b0, 1'b0, 1'b1, 3'b001, 2'b00, 2'b00, 1'b1, 1'b0, 4'b0000, 1'b0, 1'b0, 1'b0, "SW");
    
    // SB x3, 4(x2)
    instruction = {7'd0, 5'd3, 5'd2, 3'b000, 5'd4, 7'b0100011};
    check_signals(1'b0, 1'b0, 1'b1, 3'b001, 2'b00, 2'b00, 1'b1, 1'b0, 4'b0000, 1'b0, 1'b0, 1'b0, "SB");

    // Task 5: Test Branch instructions
    $display("\n--- Task 5: Branch Instructions ---");
    // BEQ x1, x2, offset
    instruction = {7'd0, 5'd2, 5'd1, 3'b000, 5'd0, 7'b1100011};
    check_signals(1'b0, 1'b0, 1'b0, 3'b010, 2'b00, 2'b01, 1'b0, 1'b0, 4'b0000, 1'b1, 1'b0, 1'b0, "BEQ");
    
    // BNE x1, x2, offset
    instruction = {7'd0, 5'd2, 5'd1, 3'b001, 5'd0, 7'b1100011};
    check_signals(1'b0, 1'b0, 1'b0, 3'b010, 2'b00, 2'b01, 1'b0, 1'b0, 4'b0000, 1'b1, 1'b0, 1'b0, "BNE");

    // Task 6: Test Jump instructions
    $display("\n--- Task 6: Jump Instructions ---");
    // JAL x1, offset
    instruction = {20'd100, 5'd1, 7'b1101111};
    check_signals(1'b1, 1'b0, 1'b0, 3'b100, 2'b10, 2'b10, 1'b0, 1'b0, 4'b0000, 1'b0, 1'b1, 1'b0, "JAL");
    
    // JALR x1, x2, 0
    instruction = {12'd0, 5'd2, 3'b000, 5'd1, 7'b1100111};
    check_signals(1'b1, 1'b0, 1'b0, 3'b000, 2'b10, 2'b11, 1'b1, 1'b0, 4'b0000, 1'b0, 1'b0, 1'b1, "JALR");

    // Task 7: Test U-type instructions
    $display("\n--- Task 7: U-type Instructions ---");
    // LUI x1, 0x12345
    instruction = {20'h12345, 5'd1, 7'b0110111};
    check_signals(1'b1, 1'b0, 1'b0, 3'b011, 2'b11, 2'b00, 1'b0, 1'b0, 4'b0000, 1'b0, 1'b0, 1'b0, "LUI");
    
    // AUIPC x1, 0x12345
    instruction = {20'h12345, 5'd1, 7'b0010111};
    check_signals(1'b1, 1'b0, 1'b0, 3'b011, 2'b00, 2'b00, 1'b1, 1'b1, 4'b0000, 1'b0, 1'b0, 1'b0, "AUIPC");

    // Task 8: Test SYSTEM/CSR decode
    $display("\n--- Task 8: SYSTEM/CSR Instructions ---");
    instruction = 32'h3050_9073; // csrw mtvec, x1
    #1;
    test_count++;
    if (CsrEn && !CsrImm && CsrOp == 2'b00 && RegWrite) begin
      $display("[PASS] CSRRW");
      pass_count++;
    end else begin
      $display("[FAIL] CSRRW decode");
    end

    instruction = 32'h0000_0073; // ecall
    #1;
    test_count++;
    if (Ecall && !Ebreak && !Mret && !RegWrite) begin
      $display("[PASS] ECALL");
      pass_count++;
    end else begin
      $display("[FAIL] ECALL decode");
    end

    instruction = 32'h3020_0073; // mret
    #1;
    test_count++;
    if (Mret && !Ecall && !Ebreak && !RegWrite) begin
      $display("[PASS] MRET");
      pass_count++;
    end else begin
      $display("[FAIL] MRET decode");
    end

    instruction = 32'h1050_0073; // wfi
    #1;
    test_count++;
    if (Wfi && !Mret && !Ecall && !Ebreak && !Illegal && !RegWrite) begin
      $display("[PASS] WFI");
      pass_count++;
    end else begin
      $display("[FAIL] WFI decode");
    end

    instruction = 32'h0000_100f; // fence.i
    #1;
    test_count++;
    if (FenceI && !Illegal && !RegWrite && !MemRead && !MemWrite) begin
      $display("[PASS] FENCE.I");
      pass_count++;
    end else begin
      $display("[FAIL] FENCE.I decode");
    end

    // The reserved imm, rs1, and rd fields do not participate in FENCE.I
    // decoding.  ACT4 exercises these encodings explicitly.
    instruction = 32'h0001_100f; // non-zero rs1
    #1;
    test_count++;
    if (FenceI && !Illegal) begin
      $display("[PASS] FENCE.I ignores rs1");
      pass_count++;
    end else begin
      $display("[FAIL] FENCE.I non-zero rs1 decode");
    end

    instruction = 32'h0000_108f; // non-zero rd
    #1;
    test_count++;
    if (FenceI && !Illegal) begin
      $display("[PASS] FENCE.I ignores rd");
      pass_count++;
    end else begin
      $display("[FAIL] FENCE.I non-zero rd decode");
    end

    instruction = 32'h0010_100f; // non-zero immediate
    #1;
    test_count++;
    if (FenceI && !Illegal) begin
      $display("[PASS] FENCE.I ignores immediate");
      pass_count++;
    end else begin
      $display("[FAIL] FENCE.I non-zero immediate decode");
    end

    instruction = 32'hffff_ffff;
    #1;
    test_count++;
    if (Illegal && !RegWrite && !MemRead && !MemWrite) begin
      $display("[PASS] Illegal instruction");
      pass_count++;
    end else begin
      $display("[FAIL] Illegal instruction decode");
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
