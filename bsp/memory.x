/* Hazard3 on run-hazard3's harness. The core has one address space: 64 KB
 * of FPGA memory (tcm) from 0x8000_0000, the reset vector, and the board's
 * DRAM (dmem) right after it, from 0x8001_0000. `hio cpu boot` loads each
 * segment into the memory that covers it.
 *
 * Code goes into tcm, which answers in one cycle. Data, the RTT block and
 * the stack go into dmem. */

MEMORY
{
  TCM  (rx)  : ORIGIN = 0x80000000, LENGTH = 64K
  /* dmem has the whole DRAM; 960 KB keeps the RTT block within the host's
   * 1 MB window into it (`aperture` in Harness.toml). */
  DMEM (rwa) : ORIGIN = 0x80010000, LENGTH = 960K
}

REGION_ALIAS("REGION_TEXT",   TCM);
REGION_ALIAS("REGION_RODATA", DMEM);
REGION_ALIAS("REGION_DATA",   DMEM);
REGION_ALIAS("REGION_BSS",    DMEM);
REGION_ALIAS("REGION_HEAP",   DMEM);
REGION_ALIAS("REGION_STACK",  DMEM);

_max_hart_id     = 0;
_hart_stack_size = 16K;
_heap_size       = 0;
