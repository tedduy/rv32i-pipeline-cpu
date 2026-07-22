module immediate_generator #(
  parameter N = 32
)(
  input logic [31:0] i_inst,
  output logic [N-1:0] o_imm
);
  
 always_comb begin
    unique case (i_inst[6:0]) // opcode [6:0]
      // OP-IMM, LOAD, JALR (I-type)
      7'b0010011,
      7'b0000011,
      7'b1100111: o_imm = {{(N-12){i_inst[31]}}, i_inst[31:20]};

      // STORE (S-type)
      7'b0100011: o_imm = {{(N-12){i_inst[31]}}, i_inst[31:25], i_inst[11:7]};

      // BRANCH (B-type)
      7'b1100011: o_imm = {{(N-13){i_inst[31]}}, i_inst[31], i_inst[7],
                           i_inst[30:25], i_inst[11:8], 1'b0};

      // LUI, AUIPC (U-type)
      7'b0110111,
      7'b0010111: o_imm = {i_inst[31:12], 12'b0};

      // JAL (J-type)
      7'b1101111: o_imm = {{(N-21){i_inst[31]}}, i_inst[31], i_inst[19:12],
                           i_inst[20], i_inst[30:21], 1'b0};

      // Instructions without an immediate operand.
      default:    o_imm = '0;
    endcase
  end

endmodule
