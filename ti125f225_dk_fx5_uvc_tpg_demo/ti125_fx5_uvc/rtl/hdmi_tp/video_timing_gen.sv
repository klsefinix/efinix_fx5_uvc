// ============================================================================
// video_timing_gen.sv
// Raster timing generator. Syncs are generated active-high here; polarity
// is applied at the top-level output register.
// VS edges are aligned to the HS leading edge (CEA-861 progressive).
// ============================================================================
module video_timing_gen #(
    parameter int H_ACTIVE = 1920,
    parameter int H_FP     = 88,
    parameter int H_SYNC   = 44,
    parameter int H_BP     = 148,
    parameter int V_ACTIVE = 1080,
    parameter int V_FP     = 4,
    parameter int V_SYNC   = 5,
    parameter int V_BP     = 36
)(
    input  logic        clk,
    input  logic        rst,
    output logic [11:0] o_x,          // = horizontal count (valid while o_de)
    output logic [11:0] o_y,          // = vertical count   (valid while o_de)
    output logic        o_de,
    output logic        o_hs,
    output logic        o_vs,
    output logic        o_vblank_start // 1-clk pulse at first blanking line
);
    localparam int H_TOTAL  = H_ACTIVE + H_FP + H_SYNC + H_BP;
    localparam int V_TOTAL  = V_ACTIVE + V_FP + V_SYNC + V_BP;
    localparam int HS_START = H_ACTIVE + H_FP;
    localparam int HS_END   = HS_START + H_SYNC;
    localparam int VS_START = V_ACTIVE + V_FP;
    localparam int VS_END   = VS_START + V_SYNC;

    logic [11:0] h, v;

    always_ff @(posedge clk) begin
        if (rst) begin
            h <= '0; v <= '0;
            o_x <= '0; o_y <= '0;
            o_de <= 1'b0; o_hs <= 1'b0; o_vs <= 1'b0;
            o_vblank_start <= 1'b0;
        end else begin
            if (h == 12'(H_TOTAL - 1)) begin
                h <= '0;
                v <= (v == 12'(V_TOTAL - 1)) ? 12'd0 : v + 12'd1;
            end else begin
                h <= h + 12'd1;
            end

            o_x  <= h;
            o_y  <= v;
            o_de <= (h < 12'(H_ACTIVE)) && (v < 12'(V_ACTIVE));
            o_hs <= (h >= 12'(HS_START)) && (h < 12'(HS_END));
            if (h == 12'(HS_START))
                o_vs <= (v >= 12'(VS_START)) && (v < 12'(VS_END));
            o_vblank_start <= (h == 12'd0) && (v == 12'(V_ACTIVE));
        end
    end
endmodule
