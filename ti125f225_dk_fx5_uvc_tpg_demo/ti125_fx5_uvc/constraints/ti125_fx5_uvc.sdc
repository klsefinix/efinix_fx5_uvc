# ============================================================================
# ti125_fx5_uvc.sdc  (style follows hdmi_tp.sdc)
#
# Clock names must match the fx_pll output pins in Interface Designer.
# After generating the interface, also merge the LVDS TX output constraints
# from the Interface Designer template (<project>.pt.sdc).
# ============================================================================
create_clock -name clk_par       -period 6.734                      [get_ports {clk_par}]
create_clock -name lvds_fast_clk -period 1.684 -waveform {0.421 1.263} [get_ports {lvds_fast_clk}]

# Asynchronous / slow inputs (synchronized in RTL)
set_false_path -from [get_ports {i_rst i_btn i_pll_locked}]
set_false_path -from [get_ports {fx_link_ready fx_dma_ready fx_phy_done fx_stream_en}]

# LEDs
set_false_path -to [get_ports {o_led_heartbeat o_led_trained o_led_err o_pattern[*]}]

# LVDS TX output enables are tied high (static)
set_false_path -to [get_ports {*_TX_OE}]

# FX5 reset (open drain on M2): static / slow
set_false_path -to   [get_ports {fx5_xres_out fx5_xres_oe}]
set_false_path -from [get_ports {fx5_xres_in}]
