module csr_file #(
    parameter N = 32
)(
    input  logic             i_clk,
    input  logic             i_arst_n,

    input  logic [11:0]      i_csr_addr,
    output logic [N-1:0]     o_csr_rdata,
    input  logic             i_csr_write,
    input  logic [N-1:0]     i_csr_wdata,

    input  logic             i_trap_enter,
    input  logic [N-1:0]     i_trap_pc,
    input  logic [N-1:0]     i_trap_cause,
    input  logic [N-1:0]     i_trap_value,
    input  logic             i_mret,
    input  logic             i_retire,

    input  logic             i_irq_software,
    input  logic             i_irq_timer,
    input  logic             i_irq_external,

    output logic [N-1:0]     o_mtvec,
    output logic [N-1:0]     o_mepc,
    output logic             o_irq_pending,
    output logic [N-1:0]     o_irq_cause
);

    localparam logic [11:0] CSR_MSTATUS  = 12'h300;
    localparam logic [11:0] CSR_MIE      = 12'h304;
    localparam logic [11:0] CSR_MTVEC    = 12'h305;
    localparam logic [11:0] CSR_MSCRATCH = 12'h340;
    localparam logic [11:0] CSR_MEPC     = 12'h341;
    localparam logic [11:0] CSR_MCAUSE   = 12'h342;
    localparam logic [11:0] CSR_MTVAL    = 12'h343;
    localparam logic [11:0] CSR_MIP      = 12'h344;
    localparam logic [11:0] CSR_MCYCLE   = 12'hB00;
    localparam logic [11:0] CSR_MINSTRET = 12'hB02;
    localparam logic [11:0] CSR_MCYCLEH  = 12'hB80;
    localparam logic [11:0] CSR_MINSTRETH = 12'hB82;

    logic             mstatus_mie;
    logic             mstatus_mpie;
    logic [N-1:0]     mie;
    logic [N-1:0]     mip;
    logic [N-1:0]     mtvec;
    logic [N-1:0]     mscratch;
    logic [N-1:0]     mepc;
    logic [N-1:0]     mcause;
    logic [N-1:0]     mtval;
    logic [63:0]      mcycle;
    logic [63:0]      minstret;

    assign o_mtvec = mtvec;
    assign o_mepc  = mepc;

    always_comb begin
        mip = '0;
        mip[3]  = i_irq_software;
        mip[7]  = i_irq_timer;
        mip[11] = i_irq_external;

        o_irq_pending = 1'b0;
        o_irq_cause   = '0;
        if (mstatus_mie && mie[11] && i_irq_external) begin
            o_irq_pending = 1'b1;
            o_irq_cause   = {1'b1, {(N-5){1'b0}}, 4'd11};
        end else if (mstatus_mie && mie[3] && i_irq_software) begin
            o_irq_pending = 1'b1;
            o_irq_cause   = {1'b1, {(N-3){1'b0}}, 2'd3};
        end else if (mstatus_mie && mie[7] && i_irq_timer) begin
            o_irq_pending = 1'b1;
            o_irq_cause   = {1'b1, {(N-4){1'b0}}, 3'd7};
        end
    end

    always_comb begin
        o_csr_rdata = '0;
        unique case (i_csr_addr)
            CSR_MSTATUS:   o_csr_rdata = {{(N-13){1'b0}}, 2'b11, 3'b000,
                                          mstatus_mpie, 3'b000, mstatus_mie, 3'b000};
            CSR_MIE:       o_csr_rdata = mie;
            CSR_MTVEC:     o_csr_rdata = mtvec;
            CSR_MSCRATCH:  o_csr_rdata = mscratch;
            CSR_MEPC:      o_csr_rdata = mepc;
            CSR_MCAUSE:    o_csr_rdata = mcause;
            CSR_MTVAL:     o_csr_rdata = mtval;
            CSR_MIP:       o_csr_rdata = mip;
            CSR_MCYCLE:    o_csr_rdata = mcycle[31:0];
            CSR_MINSTRET:  o_csr_rdata = minstret[31:0];
            CSR_MCYCLEH:   o_csr_rdata = mcycle[63:32];
            CSR_MINSTRETH: o_csr_rdata = minstret[63:32];
            default:       o_csr_rdata = '0;
        endcase
    end

    always_ff @(posedge i_clk or negedge i_arst_n) begin
        if (!i_arst_n) begin
            mstatus_mie  <= 1'b0;
            mstatus_mpie <= 1'b0;
            mie          <= '0;
            mtvec        <= '0;
            mscratch     <= '0;
            mepc         <= '0;
            mcause       <= '0;
            mtval        <= '0;
            mcycle       <= '0;
            minstret     <= '0;
        end else begin
            mcycle <= mcycle + 64'd1;
            if (i_retire)
                minstret <= minstret + 64'd1;

            if (i_trap_enter) begin
                mepc         <= {i_trap_pc[N-1:2], 2'b00};
                mcause       <= i_trap_cause;
                mtval        <= i_trap_value;
                mstatus_mpie <= mstatus_mie;
                mstatus_mie  <= 1'b0;
            end else if (i_mret) begin
                mstatus_mie  <= mstatus_mpie;
                mstatus_mpie <= 1'b1;
            end else if (i_csr_write) begin
                unique case (i_csr_addr)
                    CSR_MSTATUS: begin
                        mstatus_mie  <= i_csr_wdata[3];
                        mstatus_mpie <= i_csr_wdata[7];
                    end
                    CSR_MIE:       mie               <= i_csr_wdata &
                                                          {{(N-12){1'b0}}, 12'h888};
                    CSR_MTVEC:     mtvec             <= {i_csr_wdata[N-1:2], 2'b00};
                    CSR_MSCRATCH:  mscratch          <= i_csr_wdata;
                    CSR_MEPC:      mepc              <= {i_csr_wdata[N-1:2], 2'b00};
                    CSR_MCAUSE:    mcause            <= i_csr_wdata;
                    CSR_MTVAL:     mtval             <= i_csr_wdata;
                    CSR_MCYCLE:    mcycle[31:0]       <= i_csr_wdata;
                    CSR_MINSTRET:  minstret[31:0]     <= i_csr_wdata;
                    CSR_MCYCLEH:   mcycle[63:32]      <= i_csr_wdata;
                    CSR_MINSTRETH: minstret[63:32]    <= i_csr_wdata;
                    default: begin end
                endcase
            end
        end
    end

endmodule
