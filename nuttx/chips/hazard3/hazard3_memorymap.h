/****************************************************************************
 * SPDX-License-Identifier: Apache-2.0
 *
 * hazard3_memorymap.h: Hazard3 on run-hazard3
 ****************************************************************************/

#ifndef __ARCH_RISCV_SRC_HAZARD3_HAZARD3_MEMORYMAP_H
#define __ARCH_RISCV_SRC_HAZARD3_HAZARD3_MEMORYMAP_H

#include "riscv_common_memorymap.h"

/* The timer in rtl/hazard3_top.veryl, laid out as the usual CLINT */

#define HAZARD3_CLINT_BASE     0x02000000
#define HAZARD3_CLINT_MSIP     (HAZARD3_CLINT_BASE + 0x0000)
#define HAZARD3_CLINT_MTIMECMP (HAZARD3_CLINT_BASE + 0x4000)
#define HAZARD3_CLINT_MTIME    (HAZARD3_CLINT_BASE + 0xbff8)

#define RISCV_CLINT_MSIP       HAZARD3_CLINT_MSIP
#define RISCV_IPI              RISCV_CLINT_MSIP

/* The idle stack follows .bss */

#ifndef __ASSEMBLY__
#  define HAZARD3_IDLESTACK_BASE  (uintptr_t)_ebss
#else
#  define HAZARD3_IDLESTACK_BASE  _ebss
#endif

#endif /* __ARCH_RISCV_SRC_HAZARD3_HAZARD3_MEMORYMAP_H */
