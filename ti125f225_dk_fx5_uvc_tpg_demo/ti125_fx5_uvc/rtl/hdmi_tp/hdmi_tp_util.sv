// ============================================================================
// hdmi_tp_util.sv
// Small helpers: reset synchronizer, 1 us tick, pushbutton debounce.
// ============================================================================

// ----------------------------------------------------------------------------
// Asynchronous assert / synchronous release reset
// ----------------------------------------------------------------------------
module tp_rst_sync #(
    parameter int STAGES = 4
)(
    input  logic clk,
    input  logic i_arst,     // active high, asynchronous
    output logic o_rst       // active high, synchronous to clk
);
    logic [STAGES-1:0] sr;
    always_ff @(posedge clk or posedge i_arst) begin
        if (i_arst) sr <= '1;
        else        sr <= {sr[STAGES-2:0], 1'b0};
    end
    assign o_rst = sr[STAGES-1];
endmodule

// ----------------------------------------------------------------------------
// 1 microsecond strobe (rounded to the nearest whole clock count)
// ----------------------------------------------------------------------------
module tp_us_tick #(
    parameter int CLK_HZ = 148_500_000
)(
    input  logic clk,
    input  logic rst,
    output logic o_tick
);
    localparam int DIV = ((CLK_HZ + 500_000) / 1_000_000) < 1 ? 1
                       : ((CLK_HZ + 500_000) / 1_000_000);
    localparam int W   = $clog2(DIV + 1);
    logic [W-1:0] cnt;
    always_ff @(posedge clk) begin
        if (rst) begin
            cnt <= '0; o_tick <= 1'b0;
        end else begin
            o_tick <= (cnt == W'(DIV - 1));
            cnt    <= (cnt == W'(DIV - 1)) ? '0 : cnt + W'(1);
        end
    end
endmodule

// ----------------------------------------------------------------------------
// Pushbutton: 2-FF sync, debounce (input must be stable DEBOUNCE_US),
// short press -> o_short (pulse on release, if held < LONG_US)
// long press  -> o_long  (pulse once when held for LONG_US)
// ----------------------------------------------------------------------------
module tp_btn_debounce #(
    parameter int DEBOUNCE_US = 20_000,
    parameter int LONG_US     = 1_500_000,
    parameter bit ACTIVE_LOW  = 1'b1
)(
    input  logic clk,
    input  logic rst,
    input  logic i_us_tick,
    input  logic i_btn,
    output logic o_pressed,   // debounced level
    output logic o_short,
    output logic o_long
);
    logic [2:0]  sync;
    logic        raw, stable, long_fired;
    logic [31:0] db_cnt, hold_cnt;

    always_ff @(posedge clk) begin
        if (rst) sync <= {3{ACTIVE_LOW}};
        else     sync <= {sync[1:0], i_btn};
    end
    assign raw = ACTIVE_LOW ? ~sync[2] : sync[2];

    always_ff @(posedge clk) begin
        if (rst) begin
            stable <= 1'b0; db_cnt <= '0; hold_cnt <= '0;
            long_fired <= 1'b0; o_short <= 1'b0; o_long <= 1'b0;
        end else begin
            o_short <= 1'b0;
            o_long  <= 1'b0;

            // debounce
            if (raw == stable) begin
                db_cnt <= '0;
            end else if (i_us_tick) begin
                if (db_cnt >= 32'(DEBOUNCE_US)) begin
                    stable <= raw;
                    db_cnt <= '0;
                    if (!raw) begin                 // release
                        if (!long_fired) o_short <= 1'b1;
                        long_fired <= 1'b0;
                    end
                    hold_cnt <= '0;
                end else begin
                    db_cnt <= db_cnt + 32'd1;
                end
            end

            // long-press detection
            if (stable && !long_fired && i_us_tick) begin
                if (hold_cnt >= 32'(LONG_US)) begin
                    o_long     <= 1'b1;
                    long_fired <= 1'b1;
                end else begin
                    hold_cnt <= hold_cnt + 32'd1;
                end
            end
        end
    end
    assign o_pressed = stable;
endmodule
