/*******************************************************************************
 * File Name: cycfg_peripherals.h
 *
 * Description:
 * Clock configuration
 * This file was automatically generated and should not be modified.
 * Configurator Backend 3.80.0
 * device-db 4.37.0.10260
 * mtb-pdl-cat1 3.23.0.46632
 *
 *******************************************************************************
 * Copyright 2026, Infineon Technologies AG, or an affiliate of Infineon
 * Technologies AG. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 ******************************************************************************/

#if !defined(CYCFG_PERIPHERALS_H)
#define CYCFG_PERIPHERALS_H

#include "cycfg_notices.h"
#include "cy_scb_i2c.h"
#include "cy_sysclk.h"
#include "cy_scb_uart.h"

#if defined (CY_USING_HAL)
#include "cyhal_hwmgr.h"
#include "cyhal.h"
#endif /* defined (CY_USING_HAL) */

#if defined (CY_USING_HAL_LITE) || defined (CY_USING_HAL)
#include "cycfg_clocks.h"
#endif /* defined (CY_USING_HAL_LITE) || defined (CY_USING_HAL) */

#if defined (COMPONENT_MTB_HAL)
#include "mtb_hal.h"
#include "cycfg_clocks.h"
#include "mtb_hal_hw_types.h"
#endif /* defined (COMPONENT_MTB_HAL) */

#if defined (CY_USING_HAL_LITE)
#include "cyhal_hw_types.h"
#endif /* defined (CY_USING_HAL_LITE) */

#if defined(__cplusplus)
extern "C" {
#endif /* defined(__cplusplus) */

#define I2C_SCB_ENABLED 1U
#define I2C_SCB_HW SCB0
#define I2C_SCB_IRQ scb_0_interrupt_IRQn
#define LOG_SCB_ENABLED 1U
#define LOG_SCB_HW SCB1
#define LOG_SCB_IRQ scb_1_interrupt_IRQn

extern const cy_stc_scb_i2c_config_t I2C_SCB_config;

#if defined (CY_USING_HAL) || defined(CY_USING_HAL_LITE)
extern const cyhal_resource_inst_t I2C_SCB_obj;
#endif /* defined (CY_USING_HAL) || defined(CY_USING_HAL_LITE) */

#if defined(CY_USING_HAL_LITE) || defined (CY_USING_HAL)
extern const cyhal_clock_t I2C_SCB_clock;
#endif /* defined(CY_USING_HAL_LITE) || defined (CY_USING_HAL) */

#if defined (CY_USING_HAL) || defined(CY_USING_HAL_LITE)
extern const cyhal_i2c_configurator_t I2C_SCB_hal_config;
#endif /* defined (CY_USING_HAL) || defined(CY_USING_HAL_LITE) */

#if defined (COMPONENT_MTB_HAL)
extern const mtb_hal_peri_div_t I2C_SCB_clock_ref;
extern const mtb_hal_clock_t I2C_SCB_hal_clock;
#endif /* defined (COMPONENT_MTB_HAL) */

#if defined (COMPONENT_MTB_HAL) && (MTB_HAL_DRIVER_AVAILABLE_I2C)
extern const mtb_hal_i2c_configurator_t I2C_SCB_hal_config;
#endif /* defined (COMPONENT_MTB_HAL) && (MTB_HAL_DRIVER_AVAILABLE_I2C) */

extern const cy_stc_scb_uart_config_t LOG_SCB_config;

#if defined (CY_USING_HAL) || defined(CY_USING_HAL_LITE)
extern const cyhal_resource_inst_t LOG_SCB_obj;
#endif /* defined (CY_USING_HAL) || defined(CY_USING_HAL_LITE) */

#if defined(CY_USING_HAL_LITE) || defined (CY_USING_HAL)
extern const cyhal_clock_t LOG_SCB_clock;
#endif /* defined(CY_USING_HAL_LITE) || defined (CY_USING_HAL) */

#if defined (CY_USING_HAL) || defined(CY_USING_HAL_LITE)
extern const cyhal_uart_configurator_t LOG_SCB_hal_config;
#endif /* defined (CY_USING_HAL) || defined(CY_USING_HAL_LITE) */

#if defined (COMPONENT_MTB_HAL)
extern const mtb_hal_peri_div_t LOG_SCB_clock_ref;
extern const mtb_hal_clock_t LOG_SCB_hal_clock;
#endif /* defined (COMPONENT_MTB_HAL) */

#if defined (COMPONENT_MTB_HAL) && (MTB_HAL_DRIVER_AVAILABLE_UART)
extern const mtb_hal_uart_configurator_t LOG_SCB_hal_config;
#endif /* defined (COMPONENT_MTB_HAL) && (MTB_HAL_DRIVER_AVAILABLE_UART) */

void init_cycfg_peripherals(void);
void reserve_cycfg_peripherals(void);

#if defined(__cplusplus)
}
#endif /* defined(__cplusplus) */

#endif /* CYCFG_PERIPHERALS_H */
