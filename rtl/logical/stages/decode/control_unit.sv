module control_unit (
  input  logic [31:0] i_instruction,    // Full 32-bit instruction
  
  // General control signals
  output logic        o_reg_write,        // Write to register file
  output logic        o_mem_read,         // Memory read enable
  output logic        o_mem_write,        // Memory write enable
  output logic [1:0]  o_wb_sel,           // Writeback source selection
  output logic [1:0]  o_pc_sel,           // PC source selection
  
  // ALU control signals
  output logic        o_alu_src,          // ALU operand B source (0=reg, 1=imm)
  output logic        o_alu_a_sel,         // ALU operand A source (0=reg, 1=PC)
  output logic [3:0]  o_alu_ctrl,         // ALU operation control → ALU Unit
  
  // Branch control signals
  output logic        o_branch_en,        // Enable branch unit → Branch Unit
  output logic [2:0]  o_branch_type,      // Branch comparison type → Branch Unit
  
  // Load/Store control signals
  output logic [2:0]  o_mem_type,         // Memory access type → Load/Store Unit
  
  // Jump control signals
  output logic        o_jal,             // JAL instruction → Jump Unit
  output logic        o_jalr,            // JALR instruction → Jump Unit

  // Register read status (for hazard detection optimization)
  output logic        o_rs1_read,
  output logic        o_rs2_read,


  // Machine-mode SYSTEM/CSR control signals
  output logic        o_csr_en,
  output logic [1:0]  o_csr_op,           // 00=write, 01=set, 10=clear
  output logic        o_csr_imm,
  output logic        o_ecall,
  output logic        o_ebreak,
  output logic        o_mret,
  output logic        o_wfi,
  output logic        o_fence_i,
  output logic        o_illegal
);

  // Extract instruction fields
  logic [6:0] opcode;
  logic [2:0] funct3;
  logic [6:0] funct7;
  
  assign opcode = i_instruction[6:0];
  assign funct3 = i_instruction[14:12];
  assign funct7 = i_instruction[31:25];

  // ==========================================================================
  // RV32I Opcodes - 37 Instructions Total
  // ==========================================================================
  parameter [6:0]
    OP_LUI    = 7'b0110111,  // LUI (1)
    OP_AUIPC  = 7'b0010111,  // AUIPC (1)
    OP_JAL    = 7'b1101111,  // JAL (1)
    OP_JALR   = 7'b1100111,  // JALR (1)
    OP_BRANCH = 7'b1100011,  // BEQ, BNE, BLT, BGE, BLTU, BGEU (6)
    OP_LOAD   = 7'b0000011,  // LB, LH, LW, LBU, LHU (5)
    OP_STORE  = 7'b0100011,  // SB, SH, SW (3)
    OP_IMM    = 7'b0010011,  // ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI (9)
    OP_REG    = 7'b0110011,  // ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND (10)
    OP_MISC_MEM = 7'b0001111, // FENCE (strongly ordered core: architectural NOP)
    OP_SYSTEM = 7'b1110011;  // ECALL, EBREAK, MRET and Zicsr

  // ==========================================================================
  // Control Signal Encoding
  // ==========================================================================
  
  // ALU control codes
  parameter [3:0]
    ALU_ADD  = 4'b0000,  // ADD, ADDI, address calculation
    ALU_SUB  = 4'b0001,  // SUB
    ALU_AND  = 4'b0010,  // AND, ANDI
    ALU_OR   = 4'b0011,  // OR, ORI
    ALU_XOR  = 4'b0100,  // XOR, XORI
    ALU_SLT  = 4'b0101,  // SLT, SLTI
    ALU_SLTU = 4'b0110,  // SLTU, SLTIU
    ALU_SLL  = 4'b0111,  // SLL, SLLI
    ALU_SRL  = 4'b1000,  // SRL, SRLI
    ALU_SRA  = 4'b1001,  // SRA, SRAI
    ALU_MUL  = 4'b1010,  // MUL
    ALU_MULH = 4'b1011,  // MULH
    ALU_MULHSU = 4'b1100, // MULHSU
    ALU_MULHU = 4'b1101; // MULHU

  // Writeback source
   parameter [1:0]
    WB_ALU = 2'b00,  // ALU result
    WB_MEM = 2'b01,  // Memory data (Load instructions)
    WB_PC4 = 2'b10,  // PC + 4 (JAL/JALR return address)
    WB_IMM = 2'b11;  // Immediate (LUI direct load)

  // PC source
   parameter [1:0]
    PC_NEXT   = 2'b00,  // PC + 4 (normal sequential)
    PC_BRANCH = 2'b01,  // Branch target (if branch taken)
    PC_JAL    = 2'b10,  // JAL target (PC + J-imm)
    PC_JALR   = 2'b11;  // JALR target ((rs1 + I-imm) & ~1)

  function automatic logic instruction_is_legal(input logic [31:0] inst);
    logic [6:0] op;
    logic [2:0] f3;
    logic [6:0] f7;
    begin
      op = inst[6:0];
      f3 = inst[14:12];
      f7 = inst[31:25];
      instruction_is_legal = 1'b0;

      case (op)
        OP_LUI, OP_AUIPC, OP_JAL: instruction_is_legal = 1'b1;
        OP_JALR: instruction_is_legal = (f3 == 3'b000);
        OP_BRANCH: instruction_is_legal = (f3 == 3'b000) || (f3 == 3'b001) ||
                                                  (f3 == 3'b100) || (f3 == 3'b101) ||
                                                  (f3 == 3'b110) || (f3 == 3'b111);
        OP_LOAD: instruction_is_legal = (f3 == 3'b000) || (f3 == 3'b001) ||
                                                (f3 == 3'b010) || (f3 == 3'b100) ||
                                                (f3 == 3'b101);
        OP_STORE: instruction_is_legal = (f3 == 3'b000) || (f3 == 3'b001) ||
                                                 (f3 == 3'b010);
        OP_IMM: begin
          case (f3)
            3'b000, 3'b010, 3'b011, 3'b100, 3'b110, 3'b111:
              instruction_is_legal = 1'b1;
            3'b001: instruction_is_legal = (f7 == 7'b0000000);
            3'b101: instruction_is_legal = (f7 == 7'b0000000) ||
                                                    (f7 == 7'b0100000);
            // Every value of the three-bit funct3 field is enumerated.
          endcase
        end
        OP_REG: begin
          if (f7 == 7'b0000001)
            instruction_is_legal = 1'b1; // Full M extension
          else begin
            case (f3)
              3'b000, 3'b101: instruction_is_legal = (f7 == 7'b0000000) ||
                                                      (f7 == 7'b0100000);
              3'b001, 3'b010, 3'b011, 3'b100, 3'b110, 3'b111:
                instruction_is_legal = (f7 == 7'b0000000);
              // Every value of the three-bit funct3 field is enumerated.
            endcase
          end
        end
        // FENCE.I identifies the instruction through funct3.  Its imm, rs1,
        // and rd fields are reserved and must not make the instruction illegal.
        OP_MISC_MEM: instruction_is_legal = (f3 == 3'b000) ||
                                            (f3 == 3'b001);
        OP_SYSTEM: begin
          if (f3 == 3'b000)
            instruction_is_legal = (inst == 32'h0000_0073) ||
                                   (inst == 32'h0010_0073) ||
                                   (inst == 32'h3020_0073) ||
                                   (inst == 32'h1050_0073);
          else
            instruction_is_legal = (f3 == 3'b001) || (f3 == 3'b010) ||
                                   (f3 == 3'b011) || (f3 == 3'b101) ||
                                   (f3 == 3'b110) || (f3 == 3'b111);
        end
        default: instruction_is_legal = 1'b0;
      endcase
    end
  endfunction

  assign o_illegal = !instruction_is_legal(i_instruction);

  // ==========================================================================
  // Main Control Logic - 37 Instructions
  // ==========================================================================
  always_comb begin
    // Default values - NOP/Invalid instruction state
    o_reg_write   = 1'b0;
    o_mem_read    = 1'b0;
    o_mem_write   = 1'b0;
    o_wb_sel      = WB_ALU;
    o_pc_sel      = PC_NEXT;
    o_alu_src     = 1'b0;       // Use register rs2
    o_alu_a_sel    = 1'b0;       // Use register rs1
    o_alu_ctrl    = ALU_ADD;
    o_branch_en   = 1'b0;
    o_branch_type = 3'b000;     // Default BEQ type
    o_mem_type    = 3'b010;     // Default word access
    o_jal        = 1'b0;
    o_jalr       = 1'b0;
    o_csr_en      = 1'b0;
    o_csr_op      = 2'b00;
    o_csr_imm     = 1'b0;
    o_ecall      = 1'b0;
    o_ebreak     = 1'b0;
    o_mret       = 1'b0;
    o_wfi        = 1'b0;
    o_fence_i     = 1'b0;
    o_rs1_read    = 1'b0;
    o_rs2_read    = 1'b0;

    case (opcode)
      // ======================================================================
      // U-type Instructions (2): LUI, AUIPC
      // ======================================================================
      OP_LUI: begin
        // LUI rd, imm - Load Upper Immediate
        o_reg_write = 1'b1;
        o_wb_sel    = WB_IMM;     // Direct immediate → register
        // ALU not used for LUI
      end

      OP_AUIPC: begin
        // AUIPC rd, imm - Add Upper Immediate to PC
        o_reg_write = 1'b1;
        o_alu_src   = 1'b1;       // Use immediate as operand B
        o_alu_a_sel  = 1'b1;       // Use PC as operand A
        o_wb_sel    = WB_ALU;     // ALU result → register
        o_alu_ctrl  = ALU_ADD;    // PC + immediate
      end

      // ======================================================================
      // J-type Instructions (1): JAL
      // ======================================================================
      OP_JAL: begin
        // JAL rd, imm - Jump and Link
        o_jal      = 1'b1;       // Signal to Jump Unit
        o_reg_write = 1'b1;
        o_wb_sel    = WB_PC4;     // Return address → register
        o_pc_sel    = PC_JAL;     // PC ← PC + J-imm
      end

      // ======================================================================
      // I-type Jump Instructions (1): JALR
      // ======================================================================
      OP_JALR: begin
        // JALR rd, rs1, imm - Jump and Link Register
        o_jalr     = 1'b1;       // Signal to Jump Unit
        o_reg_write = 1'b1;
        o_rs1_read  = 1'b1;
        o_alu_src   = 1'b1;       // Use immediate for target calculation
        o_wb_sel    = WB_PC4;     // Return address → register
        o_pc_sel    = PC_JALR;    // PC ← (rs1 + I-imm) & ~1
        o_alu_ctrl  = ALU_ADD;    // Target = rs1 + immediate
      end

      // ======================================================================
      // B-type Instructions (6): BEQ, BNE, BLT, BGE, BLTU, BGEU
      // ======================================================================
      OP_BRANCH: begin
        o_branch_en   = 1'b1;     // Enable Branch Unit
        o_branch_type = funct3;   // Branch type → Branch Unit
        o_pc_sel      = PC_BRANCH; // PC ← PC + B-imm (if taken)
        o_rs1_read    = 1'b1;
        o_rs2_read    = 1'b1;
        // ALU not used - Branch Unit handles rs1 vs rs2 comparison
      end

      // ======================================================================
      // I-type Load Instructions (5): LB, LH, LW, LBU, LHU
      // ======================================================================
      OP_LOAD: begin
        o_mem_read  = 1'b1;       // Enable memory read
        o_reg_write = 1'b1;
        o_rs1_read  = 1'b1;
        o_alu_src   = 1'b1;       // Use immediate for address calculation
        o_wb_sel    = WB_MEM;     // Memory data → register
        o_alu_ctrl  = ALU_ADD;    // Address = rs1 + I-imm
        o_mem_type  = funct3;     // Memory type → Load/Store Unit
      end

      // ======================================================================
      // S-type Instructions (3): SB, SH, SW
      // ======================================================================
      OP_STORE: begin
        o_mem_write = 1'b1;       // Enable memory write
        o_rs1_read  = 1'b1;
        o_rs2_read  = 1'b1;
        o_alu_src   = 1'b1;       // Use immediate for address calculation
        o_alu_ctrl  = ALU_ADD;    // Address = rs1 + S-imm
        o_mem_type  = funct3;     // Memory type → Load/Store Unit
        // rs2 data goes to Load/Store Unit for store data
      end

      // ======================================================================
      // I-type ALU Instructions (9): ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI
      // ======================================================================
      OP_IMM: begin
        o_reg_write = 1'b1;
        o_rs1_read  = 1'b1;
        o_alu_src   = 1'b1;       // Use immediate as operand B
        o_wb_sel    = WB_ALU;     // ALU result → register
        
        // Decode specific I-type ALU operation
        case (funct3)
          3'b000: o_alu_ctrl = ALU_ADD;   // ADDI
          3'b010: o_alu_ctrl = ALU_SLT;   // SLTI
          3'b011: o_alu_ctrl = ALU_SLTU;  // SLTIU
          3'b100: o_alu_ctrl = ALU_XOR;   // XORI
          3'b110: o_alu_ctrl = ALU_OR;    // ORI
          3'b111: o_alu_ctrl = ALU_AND;   // ANDI
          3'b001: o_alu_ctrl = ALU_SLL;   // SLLI
          3'b101: begin
            // SRLI vs SRAI determined by funct7[5]
            if (funct7[5])
              o_alu_ctrl = ALU_SRA;       // SRAI
            else
              o_alu_ctrl = ALU_SRL;       // SRLI
          end
          // Every value of the three-bit funct3 field is enumerated.
          /* verilator coverage_off */
          default: o_alu_ctrl = ALU_ADD;
          /* verilator coverage_on */
        endcase
      end

      // ======================================================================
      // R-type Instructions (10): ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
      // ======================================================================
      OP_REG: begin
        o_reg_write = 1'b1;
        o_rs1_read  = 1'b1;
        o_rs2_read  = 1'b1;
        o_wb_sel    = WB_ALU;     // ALU result → register
        // ALUSrc = 0 (use rs2), ALUASel = 0 (use rs1)

        if (funct7 == 7'b0000001) begin
          case (funct3)
            3'b000: o_alu_ctrl = ALU_MUL;
            3'b001: o_alu_ctrl = ALU_MULH;
            3'b010: o_alu_ctrl = ALU_MULHSU;
            3'b011: o_alu_ctrl = ALU_MULHU;
            // DIV/DIVU/REM/REMU use the dedicated iterative divider. Their
            // funct3 is carried in the instruction payload.
            /* verilator coverage_off */
            default: o_alu_ctrl = ALU_ADD;
            /* verilator coverage_on */
          endcase
        end else begin
          // Decode base integer R-type ALU operation.
          case (funct3)
            3'b000: begin
              if (funct7[5])
                o_alu_ctrl = ALU_SUB;
              else
                o_alu_ctrl = ALU_ADD;
            end
            3'b001: o_alu_ctrl = ALU_SLL;
            3'b010: o_alu_ctrl = ALU_SLT;
            3'b011: o_alu_ctrl = ALU_SLTU;
            3'b100: o_alu_ctrl = ALU_XOR;
            3'b101: begin
              if (funct7[5])
                o_alu_ctrl = ALU_SRA;
              else
                o_alu_ctrl = ALU_SRL;
            end
            3'b110: o_alu_ctrl = ALU_OR;
            3'b111: o_alu_ctrl = ALU_AND;
            /* verilator coverage_off */
            default: o_alu_ctrl = ALU_ADD;
            /* verilator coverage_on */
          endcase
        end
      end

      OP_MISC_MEM: begin
        // This in-order core allows only one outstanding memory transaction,
        // so FENCE requires no additional datapath action.
        o_fence_i = (i_instruction[14:12] == 3'b001);
      end

      // ======================================================================
      // Machine-mode SYSTEM and Zicsr instructions
      // ======================================================================
      OP_SYSTEM: begin
        case (funct3)
          3'b000: begin
            case (i_instruction)
              32'h0000_0073: o_ecall  = 1'b1;
              32'h0010_0073: o_ebreak = 1'b1;
              32'h3020_0073: o_mret   = 1'b1;
              32'h1050_0073: o_wfi    = 1'b1;
              default: begin end
            endcase
          end
          3'b001, 3'b010, 3'b011,
          3'b101, 3'b110, 3'b111: begin
            o_csr_en      = 1'b1;
            o_reg_write   = 1'b1;
            o_wb_sel      = WB_ALU;
            o_csr_imm     = funct3[2];
            // rs1 is read only for non-immediate CSR operations
            o_rs1_read    = !funct3[2];
            case (funct3[1:0])
              2'b01: o_csr_op = 2'b00; // CSRRW/CSRRWI
              2'b10: o_csr_op = 2'b01; // CSRRS/CSRRSI
              2'b11: o_csr_op = 2'b10; // CSRRC/CSRRCI
              // Legal CSR funct3 values never produce funct3[1:0] == 0.
              /* verilator coverage_off */
              default: o_csr_op = 2'b00;
              /* verilator coverage_on */
            endcase
          end
          default: begin end
        endcase
      end

      // ======================================================================
      // Default Case - Invalid/Unsupported Instruction
      // ======================================================================
      default: begin
        // All outputs remain at default values
        // Effectively creates NOP behavior for invalid opcodes
      end
    endcase
  end
endmodule
