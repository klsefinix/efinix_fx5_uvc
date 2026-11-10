// -----------------------------------------------------------------------------
// sync_fifo_fwft : single-clock first-word-fall-through FIFO
//
// - Memory read is registered, so Efinity infers block RAM (RAM10/RAM20).
// - 'count' includes the word sitting in the output register.
// - 'srst' is a synchronous flush (used when a frame is aborted).
// -----------------------------------------------------------------------------
module sync_fifo_fwft #(
    parameter WIDTH  = 65,
    parameter AWIDTH = 10            // depth = 2**AWIDTH
) (
    input  wire              clk,
    input  wire              srst,
    // write side
    input  wire              wr_en,
    input  wire [WIDTH-1:0]  wr_data,
    // read side (FWFT)
    input  wire              rd_en,      // pop the word on dout
    output reg  [WIDTH-1:0]  dout,
    output reg               dout_valid,
    // status
    output wire [AWIDTH:0]   count
);
    localparam DEPTH = (1 << AWIDTH);

    reg [WIDTH-1:0]  mem [0:DEPTH-1];
    reg [AWIDTH-1:0] wptr = {AWIDTH{1'b0}};
    reg [AWIDTH-1:0] rptr = {AWIDTH{1'b0}};
    reg [AWIDTH:0]   mcount = {(AWIDTH+1){1'b0}};   // words held in mem

    wire do_pop  = dout_valid & rd_en;
    wire do_load = (mcount != 0) & (~dout_valid | do_pop);
    wire do_wr   = wr_en & (mcount != DEPTH);

    always @(posedge clk) begin
        if (do_wr) mem[wptr] <= wr_data;
    end

    always @(posedge clk) begin
        if (do_load) dout <= mem[rptr];
    end

    always @(posedge clk) begin
        if (srst) begin
            wptr       <= {AWIDTH{1'b0}};
            rptr       <= {AWIDTH{1'b0}};
            mcount     <= {(AWIDTH+1){1'b0}};
            dout_valid <= 1'b0;
        end else begin
            if (do_wr)   wptr <= wptr + 1'b1;
            if (do_load) rptr <= rptr + 1'b1;
            case ({do_wr, do_load})
                2'b10:   mcount <= mcount + 1'b1;
                2'b01:   mcount <= mcount - 1'b1;
                default: mcount <= mcount;
            endcase
            if (do_load)     dout_valid <= 1'b1;
            else if (do_pop) dout_valid <= 1'b0;
        end
    end

    assign count = mcount + {{AWIDTH{1'b0}}, dout_valid};
endmodule
