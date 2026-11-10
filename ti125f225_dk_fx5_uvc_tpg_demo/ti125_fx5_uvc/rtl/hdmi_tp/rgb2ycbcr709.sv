// ============================================================================
// rgb2ycbcr709.sv
// 8-bit full-range RGB -> BT.709 limited-range YCbCr (Y 16..235, C 16..240).
// Matches the ADV7511 CSC table programmed by adv7511_init (BT.709 YCbCr ->
// RGB), so colours round-trip correctly.
//
// Coefficients x1024:
//   Y  =  16 + ( 187 R + 629 G +  63 B) / 1024
//   Cb = 128 + (-103 R - 347 G + 450 B) / 1024
//   Cr = 128 + ( 450 R - 409 G -  41 B) / 1024
//
// 3-clock latency. i_byp passes i_y/i_cb/i_cr straight through (same latency).
// ============================================================================
module rgb2ycbcr709 (
    input  logic       clk,
    input  logic       rst,
    input  logic       i_de, i_hs, i_vs,
    input  logic [7:0] i_r, i_g, i_b,
    input  logic       i_byp,
    input  logic [7:0] i_y, i_cb, i_cr,
    output logic       o_de, o_hs, o_vs,
    output logic [7:0] o_y, o_cb, o_cr
);
    // stage 1: products
    logic signed [21:0] yr, yg, yb, br, bg, bb, rr, rg, rb;
    logic [2:0] s1_sync;
    logic       s1_byp;
    logic [7:0] s1_y, s1_cb, s1_cr;

    // stage 2: sums
    logic signed [21:0] sy, scb, scr;
    logic [2:0] s2_sync;
    logic       s2_byp;
    logic [7:0] s2_y, s2_cb, s2_cr;

    function automatic logic [7:0] clamp8(input logic signed [21:0] v);
        logic signed [21:0] q;
        q = v >>> 10;
        if (q < 22'sd1)        clamp8 = 8'd1;
        else if (q > 22'sd254) clamp8 = 8'd254;
        else                   clamp8 = q[7:0];
    endfunction

    always_ff @(posedge clk) begin
        if (rst) begin
            s1_sync <= '0; s2_sync <= '0;
            {o_de, o_hs, o_vs} <= '0;
            o_y <= 8'd16; o_cb <= 8'd128; o_cr <= 8'd128;
        end else begin
            // ---- stage 1
            yr <=  22'sd187 * $signed({1'b0, i_r});
            yg <=  22'sd629 * $signed({1'b0, i_g});
            yb <=  22'sd63  * $signed({1'b0, i_b});
            br <= -22'sd103 * $signed({1'b0, i_r});
            bg <= -22'sd347 * $signed({1'b0, i_g});
            bb <=  22'sd450 * $signed({1'b0, i_b});
            rr <=  22'sd450 * $signed({1'b0, i_r});
            rg <= -22'sd409 * $signed({1'b0, i_g});
            rb <= -22'sd41  * $signed({1'b0, i_b});
            s1_sync <= {i_de, i_hs, i_vs};
            s1_byp  <= i_byp;
            s1_y    <= i_y; s1_cb <= i_cb; s1_cr <= i_cr;

            // ---- stage 2 (offset + rounding folded in)
            sy  <= yr + yg + yb + 22'sd16384  + 22'sd512;   //  16<<10
            scb <= br + bg + bb + 22'sd131072 + 22'sd512;   // 128<<10
            scr <= rr + rg + rb + 22'sd131072 + 22'sd512;
            s2_sync <= s1_sync;
            s2_byp  <= s1_byp;
            s2_y    <= s1_y; s2_cb <= s1_cb; s2_cr <= s1_cr;

            // ---- stage 3
            {o_de, o_hs, o_vs} <= s2_sync;
            if (s2_byp) begin
                o_y <= s2_y; o_cb <= s2_cb; o_cr <= s2_cr;
            end else begin
                o_y <= clamp8(sy); o_cb <= clamp8(scb); o_cr <= clamp8(scr);
            end
        end
    end
endmodule
