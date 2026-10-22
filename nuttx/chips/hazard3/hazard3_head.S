/****************************************************************************
 * SPDX-License-Identifier: Apache-2.0
 *
 * hazard3_head.S: entry point of Hazard3 on run-hazard3
 *
 * The core starts at 0x80000000, in the FPGA memory (tcm), in M-mode. This
 * stub is the only code there: the rest of the kernel is in the DRAM after
 * it, so it reaches it with a far call.
 ****************************************************************************/

#include <nuttx/config.h>

#include <arch/arch.h>
#include <arch/irq.h>

#include "chip.h"
#include "riscv_internal.h"
#include "riscv_macros.S"

  .section .text.head, "ax"
  .global __start
  .type   __start, function

__start:
  csrr a0, mhartid

  /* Only one hart is supported; park any other */

  li   t1, CONFIG_SMP_NCPUS
  blt  a0, t1, 2f
  csrw CSR_IE, zero
1:
  wfi
  j    1b

2:
  riscv_set_inital_sp HAZARD3_IDLESTACK_BASE, SMP_STACK_SIZE, a0

  /* Disable all interrupts in mie */

  csrw CSR_IE, zero

  la   t0, __trap_vec
  csrw CSR_TVEC, t0

  call hazard3_start

  /* Not reached */

  .section .text
  .global _init
  .global _fini

_init:
_fini:
  ret
