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
    ALU_SRA  = 4'b1001,  // SRA, SRAI
    ALU_MUL  = 4'b1010,
    ALU_MULH = 4'b1011,
    ALU_MULHSU = 4'b1100,
    ALU_MULHU = 4'b1101;

  logic [N-1:0] result;
  logic [4:0] shamt;
  logic signed [(2*N)-1:0] operand_a_signed;
  logic signed [(2*N)-1:0] operand_b_signed;
  logic signed [(2*N)-1:0] operand_b_unsigned_signed;
  logic        [(2*N)-1:0] operand_a_unsigned;
  logic        [(2*N)-1:0] operand_b_unsigned;
  logic signed [(2*N)-1:0] product_ss;
  logic signed [(2*N)-1:0] product_su;
  logic        [(2*N)-1:0] product_uu;

  assign shamt = i_operand_b[4:0];
  assign operand_a_signed          = {{N{i_operand_a[N-1]}}, i_operand_a};
  assign operand_b_signed          = {{N{i_operand_b[N-1]}}, i_operand_b};
  assign operand_b_unsigned_signed = $signed({{N{1'b0}}, i_operand_b});
  assign operand_a_unsigned        = {{N{1'b0}}, i_operand_a};
  assign operand_b_unsigned        = {{N{1'b0}}, i_operand_b};
  assign product_ss = operand_a_signed * operand_b_signed;
  assign product_su = operand_a_signed * operand_b_unsigned_signed;
  assign product_uu = operand_a_unsigned * operand_b_unsigned;

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
      ALU_MUL:  result = product_uu[N-1:0];
      ALU_MULH: result = product_ss[(2*N)-1:N];
      ALU_MULHSU: result = product_su[(2*N)-1:N];
      ALU_MULHU: result = product_uu[(2*N)-1:N];
      default:  result = 32'd0;
    endcase
  end

  assign o_alu_result = result;
  assign o_zero_flag = (result == 32'd0);

endmodule
