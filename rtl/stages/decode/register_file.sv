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

    integer i;
    logic [N-1:0] regs [0:DEPTH - 1];

    // Không dùng initial để ghi regs, tránh xung đột với always_ff
    always_ff @(posedge i_clk or negedge i_arst_n) begin
        if (!i_arst_n) begin
            // Clear tất cả
            for (i = 0; i < DEPTH; i = i + 1) begin
                regs[i] <= '0;
            end
            // Đặt mặc định mong muốn
            if (DEPTH > 1) regs[1] <= X1_INIT; // x1
            if (DEPTH > 2) regs[2] <= X2_INIT; // x2
            if (DEPTH > 4) regs[4] <= X4_INIT; // x4
            if (DEPTH > 5) regs[5] <= X5_INIT; // x5
        end
        else begin
            // Ghi đồng bộ, không cho ghi x0
            if (i_we && (i_waddr != '0)) begin
                regs[i_waddr] <= i_wdata;
            end
        end
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
