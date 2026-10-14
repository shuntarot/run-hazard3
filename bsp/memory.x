/* Hazard3 on run-hazard3's harness. Fetches go to imem (64 KB of FPGA
 * memory); loads and stores go to dmem (the board's DRAM). Both start at
 * 0x8000_0000, the reset vector, and `hio cpu boot` loads every segment into
 * each memory that covers it.
 *
 * Only code goes into the part both memories cover. Everything the program
 * reads or writes as data sits above it, where only dmem is: imem cannot be
 * written by the core, and the host must read the RTT block where the core
 * writes it. */

MEMORY
{
  IMEM (rx)  : ORIGIN = 0x80000000, LENGTH = 64K
  /* dmem has the whole DRAM; 1 MB keeps the RTT block within the host's
   * 1 MB window into it (`aperture` in Harness.toml). */
  DMEM (rwa) : ORIGIN = 0x80010000, LENGTH = 960K
}

REGION_ALIAS("REGION_TEXT",   IMEM);
REGION_ALIAS("REGION_RODATA", DMEM);
REGION_ALIAS("REGION_DATA",   DMEM);
REGION_ALIAS("REGION_BSS",    DMEM);
REGION_ALIAS("REGION_HEAP",   DMEM);
REGION_ALIAS("REGION_STACK",  DMEM);

_max_hart_id     = 0;
_hart_stack_size = 16K;
_heap_size       = 0;
