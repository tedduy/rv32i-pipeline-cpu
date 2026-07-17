module data_memory #(
  parameter N      = 32,
  parameter BYTES  = 256        // dung lượng RAM theo byte (đặt >= 0xA8 cho test của bạn)
)(
  input  logic         i_clk,
  input  logic         i_arst_n,
  input  logic         i_we,        // write enable
  input  logic         i_re,        // read enable
  input  logic [N-1:0] i_addr,      // địa chỉ byte
  input  logic [N-1:0] i_wdata,     // dữ liệu ghi 32-bit (LSU đã sắp xếp little-endian)
  input  logic  [3:0]  i_wstrb,     // byte-enable: SB/SH/SW từ LSU
  output logic [N-1:0] o_rdata      // dữ liệu đọc 32-bit thô (LSU sẽ chọn byte/half & extend)
);

  // Byte-addressed memory (little-endian)
  logic [7:0] mem [0:BYTES-1];

  // Căn word-aligned khi đọc (đọc luôn 4 byte bắt đầu từ addr&~3)
  wire [N-1:0] addr_a = { i_addr[N-1:2], 2'b00 };

  integer i;
  always_ff @(posedge i_clk or negedge i_arst_n) begin
    if (!i_arst_n) begin
      for (i = 0; i < BYTES; i++) mem[i] <= '0;
    end else if (i_we) begin
      // ghi theo byte-enable
      if (i_wstrb[0]) mem[i_addr + 0] <= i_wdata[7:0];
      if (i_wstrb[1]) mem[i_addr + 1] <= i_wdata[15:8];
      if (i_wstrb[2]) mem[i_addr + 2] <= i_wdata[23:16];
      if (i_wstrb[3]) mem[i_addr + 3] <= i_wdata[31:24];
    end
  end

  // đọc word 32-bit (thô); LSU sẽ xử lý tiếp theo mem_addr[1:0] & mem_type
  always_comb begin
    o_rdata = '0;
    if (i_re) begin
      o_rdata = { mem[addr_a + 3],
                  mem[addr_a + 2],
                  mem[addr_a + 1],
                  mem[addr_a + 0] };
    end
  end
endmodule
