/****************************************************************************
 * SPDX-License-Identifier: Apache-2.0
 *
 * hazard3_timerisr.c: system timer of Hazard3 on run-hazard3
 ****************************************************************************/

#include <nuttx/config.h>

#include <assert.h>
#include <stdint.h>

#include <nuttx/arch.h>
#include <nuttx/timers/arch_alarm.h>

#include "riscv_internal.h"
#include "riscv_mtimer.h"
#include "chip.h"

void up_timer_initialize(void)
{
  struct oneshot_lowerhalf_s *lower = riscv_mtimer_initialize(
    HAZARD3_CLINT_MTIME, HAZARD3_CLINT_MTIMECMP,
    RISCV_IRQ_TIMER, CONFIG_RUN_HAZARD3_MTIME_FREQ);

  DEBUGASSERT(lower);

  up_alarm_set_lowerhalf(lower);
}
