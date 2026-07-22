// ==============================================================================
// DE2-115 Top-Level Module for RV32I Pipeline CPU
// Manual Clock Control Version - Clock driven by SW[17] switch
// ==============================================================================
// Board: Terasic DE2-115
// FPGA: Cyclone IV E EP4CE115F29C7
// Clock: Manual (SW[17] switch)
// ==============================================================================

module de2_115_top (
    // ===== Clock and Reset =====
    input  logic        CLOCK_50,      // 50 MHz board oscillator (for sync only)
    input  logic [3:0]  KEY,           // Push buttons (active low)
    
    // ===== User Interface =====
    input  logic [17:0] SW,            // Slide switches
    output logic [17:0] LEDR,          // Red LEDs
    output logic [8:0]  LEDG,          // Green LEDs
    
    // ===== 7-Segment Displays =====
    output logic [6:0]  HEX0, HEX1, HEX2, HEX3,
    output logic [6:0]  HEX4, HEX5, HEX6, HEX7
);

    // ==========================================================================
    // CLOCK AND RESET MANAGEMENT
    // ==========================================================================
    
    logic clk;
    logic rst_n;
    
    // KEY[0]: Reset (active low)
    // SW[17]: Manual clock - toggle to advance one cycle
    
    // Reset synchronizer
    logic rst_sync1, rst_sync2;
    
    always_ff @(posedge CLOCK_50 or negedge KEY[0]) begin
        if (!KEY[0]) begin
            rst_sync1 <= 1'b0;
            rst_sync2 <= 1'b0;
        end else begin
            rst_sync1 <= 1'b1;
            rst_sync2 <= rst_sync1;
        end
    end
    assign rst_n = rst_sync2;
    
    // ==========================================================================
    // MANUAL CLOCK FROM SW[17]
    // ==========================================================================
    // Synchronize SW[17] to avoid metastability
    
    logic sw17_sync1, sw17_sync2;
    
    always_ff @(posedge CLOCK_50 or negedge rst_n) begin
        if (!rst_n) begin
            sw17_sync1 <= 1'b0;
            sw17_sync2 <= 1'b0;
        end else begin
            sw17_sync1 <= SW[17];
            sw17_sync2 <= sw17_sync1;
        end
    end
    
    // Use synchronized SW[17] as manual clock
    assign clk = sw17_sync2;
    
    // ==========================================================================
    // CPU DEBUG INTERFACE
    // ==========================================================================
    
    logic [31:0] debug_pc;
    logic [31:0] debug_instruction;
    logic [31:0] debug_rs1_data, debug_rs2_data;
    logic [4:0]  debug_rd_addr;
    logic        debug_rd_write;
    logic [31:0] debug_alu_operand_b, debug_branch_target;
    logic [31:0] debug_alu_result;
    logic [31:0] debug_mem_addr;
    logic [31:0] debug_mem_wdata;
    logic [31:0] debug_mem_rdata;
    logic        debug_mem_write;
    logic        debug_mem_read;
    logic [31:0] debug_wb_data;
    logic        debug_branch_taken;
    logic        debug_jal;
    logic        debug_jalr;
    logic        debug_stall;
    logic        debug_flush;
    logic [31:0] debug_immediate;
    logic        debug_alu_uses_immediate;

    // Native instruction/data memory interfaces used by rv32i_core.
    logic        imem_valid;
    logic [31:0] imem_addr;
    logic [31:0] imem_rdata;
    logic        dmem_valid;
    logic        dmem_read;
    logic        dmem_write;
    logic [31:0] dmem_addr;
    logic [31:0] dmem_wdata;
    logic [31:0] dmem_rdata;
    logic [3:0]  dmem_wstrb;
    logic [1:0]  dmem_size;

    logic [31:0] cycle_counter;
    
    // Decode ALUSrc from instruction opcode
    logic        alu_uses_imm;
    
    // ==========================================================================
    // CPU INSTANTIATION
    // ==========================================================================
    
    rv32i_core u_core (
        .i_clk         (clk),
        .i_arst_n      (rst_n),

        .i_irq_software(1'b0),
        .i_irq_timer   (1'b0),
        .i_irq_external(1'b0),
        .i_time        ({32'b0, cycle_counter}),
        .o_core_sleep  (),
        .o_fence_i     (),

        .o_imem_valid  (imem_valid),
        .o_imem_addr   (imem_addr),
        .i_imem_rdata  (imem_rdata),
        .i_imem_ready  (1'b1),
        .i_imem_error  (1'b0),

        .o_dmem_valid  (dmem_valid),
        .o_dmem_read   (dmem_read),
        .o_dmem_write  (dmem_write),
        .o_dmem_addr   (dmem_addr),
        .o_dmem_wdata  (dmem_wdata),
        .o_dmem_wstrb  (dmem_wstrb),
        .o_dmem_size   (dmem_size),
        .i_dmem_rdata  (dmem_rdata),
        .i_dmem_ready  (1'b1),
        .i_dmem_error  (1'b0),

        .o_commit_valid(),
        .o_commit_pc   (),
        .o_commit_instruction(),
        .o_commit_rd_write(),
        .o_commit_rd_addr(),
        .o_commit_rd_data(),
        .o_commit_mem_write(),
        .o_commit_mem_addr(),
        .o_commit_mem_wdata(),
        .o_commit_mem_wstrb(),
        
        .o_debug_pc      (debug_pc),
        .o_debug_instruction   (debug_instruction),
        .o_debug_rs1_data         (debug_rs1_data),
        .o_debug_rs2_data         (debug_rs2_data),
        .o_debug_alu_operand_b          (debug_alu_operand_b),
        .o_debug_branch_target          (debug_branch_target),
        .o_debug_alu_result      (debug_alu_result),
        .o_debug_wb_data     (debug_wb_data),
        .o_debug_rd_addr     (debug_rd_addr),
        .o_debug_rd_write   (debug_rd_write),
        .o_debug_mem_write   (debug_mem_write),
        .o_debug_mem_read    (debug_mem_read),
        .o_debug_branch_taken(debug_branch_taken),
        .o_debug_mem_addr    (debug_mem_addr),
        .o_debug_mem_wdata   (debug_mem_wdata),
        .o_debug_mem_rdata   (debug_mem_rdata),
        .o_debug_jal         (debug_jal),
        .o_debug_jalr        (debug_jalr),
        .o_debug_stall       (debug_stall),
        .o_debug_flush       (debug_flush),
        .o_debug_immediate   (debug_immediate),
        .o_debug_alu_uses_immediate      (debug_alu_uses_immediate)
    );

    // Small on-chip memories keep the board wrapper self-contained. Both
    // native ports are zero-wait-state, matching the original FPGA demo.
    instruction_memory #(
        .N(32),
        .DEPTH(77)
    ) u_imem (
        .i_clk   (clk),
        .i_arst_n(rst_n),
        .i_addr  (imem_addr),
        .o_instruction(imem_rdata)
    );

    data_memory #(
        .N(32),
        .BYTES(256)
    ) u_dmem (
        .i_clk   (clk),
        .i_arst_n(rst_n),
        .i_we    (dmem_valid && dmem_write),
        .i_re    (dmem_valid && dmem_read),
        .i_addr  (dmem_addr),
        .i_wdata (dmem_wdata),
        .i_wstrb (dmem_wstrb),
        .o_rdata (dmem_rdata)
    );
    
    // ==========================================================================
    // PERFORMANCE COUNTERS
    // ==========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cycle_counter <= 32'h0;
        else
            cycle_counter <= cycle_counter + 32'h1;
    end
    
    logic [31:0] instruction_counter;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            instruction_counter <= 32'h0;
        else if (debug_rd_write && (debug_rd_addr != 5'h0))
            instruction_counter <= instruction_counter + 32'h1;
    end
    
    // ==========================================================================
    // DEBUG MODE SELECTION
    // ==========================================================================
    // SW[2:0] selects which value to display on 7-segment
    
    typedef enum logic [2:0] {
        MODE_PC          = 3'b000,  // Program Counter
        MODE_INSTRUCTION = 3'b001,  // Current instruction
        MODE_ALU_OUT     = 3'b010,  // ALU output
        MODE_WB_DATA     = 3'b011,  // Writeback data
        MODE_RD1         = 3'b100,  // Register read data 1
        MODE_ALU_SRC     = 3'b101,  // ALU Source (RD2 or IMM based on ALUSrc)
        MODE_MEM_ADDR    = 3'b110,  // Memory address
        MODE_CYCLE_CNT   = 3'b111   // Cycle counter
    } debug_mode_t;
    
    debug_mode_t debug_mode;
    assign debug_mode = debug_mode_t'(SW[2:0]);
    
    // Decode if instruction uses immediate (synchronized with debug_instruction at WB stage)
    logic [6:0] opcode;
    assign opcode = debug_instruction[6:0];
    
    always_comb begin
        case (opcode)
            7'b0010011,  // OP_IMM (I-type ALU)
            7'b0000011,  // LOAD
            7'b0100011,  // STORE
            7'b0010111,  // AUIPC
            7'b1100111:  // JALR
                alu_uses_imm = 1'b1;
            default:
                alu_uses_imm = 1'b0;
        endcase
    end
    
    logic [31:0] display_value;
    
    always_comb begin
        case (debug_mode)
            MODE_PC:          display_value = debug_pc;
            MODE_INSTRUCTION: display_value = debug_instruction;
            MODE_ALU_OUT:     display_value = debug_alu_result;
            MODE_WB_DATA:     display_value = debug_wb_data;
            MODE_RD1:         display_value = debug_rs1_data;
            MODE_ALU_SRC:     display_value = alu_uses_imm ? debug_immediate : debug_rs2_data;  // Show actual ALU operand B
            MODE_MEM_ADDR:    display_value = debug_mem_addr;
            MODE_CYCLE_CNT:   display_value = cycle_counter;
            default:          display_value = debug_pc;
        endcase
    end
    
    // ==========================================================================
    // LED OUTPUTS
    // ==========================================================================
    
    // Red LEDs: Mirror switches (passthrough)
    always_ff @(posedge CLOCK_50 or negedge rst_n) begin
        if (!rst_n) begin
            LEDR <= 18'h0;
        end else begin
            LEDR <= SW;
        end
    end
    
    // Green LEDs: CPU status signals (all 1-bit signals)
    always_ff @(posedge CLOCK_50 or negedge rst_n) begin
        if (!rst_n) begin
            LEDG <= 9'h0;
        end else begin
            LEDG[0] <= rst_n;           // CPU running
            LEDG[1] <= debug_rd_write;     // Register write
            LEDG[2] <= debug_mem_write;     // Memory write
            LEDG[3] <= debug_mem_read;      // Memory read
            LEDG[4] <= debug_branch_taken;  // Branch taken
            LEDG[5] <= debug_jal;           // JAL instruction
            LEDG[6] <= debug_jalr;          // JALR instruction
            LEDG[7] <= debug_stall;         // Pipeline stall
            LEDG[8] <= debug_flush;         // Pipeline flush
        end
    end
    
    // ==========================================================================
    // 7-SEGMENT DISPLAY OUTPUTS
    // ==========================================================================
    
    hex_to_7seg u_hex0 (.hex(display_value[3:0]),   .seg(HEX0));
    hex_to_7seg u_hex1 (.hex(display_value[7:4]),   .seg(HEX1));
    hex_to_7seg u_hex2 (.hex(display_value[11:8]),  .seg(HEX2));
    hex_to_7seg u_hex3 (.hex(display_value[15:12]), .seg(HEX3));
    hex_to_7seg u_hex4 (.hex(display_value[19:16]), .seg(HEX4));
    hex_to_7seg u_hex5 (.hex(display_value[23:20]), .seg(HEX5));
    hex_to_7seg u_hex6 (.hex(display_value[27:24]), .seg(HEX6));
    hex_to_7seg u_hex7 (.hex(display_value[31:28]), .seg(HEX7));

endmodule

// ==============================================================================
// HEX TO 7-SEGMENT DECODER
// ==============================================================================

module hex_to_7seg (
    input  logic [3:0] hex,
    output logic [6:0] seg
);

    always_comb begin
        case (hex)
            4'h0: seg = 7'b1000000;
            4'h1: seg = 7'b1111001;
            4'h2: seg = 7'b0100100;
            4'h3: seg = 7'b0110000;
            4'h4: seg = 7'b0011001;
            4'h5: seg = 7'b0010010;
            4'h6: seg = 7'b0000010;
            4'h7: seg = 7'b1111000;
            4'h8: seg = 7'b0000000;
            4'h9: seg = 7'b0010000;
            4'hA: seg = 7'b0001000;
            4'hB: seg = 7'b0000011;
            4'hC: seg = 7'b1000110;
            4'hD: seg = 7'b0100001;
            4'hE: seg = 7'b0000110;
            4'hF: seg = 7'b0001110;
            default: seg = 7'b1111111;
        endcase
    end

endmodule

// ==============================================================================
// USAGE INSTRUCTIONS
// ==============================================================================
//
// KEY[0]: Reset (hold to reset CPU)
// SW[17]: Manual Clock (toggle 0→1 or 1→0 to advance one clock cycle)
//
// SW[2:0]: Debug Mode Selection (7-segment display)
//   000: Program Counter (PC)
//   001: Current Instruction
//   010: ALU Output
//   011: Writeback Data
//   100: Register Read Data 1 (RD1)
//   101: ALU Source (RD2 or IMM - shows actual value used in ALU)
//   110: Memory Address
//   111: Cycle Counter
//
// LEDR[17:0]: Mirror of SW[17:0] (passthrough for visual feedback)
//
// LEDG[0]: CPU Running (reset status)
// LEDG[1]: Register Write
// LEDG[2]: Memory Write
// LEDG[3]: Memory Read
// LEDG[4]: Branch Taken
// LEDG[5]: JAL
// LEDG[6]: JALR
// LEDG[7]: Pipeline Stall
// LEDG[8]: Pipeline Flush
//
// ==============================================================================
