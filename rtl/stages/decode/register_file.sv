module register_file #(
    parameter N     = 32,  // width of a register
    parameter DEPTH = 32,  // number of registers (x0..x31)

    // Giá trị khởi tạo mong muốn cho x1,x2,x4,x5 (có thể sửa từ TB khi cần)
    parameter logic [N-1:0] X1_INIT = 32'h00000010, // 16
    parameter logic [N-1:0] X2_INIT = 32'h00000020, // 32
    parameter logic [N-1:0] X4_INIT = 32'h00000040, // 64
    parameter logic [N-1:0] X5_INIT = 32'h00000050  // 80
)(
    input  logic i_clk,
    input  logic i_arst_n,
    input  logic i_we,     // write enable

    input  logic [$clog2(DEPTH) - 1:0] i_raddr1, i_raddr2, i_waddr, // rs1,rs2,rd
    input  logic [N-1:0]               i_wdata,
    output logic [N-1:0]               o_rdata1, o_rdata2
);

    // Data flops do not need individual reset pins.  A small validity bitmap
    // supplies the architectural reset view until each register is written.
    // Besides reducing reset fanout, this makes the storage array compatible
    // with implementations whose memory bits have no hardware reset.
    logic [N-1:0] storage [0:DEPTH - 1];
    logic [DEPTH-1:0] valid_q;

    // Keep this architectural view as an array so verification code can still
    // inspect id_regfile.regs[x] without observing uninitialized storage bits.
    wire [N-1:0] regs [0:DEPTH - 1];

    genvar reg_index;
    generate
        for (reg_index = 0; reg_index < DEPTH; reg_index = reg_index + 1) begin : gen_reg_view
            if (reg_index == 0) begin : gen_x0
                assign regs[reg_index] = '0;
            end else if (reg_index == 1) begin : gen_x1
                assign regs[reg_index] = valid_q[reg_index] ? storage[reg_index]
                                                             : X1_INIT;
            end else if (reg_index == 2) begin : gen_x2
                assign regs[reg_index] = valid_q[reg_index] ? storage[reg_index]
                                                             : X2_INIT;
            end else if (reg_index == 4) begin : gen_x4
                assign regs[reg_index] = valid_q[reg_index] ? storage[reg_index]
                                                             : X4_INIT;
            end else if (reg_index == 5) begin : gen_x5
                assign regs[reg_index] = valid_q[reg_index] ? storage[reg_index]
                                                             : X5_INIT;
            end else begin : gen_zero_init
                assign regs[reg_index] = valid_q[reg_index] ? storage[reg_index]
                                                             : '0;
            end
        end
    endgenerate

    // The data array has no reset.  Only written words become observable.
    always_ff @(posedge i_clk) begin
        if (i_we && (i_waddr != '0))
            storage[i_waddr] <= i_wdata;
    end

    always_ff @(posedge i_clk or negedge i_arst_n) begin
        if (!i_arst_n)
            valid_q <= '0;
        else if (i_we && (i_waddr != '0))
            valid_q[i_waddr] <= 1'b1;
    end

    // Asynchronous reads with same-cycle WB-to-ID bypass. Without this
    // write-through path, an instruction entering ID on the same edge that WB
    // updates one of its source registers can latch the previous value. Once
    // that instruction reaches EX, the WB value is no longer available to the
    // normal forwarding network.
    assign o_rdata1 = (i_raddr1 == '0) ? '0 :
                      ((i_we && (i_waddr == i_raddr1) && (i_waddr != '0)) ?
                       i_wdata : regs[i_raddr1]);
    assign o_rdata2 = (i_raddr2 == '0) ? '0 :
                      ((i_we && (i_waddr == i_raddr2) && (i_waddr != '0)) ?
                       i_wdata : regs[i_raddr2]);

endmodule
