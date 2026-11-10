// -----------------------------------------------------------------------------
// fx_lvds_link_tx : FPGA-side LVDS transmitter for the EZ-USB FX5/FX10/FX20
//                   GPIF III LVDS receive port (narrow link, 8 data lanes,
//                   8:1 gearing - one byte per lane per parallel clock)
//
// Protocol per Infineon AN241535 / AN238689 and the Ti180 reference RTL:
//   * MSB of every byte is sent first on the wire. Efinix LVDS TX serializers
//     send bit 0 first, so bytes are bit-reversed at the output
//     (TX_LSB_FIRST = 1).
//   * Control lane carries one byte per transfer; bit 7 is odd parity
//     (except during PHY/LINK training, where the raw pattern is sent).
//        IDLE  = 0x01            data lanes ignored
//        DATA  = {P,len[5:0],0}  len = 0 -> all lanes valid (0x80)
//        STAD  = {P,0001,tt,1}   select GPIF thread tt
//        SSAD  = {P,001,kkk,1}   select socket kkk
//        EOP   = 0xEF            commit (partial) buffer to USB
//   * Training: on LINK_READY rising, PHY_TS byte on all lanes (min 50 us,
//     ends early on PHY_DONE or after PHY_TS_MAX_US), then the 4-byte link
//     training block P0..P3, then >= 3 us of IDLE.
//   * Flow control: after STAD/SSAD wait >= 100 clocks, then wait for
//     DMA_READY (P0CTL5 / FLAGA). Send exactly BUF_WORDS words of DATA,
//     then IDLE until DMA_READY drops, then wait again. The last buffer of a
//     frame is short and is closed with EOP.
//   * DMA_READY is also live back-pressure inside a buffer: the FX5 drops it
//     for a few to ~100 clocks when the FPGA sends faster than it can sink
//     (seen on hardware at the full 1 word/clock = 9.5 Gb/s). Inside a
//     buffer a word is only sent while DMA_READY is high (HONOR_READY_IN_BUF),
//     and words are spaced at least WORD_GAP clocks apart (2 -> 4.75 Gb/s,
//     still 2x the pattern source rate) so the FX5 rarely needs to throttle
//     and the few words in flight when it does stay small.
//
// Board-specific choices (Ti125F225 dev board Rev B1, FX5 CYUSB3083):
//   * No I2C between FX5 and FPGA (P10.0/P10.1 are NC), so everything the
//     Infineon flow would write over I2C is a parameter here, and two spare
//     P0CTL lines are used as firmware-driven GPIOs:
//        P0CTL4 -> phy_done   (FX firmware raises when PHY training finished)
//        P0CTL3 -> stream_en  (FX firmware raises on UVC COMMIT, drops on stop)
//     Both are optional (USE_PHY_DONE / USE_STREAM_EN) with timeout fallbacks.
//   * UVC payload headers are added by the FX5 firmware (manual DMA channel,
//     UVC_HEADER_BY_FX20=1), so the FPGA sends raw YUY2 only.
// -----------------------------------------------------------------------------
module fx_lvds_link_tx #(
    parameter integer CLK_HZ            = 148_500_000,
    parameter integer FRAME_BYTES       = 1920*1080*2,
    parameter integer BUF_BYTES         = 61440,      // FX DMA buffer minus 32-byte UVC header
    parameter [1:0]   THREAD            = 2'd0,
    parameter [2:0]   SOCKET            = 3'd0,
    parameter [7:0]   PHY_TS            = 8'h9C,
    parameter [31:0]  LINK_BLOCK        = 32'h125A4B78,  // P3 P2 P1 P0, P0 sent first
    parameter integer LINK_BLOCKS       = 1,
    parameter integer PHY_TS_MIN_US     = 50,
    parameter integer PHY_TS_MAX_US     = 10_000,
    parameter integer POST_TRAIN_IDLE_US= 3,
    parameter integer ADDR_TO_FLAG_CLKS = 128,        // >= 100 per AN241535
    parameter integer FLAG_SETTLE_CLKS  = 64,         // after a buffer/frame, ignore FLAGA this long
    parameter integer STALL_ABORT_MS    = 200,        // fallback stream-stop detect
    parameter         USE_PHY_DONE      = 1,
    parameter         USE_STREAM_EN     = 1,
    parameter         TX_LSB_FIRST      = 1,
    parameter integer WORD_GAP          = 2,          // min clocks per DATA word (1 = full rate)
    parameter         HONOR_READY_IN_BUF= 1,          // pause DATA while DMA_READY is low
    parameter [7:0]   CLK_LANE_PATTERN  = 8'hF0       // used only if the clock lane is a data-mode TX
) (
    input  wire        clk,
    input  wire        rst,
    // synchronized FX5 sideband
    input  wire        link_ready,
    input  wire        dma_ready,
    input  wire        phy_done,
    input  wire        stream_en,
    // video word FIFO (FWFT)
    input  wire [64:0] fifo_dout,      // {sof, data}
    input  wire        fifo_valid,
    output wire        fifo_rd,        // combinational pop (FWFT)
    output reg         flush,          // pulse: drop FIFO contents + restart source
    // parallel words to the Efinix LVDS TX blocks (already in serializer bit order)
    output reg  [63:0] tx_data,        // [8*i+7:8*i] -> data lane i
    output reg  [7:0]  tx_ctl,
    output wire [7:0]  tx_clk,
    // status
    output reg         trained,
    output reg         streaming,
    output reg         frame_done,     // 1-clk pulse per frame sent
    output reg  [15:0] frame_count,
    output reg  [7:0]  err_count
);
    // ---------------------------------------------------------------- constants
    localparam integer CLK_KHZ      = CLK_HZ / 1000;
    localparam integer PHY_MIN_CLKS = (CLK_KHZ * PHY_TS_MIN_US) / 1000;
    localparam integer PHY_MAX_CLKS = (CLK_KHZ * PHY_TS_MAX_US) / 1000;
    localparam integer POST_CLKS    = (CLK_KHZ * POST_TRAIN_IDLE_US) / 1000 + 1;
    localparam integer STALL_CLKS   = CLK_KHZ * STALL_ABORT_MS;
    localparam integer FRAME_WORDS  = FRAME_BYTES / 8;
    localparam integer BUF_WORDS    = BUF_BYTES / 8;

    localparam [7:0] C_IDLE = 8'h01;
    localparam [7:0] C_DATA = 8'h80;
    localparam [7:0] C_EOP  = 8'hEF;

    function [7:0] with_parity(input [6:0] b);
        with_parity = {~^b, b};          // odd parity over all 8 bits
    endfunction
    localparam [7:0] C_STAD = {~^{4'b0001, THREAD, 1'b1}, 4'b0001, THREAD, 1'b1};
    localparam [7:0] C_SSAD = {~^{3'b001, SOCKET, 1'b1}, 3'b001, SOCKET, 1'b1};

    // byte -> serializer order
    function [7:0] ser(input [7:0] b);
        integer k;
        begin
            if (TX_LSB_FIRST) for (k = 0; k < 8; k = k + 1) ser[k] = b[7-k];
            else ser = b;
        end
    endfunction

    // ------------------------------------------------------------------- state
    localparam [4:0]
        S_WAIT_LINK  = 5'd0,
        S_PHY        = 5'd1,
        S_LINK       = 5'd2,
        S_POST_IDLE  = 5'd3,
        S_READY      = 5'd4,
        S_STAD       = 5'd5,
        S_SSAD       = 5'd6,
        S_ADDR_GAP   = 5'd7,
        S_WAIT_DMA   = 5'd8,
        S_DATA       = 5'd9,
        S_WAIT_DROP  = 5'd10,
        S_EOP        = 5'd11,
        S_EOF_DROP   = 5'd12,
        S_ABORT      = 5'd13;

    reg [4:0]  st = S_WAIT_LINK;
    reg [31:0] tmr = 0;
    reg [7:0]  lcnt = 0;                 // link-training byte counter
    reg [31:0] frame_left = 0;           // words remaining in frame
    reg [31:0] buf_left = 0;             // words remaining in current buffer
    reg        buf_partial = 1'b0;       // current buffer is shorter than BUF_WORDS
    reg        mid_frame = 1'b0;         // at least one word of this frame sent
    reg        link_q = 1'b0;
    reg        saw_low = 1'b0;           // FLAGA seen low after the buffer filled

    wire link_rise = link_ready & ~link_q;
    wire stream_ok = USE_STREAM_EN ? stream_en : 1'b1;

    // next-byte registers (bit-reversed into tx_* below)
    reg [7:0]  ctl_b;
    reg [63:0] dat_b;

    // link-training byte select (P0 first)
    wire [7:0] link_byte = LINK_BLOCK >> (8 * lcnt[1:0]);

    // word pacing + in-buffer back-pressure
    reg  [7:0] pace_cnt = 0;
    wire can_send    = (pace_cnt == 8'd0) && (dma_ready || (HONOR_READY_IN_BUF == 0));

    // combinational FIFO pop: at most one word per WORD_GAP clocks in S_DATA
    wire abort_any   = rst | ~link_ready | (link_rise & (st != S_WAIT_LINK));
    wire pop_data    = (st == S_DATA)  & fifo_valid & can_send & ~(fifo_dout[64] & mid_frame);
    wire pop_discard = (st == S_READY) & stream_ok & fifo_valid & ~fifo_dout[64];
    assign fifo_rd   = ~abort_any & (pop_data | pop_discard);

    integer i;
    always @(posedge clk) begin
        link_q     <= link_ready;
        flush      <= 1'b0;
        if (pace_cnt != 0) pace_cnt <= pace_cnt - 1'b1;
        frame_done <= 1'b0;
        ctl_b      <= C_IDLE;
        dat_b      <= {8{C_IDLE}};

        if (rst) begin
            st          <= S_WAIT_LINK;
            trained     <= 1'b0;
            streaming   <= 1'b0;
            frame_count <= 0;
            err_count   <= 0;
            tmr         <= 0;
            mid_frame   <= 1'b0;
        end else if (!link_ready && st != S_WAIT_LINK) begin
            // FX dropped LINK_READY (reset / retrain request): stop everything
            st        <= S_WAIT_LINK;
            trained   <= 1'b0;
            streaming <= 1'b0;
            flush     <= 1'b1;
            mid_frame <= 1'b0;
        end else if (link_rise && st != S_WAIT_LINK) begin
            // FX re-asserted LINK_READY: retrain from scratch
            st      <= S_PHY;
            tmr     <= 0;
            trained <= 1'b0;
            flush   <= 1'b1;
            mid_frame <= 1'b0;
        end else begin
            case (st)
            // ---------------------------------------------------- training
            S_WAIT_LINK: begin
                if (link_ready) begin           // level: covers LINK_READY already high at FPGA config
                    st  <= S_PHY;
                    tmr <= 0;
                end
            end

            S_PHY: begin
                ctl_b <= PHY_TS;
                dat_b <= {8{PHY_TS}};
                tmr   <= tmr + 1;
                // With the PHY_DONE sideband the FPGA holds PHY_TS until the
                // firmware says so (the FX5 firmware's custom DLL-phase sweep
                // can take far longer than 10 ms). PHY_TS_MAX only applies
                // when USE_PHY_DONE = 0.
                if ((tmr >= PHY_MIN_CLKS - 1 && USE_PHY_DONE && phy_done) ||
                    (!USE_PHY_DONE && tmr >= PHY_MAX_CLKS - 1)) begin
                    st   <= S_LINK;
                    lcnt <= 0;
                end
            end

            S_LINK: begin
                ctl_b <= link_byte;
                dat_b <= {8{link_byte}};
                lcnt  <= lcnt + 1;
                if (lcnt == 4*LINK_BLOCKS - 1) begin
                    st  <= S_POST_IDLE;
                    tmr <= 0;
                end
            end

            S_POST_IDLE: begin
                tmr <= tmr + 1;
                if (tmr >= POST_CLKS) begin
                    st      <= S_READY;
                    trained <= 1'b1;
                end
            end

            // ---------------------------------------------------- framing
            S_READY: begin
                streaming <= 1'b0;
                if (stream_ok && fifo_valid) begin
                    if (!fifo_dout[64]) begin
                        // pop_discard drops words until start-of-frame
                    end else begin
                        st         <= S_STAD;
                        frame_left <= FRAME_WORDS;
                        mid_frame  <= 1'b0;
                    end
                end
            end

            S_STAD: begin ctl_b <= C_STAD; st <= S_SSAD; end
            S_SSAD: begin ctl_b <= C_SSAD; st <= S_ADDR_GAP; tmr <= 0; end

            S_ADDR_GAP: begin
                tmr <= tmr + 1;
                if (tmr >= ADDR_TO_FLAG_CLKS) begin st <= S_WAIT_DMA; tmr <= 0; end
            end

            S_WAIT_DMA: begin
                tmr <= tmr + 1;
                if (!stream_ok) begin
                    st <= S_ABORT;
                end else if (dma_ready) begin
                    st          <= S_DATA;
                    streaming   <= 1'b1;
                    buf_partial <= (frame_left < BUF_WORDS);
                    buf_left    <= (frame_left < BUF_WORDS) ? frame_left : BUF_WORDS;
                    tmr         <= 0;
                end else if (mid_frame && tmr >= STALL_CLKS) begin
                    st <= S_ABORT;                // host stopped mid-frame (no STREAM_EN GPIO)
                end
            end

            S_DATA: begin
                // Words are sent when the FIFO has one, the pacing gap has
                // elapsed and the FX5 is not throttling; IDLE fills the rest.
                tmr <= tmr + 1;
                if (!stream_ok) begin
                    st <= S_ABORT;                // host stopped mid-buffer
                end else if (fifo_valid && fifo_dout[64] && mid_frame) begin
                    // unexpected start-of-frame: source restarted, close what we have
                    err_count <= err_count + 1'b1;
                    st        <= S_EOP;
                end else if (fifo_valid && can_send) begin
                    ctl_b      <= C_DATA;
                    dat_b      <= fifo_dout[63:0];     // popped by pop_data
                    mid_frame  <= 1'b1;
                    pace_cnt   <= WORD_GAP - 1;
                    buf_left   <= buf_left - 1;
                    frame_left <= frame_left - 1;
                    tmr        <= 0;
                    if (buf_left == 1) begin
                        if (frame_left == 1)
                            st <= buf_partial ? S_EOP : S_EOF_DROP;
                        else begin
                            st      <= S_WAIT_DROP;
                            saw_low <= 1'b0;
                        end
                    end
                end else if (tmr >= STALL_CLKS) begin
                    st <= S_ABORT;                // FX5 stopped taking data
                end
            end

            S_WAIT_DROP: begin
                // Buffer full. FLAGA drops within a few clocks of the last
                // word (Infineon: 3-4 clocks), but it also dips for
                // back-pressure, so a low flag right here is ambiguous. Hold
                // off FLAG_SETTLE_CLKS, then use DMA_READY high = next buffer.
                tmr <= tmr + 1;
                if (!dma_ready) saw_low <= 1'b1;
                if (tmr >= FLAG_SETTLE_CLKS - 1) begin
                    if (dma_ready && !saw_low) err_count <= err_count + 1'b1;  // FX never saw the buffer fill
                    st  <= S_WAIT_DMA;
                    tmr <= 0;
                end
            end

            S_EOP: begin                          // send EOP while the FX5 is accepting
                if (!stream_ok) begin
                    st <= S_ABORT;
                end else if (dma_ready || (HONOR_READY_IN_BUF == 0)) begin
                    ctl_b <= C_EOP;
                    st    <= S_EOF_DROP;
                    tmr   <= 0;
                end
            end

            S_EOF_DROP: begin                     // frame closed; let the flag settle
                tmr <= tmr + 1;
                if (tmr >= FLAG_SETTLE_CLKS - 1) begin
                    st          <= S_READY;
                    mid_frame   <= 1'b0;
                    frame_done  <= 1'b1;
                    frame_count <= frame_count + 1'b1;
                end
            end

            S_ABORT: begin
                flush     <= 1'b1;
                streaming <= 1'b0;
                mid_frame <= 1'b0;
                st        <= S_READY;
            end

            default: st <= S_WAIT_LINK;
            endcase
        end
    end

    // output register stage in serializer bit order
    always @(posedge clk) begin
        tx_ctl <= ser(ctl_b);
        for (i = 0; i < 8; i = i + 1)
            tx_data[8*i +: 8] <= ser(dat_b[8*i +: 8]);
    end

    assign tx_clk = CLK_LANE_PATTERN;

    // keep with_parity referenced for readers / future control bytes
    wire [7:0] unused_parity_example = with_parity(7'h00);   // == C_DATA
endmodule
