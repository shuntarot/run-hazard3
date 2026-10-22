/****************************************************************************
 * SPDX-License-Identifier: Apache-2.0
 *
 * src/hazard3_boardinit.c: Hazard3 on run-hazard3
 ****************************************************************************/

#include <nuttx/config.h>

#include <sys/mount.h>

#include <nuttx/board.h>

void board_late_initialize(void)
{
#ifdef CONFIG_FS_PROCFS
  mount(NULL, "/proc", "procfs", 0, NULL);
#endif

#ifdef CONFIG_FS_TMPFS
  mount(NULL, CONFIG_LIBC_TMPDIR, "tmpfs", 0, NULL);
#endif
}
