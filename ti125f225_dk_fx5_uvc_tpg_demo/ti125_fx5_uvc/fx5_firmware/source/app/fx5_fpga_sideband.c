/*******************************************************************************
 * fx5_fpga_sideband.c  -  Ti125F225 Dev Board Rev B1 port of the Infineon
 *                         UVC example (FX5 / CYUSB3083 <-> Ti125 over LVDS port 0)
 *
 * The board has no I2C between the FX5 and the FPGA (FX5 P10.0 / P10.1 are NC),
 * so every I2C access the Infineon flow makes to the FPGA (slave 0x0D) is
 * intercepted here. Writes that matter are turned into GPIO levels on two
 * spare LVDS port-0 control pins, everything else is a successful no-op:
 *
 *   P0CTL4 (FX5 F4) -> FPGA GPIOL_05 "PHY_DONE"   reg 0x0A bit 5 (PHY_TRAINING_DONE)
 *   P0CTL3 (FX5 G4) -> FPGA GPIOL_04 "STREAM_EN"  reg 0x20 (stream enable) == CAMERA_APP_ENABLE
 *
 * LINK_READY stays on P0CTL6 and DMA_READY (FLAGA) on P0CTL5, as in the
 * Infineon reference. PHY_DONE is cleared every time LINK_READY changes so the
 * FPGA always restarts with a full PHY training sequence.
 ******************************************************************************/
#include "cy_pdl.h"
#include "cy_lvds.h"
#include "cy_usb_app.h"
#include "cy_usb_i2c.h"
#include "fx5_fpga_sideband.h"

#define FX_SB_PORT          (0u)
#define FX_SB_PHY_DONE_PIN  (CY_LVDS_PHY_GPIO_CTL4)
#define FX_SB_STREAM_EN_PIN (CY_LVDS_PHY_GPIO_CTL3)

static uint8_t fx5_shadow_phy_link_ctrl = (FPGA_PHY_CONTROL | FPGA_LINK_CONTROL);

void Fx5Fpga_SidebandInit(void)
{
    Cy_LVDS_PhyGpioModeEnable(LVDSSS_LVDS, FX_SB_PORT, FX_SB_PHY_DONE_PIN,
                              CY_LVDS_PHY_GPIO_OUTPUT, CY_LVDS_PHY_GPIO_NO_INTERRUPT);
    Cy_LVDS_PhyGpioModeEnable(LVDSSS_LVDS, FX_SB_PORT, FX_SB_STREAM_EN_PIN,
                              CY_LVDS_PHY_GPIO_OUTPUT, CY_LVDS_PHY_GPIO_NO_INTERRUPT);
    Cy_LVDS_PhyGpioClr(LVDSSS_LVDS, FX_SB_PORT, FX_SB_PHY_DONE_PIN);
    Cy_LVDS_PhyGpioClr(LVDSSS_LVDS, FX_SB_PORT, FX_SB_STREAM_EN_PIN);
}

void Fx5Fpga_PhyDone(bool done)
{
    if (done) Cy_LVDS_PhyGpioSet(LVDSSS_LVDS, FX_SB_PORT, FX_SB_PHY_DONE_PIN);
    else      Cy_LVDS_PhyGpioClr(LVDSSS_LVDS, FX_SB_PORT, FX_SB_PHY_DONE_PIN);
}

void Fx5Fpga_StreamEnable(bool en)
{
    if (en) Cy_LVDS_PhyGpioSet(LVDSSS_LVDS, FX_SB_PORT, FX_SB_STREAM_EN_PIN);
    else    Cy_LVDS_PhyGpioClr(LVDSSS_LVDS, FX_SB_PORT, FX_SB_STREAM_EN_PIN);
}

/* LINK_READY wrapper: always drop PHY_DONE first so a LINK_READY rise starts
 * a fresh PHY training on the FPGA side. */
void Fx5Fpga_LinkReady(bool ready)
{
    Fx5Fpga_PhyDone(false);
    if (ready) Cy_LVDS_PhyGpioSet(LVDSSS_LVDS, LINK_READY_CTL_PORT, LINK_READY_CTL_PIN);
    else       Cy_LVDS_PhyGpioClr(LVDSSS_LVDS, LINK_READY_CTL_PORT, LINK_READY_CTL_PIN);
}

/* Called from Cy_I2C_Write() for slave FPGASLAVE_ADDR. */
void Fx5Fpga_RegWrite(uint32_t reg, uint8_t value)
{
    if (reg == FPGA_PHY_LINK_CONTROL_ADDRESS) {
        fx5_shadow_phy_link_ctrl = value;
        Fx5Fpga_PhyDone((value & PHY_TRAINING_DONE) != 0u);
        /* An I2C write takes ~100 us on the reference design; keep the same
         * latency so the FPGA's link-training block is seen by the FX5
         * before the caller checks glIsLVDSLink0TrainingDone. */
        Cy_SysLib_DelayUs(200);
    } else if (reg == (DEVICE0_OFFSET + FPGA_DEVICE_STREAM_ENABLE_ADDRESS)) {
        Fx5Fpga_StreamEnable((value & CAMERA_APP_ENABLE) != 0u);
    }
    /* all other registers: fixed in the FPGA RTL, nothing to do */
}

/* Called from Cy_I2C_Read() for slave FPGASLAVE_ADDR. */
uint8_t Fx5Fpga_RegRead(uint32_t reg)
{
    if (reg == FPGA_PHY_LINK_CONTROL_ADDRESS) {
        return fx5_shadow_phy_link_ctrl;
    }
    return 0u;
}
