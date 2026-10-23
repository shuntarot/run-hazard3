# Performance and test results

Measured on a Digilent Arty A7-35, core clock 50 MHz.

## riscv-tests

`scripts/riscv-tests.sh <isa dir>` runs the `isa` suites. 93 of 95 pass. The
two that fail are `rv32ui-p-ma_data` (no misaligned access) and
`rv32mi-p-pmpaddr` (no PMP).

## mruby/c (`picoruby/`)

`picoruby/examples/bench.rb`. Times are in ms; CPI is cycles per instruction.

| Job | Code in DRAM only | Hot code in `tcm` |
|---|---|---|
| `fib(15)` | 1469 | 373 |
| `3000.times { }` | 2794 | 700 |
| `while` 3000 times | 586 | 150 |
| array, 1000 elements | 3473 | 845 |
| string, 500 appends | 784 | 223 |
| hash, 300 entries | 1392 | 466 |
| CPI | about 35 | about 9 |

- With the VM and the allocator in `tcm` (see `picoruby/link.ld`) the core runs
  at about 5.5 MIPS. What is left is data: the stack and the heap are in the DRAM.
- A block call costs about 1,300 instructions, a `while` iteration about 260.
- Two tasks that `sleep` run in the order of their times. A task that never
  waits stops the others: nothing interrupts it.

## NuttX

The kernel runs from the DRAM at about 1.7 MIPS (about 29 cycles per
instruction), so `ostest` takes tens of minutes.
