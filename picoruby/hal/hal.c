#include <stdint.h>

#include "hal.h"
#include "../rtt.h"

/* mtime counts the 50 MHz core clock. */
#define MTIME      (*(volatile uint32_t *)0x0200bff8)
#define TICK_CLKS  50000u   /* 1 ms */

/* Waits for the next tick, then runs it. */
void hal_idle(void)
{
  static uint32_t next;
  uint32_t now = MTIME;
  if (next == 0) next = now;
  while ((int32_t)(MTIME - next) < 0) {}
  next += TICK_CLKS;
  mrbc_tick();
}

int mrbc_hal_write(int fd, const void *buf, int nbytes)
{
  (void)fd;
  rtt_write(buf, nbytes);
  return nbytes;
}

int mrbc_hal_flush(int fd) { (void)fd; return 0; }

void mrbc_hal_abort(const char *s)
{
  if (s) {
    const char *p = s;
    while (*p) p++;
    rtt_write(s, (int)(p - s));
  }
  rtt_exit(1);
  for (;;) {}
}
