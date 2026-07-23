// RV32C decompressor.  Every legal 16-bit instruction is translated into the
// equivalent 32-bit RV32I instruction so the existing decode/execute pipeline
// remains unaware of compressed encodings.
module rv32c_decompressor (
    input  logic [15:0] i_instruction,
    output logic [31:0] o_instruction,
    output logic        o_illegal
);

    logic [4:0] rd;
    logic [4:0] rs2;
    logic [4:0] rdp;
    logic [4:0] rs1p;
    logic [4:0] rs2p;
    logic [31:0] imm;

    function automatic logic [31:0] enc_i(
        input logic [11:0] immediate,
        input logic [4:0]  rs1_i,
        input logic [2:0]  funct3_i,
        input logic [4:0]  rd_i,
        input logic [6:0]  opcode_i
    );
        enc_i = {immediate, rs1_i, funct3_i, rd_i, opcode_i};
    endfunction

    function automatic logic [31:0] enc_r(
        input logic [6:0] funct7_i,
        input logic [4:0] rs2_i,
        input logic [4:0] rs1_i,
        input logic [2:0] funct3_i,
        input logic [4:0] rd_i,
        input logic [6:0] opcode_i
    );
        enc_r = {funct7_i, rs2_i, rs1_i, funct3_i, rd_i, opcode_i};
    endfunction

    function automatic logic [31:0] enc_s(
        input logic [11:0] immediate,
        input logic [4:0]  rs2_i,
        input logic [4:0]  rs1_i,
        input logic [2:0]  funct3_i
    );
        enc_s = {immediate[11:5], rs2_i, rs1_i, funct3_i,
                 immediate[4:0], 7'b0100011};
    endfunction

    function automatic logic [31:0] enc_b(
        input logic [12:1] immediate,
        input logic [4:0]  rs2_i,
        input logic [4:0]  rs1_i,
        input logic [2:0]  funct3_i
    );
        enc_b = {immediate[12], immediate[10:5], rs2_i, rs1_i, funct3_i,
                 immediate[4:1], immediate[11], 7'b1100011};
    endfunction

    function automatic logic [31:0] enc_j(
        input logic [20:1] immediate,
        input logic [4:0]  rd_i
    );
        enc_j = {immediate[20], immediate[10:1], immediate[11],
                 immediate[19:12], rd_i, 7'b1101111};
    endfunction

    always_comb begin
        rd   = i_instruction[11:7];
        rs2  = i_instruction[6:2];
        rdp  = {2'b01, i_instruction[4:2]};
        rs1p = {2'b01, i_instruction[9:7]};
        rs2p = {2'b01, i_instruction[4:2]};
        imm  = '0;

        o_instruction = 32'h0000_0013;
        o_illegal     = 1'b0;

        unique case (i_instruction[1:0])
            2'b00: begin
                unique case (i_instruction[15:13])
                    3'b000: begin // C.ADDI4SPN
                        imm = {22'b0, i_instruction[10:7],
                               i_instruction[12:11], i_instruction[5],
                               i_instruction[6], 2'b00};
                        if (imm[9:2] == 8'b0)
                            o_illegal = 1'b1;
                        else
                            o_instruction = enc_i(imm[11:0], 5'd2, 3'b000,
                                                  rdp, 7'b0010011);
                    end
                    3'b010: begin // C.LW
                        imm = {25'b0, i_instruction[5],
                               i_instruction[12:10], i_instruction[6], 2'b00};
                        o_instruction = enc_i(imm[11:0], rs1p, 3'b010,
                                              rdp, 7'b0000011);
                    end
                    3'b110: begin // C.SW
                        imm = {25'b0, i_instruction[5],
                               i_instruction[12:10], i_instruction[6], 2'b00};
                        o_instruction = enc_s(imm[11:0], rs2p, rs1p, 3'b010);
                    end
                    default: o_illegal = 1'b1;
                endcase
            end

            2'b01: begin
                unique case (i_instruction[15:13])
                    3'b000: begin // C.NOP / C.ADDI
                        imm = {{26{i_instruction[12]}}, i_instruction[12],
                               i_instruction[6:2]};
                        o_instruction = enc_i(imm[11:0], rd, 3'b000,
                                              rd, 7'b0010011);
                    end
                    3'b001: begin // C.JAL (RV32 only)
                        imm = {{20{i_instruction[12]}}, i_instruction[12],
                               i_instruction[8], i_instruction[10:9],
                               i_instruction[6], i_instruction[7],
                               i_instruction[2], i_instruction[11],
                               i_instruction[5:3], 1'b0};
                        o_instruction = enc_j(imm[20:1], 5'd1);
                    end
                    3'b010: begin // C.LI
                        imm = {{26{i_instruction[12]}}, i_instruction[12],
                               i_instruction[6:2]};
                        o_instruction = enc_i(imm[11:0], 5'd0, 3'b000,
                                              rd, 7'b0010011);
                    end
                    3'b011: begin
                        if (rd == 5'd2) begin // C.ADDI16SP
                            imm = {{22{i_instruction[12]}}, i_instruction[12],
                                   i_instruction[4:3], i_instruction[5],
                                   i_instruction[2], i_instruction[6], 4'b0};
                            if (imm[9:4] == 6'b0)
                                o_illegal = 1'b1;
                            else
                                o_instruction = enc_i(imm[11:0], 5'd2, 3'b000,
                                                      5'd2, 7'b0010011);
                        end else begin // C.LUI
                            imm = {{14{i_instruction[12]}}, i_instruction[12],
                                   i_instruction[6:2], 12'b0};
                            if (rd == 5'd0)
                                // The rd=x0 encoding is a standard HINT.
                                o_instruction = 32'h0000_0013;
                            else if (imm[17:12] == 6'b0)
                                o_illegal = 1'b1;
                            else
                                o_instruction = {imm[31:12], rd, 7'b0110111};
                        end
                    end
                    3'b100: begin
                        unique case (i_instruction[11:10])
                            2'b00, 2'b01: begin // C.SRLI / C.SRAI
                                if (i_instruction[12])
                                    o_illegal = 1'b1;
                                else
                                    o_instruction = enc_i(
                                        {(i_instruction[11:10] == 2'b01) ? 7'b0100000 : 7'b0000000,
                                         i_instruction[6:2]},
                                        rs1p, 3'b101, rs1p, 7'b0010011);
                            end
                            2'b10: begin // C.ANDI
                                imm = {{26{i_instruction[12]}}, i_instruction[12],
                                       i_instruction[6:2]};
                                o_instruction = enc_i(imm[11:0], rs1p, 3'b111,
                                                      rs1p, 7'b0010011);
                            end
                            2'b11: begin
                                if (i_instruction[12]) begin
                                    // SUBW/ADDW encodings are reserved in RV32.
                                    o_illegal = 1'b1;
                                end else begin
                                    unique case (i_instruction[6:5])
                                        2'b00: o_instruction = enc_r(7'b0100000, rs2p, rs1p, 3'b000, rs1p, 7'b0110011); // C.SUB
                                        2'b01: o_instruction = enc_r(7'b0000000, rs2p, rs1p, 3'b100, rs1p, 7'b0110011); // C.XOR
                                        2'b10: o_instruction = enc_r(7'b0000000, rs2p, rs1p, 3'b110, rs1p, 7'b0110011); // C.OR
                                        2'b11: o_instruction = enc_r(7'b0000000, rs2p, rs1p, 3'b111, rs1p, 7'b0110011); // C.AND
                                    endcase
                                end
                            end
                        endcase
                    end
                    3'b101: begin // C.J
                        imm = {{20{i_instruction[12]}}, i_instruction[12],
                               i_instruction[8], i_instruction[10:9],
                               i_instruction[6], i_instruction[7],
                               i_instruction[2], i_instruction[11],
                               i_instruction[5:3], 1'b0};
                        o_instruction = enc_j(imm[20:1], 5'd0);
                    end
                    3'b110, 3'b111: begin // C.BEQZ / C.BNEZ
                        imm = {{23{i_instruction[12]}}, i_instruction[12],
                               i_instruction[6:5], i_instruction[2],
                               i_instruction[11:10], i_instruction[4:3], 1'b0};
                        o_instruction = enc_b(imm[12:1], 5'd0, rs1p,
                                              i_instruction[13] ? 3'b001 : 3'b000);
                    end
                endcase
            end

            2'b10: begin
                unique case (i_instruction[15:13])
                    3'b000: begin // C.SLLI
                        if (i_instruction[12])
                            o_illegal = 1'b1;
                        else
                            o_instruction = enc_i({7'b0, i_instruction[6:2]},
                                                  rd, 3'b001, rd, 7'b0010011);
                    end
                    3'b010: begin // C.LWSP
                        imm = {24'b0, i_instruction[3:2], i_instruction[12],
                               i_instruction[6:4], 2'b00};
                        if (rd == 5'd0)
                            o_illegal = 1'b1;
                        else
                            o_instruction = enc_i(imm[11:0], 5'd2, 3'b010,
                                                  rd, 7'b0000011);
                    end
                    3'b100: begin
                        if (!i_instruction[12]) begin
                            if (rs2 == 5'd0) begin // C.JR
                                if (rd == 5'd0)
                                    o_illegal = 1'b1;
                                else
                                    o_instruction = enc_i(12'b0, rd, 3'b000,
                                                          5'd0, 7'b1100111);
                            end else begin // C.MV
                                o_instruction = enc_r(7'b0, rs2, 5'd0, 3'b000,
                                                      rd, 7'b0110011);
                            end
                        end else if (rs2 == 5'd0) begin
                            if (rd == 5'd0) // C.EBREAK
                                o_instruction = 32'h0010_0073;
                            else // C.JALR
                                o_instruction = enc_i(12'b0, rd, 3'b000,
                                                      5'd1, 7'b1100111);
                        end else begin // C.ADD
                            o_instruction = enc_r(7'b0, rs2, rd, 3'b000,
                                                  rd, 7'b0110011);
                        end
                    end
                    3'b110: begin // C.SWSP
                        imm = {24'b0, i_instruction[8:7], i_instruction[12:9],
                               2'b00};
                        o_instruction = enc_s(imm[11:0], rs2, 5'd2, 3'b010);
                    end
                    default: o_illegal = 1'b1;
                endcase
            end

            // A 16-bit parcel ending in 2'b11 begins a normal 32-bit
            // instruction and must never be sent to the decompressor.
            default: o_illegal = 1'b1;
        endcase
    end
endmodule
