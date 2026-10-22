/****************************************************************************
 * SPDX-License-Identifier: Apache-2.0
 *
 * hazard3_irq_dispatch.c: interrupt dispatch of Hazard3 on run-hazard3
 ****************************************************************************/

#include <nuttx/config.h>

#include <stdint.h>
#include <assert.h>

#include <nuttx/irq.h>
#include <nuttx/arch.h>
#include <sys/types.h>

#include "riscv_internal.h"
#include "chip.h"

void *riscv_dispatch_irq(uintreg_t vector, uintreg_t *regs)
{
  int irq = vector & (~RISCV_IRQ_BIT);

  if ((vector & RISCV_IRQ_BIT) != 0)
    {
      irq += RISCV_IRQ_ASYNC;
    }

  return riscv_doirq(irq, regs);
}
