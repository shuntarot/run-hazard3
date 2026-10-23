/* mruby/c on run-hazard3. The entry stub is the only code in the 64 KB of
 * FPGA memory (tcm) at the reset vector; everything else is in DRAM (dmem)
 * from 0x8001_0000. The host window reaches the first 1 MB of dmem, so the
 * RTT block, which `hio cpu boot` looks for there, has to stay below
 * 0x8010_0000. */

MEMORY
{
  TCM  (rx)  : ORIGIN = 0x80000000, LENGTH = 64K
  DMEM (rwx) : ORIGIN = 0x80010000, LENGTH = 960K
}

ENTRY(_start)

SECTIONS
{
  .head : { KEEP(*(.text.head)) } > TCM

  .text : { *(.text .text.*) } > DMEM
  .rodata : { *(.rodata .rodata.* .srodata .srodata.*) } > DMEM

  .data : {
    . = ALIGN(4);
    *(.data .data.* .sdata .sdata.*)
    . = ALIGN(4);
  } > DMEM

  __global_pointer$ = ADDR(.data) + 0x800;

  .bss (NOLOAD) : {
    . = ALIGN(4);
    __bss_start = .;
    *(.sbss .sbss.* .bss .bss.* COMMON)
    . = ALIGN(16);
    __bss_end = .;
  } > DMEM

  /* The rest of dmem below the window's end is the heap, then the stack. */
  . = ALIGN(16);
  __heap_start = .;
  __stack_top = ORIGIN(DMEM) + LENGTH(DMEM);
  __heap_end = __stack_top - 16K;
  ASSERT(__heap_start < __heap_end, "no room for the heap")

  /DISCARD/ : { *(.eh_frame*) *(.note*) *(.comment) }
}
