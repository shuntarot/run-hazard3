#include <stdint.h>

#include "mrubyc.h"
#include "rtt.h"

#ifndef MRBC_MEMORY_SIZE
#define MRBC_MEMORY_SIZE (256 * 1024)
#endif
static uint8_t memory_pool[MRBC_MEMORY_SIZE] __attribute__((aligned(8)));

extern const uint8_t program[];

int main(void)
{
  rtt_init();
  mrbc_init(memory_pool, MRBC_MEMORY_SIZE);
  if (!mrbc_create_task(program, NULL)) {
    rtt_write("cannot load the program\n", 24);
    return 2;
  }
  return mrbc_run();
}
