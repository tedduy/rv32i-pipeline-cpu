module load_store_unit #(
  parameter N = 32
)(
  // Control inputs
  input  logic [2:0]   i_mem_type,      // Memory operation type (funct3)
  input  logic         i_mem_read,      // Memory read enable
  input  logic         i_mem_write,     // Memory write enable
  input  logic [1:0]   i_byte_offset,   // Address byte offset (addr[1:0])
  
  // Data inputs
  input  logic [N-1:0] i_mem_read_data, // Data from memory
  input  logic [N-1:0] i_store_data,    // Data to store (from register)
  
  // Outputs
  output logic [N-1:0] o_load_data,     // Processed load data
  output logic [N-1:0] o_store_data,    // Processed store data
  output logic [3:0]   o_byte_enable    // Memory byte enable
);

  // Memory operations cho 8 instructions:
  // Load (5): LB, LH, LW, LBU, LHU
  // Store (3): SB, SH, SW

  localparam [2:0]
    MEM_BYTE      = 3'b000,  // LB/SB
    MEM_HALF      = 3'b001,  // LH/SH
    MEM_WORD      = 3'b010,  // LW/SW
    MEM_BYTE_U    = 3'b100,  // LBU
    MEM_HALF_U    = 3'b101;  // LHU

  // Load data processing
  always_comb begin
    o_load_data = '0;
    if (i_mem_read) begin
      case (i_mem_type)
        MEM_BYTE: begin // LB - Load Byte (signed)
          case (i_byte_offset)
            2'b00: o_load_data = {{24{i_mem_read_data[7]}},  i_mem_read_data[7:0]};
            2'b01: o_load_data = {{24{i_mem_read_data[15]}}, i_mem_read_data[15:8]};
            2'b10: o_load_data = {{24{i_mem_read_data[23]}}, i_mem_read_data[23:16]};
            2'b11: o_load_data = {{24{i_mem_read_data[31]}}, i_mem_read_data[31:24]};
            default: o_load_data = '0;
          endcase
        end
        
        MEM_HALF: begin // LH - Load Halfword (signed)
          case (i_byte_offset[1])
            1'b0: o_load_data = {{16{i_mem_read_data[15]}}, i_mem_read_data[15:0]};
            1'b1: o_load_data = {{16{i_mem_read_data[31]}}, i_mem_read_data[31:16]};
            default: o_load_data = '0;
          endcase
        end
        
        MEM_WORD: begin // LW - Load Word
          o_load_data = i_mem_read_data;
        end
        
        MEM_BYTE_U: begin // LBU - Load Byte Unsigned
          case (i_byte_offset)
            2'b00: o_load_data = {24'b0, i_mem_read_data[7:0]};
            2'b01: o_load_data = {24'b0, i_mem_read_data[15:8]};
            2'b10: o_load_data = {24'b0, i_mem_read_data[23:16]};
            2'b11: o_load_data = {24'b0, i_mem_read_data[31:24]};
            default: o_load_data = '0;
          endcase
        end
        
        MEM_HALF_U: begin // LHU - Load Halfword Unsigned
          case (i_byte_offset[1])
            1'b0: o_load_data = {16'b0, i_mem_read_data[15:0]};
            1'b1: o_load_data = {16'b0, i_mem_read_data[31:16]};
            default: o_load_data = '0;
          endcase
        end
        
        default: o_load_data = '0;
      endcase
    end
  end

  // Store data processing and byte enable generation
  always_comb begin
    o_store_data = '0;
    o_byte_enable = 4'b0000;
    if (i_mem_write) begin
      case (i_mem_type)
        MEM_BYTE: begin // SB - Store Byte
          case (i_byte_offset)
            2'b00: begin
              o_store_data = {24'b0, i_store_data[7:0]};
              o_byte_enable = 4'b0001;
            end
            2'b01: begin
              o_store_data = {16'b0, i_store_data[7:0], 8'b0};
              o_byte_enable = 4'b0010;
            end
            2'b10: begin
              o_store_data = {8'b0, i_store_data[7:0], 16'b0};
              o_byte_enable = 4'b0100;
            end
            2'b11: begin
              o_store_data = {i_store_data[7:0], 24'b0};
              o_byte_enable = 4'b1000;
            end
            default: begin
              o_store_data = '0;
              o_byte_enable = 4'b0000;
            end
          endcase
        end
        
        MEM_HALF: begin // SH - Store Halfword
          case (i_byte_offset[1])
            1'b0: begin
              o_store_data = {16'b0, i_store_data[15:0]};
              o_byte_enable = 4'b0011;
            end
            1'b1: begin
              o_store_data = {i_store_data[15:0], 16'b0};
              o_byte_enable = 4'b1100;
            end
            default: begin
              o_store_data = '0;
              o_byte_enable = 4'b0000;
            end
          endcase
        end
        
        MEM_WORD: begin // SW - Store Word
          o_store_data = i_store_data;
          o_byte_enable = 4'b1111;
        end
        
        default: begin
          o_store_data = '0;
          o_byte_enable = 4'b0000;
        end
      endcase
    end
  end

endmodule
