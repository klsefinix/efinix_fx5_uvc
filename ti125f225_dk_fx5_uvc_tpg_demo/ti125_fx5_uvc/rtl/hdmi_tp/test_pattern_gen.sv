// ============================================================================
// test_pattern_gen.sv
// Resolution-independent test patterns (everything scales from H/V_ACTIVE).
// 3-stage pipeline; syncs are delayed to match.
//
//  0  Colour bars      top 2/3 75 %, bottom 1/3 100 %  (W Y C G M R B K)
//  1  Grey ramp        top half smooth 0..255, bottom half 16 steps
//  2  RGBW ramps       four horizontal bands: R, G, B, White ramps
//  3  Grid             white 1-px border, grid every H/16 px, red centre cross
//  4  Checkerboard     1-px black/white (maximum data toggle rate)
//  5  Chroma sweep     direct YCbCr: top Cb sweep, bottom Cr sweep (Y = 128)
//  6  Motion           colour bars scrolling left, proves frames are live
//  7  Solid cycle      full-screen W Y C G M R B K, ~64 frames each
//
// Pattern 5 bypasses the RGB->YCbCr converter (o_ycc_byp = 1) so it drives
// the chroma bus directly; a bad chroma data line shows as a step or
// discontinuity in the sweep.
// ============================================================================
module test_pattern_gen #(
    parameter int H_ACTIVE = 1920,
    parameter int V_ACTIVE = 1080
)(
    input  logic        clk,
    input  logic        rst,
    input  logic [2:0]  i_pattern,
    input  logic [15:0] i_frame_cnt,
    input  logic [11:0] i_x,
    input  logic [11:0] i_y,
    input  logic        i_de,
    input  logic        i_hs,
    input  logic        i_vs,

    output logic        o_de,
    output logic        o_hs,
    output logic        o_vs,
    output logic [7:0]  o_r,
    output logic [7:0]  o_g,
    output logic [7:0]  o_b,
    output logic        o_ycc_byp,
    output logic [7:0]  o_y,
    output logic [7:0]  o_cb,
    output logic [7:0]  o_cr
);
    // ---------------- constants ----------------
    localparam int GRID   = (H_ACTIVE / 16 < 2) ? 2 : H_ACTIVE / 16;
    localparam int KR     = (256 * 65536) / H_ACTIVE;   // x -> 0..255
    localparam int KC     = (112 * 65536) / H_ACTIVE;   // x -> 0..111
    localparam int SCROLL = (H_ACTIVE >= 1280) ? 4 : 1; // px per frame
    localparam int B1 = H_ACTIVE * 1 / 8, B2 = H_ACTIVE * 2 / 8, B3 = H_ACTIVE * 3 / 8;
    localparam int B4 = H_ACTIVE * 4 / 8, B5 = H_ACTIVE * 5 / 8, B6 = H_ACTIVE * 6 / 8;
    localparam int B7 = H_ACTIVE * 7 / 8;

    localparam logic [2:0] P_BARS = 3'd0, P_GRAY = 3'd1, P_RGBW = 3'd2, P_GRID = 3'd3,
                           P_CHK  = 3'd4, P_CHROMA = 3'd5, P_MOTION = 3'd6, P_SOLID = 3'd7;

    function automatic logic [2:0] bar_of(input logic [11:0] x);
        bar_of = 3'(x >= 12'(B1)) + 3'(x >= 12'(B2)) + 3'(x >= 12'(B3)) + 3'(x >= 12'(B4))
               + 3'(x >= 12'(B5)) + 3'(x >= 12'(B6)) + 3'(x >= 12'(B7));
    endfunction

    // bar index -> {R,G,B} on/off  (0 W, 1 Y, 2 C, 3 G, 4 M, 5 R, 6 B, 7 K)
    function automatic logic [2:0] bar_rgb(input logic [2:0] i);
        bar_rgb = {~i[1], ~i[2], ~i[0]};
    endfunction

    // ---------------- scroll offset (updates once per frame) ----------------
    logic [11:0] scroll_off;
    logic [15:0] frame_l;
    always_ff @(posedge clk) begin
        if (rst) begin
            scroll_off <= '0;
            frame_l    <= '0;
        end else begin
            frame_l <= i_frame_cnt;
            if (i_frame_cnt != frame_l)
                scroll_off <= (scroll_off + 12'(SCROLL) >= 12'(H_ACTIVE))
                            ? scroll_off + 12'(SCROLL) - 12'(H_ACTIVE)
                            : scroll_off + 12'(SCROLL);
        end
    end

    // ---------------- running counters (avoid dividers) ----------------
    logic [11:0] gx_nxt, gy_line, xm_nxt;
    logic [11:0] gx_cur, gy_cur, xm_cur;
    assign gx_cur = (i_x == 12'd0) ? 12'd0      : gx_nxt;
    assign gy_cur = (i_y == 12'd0) ? 12'd0      : gy_line;
    assign xm_cur = (i_x == 12'd0) ? scroll_off : xm_nxt;

    always_ff @(posedge clk) begin
        if (rst) begin
            gx_nxt <= '0; gy_line <= '0; xm_nxt <= '0;
        end else if (i_de) begin
            gx_nxt <= (gx_cur == 12'(GRID - 1))     ? 12'd0 : gx_cur + 12'd1;
            xm_nxt <= (xm_cur == 12'(H_ACTIVE - 1)) ? 12'd0 : xm_cur + 12'd1;
            if (i_x == 12'(H_ACTIVE - 1))
                gy_line <= (gy_cur == 12'(GRID - 1)) ? 12'd0 : gy_cur + 12'd1;
        end
    end

    // ---------------- stage A: coordinate-derived features ----------------
    logic        a_de, a_hs, a_vs;
    logic [2:0]  a_pat, a_bar, a_solid;
    logic [7:0]  a_ramp, a_cramp;
    logic [11:0] a_xm;
    logic        a_grid, a_border, a_center, a_chk;
    logic        a_bot_half, a_bot_third;
    logic [1:0]  a_band;

    logic [31:0] ramp_p, cramp_p;
    assign ramp_p  = 32'(i_x) * 32'(KR);
    assign cramp_p = 32'(i_x) * 32'(KC);

    always_ff @(posedge clk) begin
        if (rst) begin
            a_de <= 1'b0; a_hs <= 1'b0; a_vs <= 1'b0;
        end else begin
            a_de        <= i_de;
            a_hs        <= i_hs;
            a_vs        <= i_vs;
            a_pat       <= i_pattern;
            a_solid     <= i_frame_cnt[8:6];
            a_bar       <= bar_of(i_x);
            a_ramp      <= ramp_p[23:16];
            a_cramp     <= 8'd72 + cramp_p[23:16];
            a_xm        <= xm_cur;
            a_grid      <= (gx_cur == 12'd0) || (gy_cur == 12'd0);
            a_border    <= (i_x == 12'd0) || (i_x == 12'(H_ACTIVE - 1)) ||
                           (i_y == 12'd0) || (i_y == 12'(V_ACTIVE - 1));
            a_center    <= (i_x == 12'(H_ACTIVE / 2 - 1)) || (i_x == 12'(H_ACTIVE / 2)) ||
                           (i_y == 12'(V_ACTIVE / 2 - 1)) || (i_y == 12'(V_ACTIVE / 2));
            a_chk       <= i_x[0] ^ i_y[0];
            a_bot_half  <= (i_y >= 12'(V_ACTIVE / 2));
            a_bot_third <= (i_y >= 12'(V_ACTIVE * 2 / 3));
            a_band      <= (i_y >= 12'(V_ACTIVE * 3 / 4)) ? 2'd3 :
                           (i_y >= 12'(V_ACTIVE * 2 / 4)) ? 2'd2 :
                           (i_y >= 12'(V_ACTIVE * 1 / 4)) ? 2'd1 : 2'd0;
        end
    end

    // ---------------- stage B: scrolled bar index, delay the rest ----------------
    logic        b_de, b_hs, b_vs;
    logic [2:0]  b_pat, b_bar, b_mbar, b_solid;
    logic [7:0]  b_ramp, b_cramp;
    logic        b_grid, b_border, b_center, b_chk, b_bot_half, b_bot_third;
    logic [1:0]  b_band;

    always_ff @(posedge clk) begin
        if (rst) begin
            b_de <= 1'b0; b_hs <= 1'b0; b_vs <= 1'b0;
        end else begin
            b_de <= a_de; b_hs <= a_hs; b_vs <= a_vs;
            b_pat <= a_pat; b_bar <= a_bar; b_solid <= a_solid;
            b_mbar <= bar_of(a_xm);
            b_ramp <= a_ramp; b_cramp <= a_cramp;
            b_grid <= a_grid; b_border <= a_border; b_center <= a_center;
            b_chk <= a_chk; b_bot_half <= a_bot_half; b_bot_third <= a_bot_third;
            b_band <= a_band;
        end
    end

    // ---------------- stage C: colour select ----------------
    logic [7:0] r, g, b, yv, cbv, crv;
    logic       byp;
    logic [2:0] on;
    logic [7:0] lvl;

    always_comb begin
        r = 8'd0; g = 8'd0; b = 8'd0;
        byp = 1'b0; yv = 8'd16; cbv = 8'd128; crv = 8'd128;
        on  = 3'b000;
        lvl = 8'd255;

        case (b_pat)
            P_BARS: begin
                on  = bar_rgb(b_bar);
                lvl = b_bot_third ? 8'd255 : 8'd191;
                r = on[2] ? lvl : 8'd0; g = on[1] ? lvl : 8'd0; b = on[0] ? lvl : 8'd0;
            end
            P_GRAY: begin
                lvl = b_bot_half ? {b_ramp[7:4], b_ramp[7:4]} : b_ramp;
                r = lvl; g = lvl; b = lvl;
            end
            P_RGBW: begin
                case (b_band)
                    2'd0: r = b_ramp;
                    2'd1: g = b_ramp;
                    2'd2: b = b_ramp;
                    default: begin r = b_ramp; g = b_ramp; b = b_ramp; end
                endcase
            end
            P_GRID: begin
                if (b_center)                 begin r = 8'd255; end
                else if (b_border || b_grid)  begin r = 8'd255; g = 8'd255; b = 8'd255; end
            end
            P_CHK: begin
                lvl = b_chk ? 8'd255 : 8'd0;
                r = lvl; g = lvl; b = lvl;
            end
            P_CHROMA: begin
                byp = 1'b1;
                yv  = 8'd128;
                cbv = b_bot_half ? 8'd128  : b_cramp;
                crv = b_bot_half ? b_cramp : 8'd128;
            end
            P_MOTION: begin
                on = bar_rgb(b_mbar);
                r = on[2] ? 8'd255 : 8'd0; g = on[1] ? 8'd255 : 8'd0; b = on[0] ? 8'd255 : 8'd0;
            end
            P_SOLID: begin
                on = bar_rgb(b_solid);
                r = on[2] ? 8'd255 : 8'd0; g = on[1] ? 8'd255 : 8'd0; b = on[0] ? 8'd255 : 8'd0;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            o_de <= 1'b0; o_hs <= 1'b0; o_vs <= 1'b0;
            o_r <= '0; o_g <= '0; o_b <= '0;
            o_ycc_byp <= 1'b0; o_y <= 8'd16; o_cb <= 8'd128; o_cr <= 8'd128;
        end else begin
            o_de <= b_de; o_hs <= b_hs; o_vs <= b_vs;
            o_r <= r; o_g <= g; o_b <= b;
            o_ycc_byp <= byp; o_y <= yv; o_cb <= cbv; o_cr <= crv;
        end
    end
endmodule
