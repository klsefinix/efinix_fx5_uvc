// ============================================================================
// i2c_master_wr.sv
// Minimal I2C master for register writes: START | ADDR+W | REG | DATA | STOP
//
//  - Open-drain style: *_oe = 1 pulls the line low, *_oe = 0 releases it.
//    Tie the GPIO OUT pin to 0 and drive OE from these signals.
//  - Checks ACK on every byte; a NACK aborts with STOP and reports o_nack.
//  - Supports slave clock stretching (waits for SCL high after release).
// ============================================================================
module i2c_master_wr #(
    parameter int CLK_HZ = 148_500_000,
    parameter int I2C_HZ = 100_000
)(
    input  logic       clk,
    input  logic       rst,

    input  logic       i_start,      // pulse: begin a write transaction
    input  logic [6:0] i_dev_addr,   // 7-bit device address
    input  logic [7:0] i_reg,
    input  logic [7:0] i_data,
    output logic       o_busy,
    output logic       o_done,       // 1-clk pulse when transaction ends
    output logic       o_nack,       // valid with o_done: 1 = a byte was NACKed

    input  logic       i_scl,
    output logic       o_scl_oe,
    input  logic       i_sda,
    output logic       o_sda_oe
);
    // Quarter-bit period
    localparam int QDIV = (CLK_HZ / (4 * I2C_HZ)) < 2 ? 2 : (CLK_HZ / (4 * I2C_HZ));
    localparam int QW   = $clog2(QDIV + 1);

    typedef enum logic [2:0] {S_IDLE, S_START, S_BIT, S_ACK, S_STOP, S_DONE} state_t;
    state_t state;

    logic [QW-1:0] qcnt;
    logic [1:0]    q;          // quarter index within a bit
    logic [2:0]    bitn;
    logic [1:0]    byten;
    logic [7:0]    sh;
    logic [7:0]    reg_l, data_l;
    logic          nack_l;

    // Input synchronizers
    logic [1:0] scl_s, sda_s;
    always_ff @(posedge clk) begin
        scl_s <= {scl_s[0], i_scl};
        sda_s <= {sda_s[0], i_sda};
    end
    wire scl_in = scl_s[1];
    wire sda_in = sda_s[1];

    wire qtick = (qcnt == QW'(QDIV - 1));
    // SCL is released by the q=1 action; hold the q=2 step until SCL is really
    // high (rise time / slave clock stretching)
    wire stretch = (q == 2'd2) && !scl_in &&
                   (state == S_BIT || state == S_ACK || state == S_STOP);

    assign o_busy = (state != S_IDLE);

    always_ff @(posedge clk) begin
        if (rst) begin
            state    <= S_IDLE;
            qcnt     <= '0;
            q        <= '0;
            bitn     <= '0;
            byten    <= '0;
            sh       <= '0;
            reg_l    <= '0;
            data_l   <= '0;
            nack_l   <= 1'b0;
            o_scl_oe <= 1'b0;
            o_sda_oe <= 1'b0;
            o_done   <= 1'b0;
            o_nack   <= 1'b0;
        end else begin
            o_done <= 1'b0;

            if (state == S_IDLE) begin
                qcnt     <= '0;
                q        <= '0;
                o_scl_oe <= 1'b0;
                o_sda_oe <= 1'b0;
                if (i_start) begin
                    sh     <= {i_dev_addr, 1'b0};     // R/W = 0 (write)
                    reg_l  <= i_reg;
                    data_l <= i_data;
                    byten  <= '0;
                    bitn   <= '0;
                    nack_l <= 1'b0;
                    state  <= S_START;
                end
            end else if (qtick && !stretch) begin
                qcnt <= '0;
                q    <= q + 2'd1;

                case (state)
                    // SDA falls while SCL high, then SCL low
                    S_START: begin
                        case (q)
                            2'd0: begin o_sda_oe <= 1'b0; o_scl_oe <= 1'b0; end
                            2'd1: o_sda_oe <= 1'b1;
                            2'd2: ;
                            2'd3: begin o_scl_oe <= 1'b1; state <= S_BIT; end
                        endcase
                    end

                    S_BIT: begin
                        case (q)
                            2'd0: o_sda_oe <= ~sh[7];           // set data while SCL low
                            2'd1: o_scl_oe <= 1'b0;             // release SCL
                            2'd2: ;                             // SCL high
                            2'd3: begin
                                o_scl_oe <= 1'b1;
                                sh       <= {sh[6:0], 1'b0};
                                bitn     <= bitn + 3'd1;
                                if (bitn == 3'd7) state <= S_ACK;
                            end
                        endcase
                    end

                    S_ACK: begin
                        case (q)
                            2'd0: o_sda_oe <= 1'b0;             // release SDA for slave
                            2'd1: o_scl_oe <= 1'b0;
                            2'd2: if (sda_in) nack_l <= 1'b1;   // sample ACK while SCL high
                            2'd3: begin
                                o_scl_oe <= 1'b1;
                                if (nack_l || byten == 2'd2) begin
                                    state <= S_STOP;
                                end else begin
                                    byten <= byten + 2'd1;
                                    sh    <= (byten == 2'd0) ? reg_l : data_l;
                                    state <= S_BIT;
                                end
                            end
                        endcase
                    end

                    // SDA rises while SCL high
                    S_STOP: begin
                        case (q)
                            2'd0: o_sda_oe <= 1'b1;
                            2'd1: o_scl_oe <= 1'b0;
                            2'd2: o_sda_oe <= 1'b0;
                            2'd3: state <= S_DONE;              // bus-free time
                        endcase
                    end

                    S_DONE: begin
                        o_done <= 1'b1;
                        o_nack <= nack_l;
                        state  <= S_IDLE;
                    end

                    default: state <= S_IDLE;
                endcase
            end else if (!stretch) begin
                qcnt <= qcnt + QW'(1);
            end
        end
    end
endmodule
