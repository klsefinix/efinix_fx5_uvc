// ============================================================================
// ycbcr444_to_422.sv
// Packs 4:4:4 YCbCr into the 16-bit 4:2:2 bus used by the ADV7511 card:
//   even pixel: {Cb, Y0}    odd pixel: {Cr, Y1}
// Cb and Cr are both taken from the even pixel (co-sited), as BT.601/709
// 4:2:2 expects. Phase restarts at the first pixel of every line.
// Same {C, Y} bit order as the Ti180 OOB hdmi_post_process output.
// ============================================================================
module ycbcr444_to_422 (
    input  logic        clk,
    input  logic        rst,
    input  logic        i_de, i_hs, i_vs,
    input  logic [7:0]  i_y, i_cb, i_cr,
    output logic        o_de, o_hs, o_vs,
    output logic [15:0] o_data
);
    logic       odd;
    logic [7:0] cr_hold;

    always_ff @(posedge clk) begin
        if (rst) begin
            odd <= 1'b0; cr_hold <= 8'd128;
            {o_de, o_hs, o_vs} <= '0;
            o_data <= 16'h8010;
        end else begin
            {o_de, o_hs, o_vs} <= {i_de, i_hs, i_vs};
            if (i_de) begin
                odd <= ~odd;
                if (!odd) begin
                    o_data  <= {i_cb, i_y};
                    cr_hold <= i_cr;
                end else begin
                    o_data  <= {cr_hold, i_y};
                end
            end else begin
                odd    <= 1'b0;
                o_data <= 16'h8010;   // black during blanking
            end
        end
    end
endmodule
