module csr_file #(
    parameter N = 32,
    parameter logic [N-1:0] MVENDOR_ID = '0,
    parameter logic [N-1:0] MARCH_ID = '0,
    parameter logic [N-1:0] MIMP_ID = '0,
    parameter logic [N-1:0] HART_ID = '0,
    parameter logic [N-1:0] CONFIG_PTR = '0
)(
    input  logic             i_clk,
    input  logic             i_arst_n,

    input  logic [11:0]      i_csr_addr,
    output logic [N-1:0]     o_csr_rdata,
    output logic             o_csr_valid,
    output logic             o_csr_writable,
    input  logic             i_csr_write,
    input  logic [N-1:0]     i_csr_wdata,

    input  logic             i_trap_enter,
    input  logic [N-1:0]     i_trap_pc,
    input  logic [N-1:0]     i_trap_cause,
    input  logic [N-1:0]     i_trap_value,
    input  logic             i_mret,
    input  logic             i_retire,
    // Platform timebase, normally supplied by the SoC timer/RTC domain.
    input  logic [63:0]      i_time,

    input  logic             i_irq_software,
    input  logic             i_irq_timer,
    input  logic             i_irq_external,

    output logic [N-1:0]     o_mtvec,
    output logic [N-1:0]     o_mepc,
    output logic             o_irq_pending,
    output logic             o_wake_pending,
    output logic [N-1:0]     o_irq_cause
);

    localparam logic [11:0] CSR_MSTATUS  = 12'h300;
    localparam logic [11:0] CSR_MSTATUSH = 12'h310;
    localparam logic [11:0] CSR_MISA     = 12'h301;
    localparam logic [11:0] CSR_MIE      = 12'h304;
    localparam logic [11:0] CSR_MTVEC    = 12'h305;
    localparam logic [11:0] CSR_MCOUNTINHIBIT = 12'h320;
    localparam logic [11:0] CSR_MHPMEVENT3 = 12'h323;
    localparam logic [11:0] CSR_MHPMEVENT31 = 12'h33F;
    localparam logic [11:0] CSR_MSCRATCH = 12'h340;
    localparam logic [11:0] CSR_MEPC     = 12'h341;
    localparam logic [11:0] CSR_MCAUSE   = 12'h342;
    localparam logic [11:0] CSR_MTVAL    = 12'h343;
    localparam logic [11:0] CSR_MIP      = 12'h344;
    localparam logic [11:0] CSR_MCYCLE   = 12'hB00;
    localparam logic [11:0] CSR_MINSTRET = 12'hB02;
    localparam logic [11:0] CSR_MCYCLEH  = 12'hB80;
    localparam logic [11:0] CSR_MINSTRETH = 12'hB82;
    localparam logic [11:0] CSR_CYCLE    = 12'hC00;
    localparam logic [11:0] CSR_TIME     = 12'hC01;
    localparam logic [11:0] CSR_INSTRET  = 12'hC02;
    localparam logic [11:0] CSR_CYCLEH   = 12'hC80;
    localparam logic [11:0] CSR_TIMEH    = 12'hC81;
    localparam logic [11:0] CSR_INSTRETH = 12'hC82;
    localparam logic [11:0] CSR_MVENDORID = 12'hF11;
    localparam logic [11:0] CSR_MARCHID   = 12'hF12;
    localparam logic [11:0] CSR_MIMPID    = 12'hF13;
    localparam logic [11:0] CSR_MHARTID   = 12'hF14;
    localparam logic [11:0] CSR_MCONFIGPTR = 12'hF15;

    // RV32 (MXL=1) with I, M and C. Zicsr is not represented in misa because
    // only single-letter extensions appear there.
    localparam logic [N-1:0] MISA_VALUE = 32'h4000_1104;

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
    logic [N-1:0]     mcountinhibit;

    assign o_mtvec = mtvec;
    assign o_mepc  = mepc;

    always_comb begin
        mip = '0;
        mip[3]  = i_irq_software;
        mip[7]  = i_irq_timer;
        mip[11] = i_irq_external;

        o_irq_pending = 1'b0;
        o_wake_pending = (mie[11] && i_irq_external) ||
                         (mie[3]  && i_irq_software) ||
                         (mie[7]  && i_irq_timer);
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
        o_csr_valid = 1'b1;
        o_csr_writable = 1'b1;
        unique case (i_csr_addr)
            CSR_MSTATUS:   o_csr_rdata = {{(N-13){1'b0}}, 2'b11, 3'b000,
                                          mstatus_mpie, 3'b000, mstatus_mie, 3'b000};
            // mstatush exists on RV32. This little-endian RV32I core does not
            // implement any of its optional fields, so all bits are WARL zero.
            // Writes are nevertheless legal and are ignored.
            CSR_MSTATUSH:  o_csr_rdata = '0;
            // misa is at a read/write CSR address, but every implemented field
            // is immutable in this core. Writes are legal and have no effect.
            CSR_MISA:      o_csr_rdata = MISA_VALUE;
            CSR_MIE:       o_csr_rdata = mie;
            CSR_MTVEC:     o_csr_rdata = mtvec;
            CSR_MCOUNTINHIBIT: o_csr_rdata = mcountinhibit;
            CSR_MSCRATCH:  o_csr_rdata = mscratch;
            CSR_MEPC:      o_csr_rdata = mepc;
            CSR_MCAUSE:    o_csr_rdata = mcause;
            CSR_MTVAL:     o_csr_rdata = mtval;
            CSR_MIP: begin
                o_csr_rdata = mip;
                // Pending bits are driven by pins. Writes remain legal because
                // mip is not in the architecturally read-only CSR address range.
            end
            CSR_MCYCLE:    o_csr_rdata = mcycle[31:0];
            CSR_MINSTRET:  o_csr_rdata = minstret[31:0];
            CSR_MCYCLEH:   o_csr_rdata = mcycle[63:32];
            CSR_MINSTRETH: o_csr_rdata = minstret[63:32];
            // Zicntr unprivileged shadows are architecturally read-only, even
            // when accessed from machine mode.
            CSR_CYCLE: begin
                o_csr_rdata = mcycle[31:0];
                o_csr_writable = 1'b0;
            end
            CSR_TIME: begin
                o_csr_rdata = i_time[31:0];
                o_csr_writable = 1'b0;
            end
            CSR_INSTRET: begin
                o_csr_rdata = minstret[31:0];
                o_csr_writable = 1'b0;
            end
            CSR_CYCLEH: begin
                o_csr_rdata = mcycle[63:32];
                o_csr_writable = 1'b0;
            end
            CSR_TIMEH: begin
                o_csr_rdata = i_time[63:32];
                o_csr_writable = 1'b0;
            end
            CSR_INSTRETH: begin
                o_csr_rdata = minstret[63:32];
                o_csr_writable = 1'b0;
            end
            CSR_MVENDORID: begin
                o_csr_rdata = MVENDOR_ID;
                o_csr_writable = 1'b0;
            end
            CSR_MARCHID: begin
                o_csr_rdata = MARCH_ID;
                o_csr_writable = 1'b0;
            end
            CSR_MIMPID: begin
                o_csr_rdata = MIMP_ID;
                o_csr_writable = 1'b0;
            end
            CSR_MHARTID: begin
                o_csr_rdata = HART_ID;
                o_csr_writable = 1'b0;
            end
            CSR_MCONFIGPTR: begin
                o_csr_rdata = CONFIG_PTR;
                o_csr_writable = 1'b0;
            end
            default: begin
                if ((i_csr_addr >= CSR_MHPMEVENT3) &&
                    (i_csr_addr <= CSR_MHPMEVENT31)) begin
                    // Unimplemented HPM event selectors are legal WARL-zero
                    // CSRs. This lets generic machine-mode software disable
                    // them without pretending that HPM counters exist.
                    o_csr_rdata = '0;
                end else begin
                    o_csr_rdata = '0;
                    o_csr_valid = 1'b0;
                    o_csr_writable = 1'b0;
                end
            end
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
            mcountinhibit <= '0;
        end else begin
            if (i_trap_enter) begin
                mepc         <= {i_trap_pc[N-1:1], 1'b0};
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
                    CSR_MCOUNTINHIBIT: mcountinhibit <= i_csr_wdata &
                                                          {{(N-3){1'b0}}, 3'b101};
                    CSR_MSCRATCH:  mscratch          <= i_csr_wdata;
                    CSR_MEPC:      mepc              <= {i_csr_wdata[N-1:1], 1'b0};
                    CSR_MCAUSE:    mcause            <= i_csr_wdata;
                    CSR_MTVAL:     mtval             <= i_csr_wdata;
                    default: begin end
                endcase
            end
        end
    end

    // Counters are independent of trap-state updates.  Keeping them in a
    // separate sequential process prevents the trap/mret priority mux from
    // becoming part of every mcycle/minstret D path.  The core qualifies
    // i_csr_write so it is never asserted on a trap-taking cycle; explicit
    // counter writes retain priority over automatic increments.
    always_ff @(posedge i_clk or negedge i_arst_n) begin
        if (!i_arst_n) begin
            mcycle   <= '0;
            minstret <= '0;
        end else begin
            if (!mcountinhibit[0])
                mcycle <= mcycle + 64'd1;
            if (i_retire && !mcountinhibit[2])
                minstret <= minstret + 64'd1;

            if (i_csr_write) begin
                unique case (i_csr_addr)
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
