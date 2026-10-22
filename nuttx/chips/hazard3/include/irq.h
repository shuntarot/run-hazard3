/****************************************************************************
 * SPDX-License-Identifier: Apache-2.0
 *
 * include/irq.h: Hazard3 on run-hazard3
 ****************************************************************************/

#ifndef __ARCH_RISCV_INCLUDE_HAZARD3_IRQ_H
#define __ARCH_RISCV_INCLUDE_HAZARD3_IRQ_H

/* Only the software and timer interrupts are wired. The core's external
 * interrupt inputs are tied off, so there is nothing past the standard
 * RISC-V interrupts.
 */

#define NR_IRQS (RISCV_IRQ_MEXT + 1)

#endif /* __ARCH_RISCV_INCLUDE_HAZARD3_IRQ_H */
