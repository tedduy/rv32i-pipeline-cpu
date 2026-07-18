module alu_unit #(
  parameter N = 32
)(
  input  logic [N-1:0] i_operand_a,
  input  logic [N-1:0] i_operand_b,
  input  logic [3:0]   i_alu_ctrl,
  output logic [N-1:0] o_alu_result,
  output logic         o_zero_flag
);

  // ALU operations cho 19 instructions:
  // R-type (10): ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
  // I-type (9): ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI
  // Plus: AUIPC address calculation

  localparam [3:0]
    ALU_ADD  = 4'b0000,  // ADD, ADDI, address calculation
    ALU_SUB  = 4'b0001,  // SUB only
    ALU_AND  = 4'b0010,  // AND, ANDI
    ALU_OR   = 4'b0011,  // OR, ORI
    ALU_XOR  = 4'b0100,  // XOR, XORI
    ALU_SLT  = 4'b0101,  // SLT, SLTI
    ALU_SLTU = 4'b0110,  // SLTU, SLTIU
    ALU_SLL  = 4'b0111,  // SLL, SLLI
    ALU_SRL  = 4'b1000,  // SRL, SRLI
    ALU_SRA  = 4'b1001;  // SRA, SRAI

  logic [N-1:0] result;
  logic [4:0] shamt;
  assign shamt = i_operand_b[4:0];

  always_comb begin
    case (i_alu_ctrl)
      ALU_ADD:  result = i_operand_a + i_operand_b;
      ALU_SUB:  result = i_operand_a - i_operand_b;
      ALU_AND:  result = i_operand_a & i_operand_b;
      ALU_OR:   result = i_operand_a | i_operand_b;
      ALU_XOR:  result = i_operand_a ^ i_operand_b;
      ALU_SLT:  result = ($signed(i_operand_a) < $signed(i_operand_b)) ? 32'd1 : 32'd0;
      ALU_SLTU: result = (i_operand_a < i_operand_b) ? 32'd1 : 32'd0;
      ALU_SLL:  result = i_operand_a << shamt;
      ALU_SRL:  result = i_operand_a >> shamt;
      ALU_SRA:  result = $signed(i_operand_a) >>> shamt;
      default:  result = 32'd0;
    endcase
  end

  assign o_alu_result = result;
  assign o_zero_flag = (result == 32'd0);

endmodule
