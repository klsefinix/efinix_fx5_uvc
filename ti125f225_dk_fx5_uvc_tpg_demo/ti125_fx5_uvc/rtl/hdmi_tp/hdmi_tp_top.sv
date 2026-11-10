// ============================================================================
// hdmi_tp_top.sv
// Standalone HDMI test-pattern generator for Efinix dev kits + ADV7511
// HDMI daughter card (QSE connector).
//
// Derived from the Ti180M484 OOB HDMI path (adv7511_config + i2c_phy +
// hdmi_post_process), with the camera/DDR/DMA/debayer pipeline replaced by
// an internal pattern generator. Single clock domain: everything runs on the
// pixel clock, so there is no CDC in the design.
//
//   timing gen -> pattern gen -> RGB->YCbCr(709) -> 4:2:2 pack -> pins
//                                   ADV7511 I2C init (same clock)
//
// Push button:
//   short press (< LONG_PRESS_US) : next test pattern (applied at frame start)
//   long press  (>= LONG_PRESS_US): re-run the ADV7511 I2C configuration
//
// VIDEO_MODE / pixel clock (the PLL must supply CLK_HZ on i_pixel_clk):
//   "1080P" : 1920x1080, 148.5 MHz = 1080p60   (74.25 MHz gives 1080p30,
//             same raster - set CLK_HZ to match)
//   "720P"  : 1280x720 @ 74.25 MHz = 720p60
//   "480P"  : 720x480  @ 27.0 MHz  = 480p60
//
// The pixel clock to the ADV7511 is forwarded by an output GPIO configured in
// Interface Designer (clock-out from the pixel PLL), not by this RTL.
// ============================================================================
module hdmi_tp_top #(
    parameter        VIDEO_MODE      = "1080P",
    parameter int    CLK_HZ          = 148_500_000,
    parameter int    I2C_HZ          = 100_000,
    parameter int    POWERUP_US      = 200_000,    // ADV7511 settle before I2C
    parameter int    RETRY_US        = 500_000,    // wait after a NACK
    parameter int    REFRESH_US      = 0,          // periodic re-init, 0 = off
    parameter int    DEBOUNCE_US     = 20_000,
    parameter int    LONG_PRESS_US   = 1_500_000,
    parameter bit    BTN_ACTIVE_LOW  = 1'b1,       // dev-kit buttons are normally active low
    parameter bit    RST_ACTIVE_LOW  = 1'b1,
    parameter logic [2:0] DEFAULT_PATTERN = 3'd0
)(
    // Clock / reset
    input  logic        i_pixel_clk,
    input  logic        i_pll_locked,
    input  logic        i_rst,            // board reset button; tie inactive if unused

    // User push button (pattern select / long-press re-init)
    input  logic        i_btn,

    // ADV7511 I2C - Efinix GPIO "inout" naming. hdmi_*_OUT are tied to 0;
    // *_OE = 1 pulls the line low (open drain). Board pull-ups required.
    input  logic        hdmi_scl_IN,
    output logic        hdmi_scl_OUT,
    output logic        hdmi_scl_OE,
    input  logic        hdmi_sda_IN,
    output logic        hdmi_sda_OUT,
    output logic        hdmi_sda_OE,

    // ADV7511 video bus: YCbCr 4:2:2, [15:8] = Cb/Cr, [7:0] = Y
    // (same names / bit order as ti180_oob_top)
    output logic        hdmi_yuv_vs,
    output logic        hdmi_yuv_hs,
    output logic        hdmi_yuv_de,
    output logic [15:0] hdmi_yuv_data,

    // Status
    output logic        o_led_heartbeat,  // toggles every 32 frames
    output logic        o_led_cfg_done,   // ADV7511 configured, all ACKs
    output logic        o_led_cfg_err,    // last config pass got a NACK
    output logic [2:0]  o_pattern         // current pattern number
);
    // ------------------------------------------------------------------
    // Video timing presets (CEA-861)
    // ------------------------------------------------------------------
    localparam bit M720 = (VIDEO_MODE == "720P");
    localparam bit M480 = (VIDEO_MODE == "480P");
    localparam bit MSIM = (VIDEO_MODE == "SIM");   // tiny raster, simulation only

    localparam int H_ACTIVE = MSIM ? 64 : M480 ? 720 : M720 ? 1280 : 1920;
    localparam int H_FP     = MSIM ? 4  : M480 ? 16  : M720 ? 110  : 88;
    localparam int H_SYNC   = MSIM ? 4  : M480 ? 62  : M720 ? 40   : 44;
    localparam int H_BP     = MSIM ? 8  : M480 ? 60  : M720 ? 220  : 148;
    localparam int V_ACTIVE = MSIM ? 36 : M480 ? 480 : M720 ? 720  : 1080;
    localparam int V_FP     = MSIM ? 2  : M480 ? 9   : M720 ? 5    : 4;
    localparam int V_SYNC   = MSIM ? 2  : M480 ? 6   : M720 ? 5    : 5;
    localparam int V_BP     = MSIM ? 4  : M480 ? 30  : M720 ? 20   : 36;
    localparam bit SYNC_POS = !M480;   // 480p uses negative syncs

    // ------------------------------------------------------------------
    // Reset: held while PLL unlocked or reset button pressed
    // ------------------------------------------------------------------
    logic rst;
    wire  rst_btn = RST_ACTIVE_LOW ? ~i_rst : i_rst;

    tp_rst_sync u_rst (
        .clk(i_pixel_clk), .i_arst(~i_pll_locked | rst_btn), .o_rst(rst)
    );

    logic tick_us;
    tp_us_tick #(.CLK_HZ(CLK_HZ)) u_tick (.clk(i_pixel_clk), .rst(rst), .o_tick(tick_us));

    // ------------------------------------------------------------------
    // Push button
    // ------------------------------------------------------------------
    logic btn_short, btn_long;
    tp_btn_debounce #(
        .DEBOUNCE_US(DEBOUNCE_US), .LONG_US(LONG_PRESS_US), .ACTIVE_LOW(BTN_ACTIVE_LOW)
    ) u_btn (
        .clk(i_pixel_clk), .rst(rst), .i_us_tick(tick_us), .i_btn(i_btn),
        .o_pressed(), .o_short(btn_short), .o_long(btn_long)
    );

    // ------------------------------------------------------------------
    // ADV7511 configuration
    // ------------------------------------------------------------------
    logic scl_oe, sda_oe;
    adv7511_init #(
        .CLK_HZ(CLK_HZ), .I2C_HZ(I2C_HZ),
        .POWERUP_US(POWERUP_US), .RETRY_US(RETRY_US), .REFRESH_US(REFRESH_US)
    ) u_init (
        .clk(i_pixel_clk), .rst(rst), .i_us_tick(tick_us), .i_reconfig(btn_long),
        .o_cfg_done(o_led_cfg_done), .o_cfg_err(o_led_cfg_err), .o_cfg_busy(),
        .i_scl(hdmi_scl_IN), .o_scl_oe(scl_oe),
        .i_sda(hdmi_sda_IN), .o_sda_oe(sda_oe)
    );
    assign hdmi_scl_OUT = 1'b0;
    assign hdmi_sda_OUT = 1'b0;
    assign hdmi_scl_OE  = scl_oe;
    assign hdmi_sda_OE  = sda_oe;

    // ------------------------------------------------------------------
    // Timing
    // ------------------------------------------------------------------
    logic [11:0] t_x, t_y;
    logic        t_de, t_hs, t_vs, t_vblank;

    video_timing_gen #(
        .H_ACTIVE(H_ACTIVE), .H_FP(H_FP), .H_SYNC(H_SYNC), .H_BP(H_BP),
        .V_ACTIVE(V_ACTIVE), .V_FP(V_FP), .V_SYNC(V_SYNC), .V_BP(V_BP)
    ) u_timing (
        .clk(i_pixel_clk), .rst(rst),
        .o_x(t_x), .o_y(t_y), .o_de(t_de), .o_hs(t_hs), .o_vs(t_vs),
        .o_vblank_start(t_vblank)
    );

    // Pattern select: button request latched, applied at start of vblank
    // so every frame is drawn with a single pattern.
    logic [2:0]  pat_req, pat_cur;
    logic [15:0] frame_cnt;
    always_ff @(posedge i_pixel_clk) begin
        if (rst) begin
            pat_req   <= DEFAULT_PATTERN;
            pat_cur   <= DEFAULT_PATTERN;
            frame_cnt <= '0;
        end else begin
            if (btn_short) pat_req <= pat_req + 3'd1;
            if (t_vblank) begin
                pat_cur   <= pat_req;
                frame_cnt <= frame_cnt + 16'd1;
            end
        end
    end
    assign o_pattern       = pat_cur;
    assign o_led_heartbeat = frame_cnt[5];

    // ------------------------------------------------------------------
    // Pattern -> colour space -> 4:2:2
    // ------------------------------------------------------------------
    logic       p_de, p_hs, p_vs, p_byp;
    logic [7:0] p_r, p_g, p_b, p_y, p_cb, p_cr;

    test_pattern_gen #(.H_ACTIVE(H_ACTIVE), .V_ACTIVE(V_ACTIVE)) u_pat (
        .clk(i_pixel_clk), .rst(rst),
        .i_pattern(pat_cur), .i_frame_cnt(frame_cnt),
        .i_x(t_x), .i_y(t_y), .i_de(t_de), .i_hs(t_hs), .i_vs(t_vs),
        .o_de(p_de), .o_hs(p_hs), .o_vs(p_vs),
        .o_r(p_r), .o_g(p_g), .o_b(p_b),
        .o_ycc_byp(p_byp), .o_y(p_y), .o_cb(p_cb), .o_cr(p_cr)
    );

    logic       c_de, c_hs, c_vs;
    logic [7:0] c_y, c_cb, c_cr;

    rgb2ycbcr709 u_csc (
        .clk(i_pixel_clk), .rst(rst),
        .i_de(p_de), .i_hs(p_hs), .i_vs(p_vs),
        .i_r(p_r), .i_g(p_g), .i_b(p_b),
        .i_byp(p_byp), .i_y(p_y), .i_cb(p_cb), .i_cr(p_cr),
        .o_de(c_de), .o_hs(c_hs), .o_vs(c_vs),
        .o_y(c_y), .o_cb(c_cb), .o_cr(c_cr)
    );

    logic        k_de, k_hs, k_vs;
    logic [15:0] k_data;

    ycbcr444_to_422 u_pack (
        .clk(i_pixel_clk), .rst(rst),
        .i_de(c_de), .i_hs(c_hs), .i_vs(c_vs),
        .i_y(c_y), .i_cb(c_cb), .i_cr(c_cr),
        .o_de(k_de), .o_hs(k_hs), .o_vs(k_vs), .o_data(k_data)
    );

    // ------------------------------------------------------------------
    // Output registers (pack these into the I/O cells in Interface Designer)
    // ------------------------------------------------------------------
    always_ff @(posedge i_pixel_clk) begin
        if (rst) begin
            hdmi_yuv_de   <= 1'b0;
            hdmi_yuv_hs   <= ~SYNC_POS;
            hdmi_yuv_vs   <= ~SYNC_POS;
            hdmi_yuv_data <= 16'h8010;
        end else begin
            hdmi_yuv_de   <= k_de;
            hdmi_yuv_hs   <= SYNC_POS ? k_hs : ~k_hs;
            hdmi_yuv_vs   <= SYNC_POS ? k_vs : ~k_vs;
            hdmi_yuv_data <= k_data;
        end
    end
endmodule
