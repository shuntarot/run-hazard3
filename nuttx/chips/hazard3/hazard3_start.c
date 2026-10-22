/****************************************************************************
 * SPDX-License-Identifier: Apache-2.0
 *
 * hazard3_start.c: C entry point of Hazard3 on run-hazard3
 ****************************************************************************/

#include <nuttx/config.h>

#include <nuttx/init.h>
#include <nuttx/arch.h>
#include <arch/board/board.h>

#include "riscv_internal.h"
#include "chip.h"

#ifdef CONFIG_DEBUG_FEATURES
#  define showprogress(c) up_putc(c)
#else
#  define showprogress(c)
#endif

static void hazard3_clear_bss(void)
{
  uint32_t *dest;

  for (dest = (uint32_t *)_sbss; dest < (uint32_t *)_ebss; )
    {
      *dest++ = 0;
    }
}

void hazard3_start(int mhartid)
{
  if (mhartid > 0)
    {
      goto cpux;
    }

  hazard3_clear_bss();

#ifdef CONFIG_RISCV_PERCPU_SCRATCH
  riscv_percpu_add_hart(mhartid);
#endif

  showprogress('A');

#ifdef USE_EARLYSERIALINIT
  riscv_earlyserialinit();
#endif

  showprogress('B');

  nx_start();

cpux:
  while (true)
    {
      asm("WFI");
    }
}

void riscv_earlyserialinit(void)
{
}

void riscv_serialinit(void)
{
  /* The RTT serial driver is registered by drivers_initialize() */
}
