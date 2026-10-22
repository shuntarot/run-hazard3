// Smoke test for Hazard3 on the FPGA harness.
// It runs from tcm, the 64 KB of FPGA memory at 0x8000_0000, and writes its
// results there at 0x8000_1000:
//   +0x00: 0x21534e48 ("HNS!")
//   +0x04: misa (0x40801105: RV32IMAC, and X for Hazard3's own extensions)
//   +0x08: mhartid
//   +0x0c: a word loaded from .rodata (0xc0ffee42)
//   +0x10: 1234 * 5678 / 7 (0x000f45f6)
//   +0x14: four byte stores (0x44332211)
//   +0x18: two halfword stores (0x66665555)
//   +0x1c: amoadd.w of 5 onto 37 (0x0000002a), and the old value at +0x20 (0x00000025)
//   +0x24: a store read back by the very next load (0x12345678), copied to +0x28
//   +0x2c: counter, incremented forever
//   +0x30: a word stored to DRAM (dmem, 0x8001_0000) and loaded back (0xfeedface)
//   +0x34: mcause of the software interrupt raised through msip (0x80000003)
//   +0x38: mcause of the timer interrupt raised through mtimecmp (0x80000007)
#define RESULT 0x80001000
#define DRAM   0x80010000
#define CLINT  0x02000000

.section .text.start, "ax", @progbits
.globl _start
_start:
  li   t0, RESULT
  li   t1, 0x21534e48
  sw   t1, 0x00(t0)
  csrr t1, misa
  sw   t1, 0x04(t0)
  csrr t1, mhartid
  sw   t1, 0x08(t0)
  la   t2, pattern
  lw   t1, 0(t2)
  sw   t1, 0x0c(t0)
  li   t1, 1234
  li   t2, 5678
  mul  t1, t1, t2
  li   t2, 7
  divu t1, t1, t2
  sw   t1, 0x10(t0)
  li   t1, 0x11
  sb   t1, 0x14(t0)
  li   t1, 0x22
  sb   t1, 0x15(t0)
  li   t1, 0x33
  sb   t1, 0x16(t0)
  li   t1, 0x44
  sb   t1, 0x17(t0)
  li   t1, 0x5555
  sh   t1, 0x18(t0)
  li   t1, 0x6666
  sh   t1, 0x1a(t0)
  li   t1, 37
  sw   t1, 0x1c(t0)
  addi t2, t0, 0x1c
  li   t1, 5
  amoadd.w t1, t1, (t2)
  sw   t1, 0x20(t0)
  li   t1, 0x12345678
  sw   t1, 0x24(t0)
  lw   t2, 0x24(t0)
  sw   t2, 0x28(t0)
  li   t2, DRAM
  li   t1, 0xfeedface
  sw   t1, 0(t2)
  lw   t1, 0(t2)
  sw   t1, 0x30(t0)

  // Interrupts. The handler records mcause and turns its source off.
  la   t1, trap
  csrw mtvec, t1
  li   t1, 0x88            // mie: MSIE, MTIE
  csrw mie, t1
  csrsi mstatus, 8         // MIE
  li   t2, CLINT
  li   t1, 1
  sw   t1, 0(t2)           // msip: taken at once
2:
  lw   t1, 0x34(t0)
  beqz t1, 2b
  // mtimecmp = mtime + 200. The high word goes to all ones first, so the
  // compare does not match half-written.
  li   t2, CLINT + 0xbff8
  lw   t1, 0(t2)
  lw   t3, 4(t2)
  addi t4, t1, 200
  sltu t1, t4, t1
  add  t3, t3, t1
  li   t2, CLINT + 0x4000
  li   t1, -1
  sw   t1, 4(t2)
  sw   t4, 0(t2)
  sw   t3, 4(t2)
3:
  wfi
  lw   t1, 0x38(t0)
  beqz t1, 3b

  li   t1, 0
1:
  addi t1, t1, 1
  sw   t1, 0x2c(t0)
  j    1b

.balign 4
trap:
  csrr s0, mcause
  li   s1, 0x80000003
  bne  s0, s1, 4f
  sw   s0, 0x34(t0)
  li   s1, CLINT
  sw   zero, 0(s1)         // msip = 0
  mret
4:
  sw   s0, 0x38(t0)
  li   s1, CLINT + 0x4000
  li   s2, -1
  sw   s2, 4(s1)           // mtimecmp = all ones: no more
  sw   s2, 0(s1)
  mret

.section .rodata
.balign 4
pattern:
  .word 0xc0ffee42
