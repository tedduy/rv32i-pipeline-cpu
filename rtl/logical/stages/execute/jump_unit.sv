module jump_unit #(
  parameter N = 32
)(
  input  logic [N-1:0] i_pc,            // Current PC
  input  logic [N-1:0] i_rs1_data,      // Register rs1 (for JALR)
  input  logic [N-1:0] i_immediate,     // Jump offset
  input  logic         i_jal,           // JAL instruction
  input  logic         i_jalr,          // JALR instruction
  output logic [N-1:0] o_jump_target,   // Jump target address
  output logic [N-1:0] o_return_addr    // Return address (PC+4)
);

  // Jump operations cho 2 instructions:
  // JAL, JALR

  always_comb begin
    // Return address is always PC+4
    o_return_addr = i_pc + 32'd4;
    
    if (i_jal) begin
      // JAL: target = PC + immediate
      o_jump_target = i_pc + i_immediate;
    end else if (i_jalr) begin
      // JALR: target = (rs1 + immediate) & ~1
      o_jump_target = (i_rs1_data + i_immediate) & ~32'd1;
    end else begin
      o_jump_target = i_pc + 32'd4; // Default: sequential
    end
  end

endmodule
