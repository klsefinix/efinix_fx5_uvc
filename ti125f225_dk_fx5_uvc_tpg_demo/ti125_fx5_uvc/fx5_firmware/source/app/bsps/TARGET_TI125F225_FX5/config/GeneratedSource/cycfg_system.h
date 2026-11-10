/*******************************************************************************
 * File Name: cycfg_system.h
 *
 * Description:
 * System configuration
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

#if !defined(CYCFG_SYSTEM_H)
#define CYCFG_SYSTEM_H

#include "cycfg_notices.h"
#include "cy_sysclk.h"
#include "cy_pra.h"
#include "cy_pra_cfg.h"
#include "cy_gpio.h"
#include "cy_device.h"

#if defined (CY_USING_HAL)
#include "cyhal_hwmgr.h"
#endif /* defined (CY_USING_HAL) */

#if defined(__cplusplus)
extern "C" {
#endif /* defined(__cplusplus) */

#define srss_0_clock_0_ENABLED 1U
#define srss_0_clock_0_eco_0_ENABLED 1U
#define srss_0_clock_0_ilo_0_ENABLED 1U
#define srss_0_clock_0_imo_0_ENABLED 1U
#define srss_0_clock_0_lfclk_0_ENABLED 1U
#define CY_CFG_SYSCLK_CLKLF_FREQ_HZ 32768
#define CY_CFG_SYSCLK_CLKLF_SOURCE CY_SYSCLK_CLKLF_IN_ILO
#define srss_0_clock_0_pathmux_0_ENABLED 1U
#define srss_0_clock_0_pathmux_1_ENABLED 1U
#define srss_0_clock_0_pathmux_2_ENABLED 1U
#define srss_0_clock_0_pathmux_3_ENABLED 1U
#define srss_0_clock_0_pathmux_4_ENABLED 1U
#define srss_0_clock_0_fll_0_ENABLED 1U
#define srss_0_clock_0_pll_0_ENABLED 1U
#define srss_0_clock_0_pll_1_ENABLED 1U
#define srss_0_clock_0_hfclk_0_ENABLED 1U
#define CY_CFG_SYSCLK_CLKHF0 0UL
#define CY_CFG_SYSCLK_CLKHF0_FREQ_MHZ 150UL
#define CY_CFG_SYSCLK_CLKHF0_CLKPATH_NUM 1UL
#define srss_0_clock_0_hfclk_1_ENABLED 1U
#define CY_CFG_SYSCLK_CLKHF1 1UL
#define CY_CFG_SYSCLK_CLKHF1_FREQ_MHZ 37UL
#define CY_CFG_SYSCLK_CLKHF1_CLKPATH_NUM 1UL
#define srss_0_clock_0_hfclk_2_ENABLED 1U
#define CY_CFG_SYSCLK_CLKHF2 2UL
#define CY_CFG_SYSCLK_CLKHF2_FREQ_MHZ 48UL
#define CY_CFG_SYSCLK_CLKHF2_CLKPATH_NUM 2UL
#define srss_0_clock_0_hfclk_3_ENABLED 1U
#define CY_CFG_SYSCLK_CLKHF3 3UL
#define CY_CFG_SYSCLK_CLKHF3_FREQ_MHZ 3UL
#define CY_CFG_SYSCLK_CLKHF3_CLKPATH_NUM 0UL
#define srss_0_clock_0_hfclk_4_ENABLED 1U
#define CY_CFG_SYSCLK_CLKHF4 4UL
#define CY_CFG_SYSCLK_CLKHF4_FREQ_MHZ 150UL
#define CY_CFG_SYSCLK_CLKHF4_CLKPATH_NUM 1UL
#define srss_0_clock_0_fastclk_0_ENABLED 1U
#define srss_0_clock_0_periclk_0_ENABLED 1U
#define CY_CFG_SYSCLK_CLKPERI_ENABLED 1
#define CY_CFG_SYSCLK_CLKPERI_DIVIDER 1
#define srss_0_clock_0_slowclk_0_ENABLED 1U
#define cpuss_0_dap_0_ENABLED 1U

#if defined (CY_USING_HAL)
extern const cyhal_resource_inst_t srss_0_clock_0_pathmux_0_obj;
extern const cyhal_resource_inst_t srss_0_clock_0_pathmux_1_obj;
extern const cyhal_resource_inst_t srss_0_clock_0_pathmux_2_obj;
extern const cyhal_resource_inst_t srss_0_clock_0_pathmux_3_obj;
extern const cyhal_resource_inst_t srss_0_clock_0_pathmux_4_obj;
#endif /* defined (CY_USING_HAL) */

void init_cycfg_system(void);
void reserve_cycfg_system(void);

#if defined(__cplusplus)
}
#endif /* defined(__cplusplus) */

#endif /* CYCFG_SYSTEM_H */
