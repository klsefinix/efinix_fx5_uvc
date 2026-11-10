// ============================================================================
// ti125_fx5_uvc_top.sv
// Ti125F225 dev board Rev B1: hdmi_tp test patterns -> on-board EZ-USB FX5
// (CYUSB3083) over the GPIF III LVDS link -> UVC camera on the host PC.
//
// Pattern path re-uses the proven hdmi_tp RTL unchanged:
//   tpg_raster_ce -> test_pattern_gen -> rgb2ycbcr709 -> ycbcr_to_yuy2_packer
//   -> FIFO -> fx_lvds_link_tx -> 8 data + CTL + CLK LVDS lanes (FX5 port 0)
// tpg_raster_ce replaces video_timing_gen on this path: it emits active
// pixels only and pauses while the FIFO is full, because the FX5 throttles the
// link with DMA_READY. Everything else (patterns, BT.709 CSC, button, LEDs,
// reset) behaves as in hdmi_tp_top.
//
// Clocking: one domain. clk_par = 148.5 MHz LVDS parallel clock from PLL_BL0
// (74.25 MHz X4 on GPIOB_P_00_PLLIN1); the 594 MHz serial clock only feeds the
// LVDS TX blocks in Interface Designer. 148.5 MHz is also the 1080p60 pixel
// clock, so the pattern pipeline runs exactly as it does on the HDMI card.
//
// Push button (BUTTON_0), as in hdmi_tp_top: short press = next pattern.
// ============================================================================
module ti125_fx5_uvc_top #(
    parameter int    H_ACTIVE        = 1920,
    parameter int    V_ACTIVE        = 1080,
    parameter int    FPS             = 30,          // must match the FX5 UVC frame interval
    parameter int    CLK_HZ          = 148_500_000,
    parameter int    BUF_BYTES       = 61440,       // FX5 CY_USB_UVC_STREAM_BUF_SIZE - 32
    parameter bit    USE_PHY_DONE    = 1'b1,        // FX5 firmware drives P0CTL4
    parameter bit    USE_STREAM_EN   = 1'b1,        // FX5 firmware drives P0CTL3
    parameter int    WORD_GAP        = 2,           // link pacing: 1 word per N clocks (FX5 can't sink 1/clk)
    parameter bit    HONOR_READY_IN_BUF = 1'b1,     // pause DATA while FX5 DMA_READY is low
    parameter int    DEBOUNCE_US     = 20_000,
    parameter int    LONG_PRESS_US   = 1_500_000,
    parameter bit    BTN_ACTIVE_LOW  = 1'b1,
    parameter bit    RST_ACTIVE_LOW  = 1'b1,
    parameter logic [2:0] DEFAULT_PATTERN = 3'd0,
    parameter int    FX5_XRES_HOLD_US = 10_000      // FX5 held in reset this long after the FPGA core is ready
)(
    // ---- clock / reset (Interface Designer) ----
    input  logic        clk_par,          // PLL_BL0 148.5 MHz
    input  logic        i_pll_locked,
    input  logic        i_rst,            // BUTTON_2
    input  logic        i_btn,            // BUTTON_0: next pattern

    // ---- FX5 port 0 LVDS TX parallel buses (8:1 serial data mode) ----
    output logic [7:0]  fx_d0_tx,         // GPIOB_PN_22 -> P0D0
    output logic [7:0]  fx_d1_tx,         // GPIOB_PN_21 -> P0D1
    output logic [7:0]  fx_d2_tx,         // GPIOB_PN_20 -> P0D2
    output logic [7:0]  fx_d3_tx,         // GPIOB_PN_19 -> P0D3
    output logic [7:0]  fx_d4_tx,         // GPIOB_PN_05 -> P0D4
    output logic [7:0]  fx_d5_tx,         // GPIOB_PN_04 -> P0D5
    output logic [7:0]  fx_d6_tx,         // GPIOB_PN_03 -> P0D6
    output logic [7:0]  fx_d7_tx,         // GPIOB_PN_02 -> P0D7
    output logic [7:0]  fx_ctl_tx,        // GPIOB_PN_23 -> P0C control lane
`ifdef FX_CLK_LANE_DATA_MODE
    // Only if the P0CLK LVDS TX is built in "serial data output" mode.
    // Default: P0CLK is an LVDS TX in "reference clock output" mode, which
    // needs no core bus.
    output logic [7:0]  fx_clk_tx,        // GPIOB_PN_14 -> P0CLK (0xF0 pattern)
`endif

    // ---- LVDS TX serializer reset / output enable (one pair per LVDS TX
    //      block; names are Interface Designer's defaults <bus>_TX_RST/_TX_OE).
    //      TX_RST is active high (Infineon's Ti180 design holds it low in
    //      normal operation and high only to power a lane down).
    output logic        fx_d0_tx_TX_RST,
    output logic        fx_d0_tx_TX_OE,
    output logic        fx_d1_tx_TX_RST,
    output logic        fx_d1_tx_TX_OE,
    output logic        fx_d2_tx_TX_RST,
    output logic        fx_d2_tx_TX_OE,
    output logic        fx_d3_tx_TX_RST,
    output logic        fx_d3_tx_TX_OE,
    output logic        fx_d4_tx_TX_RST,
    output logic        fx_d4_tx_TX_OE,
    output logic        fx_d5_tx_TX_RST,
    output logic        fx_d5_tx_TX_OE,
    output logic        fx_d6_tx_TX_RST,
    output logic        fx_d6_tx_TX_OE,
    output logic        fx_d7_tx_TX_RST,
    output logic        fx_d7_tx_TX_OE,
    output logic        fx_ctl_tx_TX_RST,
    output logic        fx_ctl_tx_TX_OE,
    output logic        fx_clk_tx_TX_RST,
    output logic        fx_clk_tx_TX_OE,

    // ---- FX5 P0CTL sideband (BL bank, 1.8 V) ----
    input  logic        fx_link_ready,    // P0CTL6 -> GPIOL_08 (N14)
    input  logic        fx_dma_ready,     // P0CTL5 -> GPIOL_07 (P14)
    input  logic        fx_phy_done,      // P0CTL4 -> GPIOL_05 (N13)
    input  logic        fx_stream_en,     // P0CTL3 -> GPIOL_04 (P15)

    // ---- FX5 reset (pin M2 -> FX5_XRES, open drain; 10k pull-up R168 and
    //      BTN4 on the board). Interface Designer: one bidirectional GPIO with
    //      IN = fx5_xres_in, OUT = fx5_xres_out, OE = fx5_xres_oe.
    input  logic        fx5_xres_in,      // pin level (low while anyone holds the FX5 in reset)
    output logic        fx5_xres_out,     // always 0: only ever drives low
    output logic        fx5_xres_oe,      // 1 = drive low (reset), 0 = Hi-Z (pull-up releases)

    // ---- status LEDs (same pins as hdmi_tp_top) ----
    output logic        o_led_heartbeat,  // USER_LED1: toggles every 32 frames sent
    output logic        o_led_trained,    // USER_LED2: LVDS PHY + link training sent
    output logic        o_led_err,        // USER_LED3: link protocol error seen
    output logic [2:0]  o_pattern         // USER_LED4..6: current pattern
);
    // ------------------------------------------------------------------
    // Reset, 1 us tick, button (hdmi_tp_util)
    // ------------------------------------------------------------------
    logic rst;
    wire  rst_btn = RST_ACTIVE_LOW ? ~i_rst : i_rst;
    wire  arst    = ~i_pll_locked | rst_btn;
    tp_rst_sync u_rst (.clk(clk_par), .i_arst(arst), .o_rst(rst));

    // ------------------------------------------------------------------
    // FX5 reset sequencing (open drain on FX5_XRES)
    //   * During FPGA configuration the pin is tri-stated by the device, so
    //     the FX5 may boot early; that boot is discarded.
    //   * From user mode, whenever the core is in reset (PLL not locked or
    //     BUTTON_2) the FX5 is held in reset too: OE is set asynchronously, so
    //     this holds even with no clk_par.
    //   * FX5_XRES_HOLD_US after the core reset releases - PLL locked, LVDS
    //     serializers out of reset and sending IDLE, link FSM waiting for
    //     LINK_READY, pattern pipeline reset - the pin goes Hi-Z and the
    //     board pull-up lets the FX5 boot. It then trains a link the FPGA is
    //     already waiting on.
    //   * BUTTON_2 is therefore a full system reset (FPGA logic + FX5).
    // ------------------------------------------------------------------
    localparam longint XRES_HOLD_CLKS = (longint'(CLK_HZ) * FX5_XRES_HOLD_US) / 1_000_000;
    logic [31:0] xres_cnt;
    logic        fx5_released;
    always_ff @(posedge clk_par or posedge arst) begin
        if (arst) begin
            xres_cnt     <= '0;
            fx5_released <= 1'b0;
        end else if (rst) begin
            xres_cnt     <= '0;
            fx5_released <= 1'b0;
        end else if (!fx5_released) begin
            xres_cnt     <= xres_cnt + 32'd1;
            fx5_released <= (xres_cnt >= 32'(XRES_HOLD_CLKS - 1));
        end
    end
    assign fx5_xres_out = 1'b0;
    assign fx5_xres_oe  = ~fx5_released;

    // FX5 actually running = we released it and nobody else (BTN4) holds XRES low
    logic fx5_xres_s;
    sync2 u_sx (.clk(clk_par), .d(fx5_xres_in), .q(fx5_xres_s));
    wire  fx5_running = fx5_released & fx5_xres_s;

    logic tick_us;
    tp_us_tick #(.CLK_HZ(CLK_HZ)) u_tick (.clk(clk_par), .rst(rst), .o_tick(tick_us));

    logic btn_short;
    tp_btn_debounce #(
        .DEBOUNCE_US(DEBOUNCE_US), .LONG_US(LONG_PRESS_US), .ACTIVE_LOW(BTN_ACTIVE_LOW)
    ) u_btn (
        .clk(clk_par), .rst(rst), .i_us_tick(tick_us), .i_btn(i_btn),
        .o_pressed(), .o_short(btn_short), .o_long()
    );

    // ------------------------------------------------------------------
    // FX5 sideband synchronizers
    // ------------------------------------------------------------------
    logic link_ready_s, dma_ready_s, phy_done_s, stream_en_s;
    // While the FX5 is in reset its P0CTL pins float; ignore LINK_READY then
    // so the link FSM stays in S_WAIT_LINK until the FX5 really asks.
    logic link_ready_raw;
    sync2 u_s0 (.clk(clk_par), .d(fx_link_ready), .q(link_ready_raw));
    assign link_ready_s = link_ready_raw & fx5_running;
    sync2 u_s1 (.clk(clk_par), .d(fx_dma_ready),  .q(dma_ready_s));
    sync2 u_s2 (.clk(clk_par), .d(fx_phy_done),   .q(phy_done_s));
    sync2 u_s3 (.clk(clk_par), .d(fx_stream_en),  .q(stream_en_s));

    // ------------------------------------------------------------------
    // Frame-rate tick
    // ------------------------------------------------------------------
    localparam int TICK_CLKS = CLK_HZ / FPS;
    logic [31:0] tick_cnt;
    logic        frame_go;
    always_ff @(posedge clk_par) begin
        if (rst) begin
            tick_cnt <= '0; frame_go <= 1'b0;
        end else begin
            frame_go <= (tick_cnt == 32'(TICK_CLKS - 1));
            tick_cnt <= (tick_cnt == 32'(TICK_CLKS - 1)) ? '0 : tick_cnt + 32'd1;
        end
    end

    // ------------------------------------------------------------------
    // Pattern pipeline
    // ------------------------------------------------------------------
    logic        flush;                       // link aborted a frame
    logic        src_rst;
    assign src_rst = rst | flush;

    localparam int FIFO_AW = 10;
    logic [FIFO_AW:0] fifo_count;
    logic             space_ok;
    assign space_ok = (fifo_count <= (1 << FIFO_AW) - 16);   // <= 2 words in flight

    logic [11:0] t_x, t_y;
    logic        t_de, t_eol, t_sof, t_fstart;
    tpg_raster_ce #(.H_ACTIVE(H_ACTIVE), .V_ACTIVE(V_ACTIVE)) u_raster (
        .clk(clk_par), .rst(src_rst),
        .i_frame_go(frame_go), .i_space_ok(space_ok),
        .o_x(t_x), .o_y(t_y), .o_de(t_de), .o_hs(t_eol), .o_vs(t_sof),
        .o_frame_start(t_fstart)
    );

    // pattern select applied at frame start (as hdmi_tp_top does at vblank)
    logic [2:0]  pat_req, pat_cur;
    logic [15:0] frame_cnt;
    always_ff @(posedge clk_par) begin
        if (rst) begin
            pat_req <= DEFAULT_PATTERN; pat_cur <= DEFAULT_PATTERN; frame_cnt <= '0;
        end else begin
            if (btn_short) pat_req <= pat_req + 3'd1;
            if (t_fstart) begin
                pat_cur   <= pat_req;
                frame_cnt <= frame_cnt + 16'd1;
            end
        end
    end
    assign o_pattern = pat_cur;

    logic       p_de, p_eol, p_sof, p_byp;
    logic [7:0] p_r, p_g, p_b, p_y, p_cb, p_cr;
    test_pattern_gen #(.H_ACTIVE(H_ACTIVE), .V_ACTIVE(V_ACTIVE)) u_pat (
        .clk(clk_par), .rst(src_rst),
        .i_pattern(pat_cur), .i_frame_cnt(frame_cnt),
        .i_x(t_x), .i_y(t_y), .i_de(t_de), .i_hs(t_eol), .i_vs(t_sof),
        .o_de(p_de), .o_hs(p_eol), .o_vs(p_sof),
        .o_r(p_r), .o_g(p_g), .o_b(p_b),
        .o_ycc_byp(p_byp), .o_y(p_y), .o_cb(p_cb), .o_cr(p_cr)
    );

    logic       c_de, c_eol, c_sof;
    logic [7:0] c_y, c_cb, c_cr;
    rgb2ycbcr709 u_csc (
        .clk(clk_par), .rst(src_rst),
        .i_de(p_de), .i_hs(p_eol), .i_vs(p_sof),
        .i_r(p_r), .i_g(p_g), .i_b(p_b),
        .i_byp(p_byp), .i_y(p_y), .i_cb(p_cb), .i_cr(p_cr),
        .o_de(c_de), .o_hs(c_eol), .o_vs(c_sof),
        .o_y(c_y), .o_cb(c_cb), .o_cr(c_cr)
    );

    logic        pk_wr;
    logic [64:0] pk_word;
    ycbcr_to_yuy2_packer u_pack (
        .clk(clk_par), .rst(src_rst),
        .i_de(c_de), .i_sof(c_sof), .i_y(c_y), .i_cb(c_cb), .i_cr(c_cr),
        .o_wr(pk_wr), .o_word(pk_word)
    );

    // ------------------------------------------------------------------
    // Word FIFO and FX LVDS link
    // ------------------------------------------------------------------
    logic [64:0] fifo_dout;
    logic        fifo_valid, fifo_rd;
    sync_fifo_fwft #(.WIDTH(65), .AWIDTH(FIFO_AW)) u_fifo (
        .clk(clk_par), .srst(src_rst),
        .wr_en(pk_wr), .wr_data(pk_word),
        .rd_en(fifo_rd), .dout(fifo_dout), .dout_valid(fifo_valid),
        .count(fifo_count)
    );

    logic [63:0] tx_data;
    logic [7:0]  clk_lane_pat;
`ifdef FX_CLK_LANE_DATA_MODE
    assign fx_clk_tx = clk_lane_pat;
`endif
    logic        trained, streaming, frame_done;
    logic [15:0] frames_sent;
    logic [7:0]  err_count;
    fx_lvds_link_tx #(
        .CLK_HZ        (CLK_HZ),
        .FRAME_BYTES   (H_ACTIVE * V_ACTIVE * 2),
        .BUF_BYTES     (BUF_BYTES),
        .USE_PHY_DONE  (USE_PHY_DONE),
        .USE_STREAM_EN (USE_STREAM_EN),
        .WORD_GAP      (WORD_GAP),
        .HONOR_READY_IN_BUF (HONOR_READY_IN_BUF)
    ) u_link (
        .clk(clk_par), .rst(rst),
        .link_ready(link_ready_s), .dma_ready(dma_ready_s),
        .phy_done(phy_done_s), .stream_en(stream_en_s),
        .fifo_dout(fifo_dout), .fifo_valid(fifo_valid), .fifo_rd(fifo_rd),
        .flush(flush),
        .tx_data(tx_data), .tx_ctl(fx_ctl_tx), .tx_clk(clk_lane_pat),
        .trained(trained), .streaming(streaming), .frame_done(frame_done),
        .frame_count(frames_sent), .err_count(err_count)
    );

    assign fx_d0_tx = tx_data[ 7: 0];
    assign fx_d1_tx = tx_data[15: 8];
    assign fx_d2_tx = tx_data[23:16];
    assign fx_d3_tx = tx_data[31:24];
    assign fx_d4_tx = tx_data[39:32];
    assign fx_d5_tx = tx_data[47:40];
    assign fx_d6_tx = tx_data[55:48];
    assign fx_d7_tx = tx_data[63:56];


    // ------------------------------------------------------------------
    // LVDS TX serializer control: serializers held in reset until the PLL
    // is locked and the core reset releases (rst is synchronous to clk_par,
    // the LVDS slow clock); outputs always enabled.
    // ------------------------------------------------------------------
    assign fx_d0_tx_TX_RST = rst;
    assign fx_d0_tx_TX_OE  = 1'b1;
    assign fx_d1_tx_TX_RST = rst;
    assign fx_d1_tx_TX_OE  = 1'b1;
    assign fx_d2_tx_TX_RST = rst;
    assign fx_d2_tx_TX_OE  = 1'b1;
    assign fx_d3_tx_TX_RST = rst;
    assign fx_d3_tx_TX_OE  = 1'b1;
    assign fx_d4_tx_TX_RST = rst;
    assign fx_d4_tx_TX_OE  = 1'b1;
    assign fx_d5_tx_TX_RST = rst;
    assign fx_d5_tx_TX_OE  = 1'b1;
    assign fx_d6_tx_TX_RST = rst;
    assign fx_d6_tx_TX_OE  = 1'b1;
    assign fx_d7_tx_TX_RST = rst;
    assign fx_d7_tx_TX_OE  = 1'b1;
    assign fx_ctl_tx_TX_RST = rst;
    assign fx_ctl_tx_TX_OE  = 1'b1;
    assign fx_clk_tx_TX_RST = rst;
    assign fx_clk_tx_TX_OE  = 1'b1;

    assign o_led_heartbeat = frames_sent[5];
    assign o_led_trained   = trained;
    assign o_led_err       = (err_count != 8'd0);
endmodule
