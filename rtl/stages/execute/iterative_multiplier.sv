module iterative_multiplier #(
  parameter int N = 32
)(
  input  logic             i_clk,
  input  logic             i_arst_n,
  input  logic             i_start,
  input  logic             i_consume,
  input  logic [N-1:0]     i_operand_a,
  input  logic [N-1:0]     i_operand_b,
  input  logic [3:0]       i_alu_ctrl,
  output logic             o_busy,
  output logic             o_done,
  output logic [N-1:0]     o_result
);

  localparam int COUNT_WIDTH = (N <= 2) ? 1 : $clog2(N);

  localparam logic [3:0]
    ALU_MUL    = 4'b1010,
    ALU_MULH   = 4'b1011,
    ALU_MULHSU = 4'b1100,
    ALU_MULHU  = 4'b1101;

  typedef enum logic [1:0] {
    MUL_IDLE,
    MUL_RUN,
    MUL_DONE
  } mul_state_t;

  mul_state_t state_q;
  logic [COUNT_WIDTH-1:0] iteration_q;
  logic [(2*N)-1:0] product_q;
  logic [N-1:0] multiplicand_q;
  logic negate_result_q, select_high_q;

  logic operand_a_signed, operand_b_signed;
  logic [N-1:0] operand_a_magnitude, operand_b_magnitude;
  logic [N:0] upper_sum;
  logic [(2*N)-1:0] magnitude_product_next;
  logic [(2*N)-1:0] corrected_product_next;
  logic final_iteration;

  assign operand_a_signed = ((i_alu_ctrl == ALU_MULH) ||
                             (i_alu_ctrl == ALU_MULHSU)) &&
                            i_operand_a[N-1];
  assign operand_b_signed = (i_alu_ctrl == ALU_MULH) &&
                            i_operand_b[N-1];
  assign operand_a_magnitude = operand_a_signed ? (~i_operand_a + 1'b1)
                                                  : i_operand_a;
  assign operand_b_magnitude = operand_b_signed ? (~i_operand_b + 1'b1)
                                                  : i_operand_b;

  // Classic combined accumulator/multiplier implementation.  product_q holds
  // the partial accumulator in its upper half and the remaining multiplier in
  // its lower half.  Each cycle conditionally adds the N-bit multiplicand to
  // the upper half, then shifts the carry/accumulator/multiplier tuple right.
  // This needs only a (N+1)-bit adder and 3*N datapath flops in total.
  assign upper_sum = {1'b0, product_q[(2*N)-1:N]} +
                     (product_q[0] ? {1'b0, multiplicand_q} : '0);
  assign magnitude_product_next = {upper_sum, product_q[N-1:1]};
  assign corrected_product_next = negate_result_q
                                ? (~magnitude_product_next + 1'b1)
                                : magnitude_product_next;
  assign final_iteration = (state_q == MUL_RUN) &&
                           (iteration_q == N-1);

  assign o_busy = (state_q != MUL_IDLE);
  assign o_done = (state_q == MUL_DONE) || final_iteration;
  assign o_result = final_iteration
                  ? (select_high_q ? corrected_product_next[(2*N)-1:N]
                                   : corrected_product_next[N-1:0])
                  : (select_high_q ? product_q[(2*N)-1:N]
                                   : product_q[N-1:0]);

  always_ff @(posedge i_clk or negedge i_arst_n) begin
    if (!i_arst_n) begin
      state_q          <= MUL_IDLE;
      iteration_q      <= '0;
      product_q        <= '0;
      multiplicand_q   <= '0;
      negate_result_q  <= 1'b0;
      select_high_q    <= 1'b0;
    end else begin
      unique case (state_q)
        MUL_IDLE: begin
          if (i_start) begin
            iteration_q     <= '0;
            product_q       <= {{N{1'b0}}, operand_b_magnitude};
            multiplicand_q  <= operand_a_magnitude;
            negate_result_q <= operand_a_signed ^ operand_b_signed;
            select_high_q   <= (i_alu_ctrl != ALU_MUL);
            state_q         <= MUL_RUN;
          end
        end

        MUL_RUN: begin
          if (final_iteration) begin
            product_q <= corrected_product_next;
            if (i_consume)
              state_q <= MUL_IDLE;
            else
              state_q <= MUL_DONE;
          end else begin
            product_q   <= magnitude_product_next;
            iteration_q <= iteration_q + 1'b1;
          end
        end

        MUL_DONE: begin
          if (i_consume)
            state_q <= MUL_IDLE;
        end

        default: state_q <= MUL_IDLE;
      endcase
    end
  end

endmodule
