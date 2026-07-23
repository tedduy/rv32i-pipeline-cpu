// Public CPU top-level with separate instruction and data AHB-Lite masters.
module tdrv32_top #(
    parameter N = 32,
    parameter REG_DEPTH = 32,
    parameter logic [N-1:0] RESET_VECTOR = '0,
    parameter logic [N-1:0] MVENDOR_ID = '0,
    parameter logic [N-1:0] MARCH_ID = '0,
    parameter logic [N-1:0] MIMP_ID = '0,
    parameter logic [N-1:0] HART_ID = '0,
    parameter logic [N-1:0] CONFIG_PTR = '0
)(
    input  logic i_clk,
    input  logic i_arst_n,

    input  logic i_irq_software,
    input  logic i_irq_timer,
    input  logic i_irq_external,
    input  logic [63:0] i_time,

    output logic o_core_sleep,
    output logic o_fence_i,

    // Instruction AHB-Lite master
    output logic [N-1:0] o_iahb_haddr,
    output logic [1:0]   o_iahb_htrans,
    output logic         o_iahb_hwrite,
    output logic [2:0]   o_iahb_hsize,
    output logic [2:0]   o_iahb_hburst,
    output logic [3:0]   o_iahb_hprot,
    output logic         o_iahb_hmastlock,
    output logic [N-1:0] o_iahb_hwdata,
    input  logic [N-1:0] i_iahb_hrdata,
    input  logic         i_iahb_hready,
    input  logic         i_iahb_hresp,

    // Data AHB-Lite master
    output logic [N-1:0] o_dahb_haddr,
    output logic [1:0]   o_dahb_htrans,
    output logic         o_dahb_hwrite,
    output logic [2:0]   o_dahb_hsize,
    output logic [2:0]   o_dahb_hburst,
    output logic [3:0]   o_dahb_hprot,
    output logic         o_dahb_hmastlock,
    output logic [N-1:0] o_dahb_hwdata,
    input  logic [N-1:0] i_dahb_hrdata,
    input  logic         i_dahb_hready,
    input  logic         i_dahb_hresp,

    output logic         o_commit_valid,
    output logic [N-1:0] o_commit_pc,
    output logic [N-1:0] o_commit_instruction,
    output logic         o_commit_rd_write,
    output logic [4:0]   o_commit_rd_addr,
    output logic [N-1:0] o_commit_rd_data,
    output logic         o_commit_mem_write,
    output logic [N-1:0] o_commit_mem_addr,
    output logic [N-1:0] o_commit_mem_wdata,
    output logic [3:0]   o_commit_mem_wstrb
);

    logic         imem_valid, imem_ready, imem_error;
    logic [N-1:0] imem_addr, imem_rdata;
    logic         dmem_valid, dmem_read, dmem_write, dmem_ready, dmem_error;
    logic [N-1:0] dmem_addr, dmem_wdata, dmem_rdata;
    logic [3:0]   dmem_wstrb;
    logic [1:0]   dmem_size;
    logic         core_sleep, iahb_busy, dahb_busy;

    core_sleep_gate u_sleep_gate (
        .i_core_sleep(core_sleep),
        .i_instruction_busy(iahb_busy),
        .i_data_busy(dahb_busy),
        .o_core_sleep(o_core_sleep)
    );

    tdrv32_core #(
        .N(N),
        .REG_DEPTH(REG_DEPTH),
        .RESET_VECTOR(RESET_VECTOR),
        .MVENDOR_ID(MVENDOR_ID),
        .MARCH_ID(MARCH_ID),
        .MIMP_ID(MIMP_ID),
        .HART_ID(HART_ID),
        .CONFIG_PTR(CONFIG_PTR)
    ) u_core (
        .i_clk(i_clk),
        .i_arst_n(i_arst_n),
        .i_irq_software(i_irq_software),
        .i_irq_timer(i_irq_timer),
        .i_irq_external(i_irq_external),
        .i_time(i_time),
        .o_core_sleep(core_sleep),
        .o_fence_i(o_fence_i),
        .o_imem_valid(imem_valid),
        .o_imem_addr(imem_addr),
        .i_imem_rdata(imem_rdata),
        .i_imem_ready(imem_ready),
        .i_imem_error(imem_error),
        .o_dmem_valid(dmem_valid),
        .o_dmem_read(dmem_read),
        .o_dmem_write(dmem_write),
        .o_dmem_addr(dmem_addr),
        .o_dmem_wdata(dmem_wdata),
        .o_dmem_wstrb(dmem_wstrb),
        .o_dmem_size(dmem_size),
        .i_dmem_rdata(dmem_rdata),
        .i_dmem_ready(dmem_ready),
        .i_dmem_error(dmem_error),
        .o_commit_valid(o_commit_valid),
        .o_commit_pc(o_commit_pc),
        .o_commit_instruction(o_commit_instruction),
        .o_commit_rd_write(o_commit_rd_write),
        .o_commit_rd_addr(o_commit_rd_addr),
        .o_commit_rd_data(o_commit_rd_data),
        .o_commit_mem_write(o_commit_mem_write),
        .o_commit_mem_addr(o_commit_mem_addr),
        .o_commit_mem_wdata(o_commit_mem_wdata),
        .o_commit_mem_wstrb(o_commit_mem_wstrb),
        .o_debug_pc(), .o_debug_instruction(), .o_debug_rs1_data(), .o_debug_rs2_data(), .o_debug_alu_operand_b(), .o_debug_branch_target(),
        .o_debug_alu_result(), .o_debug_wb_data(), .o_debug_rd_addr(), .o_debug_rd_write(),
        .o_debug_mem_write(), .o_debug_mem_read(), .o_debug_branch_taken(), .o_debug_mem_addr(),
        .o_debug_mem_wdata(), .o_debug_mem_rdata(), .o_debug_jal(), .o_debug_jalr(), .o_debug_stall(),
        .o_debug_flush(), .o_debug_immediate(), .o_debug_alu_uses_immediate()
    );

    native_to_ahb_lite #(
        .N(N),
        .HPROT_VALUE(4'b0010) // privileged instruction access
    ) u_instruction_ahb (
        .i_clk(i_clk),
        .i_arst_n(i_arst_n),
        .i_native_valid(imem_valid),
        .i_native_write(1'b0),
        .i_native_addr(imem_addr),
        .i_native_wdata('0),
        .i_native_size(2'd2),
        .o_native_rdata(imem_rdata),
        .o_native_ready(imem_ready),
        .o_native_error(imem_error),
        .o_busy(iahb_busy),
        .o_haddr(o_iahb_haddr),
        .o_htrans(o_iahb_htrans),
        .o_hwrite(o_iahb_hwrite),
        .o_hsize(o_iahb_hsize),
        .o_hburst(o_iahb_hburst),
        .o_hprot(o_iahb_hprot),
        .o_hmastlock(o_iahb_hmastlock),
        .o_hwdata(o_iahb_hwdata),
        .i_hrdata(i_iahb_hrdata),
        .i_hready(i_iahb_hready),
        .i_hresp(i_iahb_hresp)
    );

    native_to_ahb_lite #(
        .N(N),
        .HPROT_VALUE(4'b0011) // privileged data access
    ) u_data_ahb (
        .i_clk(i_clk),
        .i_arst_n(i_arst_n),
        .i_native_valid(dmem_valid),
        .i_native_write(dmem_write),
        .i_native_addr(dmem_addr),
        .i_native_wdata(dmem_wdata),
        .i_native_size(dmem_size),
        .o_native_rdata(dmem_rdata),
        .o_native_ready(dmem_ready),
        .o_native_error(dmem_error),
        .o_busy(dahb_busy),
        .o_haddr(o_dahb_haddr),
        .o_htrans(o_dahb_htrans),
        .o_hwrite(o_dahb_hwrite),
        .o_hsize(o_dahb_hsize),
        .o_hburst(o_dahb_hburst),
        .o_hprot(o_dahb_hprot),
        .o_hmastlock(o_dahb_hmastlock),
        .o_hwdata(o_dahb_hwdata),
        .i_hrdata(i_dahb_hrdata),
        .i_hready(i_dahb_hready),
        .i_hresp(i_dahb_hresp)
    );

endmodule
