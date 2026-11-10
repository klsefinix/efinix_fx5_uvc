// ============================================================================
// tpg_raster_ce.sv
// Flow-controlled raster for the USB path. Drop-in source of the same
// x / y / de / hs / vs signals video_timing_gen gives test_pattern_gen, but:
//   - active pixels only (USB/UVC has no blanking)
//   - advances only while i_space_ok = 1, so FX5 back-pressure (DMA_READY)
//     pauses the pattern instead of dropping pixels
//   - a new frame starts only after i_frame_go (frame-rate tick)
//
// The two sync outputs are re-used as in-band markers; they ride through
// test_pattern_gen and rgb2ycbcr709 with the same latency as DE:
//   o_vs = start of frame  (first pixel, x=0 y=0)
//   o_hs = end of line     (x = H_ACTIVE-1)
// o_frame_start pulses 4 clocks before the first pixel of each frame
// (use it where hdmi_tp_top uses o_vblank_start: pattern latch, frame count).
// ============================================================================
module tpg_raster_ce #(
    parameter int H_ACTIVE = 1920,
    parameter int V_ACTIVE = 1080
)(
    input  logic        clk,
    input  logic        rst,
    input  logic        i_frame_go,     // pulse: allow the next frame to start
    input  logic        i_space_ok,     // downstream FIFO can take more pixels
    output logic [11:0] o_x,
    output logic [11:0] o_y,
    output logic        o_de,
    output logic        o_hs,           // end-of-line marker
    output logic        o_vs,           // start-of-frame marker
    output logic        o_frame_start
);
    logic [11:0] x, y;
    logic        running, go_pend;
    logic [2:0]  lead;            // gap between o_frame_start and pixel (0,0)

    always_ff @(posedge clk) begin
        if (rst) begin
            x <= '0; y <= '0;
            running <= 1'b0; go_pend <= 1'b0; lead <= '0;
            o_de <= 1'b0; o_hs <= 1'b0; o_vs <= 1'b0;
            o_x <= '0; o_y <= '0;
            o_frame_start <= 1'b0;
        end else begin
            o_de          <= 1'b0;
            o_hs          <= 1'b0;
            o_vs          <= 1'b0;
            o_frame_start <= 1'b0;
            if (i_frame_go) go_pend <= 1'b1;

            if (!running) begin
                if (go_pend || i_frame_go) begin
                    running       <= 1'b1;
                    go_pend       <= 1'b0;
                    lead          <= 3'd4;
                    o_frame_start <= 1'b1;      // lets pattern/scroll settle before (0,0)
                end
            end else if (lead != 3'd0) begin
                lead <= lead - 3'd1;
            end else if (i_space_ok) begin
                o_de <= 1'b1;
                o_x  <= x;
                o_y  <= y;
                o_vs <= (x == 12'd0) && (y == 12'd0);
                o_hs <= (x == 12'(H_ACTIVE - 1));
                if (x == 12'(H_ACTIVE - 1)) begin
                    x <= '0;
                    if (y == 12'(V_ACTIVE - 1)) begin
                        y       <= '0;
                        running <= 1'b0;
                    end else begin
                        y <= y + 12'd1;
                    end
                end else begin
                    x <= x + 12'd1;
                end
            end
        end
    end
endmodule
