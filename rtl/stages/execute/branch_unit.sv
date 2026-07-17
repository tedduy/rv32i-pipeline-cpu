module branch_unit #(
  parameter N = 32
)(
  input  logic [N-1:0] i_rs1_data,      // Register rs1
  input  logic [N-1:0] i_rs2_data,      // Register rs2
  input  logic [2:0]   i_branch_type,   // Branch type (funct3)
  input  logic         i_branch_enable, // Branch instruction enable
  output logic         o_branch_taken   // Branch taken decision
);

  // Branch operations cho 6 instructions:
  // BEQ, BNE, BLT, BGE, BLTU, BGEU

  localparam [2:0]
    BRANCH_BEQ  = 3'b000,  // Branch if Equal
    BRANCH_BNE  = 3'b001,  // Branch if Not Equal
    BRANCH_BLT  = 3'b100,  // Branch if Less Than (signed)
    BRANCH_BGE  = 3'b101,  // Branch if Greater or Equal (signed)
    BRANCH_BLTU = 3'b110,  // Branch if Less Than (unsigned)
    BRANCH_BGEU = 3'b111;  // Branch if Greater or Equal (unsigned)

  logic condition_met;

  always_comb begin
    case (i_branch_type)
      BRANCH_BEQ:  condition_met = (i_rs1_data == i_rs2_data);
      BRANCH_BNE:  condition_met = (i_rs1_data != i_rs2_data);
      BRANCH_BLT:  condition_met = ($signed(i_rs1_data) < $signed(i_rs2_data));
      BRANCH_BGE:  condition_met = ($signed(i_rs1_data) >= $signed(i_rs2_data));
      BRANCH_BLTU: condition_met = (i_rs1_data < i_rs2_data);
      BRANCH_BGEU: condition_met = (i_rs1_data >= i_rs2_data);
      default:     condition_met = 1'b0;
    endcase
  end

  assign o_branch_taken = i_branch_enable & condition_met;

endmodule
