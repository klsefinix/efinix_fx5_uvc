# ============================================================================
# hdmi_tp.sdc - timing constraints template for hdmi_tp_top
#
# i_pixel_clk comes from a PLL output defined in Interface Designer. Use the
# same clock name here as the PLL output (rename i_pixel_clk in Interface
# Designer or edit the get_ports name below).
#
#   1080p60 : 148.5  MHz -> 6.734 ns
#   1080p30 / 720p60 : 74.25 MHz -> 13.468 ns
#   480p60  : 27.0   MHz -> 37.037 ns
# ============================================================================
create_clock -name pixel_clk -period 6.734 [get_ports {i_pixel_clk}]

# Asynchronous / slow inputs: reset, push button, I2C (all synchronized in RTL)
set_false_path -from [get_ports {i_rst i_btn i_pll_locked hdmi_scl_IN hdmi_sda_IN}]

# Slow outputs: I2C open-drain enables and LEDs
set_false_path -to [get_ports {hdmi_scl_OE hdmi_sda_OE hdmi_scl_OUT hdmi_sda_OUT}]
set_false_path -to [get_ports {o_led_heartbeat o_led_cfg_done o_led_cfg_err o_pattern[*]}]

# ----------------------------------------------------------------------------
# Video bus to ADV7511 (hdmi_yuv_data/de/hs/vs).
# Best practice: enable the output register in each GPIO (Interface Designer)
# and forward the pixel clock from the same PLL through a GPIO in clock-out
# mode, phase-shifted (or inverted) so the ADV7511 samples mid-eye.
# Fill in <tSU>/<tH> from the ADV7511 datasheet input timing table once the
# forwarded-clock phase is chosen, then uncomment.
# ----------------------------------------------------------------------------
# set_output_delay -clock pixel_clk -max <tSU> [get_ports {hdmi_yuv_data[*] hdmi_yuv_de hdmi_yuv_hs hdmi_yuv_vs}]
# set_output_delay -clock pixel_clk -min -<tH> [get_ports {hdmi_yuv_data[*] hdmi_yuv_de hdmi_yuv_hs hdmi_yuv_vs}]
