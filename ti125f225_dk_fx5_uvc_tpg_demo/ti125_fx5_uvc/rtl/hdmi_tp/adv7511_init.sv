// ============================================================================
// adv7511_init.sv
// Writes the ADV7511 register set over I2C after power-up.
//
// The register table is the same sequence the Ti180 OOB design loads from
// adv7511_reg.mem, built in as a case-statement ROM so no .mem file or
// relative path is needed. Input format it configures:
//   YCbCr 4:2:2, 16-bit, separate HS/VS/DE (ID 1, style 1, 8-bit),
//   ADV7511 CSC converts BT.709 limited-range YCbCr -> RGB, HDMI mode, 16:9.
//
// Behaviour:
//   - waits POWERUP_US after reset, then writes every entry
//   - any NACK: o_cfg_err=1, wait RETRY_US, rewrite the whole table
//   - i_reconfig pulse: rewrite the whole table (e.g. after a monitor swap)
//   - REFRESH_US > 0: rewrite periodically (0 = off)
// ============================================================================
module adv7511_init #(
    parameter int CLK_HZ     = 148_500_000,
    parameter int I2C_HZ     = 100_000,
    parameter int POWERUP_US = 200_000,
    parameter int RETRY_US   = 500_000,
    parameter int REFRESH_US = 0,
    parameter logic [6:0] DEV_ADDR = 7'h39     // 0x72 >> 1 (PD/AD pin low)
)(
    input  logic clk,
    input  logic rst,
    input  logic i_us_tick,        // 1 us strobe
    input  logic i_reconfig,       // pulse

    output logic o_cfg_done,       // last full pass completed with all ACKs
    output logic o_cfg_err,        // last pass hit a NACK
    output logic o_cfg_busy,

    input  logic i_scl,
    output logic o_scl_oe,
    input  logic i_sda,
    output logic o_sda_oe
);
    localparam int N_REGS = 51;

    // {register, value}
    function automatic logic [15:0] rom(input logic [5:0] i);
        case (i)
            6'd0 : rom = 16'hD6_C0;  // HPD forced high (don't depend on HPD line)
            6'd1 : rom = 16'h15_01;  // Input ID 1: YCbCr 4:2:2, separate syncs
            6'd2 : rom = 16'h16_38;  // Out 4:4:4, 8-bit, style 1
            // 0x18-0x2F: CSC = HDTV (BT.709) YCbCr limited -> RGB, enabled
            6'd3 : rom = 16'h18_E7;
            6'd4 : rom = 16'h19_34;
            6'd5 : rom = 16'h1A_04;
            6'd6 : rom = 16'h1B_AD;
            6'd7 : rom = 16'h1C_00;
            6'd8 : rom = 16'h1D_00;
            6'd9 : rom = 16'h1E_1C;
            6'd10: rom = 16'h1F_1B;
            6'd11: rom = 16'h20_1D;
            6'd12: rom = 16'h21_DC;
            6'd13: rom = 16'h22_04;
            6'd14: rom = 16'h23_AD;
            6'd15: rom = 16'h24_1F;
            6'd16: rom = 16'h25_24;
            6'd17: rom = 16'h26_01;
            6'd18: rom = 16'h27_35;
            6'd19: rom = 16'h28_00;
            6'd20: rom = 16'h29_00;
            6'd21: rom = 16'h2A_04;
            6'd22: rom = 16'h2B_AD;
            6'd23: rom = 16'h2C_08;
            6'd24: rom = 16'h2D_7C;
            6'd25: rom = 16'h2E_1B;
            6'd26: rom = 16'h2F_77;
            6'd27: rom = 16'h41_10;  // Power up
            6'd28: rom = 16'h48_08;  // Video input justification: right
            6'd29: rom = 16'h55_00;  // AVI InfoFrame: RGB
            6'd30: rom = 16'h56_28;  // AVI InfoFrame: 16:9
            6'd31: rom = 16'h96_C0;  // Clear HPD / monitor-sense interrupts
            6'd32: rom = 16'h98_03;  // Fixed (per ADI programming guide)
            6'd33: rom = 16'h9A_E0;  // Fixed
            6'd34: rom = 16'h9C_30;  // Fixed
            6'd35: rom = 16'h9D_61;  // Fixed / clock divide
            6'd36: rom = 16'hA2_A4;  // Fixed
            6'd37: rom = 16'hA3_A4;  // Fixed
            6'd38: rom = 16'hAF_06;  // HDMI mode (not DVI)
            6'd39: rom = 16'hBA_60;  // Input clock delay = 0
            6'd40: rom = 16'hD6_C0;  // HPD forced high (again, after power-up)
            6'd41: rom = 16'hE0_D0;  // Fixed
            6'd42: rom = 16'hDF_01;  // Carried over from OOB sequence
            6'd43: rom = 16'h9A_E0;  // Fixed
            6'd44: rom = 16'hFD_E0;  // Carried over from OOB sequence
            6'd45: rom = 16'hFE_80;  // Carried over from OOB sequence
            6'd46: rom = 16'hF9_00;  // Fixed
            6'd47: rom = 16'h7F_00;  // Carried over from OOB sequence
            6'd48: rom = 16'h94_00;  // Interrupt enables off
            6'd49: rom = 16'hE2_01;  // Carried over from OOB sequence
            6'd50: rom = 16'h41_10;  // Power up (final)
            default: rom = 16'h41_10;
        endcase
    endfunction

    // ---- I2C engine ----
    logic       i2c_start, i2c_busy, i2c_done, i2c_nack;
    logic [5:0] idx;
    logic [15:0] entry;
    assign entry = rom(idx);

    i2c_master_wr #(.CLK_HZ(CLK_HZ), .I2C_HZ(I2C_HZ)) u_i2c (
        .clk(clk), .rst(rst),
        .i_start(i2c_start), .i_dev_addr(DEV_ADDR),
        .i_reg(entry[15:8]), .i_data(entry[7:0]),
        .o_busy(i2c_busy), .o_done(i2c_done), .o_nack(i2c_nack),
        .i_scl(i_scl), .o_scl_oe(o_scl_oe),
        .i_sda(i_sda), .o_sda_oe(o_sda_oe)
    );

    // ---- Sequencer ----
    typedef enum logic [2:0] {C_WAIT, C_ISSUE, C_XFER, C_IDLE} cstate_t;
    cstate_t    cs;
    logic [31:0] us_cnt, us_target;
    logic        reconfig_pend;

    assign o_cfg_busy = (cs == C_ISSUE) || (cs == C_XFER);

    always_ff @(posedge clk) begin
        if (rst) begin
            cs            <= C_WAIT;
            us_cnt        <= '0;
            us_target     <= 32'(POWERUP_US);
            idx           <= '0;
            i2c_start     <= 1'b0;
            o_cfg_done    <= 1'b0;
            o_cfg_err     <= 1'b0;
            reconfig_pend <= 1'b0;
        end else begin
            i2c_start <= 1'b0;
            if (i_reconfig) reconfig_pend <= 1'b1;

            case (cs)
                C_WAIT: begin
                    if (us_cnt >= us_target) begin
                        us_cnt        <= '0;
                        idx           <= '0;
                        reconfig_pend <= 1'b0;
                        cs            <= C_ISSUE;
                    end else if (i_us_tick) begin
                        us_cnt <= us_cnt + 32'd1;
                    end
                end

                C_ISSUE: begin
                    if (!i2c_busy) begin
                        i2c_start <= 1'b1;
                        cs        <= C_XFER;
                    end
                end

                C_XFER: begin
                    if (i2c_done) begin
                        if (i2c_nack) begin
                            // Abort this pass; retry the whole table later
                            o_cfg_err  <= 1'b1;
                            o_cfg_done <= 1'b0;
                            us_cnt     <= '0;
                            us_target  <= 32'(RETRY_US);
                            cs         <= C_WAIT;
                        end else if (idx == 6'(N_REGS - 1)) begin
                            o_cfg_err  <= 1'b0;
                            o_cfg_done <= 1'b1;
                            us_cnt     <= '0;
                            cs         <= C_IDLE;
                        end else begin
                            idx <= idx + 6'd1;
                            cs  <= C_ISSUE;
                        end
                    end
                end

                C_IDLE: begin
                    if (reconfig_pend) begin
                        us_cnt    <= '0;
                        us_target <= 32'd0;
                        cs        <= C_WAIT;
                    end else if (REFRESH_US > 0) begin
                        if (us_cnt >= 32'(REFRESH_US)) begin
                            us_cnt    <= '0;
                            us_target <= 32'd0;
                            cs        <= C_WAIT;
                        end else if (i_us_tick) begin
                            us_cnt <= us_cnt + 32'd1;
                        end
                    end
                end

                default: cs <= C_WAIT;
            endcase
        end
    end
endmodule
