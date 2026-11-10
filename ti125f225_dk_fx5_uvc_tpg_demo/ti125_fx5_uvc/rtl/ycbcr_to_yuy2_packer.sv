// ============================================================================
// ycbcr_to_yuy2_packer.sv
// YCbCr 4:4:4 pixel stream (from rgb2ycbcr709) -> UVC YUY2 64-bit words.
//
// Same 4:2:2 decimation as ycbcr444_to_422 (Cb and Cr from the even pixel),
// but packed for an 8-lane FX link instead of the ADV7511's 16-bit bus:
//     lane : 0  1  2  3  4  5  6  7          (o_word[7:0] = lane 0)
//     byte : Y0 U0 Y1 V0 Y2 U2 Y3 V2
// i_de may drop for any number of clocks mid-line (flow control); the
// pixel phase only restarts on i_sof. H_ACTIVE must be a multiple of 4.
// o_word = {sof, data[63:0]}; sof marks the first word of a frame.
// ============================================================================
module ycbcr_to_yuy2_packer (
    input  logic        clk,
    input  logic        rst,
    input  logic        i_de,
    input  logic        i_sof,
    input  logic [7:0]  i_y, i_cb, i_cr,
    output logic        o_wr,
    output logic [64:0] o_word
);
    logic [1:0]  ph;
    logic [47:0] acc;
    logic [7:0]  cr_even;
    logic        grp_sof;

    always_ff @(posedge clk) begin
        if (rst) begin
            ph <= '0; o_wr <= 1'b0; grp_sof <= 1'b0;
        end else begin
            o_wr <= 1'b0;
            if (i_de) begin
                logic [1:0] p;
                p  = i_sof ? 2'd0 : ph;
                ph <= p + 2'd1;
                case (p)
                    2'd0: begin acc[15:0]  <= {i_cb, i_y}; cr_even <= i_cr; grp_sof <= i_sof; end
                    2'd1: begin acc[31:16] <= {cr_even, i_y}; end
                    2'd2: begin acc[47:32] <= {i_cb, i_y}; cr_even <= i_cr; end
                    2'd3: begin
                        o_word <= {grp_sof, cr_even, i_y, acc};
                        o_wr   <= 1'b1;
                    end
                endcase
            end
        end
    end
endmodule
