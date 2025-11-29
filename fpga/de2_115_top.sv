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
    
    logic [31:0] W_PC_out;
    logic [31:0] W_instruction;
    logic [31:0] W_RD1, W_RD2;
    logic [4:0]  W_rd_addr;
    logic        W_reg_write;
    logic [31:0] W_m1, W_m2;
    logic [31:0] W_ALUout;
    logic [31:0] W_mem_addr;
    logic [31:0] W_mem_wdata;
    logic [31:0] W_mem_rdata;
    logic        W_mem_write;
    logic        W_mem_read;
    logic [31:0] W_WB_data;
    logic        W_branch_taken;
    logic        W_jal;
    logic        W_jalr;
    logic        W_stall;
    logic        W_flush;
    
    // ==========================================================================
    // CPU INSTANTIATION
    // ==========================================================================
    
    rv32i_top cpu (
        .i_clk         (clk),
        .i_arst_n      (rst_n),
        
        .W_PC_out      (W_PC_out),
        .instruction   (W_instruction),
        .W_RD1         (W_RD1),
        .W_RD2         (W_RD2),
        .W_m1          (W_m1),
        .W_m2          (W_m2),
        .W_ALUout      (W_ALUout),
        .W_WB_data     (W_WB_data),
        .W_rd_addr     (W_rd_addr),
        .W_reg_write   (W_reg_write),
        .W_mem_write   (W_mem_write),
        .W_mem_read    (W_mem_read),
        .W_branch_taken(W_branch_taken),
        .W_mem_addr    (W_mem_addr),
        .W_mem_wdata   (W_mem_wdata),
        .W_mem_rdata   (W_mem_rdata),
        .W_jal         (W_jal),
        .W_jalr        (W_jalr),
        .W_stall       (W_stall),
        .W_flush       (W_flush)
    );
    
    // ==========================================================================
    // PERFORMANCE COUNTERS
    // ==========================================================================
    
    logic [31:0] cycle_counter;
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
        else if (W_reg_write && (W_rd_addr != 5'h0))
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
        MODE_RD2         = 3'b101,  // Register read data 2
        MODE_MEM_ADDR    = 3'b110,  // Memory address
        MODE_CYCLE_CNT   = 3'b111   // Cycle counter
    } debug_mode_t;
    
    debug_mode_t debug_mode;
    assign debug_mode = debug_mode_t'(SW[2:0]);
    
    logic [31:0] display_value;
    
    always_comb begin
        case (debug_mode)
            MODE_PC:          display_value = W_PC_out;
            MODE_INSTRUCTION: display_value = W_instruction;
            MODE_ALU_OUT:     display_value = W_ALUout;
            MODE_WB_DATA:     display_value = W_WB_data;
            MODE_RD1:         display_value = W_RD1;
            MODE_RD2:         display_value = W_RD2;
            MODE_MEM_ADDR:    display_value = W_mem_addr;
            MODE_CYCLE_CNT:   display_value = cycle_counter;
            default:          display_value = W_PC_out;
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
            LEDG[1] <= W_reg_write;     // Register write
            LEDG[2] <= W_mem_write;     // Memory write
            LEDG[3] <= W_mem_read;      // Memory read
            LEDG[4] <= W_branch_taken;  // Branch taken
            LEDG[5] <= W_jal;           // JAL instruction
            LEDG[6] <= W_jalr;          // JALR instruction
            LEDG[7] <= W_stall;         // Pipeline stall
            LEDG[8] <= W_flush;         // Pipeline flush
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
//   101: Register Read Data 2 (RD2)
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
