// Converts one blocking native valid/ready request stream into an AHB-Lite
// master. Transfers are deliberately non-pipelined: one address phase is
// followed by its data/response phase before the next request starts.
module native_to_ahb_lite #(
    parameter N = 32,
    parameter logic [3:0] HPROT_VALUE = 4'b0011
)(
    input  logic         i_clk,
    input  logic         i_arst_n,

    input  logic         i_native_valid,
    input  logic         i_native_write,
    input  logic [N-1:0] i_native_addr,
    input  logic [N-1:0] i_native_wdata,
    input  logic [1:0]   i_native_size,
    output logic [N-1:0] o_native_rdata,
    output logic         o_native_ready,
    output logic         o_native_error,
    output logic         o_busy,

    output logic [N-1:0] o_haddr,
    output logic [1:0]   o_htrans,
    output logic         o_hwrite,
    output logic [2:0]   o_hsize,
    output logic [2:0]   o_hburst,
    output logic [3:0]   o_hprot,
    output logic         o_hmastlock,
    output logic [N-1:0] o_hwdata,
    input  logic [N-1:0] i_hrdata,
    input  logic         i_hready,
    input  logic         i_hresp
);

    typedef enum logic {ADDR_PHASE, DATA_PHASE} state_t;
    state_t state_q;

    logic [N-1:0] request_addr_q;
    logic [N-1:0] request_wdata_q;

    assign o_hburst    = 3'b000; // SINGLE
    assign o_hprot     = HPROT_VALUE;
    assign o_hmastlock = 1'b0;
    assign o_busy       = (state_q == DATA_PHASE);

    always_comb begin
        o_haddr   = request_addr_q;
        o_hwdata  = request_wdata_q;
        o_hwrite  = 1'b0;
        o_hsize   = 3'b010;
        o_htrans  = 2'b00; // IDLE

        if (state_q == ADDR_PHASE) begin
            o_haddr  = i_native_addr;
            o_hwrite = i_native_write;
            o_hsize  = {1'b0, i_native_size};
            o_htrans = i_native_valid ? 2'b10 : 2'b00; // NONSEQ/IDLE
        end else begin
            // Address/control for the completed transfer were accepted in the
            // previous phase. HWDATA belongs to that transfer in this phase.
            o_hwdata = request_wdata_q;
        end

        o_native_rdata = i_hrdata;
        o_native_ready = (state_q == DATA_PHASE) && i_hready;
        o_native_error = o_native_ready && i_hresp;
    end

    always_ff @(posedge i_clk or negedge i_arst_n) begin
        if (!i_arst_n) begin
            state_q         <= ADDR_PHASE;
            request_addr_q  <= '0;
            request_wdata_q <= '0;
        end else begin
            unique case (state_q)
                ADDR_PHASE: begin
                    if (i_native_valid && i_hready) begin
                        request_addr_q  <= i_native_addr;
                        request_wdata_q <= i_native_wdata;
                        state_q         <= DATA_PHASE;
                    end
                end
                DATA_PHASE: begin
                    if (i_hready)
                        state_q <= ADDR_PHASE;
                end
                // Defensive recovery for an invalid encoded FSM state.
                /* verilator coverage_off */
                default: state_q <= ADDR_PHASE;
                /* verilator coverage_on */
            endcase
        end
    end

endmodule
