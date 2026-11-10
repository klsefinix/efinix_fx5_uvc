/*******************************************************************************
 * File Name: cycfg_pins.h
 *
 * Description:
 * Pin configuration
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

#if !defined(CYCFG_PINS_H)
#define CYCFG_PINS_H

#include "cycfg_notices.h"
#include "cy_gpio.h"
#include "cycfg_routing.h"

#if defined (CY_USING_HAL)
#include "cyhal_hwmgr.h"
#endif /* defined (CY_USING_HAL) */

#if defined (CY_USING_HAL_LITE)
#include "cyhal_hw_types.h"
#endif /* defined (CY_USING_HAL_LITE) */

#if defined(__cplusplus)
extern "C" {
#endif /* defined(__cplusplus) */

#define ioss_0_port_5_pin_0_ENABLED 1U
#define ioss_0_port_5_pin_0_PORT GPIO_PRT5
#define ioss_0_port_5_pin_0_PORT_NUM 5U
#define ioss_0_port_5_pin_0_PIN 0U
#define ioss_0_port_5_pin_0_NUM 0U
#define ioss_0_port_5_pin_0_DRIVEMODE CY_GPIO_DM_ANALOG
#define ioss_0_port_5_pin_0_INIT_DRIVESTATE 1
#ifndef ioss_0_port_5_pin_0_HSIOM
    #define ioss_0_port_5_pin_0_HSIOM HSIOM_SEL_GPIO
#endif
#define ioss_0_port_5_pin_0_IRQ ioss_interrupts_gpio_5_IRQn

#if defined (CY_USING_HAL) || (CY_USING_HAL_LITE)
#define ioss_0_port_5_pin_0_HAL_PORT_PIN P5_0
#define ioss_0_port_5_pin_0 P5_0
#define ioss_0_port_5_pin_0_HAL_IRQ CYHAL_GPIO_IRQ_NONE
#define ioss_0_port_5_pin_0_HAL_DIR CYHAL_GPIO_DIR_INPUT 
#define ioss_0_port_5_pin_0_HAL_DRIVEMODE CYHAL_GPIO_DRIVE_ANALOG
#endif /* defined (CY_USING_HAL) || (CY_USING_HAL_LITE) */

#define ioss_0_port_5_pin_1_ENABLED 1U
#define ioss_0_port_5_pin_1_PORT GPIO_PRT5
#define ioss_0_port_5_pin_1_PORT_NUM 5U
#define ioss_0_port_5_pin_1_PIN 1U
#define ioss_0_port_5_pin_1_NUM 1U
#define ioss_0_port_5_pin_1_DRIVEMODE CY_GPIO_DM_ANALOG
#define ioss_0_port_5_pin_1_INIT_DRIVESTATE 1
#ifndef ioss_0_port_5_pin_1_HSIOM
    #define ioss_0_port_5_pin_1_HSIOM HSIOM_SEL_GPIO
#endif
#define ioss_0_port_5_pin_1_IRQ ioss_interrupts_gpio_5_IRQn

#if defined (CY_USING_HAL) || (CY_USING_HAL_LITE)
#define ioss_0_port_5_pin_1_HAL_PORT_PIN P5_1
#define ioss_0_port_5_pin_1 P5_1
#define ioss_0_port_5_pin_1_HAL_IRQ CYHAL_GPIO_IRQ_NONE
#define ioss_0_port_5_pin_1_HAL_DIR CYHAL_GPIO_DIR_INPUT 
#define ioss_0_port_5_pin_1_HAL_DRIVEMODE CYHAL_GPIO_DRIVE_ANALOG
#endif /* defined (CY_USING_HAL) || (CY_USING_HAL_LITE) */

#define ioss_0_port_8_pin_0_ENABLED 1U
#define ioss_0_port_8_pin_0_PORT GPIO_PRT8
#define ioss_0_port_8_pin_0_PORT_NUM 8U
#define ioss_0_port_8_pin_0_PIN 0U
#define ioss_0_port_8_pin_0_NUM 0U
#define ioss_0_port_8_pin_0_DRIVEMODE CY_GPIO_DM_HIGHZ
#define ioss_0_port_8_pin_0_INIT_DRIVESTATE 1
#ifndef ioss_0_port_8_pin_0_HSIOM
    #define ioss_0_port_8_pin_0_HSIOM HSIOM_SEL_GPIO
#endif
#define ioss_0_port_8_pin_0_IRQ ioss_interrupts_gpio_8_IRQn

#if defined (CY_USING_HAL) || (CY_USING_HAL_LITE)
#define ioss_0_port_8_pin_0_HAL_PORT_PIN P8_0
#define ioss_0_port_8_pin_0 P8_0
#define ioss_0_port_8_pin_0_HAL_IRQ CYHAL_GPIO_IRQ_NONE
#define ioss_0_port_8_pin_0_HAL_DIR CYHAL_GPIO_DIR_INPUT 
#define ioss_0_port_8_pin_0_HAL_DRIVEMODE CYHAL_GPIO_DRIVE_NONE
#endif /* defined (CY_USING_HAL) || (CY_USING_HAL_LITE) */

#define ioss_0_port_8_pin_1_ENABLED 1U
#define ioss_0_port_8_pin_1_PORT GPIO_PRT8
#define ioss_0_port_8_pin_1_PORT_NUM 8U
#define ioss_0_port_8_pin_1_PIN 1U
#define ioss_0_port_8_pin_1_NUM 1U
#define ioss_0_port_8_pin_1_DRIVEMODE CY_GPIO_DM_STRONG_IN_OFF
#define ioss_0_port_8_pin_1_INIT_DRIVESTATE 1
#ifndef ioss_0_port_8_pin_1_HSIOM
    #define ioss_0_port_8_pin_1_HSIOM HSIOM_SEL_GPIO
#endif
#define ioss_0_port_8_pin_1_IRQ ioss_interrupts_gpio_8_IRQn

#if defined (CY_USING_HAL) || (CY_USING_HAL_LITE)
#define ioss_0_port_8_pin_1_HAL_PORT_PIN P8_1
#define ioss_0_port_8_pin_1 P8_1
#define ioss_0_port_8_pin_1_HAL_IRQ CYHAL_GPIO_IRQ_NONE
#define ioss_0_port_8_pin_1_HAL_DIR CYHAL_GPIO_DIR_OUTPUT 
#define ioss_0_port_8_pin_1_HAL_DRIVEMODE CYHAL_GPIO_DRIVE_STRONG
#endif /* defined (CY_USING_HAL) || (CY_USING_HAL_LITE) */

#define ioss_0_port_10_pin_0_ENABLED 1U
#define ioss_0_port_10_pin_0_PORT GPIO_PRT10
#define ioss_0_port_10_pin_0_PORT_NUM 10U
#define ioss_0_port_10_pin_0_PIN 0U
#define ioss_0_port_10_pin_0_NUM 0U
#define ioss_0_port_10_pin_0_DRIVEMODE CY_GPIO_DM_OD_DRIVESLOW
#define ioss_0_port_10_pin_0_INIT_DRIVESTATE 1
#ifndef ioss_0_port_10_pin_0_HSIOM
    #define ioss_0_port_10_pin_0_HSIOM HSIOM_SEL_GPIO
#endif
#define ioss_0_port_10_pin_0_IRQ ioss_interrupts_gpio_10_IRQn

#if defined (CY_USING_HAL) || (CY_USING_HAL_LITE)
#define ioss_0_port_10_pin_0_HAL_PORT_PIN P10_0
#define ioss_0_port_10_pin_0 P10_0
#define ioss_0_port_10_pin_0_HAL_IRQ CYHAL_GPIO_IRQ_NONE
#define ioss_0_port_10_pin_0_HAL_DIR CYHAL_GPIO_DIR_BIDIRECTIONAL 
#define ioss_0_port_10_pin_0_HAL_DRIVEMODE CYHAL_GPIO_DRIVE_OPENDRAINDRIVESLOW
#endif /* defined (CY_USING_HAL) || (CY_USING_HAL_LITE) */

#define ioss_0_port_10_pin_1_ENABLED 1U
#define ioss_0_port_10_pin_1_PORT GPIO_PRT10
#define ioss_0_port_10_pin_1_PORT_NUM 10U
#define ioss_0_port_10_pin_1_PIN 1U
#define ioss_0_port_10_pin_1_NUM 1U
#define ioss_0_port_10_pin_1_DRIVEMODE CY_GPIO_DM_OD_DRIVESLOW
#define ioss_0_port_10_pin_1_INIT_DRIVESTATE 1
#ifndef ioss_0_port_10_pin_1_HSIOM
    #define ioss_0_port_10_pin_1_HSIOM HSIOM_SEL_GPIO
#endif
#define ioss_0_port_10_pin_1_IRQ ioss_interrupts_gpio_10_IRQn

#if defined (CY_USING_HAL) || (CY_USING_HAL_LITE)
#define ioss_0_port_10_pin_1_HAL_PORT_PIN P10_1
#define ioss_0_port_10_pin_1 P10_1
#define ioss_0_port_10_pin_1_HAL_IRQ CYHAL_GPIO_IRQ_NONE
#define ioss_0_port_10_pin_1_HAL_DIR CYHAL_GPIO_DIR_BIDIRECTIONAL 
#define ioss_0_port_10_pin_1_HAL_DRIVEMODE CYHAL_GPIO_DRIVE_OPENDRAINDRIVESLOW
#define CYBSP_DEBUG_UART_TX (P11_0)
#define CYBSP_DEBUG_UART_RX (P11_1)
#endif /* defined (CY_USING_HAL) || (CY_USING_HAL_LITE) */

#define ioss_0_port_11_pin_2_ENABLED 1U
#define ioss_0_port_11_pin_2_PORT GPIO_PRT11
#define ioss_0_port_11_pin_2_PORT_NUM 11U
#define ioss_0_port_11_pin_2_PIN 2U
#define ioss_0_port_11_pin_2_NUM 2U
#define ioss_0_port_11_pin_2_DRIVEMODE CY_GPIO_DM_PULLUP
#define ioss_0_port_11_pin_2_INIT_DRIVESTATE 1
#ifndef ioss_0_port_11_pin_2_HSIOM
    #define ioss_0_port_11_pin_2_HSIOM HSIOM_SEL_GPIO
#endif
#define ioss_0_port_11_pin_2_IRQ ioss_interrupts_gpio_11_IRQn

#if defined (CY_USING_HAL) || (CY_USING_HAL_LITE)
#define ioss_0_port_11_pin_2_HAL_PORT_PIN P11_2
#define ioss_0_port_11_pin_2 P11_2
#define ioss_0_port_11_pin_2_HAL_IRQ CYHAL_GPIO_IRQ_NONE
#define ioss_0_port_11_pin_2_HAL_DIR CYHAL_GPIO_DIR_BIDIRECTIONAL 
#define ioss_0_port_11_pin_2_HAL_DRIVEMODE CYHAL_GPIO_DRIVE_PULLUP
#endif /* defined (CY_USING_HAL) || (CY_USING_HAL_LITE) */

#define ioss_0_port_11_pin_3_ENABLED 1U
#define ioss_0_port_11_pin_3_PORT GPIO_PRT11
#define ioss_0_port_11_pin_3_PORT_NUM 11U
#define ioss_0_port_11_pin_3_PIN 3U
#define ioss_0_port_11_pin_3_NUM 3U
#define ioss_0_port_11_pin_3_DRIVEMODE CY_GPIO_DM_PULLDOWN
#define ioss_0_port_11_pin_3_INIT_DRIVESTATE 1
#ifndef ioss_0_port_11_pin_3_HSIOM
    #define ioss_0_port_11_pin_3_HSIOM HSIOM_SEL_GPIO
#endif
#define ioss_0_port_11_pin_3_IRQ ioss_interrupts_gpio_11_IRQn

#if defined (CY_USING_HAL) || (CY_USING_HAL_LITE)
#define ioss_0_port_11_pin_3_HAL_PORT_PIN P11_3
#define ioss_0_port_11_pin_3 P11_3
#define ioss_0_port_11_pin_3_HAL_IRQ CYHAL_GPIO_IRQ_NONE
#define ioss_0_port_11_pin_3_HAL_DIR CYHAL_GPIO_DIR_BIDIRECTIONAL 
#define ioss_0_port_11_pin_3_HAL_DRIVEMODE CYHAL_GPIO_DRIVE_PULLDOWN
#endif /* defined (CY_USING_HAL) || (CY_USING_HAL_LITE) */

extern const cy_stc_gpio_pin_config_t ioss_0_port_5_pin_0_config;

#if defined (CY_USING_HAL) || (CY_USING_HAL_LITE)
extern const cyhal_resource_inst_t ioss_0_port_5_pin_0_obj;
#endif /* defined (CY_USING_HAL) || (CY_USING_HAL_LITE) */

extern const cy_stc_gpio_pin_config_t ioss_0_port_5_pin_1_config;

#if defined (CY_USING_HAL) || (CY_USING_HAL_LITE)
extern const cyhal_resource_inst_t ioss_0_port_5_pin_1_obj;
#endif /* defined (CY_USING_HAL) || (CY_USING_HAL_LITE) */

extern const cy_stc_gpio_pin_config_t ioss_0_port_8_pin_0_config;

#if defined (CY_USING_HAL) || (CY_USING_HAL_LITE)
extern const cyhal_resource_inst_t ioss_0_port_8_pin_0_obj;
#endif /* defined (CY_USING_HAL) || (CY_USING_HAL_LITE) */

extern const cy_stc_gpio_pin_config_t ioss_0_port_8_pin_1_config;

#if defined (CY_USING_HAL) || (CY_USING_HAL_LITE)
extern const cyhal_resource_inst_t ioss_0_port_8_pin_1_obj;
#endif /* defined (CY_USING_HAL) || (CY_USING_HAL_LITE) */

extern const cy_stc_gpio_pin_config_t ioss_0_port_10_pin_0_config;

#if defined (CY_USING_HAL) || (CY_USING_HAL_LITE)
extern const cyhal_resource_inst_t ioss_0_port_10_pin_0_obj;
#endif /* defined (CY_USING_HAL) || (CY_USING_HAL_LITE) */

extern const cy_stc_gpio_pin_config_t ioss_0_port_10_pin_1_config;

#if defined (CY_USING_HAL) || (CY_USING_HAL_LITE)
extern const cyhal_resource_inst_t ioss_0_port_10_pin_1_obj;
#endif /* defined (CY_USING_HAL) || (CY_USING_HAL_LITE) */

extern const cy_stc_gpio_pin_config_t ioss_0_port_11_pin_2_config;

#if defined (CY_USING_HAL) || (CY_USING_HAL_LITE)
extern const cyhal_resource_inst_t ioss_0_port_11_pin_2_obj;
#endif /* defined (CY_USING_HAL) || (CY_USING_HAL_LITE) */

extern const cy_stc_gpio_pin_config_t ioss_0_port_11_pin_3_config;

#if defined (CY_USING_HAL) || (CY_USING_HAL_LITE)
extern const cyhal_resource_inst_t ioss_0_port_11_pin_3_obj;
#endif /* defined (CY_USING_HAL) || (CY_USING_HAL_LITE) */

void init_cycfg_pins(void);
void reserve_cycfg_pins(void);

#if defined(__cplusplus)
}
#endif /* defined(__cplusplus) */

#endif /* CYCFG_PINS_H */
