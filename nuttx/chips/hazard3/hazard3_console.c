/****************************************************************************
 * SPDX-License-Identifier: Apache-2.0
 *
 * hazard3_console.c: low-level console of Hazard3 on run-hazard3
 *
 * The console is SEGGER RTT: a control block and ring buffers in memory,
 * which `hio cpu boot` reads and writes through the harness window. This is
 * the polled path for early boot and panic output; /dev/console is
 * drivers/segger/serial_rtt.c.
 *
 * SEGGER_RTT_PutChar() cannot be used here: it takes the scheduler lock,
 * which faults before nx_start() has set the scheduler up. The no-lock write
 * has no such dependency.
 ****************************************************************************/

#include <nuttx/config.h>

#include <stdbool.h>

#include <nuttx/arch.h>

#ifdef CONFIG_SEGGER_RTT
void     SEGGER_RTT_Init(void);
unsigned SEGGER_RTT_WriteNoLock(unsigned BufferIndex, const void *pBuffer,
                                unsigned NumBytes);

static bool g_rtt_ready;
#endif

void up_putc(int ch)
{
#ifdef CONFIG_SEGGER_RTT
  char c = (char)ch;

  if (!g_rtt_ready)
    {
      SEGGER_RTT_Init();
      g_rtt_ready = true;
    }

  SEGGER_RTT_WriteNoLock(0, &c, 1);
#endif
}
