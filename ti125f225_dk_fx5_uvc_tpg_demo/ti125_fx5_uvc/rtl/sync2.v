// -----------------------------------------------------------------------------
// sync2 : two-flop synchronizer for asynchronous single-bit inputs
//         (FX5 P0CTL sideband: LINK_READY, DMA_READY, PHY_DONE, STREAM_EN)
// -----------------------------------------------------------------------------
module sync2 #(
    parameter INIT = 1'b0
) (
    input  wire clk,
    input  wire d,
    output wire q
);
    (* async_reg = "true" *) reg s1 = INIT;
    (* async_reg = "true" *) reg s2 = INIT;
    always @(posedge clk) begin
        s1 <= d;
        s2 <= s1;
    end
    assign q = s2;
endmodule
