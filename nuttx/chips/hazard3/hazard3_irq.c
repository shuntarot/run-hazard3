/****************************************************************************
 * SPDX-License-Identifier: Apache-2.0
 *
 * hazard3_irq.c: interrupts of Hazard3 on run-hazard3
 *
 * Only the software and timer interrupts exist: the external interrupt
 * inputs of the core are tied off.
 ****************************************************************************/

#include <nuttx/config.h>

#include <stdint.h>
#include <assert.h>

#include <nuttx/arch.h>
#include <nuttx/irq.h>

#include "riscv_internal.h"
#include "chip.h"

void up_irqinitialize(void)
{
  /* Disable Machine interrupts */

  up_irq_save();

#if defined(CONFIG_STACK_COLORATION) && CONFIG_ARCH_INTERRUPTSTACK > 15
  size_t intstack_size = (CONFIG_ARCH_INTERRUPTSTACK & ~15);
  riscv_stack_color(g_intstackalloc, intstack_size);
#endif

  /* Attach the common exception handlers */

  riscv_exception_attach();

#ifndef CONFIG_SUPPRESS_INTERRUPTS
  riscv_color_intstack();
  up_irq_enable();
#endif
}

void up_disable_irq(int irq)
{
  if (irq == RISCV_IRQ_SOFT)
    {
      CLEAR_CSR(CSR_IE, IE_SIE);
    }
  else if (irq == RISCV_IRQ_TIMER)
    {
      CLEAR_CSR(CSR_IE, IE_TIE);
    }
  else
    {
      PANIC();
    }
}

void up_enable_irq(int irq)
{
  if (irq == RISCV_IRQ_SOFT)
    {
      SET_CSR(CSR_IE, IE_SIE);
    }
  else if (irq == RISCV_IRQ_TIMER)
    {
      SET_CSR(CSR_IE, IE_TIE);
    }
  else
    {
      PANIC();
    }
}

irqstate_t up_irq_enable(void)
{
  /* Read and enable global interrupts (MIE) in mstatus */

  return READ_AND_SET_CSR(CSR_STATUS, STATUS_IE);
}
