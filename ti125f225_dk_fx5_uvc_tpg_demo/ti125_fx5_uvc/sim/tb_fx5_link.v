`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// tb_fx5_link : behavioural model of the FX5 LVDS receive port + UVC buffer
//               accounting, driving ti125_fx5_uvc_top.
//
// Checks
//   - PHY training: PHY_TS on CTL + all 8 data lanes for >= 50 us, ends after PHY_DONE
//   - link training block 78 4B 5A 12 on every lane, then IDLE
//   - STAD/SSAD (0x89, 0x91) before every frame, >= 100 clk before data
//   - no DATA while DMA_READY is low / once a buffer is full
//   - every frame = FRAME_BYTES, EOP present iff the last buffer is short
//   - first pixel of each frame = white bar (Y=0xB4, U=V=0x80)
//   - stream stop mid-frame, restart -> next frame complete and aligned
// Dumps frame 0 as raw YUY2 (frame0.yuv) for visual inspection.
// -----------------------------------------------------------------------------
module tb_fx5_link;
    parameter integer H   = 64;
    parameter integer V   = 20;
    parameter integer BUF = 1024;
    parameter integer NFRAMES = 6;
    parameter integer STOP_TEST = 1;       // stop/restart streaming mid-frame
    parameter integer CYCLE_PATTERNS = 0;  // frame N uses pattern N%8, dumps frameN.yuv
    parameter integer PHY_DONE_DLY_NS = 20000; // firmware PHY_DONE delay after LINK_READY
    // FX5 ingress model: a small FIFO drained at 1 word per FX_DRAIN clocks;
    // DMA_READY drops while it is above FX_WM (back-pressure seen on hardware)
    // and reaches the pin FLAG_LAT clocks late. A word arriving when the FIFO
    // is full is lost -> error.
    parameter integer FX_THROTTLE = 1;
    parameter integer FX_DRAIN    = 3;
    parameter integer FX_DEPTH    = 32;
    parameter integer FX_WM       = 24;
    parameter integer FLAG_LAT    = 3;
    parameter integer WORD_GAP    = 2;
    parameter integer HONOR       = 1;
    parameter integer XRES_HOLD_US = 20;     // FX5 reset hold after FPGA core ready (short for sim)
    parameter integer SYSRST_TEST  = 1;      // press BUTTON_2 mid-stream: FPGA + FX5 restart together
    localparam integer FRAME_BYTES = H*V*2;

    reg clk = 0;
    always #3.367 clk = ~clk;          // 148.5 MHz

    reg rst_n = 1;                     // BUTTON_2 (active low)
    reg pll_locked = 0, link_ready = 0, buf_rdy = 0, phy_done = 0, stream_en = 0;
    wire dma_pin;                      // FX5 FLAGA as seen by the FPGA
    wire xres_out, xres_oe;
    wire xres_pin = (xres_oe && !xres_out) ? 1'b0 : 1'b1;   // open drain + board pull-up
    wire [7:0] d [0:7];
    wire [7:0] ctl_w, clk_w;
    wire led_h, led_t, led_e; wire [2:0] pat;

    ti125_fx5_uvc_top #(
        .H_ACTIVE(H), .V_ACTIVE(V), .FPS(5000), .BUF_BYTES(BUF),
        .WORD_GAP(WORD_GAP), .HONOR_READY_IN_BUF(HONOR),
        .FX5_XRES_HOLD_US(XRES_HOLD_US)
    ) dut (
        .clk_par(clk), .i_pll_locked(pll_locked), .i_rst(rst_n), .i_btn(1'b1),
        .fx_d0_tx(d[0]), .fx_d1_tx(d[1]), .fx_d2_tx(d[2]), .fx_d3_tx(d[3]),
        .fx_d4_tx(d[4]), .fx_d5_tx(d[5]), .fx_d6_tx(d[6]), .fx_d7_tx(d[7]),
        .fx_ctl_tx(ctl_w),
        .fx_link_ready(link_ready), .fx_dma_ready(dma_pin),
        .fx_phy_done(phy_done), .fx_stream_en(stream_en),
        .fx5_xres_in(xres_pin), .fx5_xres_out(xres_out), .fx5_xres_oe(xres_oe),
        .o_led_heartbeat(led_h), .o_led_trained(led_t), .o_led_err(led_e), .o_pattern(pat));

    // undo the serializer bit reversal (what arrives on the wire, MSB first)
    function [7:0] rev(input [7:0] b);
        integer k; begin for (k = 0; k < 8; k = k + 1) rev[k] = b[7-k]; end
    endfunction
    wire [7:0] C = rev(ctl_w);
    wire [7:0] L0 = rev(d[0]), L1 = rev(d[1]), L2 = rev(d[2]), L3 = rev(d[3]);
    wire [7:0] L4 = rev(d[4]), L5 = rev(d[5]), L6 = rev(d[6]), L7 = rev(d[7]);
    wire all_lanes_eq = (L0==C)&&(L1==C)&&(L2==C)&&(L3==C)&&(L4==C)&&(L5==C)&&(L6==C)&&(L7==C);

    integer errors = 0;
    task fail(input [8*80-1:0] msg); begin errors = errors + 1; $display("%t ERROR: %0s", $time, msg); end endtask

    // ------------------------------------------------------------- training checker
    integer phy_cnt = 0, phase = 0;   // 0 wait, 1 phy, 2 link, 3 done
    reg [7:0] exp_link [0:3];
    integer lk = 0;
    initial begin exp_link[0]=8'h78; exp_link[1]=8'h4B; exp_link[2]=8'h5A; exp_link[3]=8'h12; end
    always @(posedge clk) if (link_ready) begin
        case (phase)
        0: if (C == 8'h9C) begin phase = 1; phy_cnt = 1; end
        1: if (C == 8'h9C) begin
               phy_cnt = phy_cnt + 1;
               if (!all_lanes_eq) fail("PHY_TS not on all lanes");
           end else if (C == 8'h78) begin
               $display("%t PHY training: %0d clocks (%0.1f us)", $time, phy_cnt, phy_cnt*6.734/1000.0);
               if (phy_cnt < 7425) fail("PHY training shorter than 50 us");
               if (!phy_done) fail("PHY phase ended before PHY_DONE");
               phase = 2; lk = 1;
               if (!all_lanes_eq) fail("link byte not on all lanes");
           end else fail("unexpected byte during PHY training");
        2: begin
               if (lk < 4) begin
                   if (C != exp_link[lk] || !all_lanes_eq) fail("bad link training byte");
                   lk = lk + 1;
               end else begin
                   if (C != 8'h01) fail("no IDLE after link block");
                   phase = 3; $display("%t link training block sent, link up", $time);
               end
           end
        default: ;
        endcase
    end

    // FX5 boot model: it can only run once the FPGA releases FX5_XRES;
    // then (after a short "boot") it raises LINK_READY, and the firmware
    // raises PHY_DONE PHY_DONE_DLY_NS later. Check the FPGA holds the FX5 in
    // reset until its PLL is locked and FX5_XRES_HOLD_US has passed.
    time t_lock, t_rel;
    integer boots = 0;
    initial begin
        #200;   pll_locked = 1; t_lock = $time;
        if (xres_pin !== 1'b0) fail("FX5_XRES not held low while FPGA comes out of reset");
    end
    // FX5: runs whenever XRES is high; anything that pulls XRES low resets it
    always begin
        wait (xres_pin === 1'b1);
        t_rel = $time; boots = boots + 1;
        if (boots == 1) begin
            $display("%t FX5_XRES released %0.1f us after PLL lock", $time, (t_rel - t_lock)/1000.0);
            if ((t_rel - t_lock) < XRES_HOLD_US*1000) fail("FX5_XRES released too early");
        end else
            $display("%t FX5_XRES released again (boot %0d)", $time, boots);
        if (dut.u_link.st != 0) fail("link FSM not idle when FX5 released");
        #2000;  if (xres_pin === 1'b1) link_ready = 1;
        #(PHY_DONE_DLY_NS); if (xres_pin === 1'b1) phy_done = 1;
        wait (xres_pin === 1'b0);
        link_ready = 0; phy_done = 0; stream_en = 0; buf_rdy = 0;
        $display("%t FX5 in reset", $time);
    end
    always @(negedge link_ready) phase = 0;     // retraining is checked again
    always @(posedge clk) if (xres_pin === 1'b0 && link_ready) fail("FX5 running while held in reset");

    // ------------------------------------------------------------- FX ingress throttle
    integer fx_fill = 0, drain_cnt = 0, lost = 0, thr_cycles = 0;
    reg [15:0] flag_sh = 0;
    wire throttle_ok = !FX_THROTTLE || (fx_fill < FX_WM);
    always @(posedge clk) begin
        flag_sh <= {flag_sh[14:0], buf_rdy & throttle_ok};
        if (!throttle_ok) thr_cycles = thr_cycles + 1;
    end
    assign dma_pin = (FLAG_LAT == 0) ? (buf_rdy & throttle_ok) : flag_sh[FLAG_LAT-1];

    // ------------------------------------------------------------- FX DMA model
    integer buf_cnt = 0, frame_cnt_b = 0, frames = 0, gap = 0;
    integer since_addr = 0, stad_seen = 0, ssad_seen = 0;
    reg     buf_open = 0;          // FX has a buffer allocated (internal), FLAGA follows with latency
    integer flag_dly = 0;
    reg     frame_start = 1;
    reg [7:0] fbuf [0:FRAME_BYTES-1];
    integer fd, k;
    integer aborted = 0;
    reg [8*10-1:0] fname;
    always @(frames) if (CYCLE_PATTERNS) force dut.pat_req = frames[2:0];

    task commit_frame(input integer had_eop);
        begin
            if (frame_cnt_b != FRAME_BYTES) begin
                if (aborted) $display("%t  (aborted frame discarded: %0d bytes)", $time, frame_cnt_b);
                else fail("frame size mismatch");
            end else begin
                if (had_eop != ((FRAME_BYTES % BUF) != 0)) fail("EOP presence wrong for frame size");
                if (!CYCLE_PATTERNS && (fbuf[0] != 8'hB4 || fbuf[1] != 8'h80 || fbuf[3] != 8'h80)) fail("frame does not start with white bar");
                $display("%t frame %0d OK: %0d bytes (first YUYV %02x %02x %02x %02x)",
                         $time, frames, frame_cnt_b, fbuf[0], fbuf[1], fbuf[2], fbuf[3]);
                if (frames == 0 || CYCLE_PATTERNS) begin
                    $sformat(fname, "frame%0d.yuv", frames);
                    fd = $fopen(fname, "wb");
                    for (k = 0; k < FRAME_BYTES; k = k + 1) $fwrite(fd, "%c", fbuf[k]);
                    $fclose(fd);
                end
                frames = frames + 1;
            end
            frame_cnt_b = 0; buf_cnt = 0; aborted = 0;
        end
    endtask

    always @(posedge clk) begin
        since_addr <= since_addr + 1;
        // FLAGA latency model: ~12 clocks from internal state to pin
        if (flag_dly > 0) begin
            flag_dly <= flag_dly - 1;
            if (flag_dly == 1) buf_rdy <= 0;
        end

        if (phase == 3 && C == 8'h89) begin stad_seen <= 1; end
        if (phase == 3 && C == 8'h91) begin
            if (!stad_seen) fail("SSAD without STAD");
            ssad_seen <= 1; since_addr <= 0;
            if (frame_cnt_b != 0 && !aborted) fail("thread/socket re-sent mid-frame");
            if (aborted) begin frame_cnt_b = 0; buf_cnt = 0; aborted = 0; end
            buf_open <= stream_en; gap <= 40;
        end

        // buffer becomes available 'gap' clocks after request / after previous commit
        if (gap > 0) begin
            gap <= gap - 1;
            if (gap == 1 && stream_en) buf_rdy <= 1;
        end

        // ingress FIFO drain
        if (FX_THROTTLE) begin
            drain_cnt = drain_cnt + 1;
            if (drain_cnt >= FX_DRAIN) begin drain_cnt = 0; if (fx_fill > 0) fx_fill = fx_fill - 1; end
        end
        if (C == 8'h80) begin               // DATA, full width
            if (FX_THROTTLE) begin
                if (fx_fill >= FX_DEPTH) begin lost = lost + 1; fail("FX ingress overflow: word lost"); end
                else fx_fill = fx_fill + 1;
            end
            if (!buf_rdy && buf_cnt == 0) fail("DATA before DMA_READY");
            if (buf_cnt >= BUF) fail("DATA past end of buffer");
            if (since_addr < 100 && frame_cnt_b == 0) fail("DATA < 100 clk after SSAD");
            fbuf[frame_cnt_b+0] = L0; fbuf[frame_cnt_b+1] = L1; fbuf[frame_cnt_b+2] = L2; fbuf[frame_cnt_b+3] = L3;
            fbuf[frame_cnt_b+4] = L4; fbuf[frame_cnt_b+5] = L5; fbuf[frame_cnt_b+6] = L6; fbuf[frame_cnt_b+7] = L7;
            frame_cnt_b = frame_cnt_b + 8;
            buf_cnt     = buf_cnt + 8;
            if (buf_cnt == BUF) begin
                // buffer full -> commit, FLAGA drops after a few clocks, next buffer later
                flag_dly <= 12;
                buf_cnt = 0;
                if (frame_cnt_b == FRAME_BYTES) commit_frame(0);
                gap <= 300;
            end
        end else if (C == 8'hEF) begin      // EOP
            flag_dly <= 12;
            buf_cnt = 0;
            commit_frame(1);
            gap <= 300;
        end else if (C != 8'h01 && C != 8'h89 && C != 8'h91 && phase == 3) begin
            fail("unknown control byte after training");
        end
    end

    // ------------------------------------------------------------- stream control
    initial begin
        wait (phy_done); #80000; stream_en = 1;
        if (STOP_TEST) begin
        wait (frames == 2);
        // stop in the middle of the next frame
        wait (frame_cnt_b > FRAME_BYTES/2);
        @(posedge clk); stream_en = 0; buf_rdy = 0; aborted = 1;
        $display("%t host stops streaming mid-frame", $time);
        #20000; stream_en = 1;
        $display("%t host restarts streaming", $time);
        end
        if (SYSRST_TEST) begin
        wait (frames == 3);
        wait (frame_cnt_b > FRAME_BYTES/3);
        @(posedge clk); aborted = 1;
        rst_n = 0; $display("%t BUTTON_2 pressed mid-frame (system reset)", $time);
        #1000; rst_n = 1;
        if (xres_pin !== 1'b0) fail("FX5 not held in reset after BUTTON_2");
        wait (phy_done); #80000; stream_en = 1;   // host re-opens the camera
        $display("%t host streaming again after re-enumeration", $time);
        end
        wait (frames == NFRAMES);
        #2000;
        if (dut.u_link.err_count != 0) fail("link reported errors");
        $display("throttle: DMA_READY held low by back-pressure for %0d clocks, %0d words lost", thr_cycles, lost);
        $display("RESULT: %0d frames, %0d errors -> %0s", frames, errors, errors ? "FAIL" : "PASS");
        $finish;
    end

    initial begin #400_000_000; fail("timeout"); $finish; end
endmodule
