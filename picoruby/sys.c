/* The few system calls newlib needs. Output goes to the RTT console. */

#include <errno.h>
#include <stddef.h>
#include <sys/stat.h>

#include "rtt.h"

extern char __heap_start, __heap_end;

void *_sbrk(ptrdiff_t incr)
{
  static char *brk;
  if (!brk) brk = &__heap_start;
  if (brk + incr > &__heap_end) {
    errno = ENOMEM;
    return (void *)-1;
  }
  char *old = brk;
  brk += incr;
  return old;
}

int _write(int fd, const void *buf, size_t n) { (void)fd; rtt_write(buf, (int)n); return (int)n; }
int _read(int fd, void *buf, size_t n)        { (void)fd; (void)buf; (void)n; return 0; }
int _close(int fd)                            { (void)fd; return -1; }
int _fstat(int fd, struct stat *st)           { (void)fd; st->st_mode = S_IFCHR; return 0; }
int _isatty(int fd)                           { (void)fd; return 1; }
off_t _lseek(int fd, off_t off, int whence)   { (void)fd; (void)off; (void)whence; return 0; }
int _getpid(void)                             { return 1; }
int _kill(int pid, int sig)                   { (void)pid; (void)sig; errno = EINVAL; return -1; }

void _exit(int code)
{
  rtt_exit(code);
  for (;;) {}
}
