#ifndef FX5_FPGA_SIDEBAND_H
#define FX5_FPGA_SIDEBAND_H
#include <stdbool.h>
#include <stdint.h>

void    Fx5Fpga_SidebandInit(void);
void    Fx5Fpga_PhyDone(bool done);
void    Fx5Fpga_StreamEnable(bool en);
void    Fx5Fpga_LinkReady(bool ready);
void    Fx5Fpga_RegWrite(uint32_t reg, uint8_t value);
uint8_t Fx5Fpga_RegRead(uint32_t reg);

#endif
