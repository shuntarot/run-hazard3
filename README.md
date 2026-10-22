# run-hazard3

Runs the [Hazard3](https://github.com/Wren6991/Hazard3) RISC-V core (RV32IMAC,
with Zbb, Zifencei and the counters) on a Digilent Arty A7-35 with
[veryl-harness](https://github.com/shuntarot/uharness).
The core's single bus port sees one address space: 64 KB of FPGA memory
from 0x8000_0000 (`tcm`), and the board's DDR3 right after it (`dmem`, through
`hns::ahb2axi`). A timer laid out as the usual CLINT answers at 0x0200_0000:
`msip` at +0x0, `mtimecmp` at +0x4000, and `mtime` at +0xbff8, which counts
the 50 MHz core clock.

## Requirements

- Veryl, with `veryl-harness` and `hio` from veryl-harness
- Vivado
- An Arty A7-35 on USB
- Rust through rustup, for the firmware (`rust-toolchain.toml` picks the target)
- `qemu-system-riscv32`, to run the firmware without the board

## Run

```bash
veryl harness gen --target digilent/arty-a7-35
make -C hns/syn
hio program
hio run bringup.hio
```

`bringup.hio` loads `asm/smoke.elf`, runs it, and reads back what it wrote.
The expected values are in its comments.

Firmware in Rust runs with cargo. `hio cpu boot` loads it, connects to its RTT
console, and exits with its status; Ctrl-A x leaves. If `veryl harness gen`
wrote somewhere other than `hns/` (`--out-dir`), change the path of
`HIO_REGS` under `[env]` in `.cargo/config.toml` to match.

```bash
cargo run -p hello
cargo run -p console
cargo run-emu -p console   # the same on QEMU's virt machine
cargo run -p semihost      # prints by semihosting; also under run-emu
```

riscv-tests' `isa` tests run one by one through `hio cpu boot`, each ending
with its pass or failure code (a test that hangs times out after 60 s):

```bash
scripts/riscv-tests.sh <riscv-tests>/share/riscv-tests/isa          # the suites this core runs
scripts/riscv-tests.sh -o results.txt <isa dir> 'rv32ui-p-*'   # or name them
```

The tests must be built for RV32 (`./configure --with-xlen=32` in riscv-tests).
On the Arty A7-35, 93 of the 95 pass. Two fail by design of this setup:
`rv32ui-p-ma_data` (no misaligned access) and `rv32mi-p-pmpaddr` (no PMP).

The core's Debug Module is reached the same way:

```bash
hio cpu halt               # also: step, regs, resume, reset --halt, info
```

The console has a debug prompt as well (Ctrl-A c); [doc/debug.md](doc/debug.md)
walks through a session.

## NuttX

`nuttx/` holds a chip (`chips/hazard3`) and a board (`boards/run-hazard3`) for
[NuttX](https://nuttx.apache.org/), kept out of the NuttX tree. The `nsh`
configuration runs the NuttShell on the RTT console, with `ostest`.

```bash
export NUTTX_DIR=<nuttx checkout>   # with nuttx-apps at ../apps
nuttx/build.sh                      # CONFIG=nsh by default
hio cpu boot $NUTTX_DIR/nuttx
```

`build.sh` needs `riscv32-unknown-elf-gcc` on PATH and kconfiglib (or
kconfig-frontends). Only the entry stub and the RTT block are in `tcm`; the
kernel is in the DRAM, where the core runs at about 1.7 MIPS: each instruction
is fetched through the memory controller. `ostest` takes a long time for that
reason.

## Size

LUT and FF counts, block RAM in 36 Kb blocks, after place and route. The
core is the DUT alone; the design adds the harness and the memory behind it
(block RAM, or the board's memory controller; the PYNQ-Z1's is hard silicon
in its PS and is not counted).

| Target | Clock | Core LUT / FF / BRAM / DSP | Design LUT / FF / BRAM / DSP |
|---|---|---|---|
| `digilent/arty-a7-35` | 50 MHz | 3,300 / 1,202 / 1 / 0 | 9,632 / 6,828 / 17 / 0 |
| `digilent/pynq-z1` | 50 MHz | 3,246 / 1,069 / 1 / 0 | 4,171 / 2,213 / 17 / 0 |
| `xilinx/vcu118` | 50 MHz | 3,329 / 1,133 / 0 / 0 | 22,674 / 23,417 / 41.5 / 3 |

The PYNQ-Z1 and VCU118 rows are from before the timer, which adds about 150
LUTs and 130 FFs to the core on the Arty.

## Files

| | |
|---|---|
| `rtl/hazard3_top.veryl` | the DUT: Hazard3 with one bus port split into a memory port, an AXI4 port and the timer, and its Debug Module |
| `rtl/hazard3.v` | Hazard3 and its Debug Module in one file (`make hazard3`) |
| `Harness.toml` | where each port goes |
| `asm/smoke.S` | the test program (`make asm`) |
| `bsp/` | startup, console (RTT, or the UART on QEMU) and exit for the firmware |
| `apps/` | the firmware: `hello`, `console`, `semihost` |
| `nuttx/` | NuttX for this core: chip, board, and `build.sh` |
| `sim/` | the DUT alone in Verilator (`make sim`) |

Put paths for your machine in `local.mk`; see `Makefile`.

## License

MIT (`LICENSE`), except Hazard3 in `rtl/hazard3.v`, which is under the Apache
License 2.0 (`rtl/LICENSE.Hazard3`).
