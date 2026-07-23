// Iterative RV32M execution wrapper. It owns instruction classification and
// the start/done/consume protocol so the pipeline only sees one active/result/
// stall interface for all multiply and divide operations.
module mdu_unit #(
  parameter int N = 32
)(
  input  logic             i_clk,
  input  logic             i_arst_n,
  input  logic             i_valid,
  input  logic             i_instruction_access_fault,
  input  logic [6:0]       i_funct7,
  input  logic [2:0]       i_funct3,
  input  logic [6:0]       i_opcode,
  input  logic [N-1:0]     i_operand_a,
  input  logic [N-1:0]     i_operand_b,
  input  logic             i_result_ready,
  output logic             o_active,
  output logic             o_stall,
  output logic [N-1:0]     o_result
);

  localparam logic [3:0]
    ALU_MUL    = 4'b1010,
    ALU_MULH   = 4'b1011,
    ALU_MULHSU = 4'b1100,
    ALU_MULHU  = 4'b1101;

  logic       select_divide;
  logic [3:0] multiply_control;
  logic       multiply_start, multiply_busy, multiply_done;
  logic       multiply_consume;
  logic       divide_start, divide_busy, divide_done;
  logic       divide_consume;
  logic [N-1:0] multiply_result, divide_result;

  // Exact case matching keeps all classification outputs deterministic when
  // an invalid or unknown instruction payload is present in a bubble.
  always_comb begin
    o_active        = 1'b0;
    select_divide   = 1'b0;
    multiply_control = ALU_MUL;

    if (i_valid && !i_instruction_access_fault) begin
      case ({i_funct7, i_opcode})
        {7'b0000001, 7'b0110011}: begin
          case (i_funct3)
            3'b000: begin
              o_active         = 1'b1;
              multiply_control = ALU_MUL;
            end
            3'b001: begin
              o_active         = 1'b1;
              multiply_control = ALU_MULH;
            end
            3'b010: begin
              o_active         = 1'b1;
              multiply_control = ALU_MULHSU;
            end
            3'b011: begin
              o_active         = 1'b1;
              multiply_control = ALU_MULHU;
            end
            3'b100, 3'b101, 3'b110, 3'b111: begin
              o_active      = 1'b1;
              select_divide = 1'b1;
            end
            // funct3 is constrained to the eight RV32M operations.
            /* verilator coverage_off */
            default: begin end
            /* verilator coverage_on */
          endcase
        end
        default: begin end
      endcase
    end
  end

  assign multiply_start   = o_active && !select_divide &&
                            !multiply_busy && !multiply_done;
  assign multiply_consume = o_active && !select_divide && multiply_done &&
                            i_result_ready;
  assign divide_start     = o_active && select_divide &&
                            !divide_busy && !divide_done;
  assign divide_consume   = o_active && select_divide && divide_done &&
                            i_result_ready;

  assign o_stall = o_active &&
                   !(select_divide ? divide_done : multiply_done);
  assign o_result = !o_active ? '0 :
                    select_divide ? divide_result : multiply_result;

  iterative_multiplier #(.N(N)) u_multiplier (
    .i_clk(i_clk),
    .i_arst_n(i_arst_n),
    .i_start(multiply_start),
    .i_consume(multiply_consume),
    .i_operand_a(i_operand_a),
    .i_operand_b(i_operand_b),
    .i_alu_ctrl(multiply_control),
    .o_busy(multiply_busy),
    .o_done(multiply_done),
    .o_result(multiply_result)
  );

  iterative_divider #(.N(N)) u_divider (
    .i_clk(i_clk),
    .i_arst_n(i_arst_n),
    .i_start(divide_start),
    .i_consume(divide_consume),
    .i_dividend(i_operand_a),
    .i_divisor(i_operand_b),
    .i_operation(i_funct3[1:0]),
    .o_busy(divide_busy),
    .o_done(divide_done),
    .o_result(divide_result)
  );

endmodule
