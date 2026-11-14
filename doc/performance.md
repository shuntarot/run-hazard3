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

## memlat, membw, issue

Benchmarks written to compare cores (`apps/`). `issue` builds for RV32 and
RV64 and changes only its board section between cores. Hazard3 has no cache
and no FPU: `memlat` shows DRAM at every size and `tcm` beside it, and
`membw` runs STREAM on 32-bit integers.

```bash
cargo run --release -p memlat
cargo run --release -p membw
cargo run --release -p issue
```

`memlat`, cycles per load:

| Where | Cycles |
|---|---|
| `tcm` | 2.25 |
| DRAM, any size, random or in address order | 25.4 |
| DRAM, two to four chases side by side | 25.0–25.4 |

`membw`, bytes per cycle (1 B/cycle is 50 MB/s):

| | B/cycle |
|---|---|
| STREAM Copy / Scale / Add / Triad | 0.21 / 0.20 / 0.18 / 0.18 |
| Loads from DRAM / from `tcm` | 0.14 / 1.12 |
| Stores to DRAM | 0.30 |

`issue`, cycles, with the loop's share:

| Access | Cycles |
|---|---|
| Timer load (`mtime`) | 1.9 |
| Timer poll: load, branch | 3.4 |
| Timer store (`mtimecmp`) | 1.9 |
| Timer load, or, store | 7 |
| DRAM load, dependent / independent | 25.4 / 25.5 |
| DRAM store | 13.1 |
| CSR read / write | 1.4 / 1.4 |
| `fence` / `fence.i` | 1.5 / 6.4 |
| `ecall` to a handler and back | 11.4 |
| `msip` store to the interrupt handler | 9 |
| `msip` store, the handler, and back | 16 |

The last two include two `mcycle` reads, 5 cycles together.

- One load or store is in flight at a time: loads that do not depend on
  each other take as long as a chase, and the core waits for each store.
- The timer is on the core's bus, so a register access costs about what a
  `tcm` access does.
