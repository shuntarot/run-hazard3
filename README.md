# run-hazard3

Runs the [Hazard3](https://github.com/Wren6991/Hazard3) RISC-V core (RV32IMAC,
with Zbb and the counters) on a Digilent Arty A7-35 with
[veryl-harness](https://github.com/shuntarot/uharness).
Fetches read FPGA memory; loads and stores go to the board's DDR3 through
`hns::ahb2axi`.

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
On the Arty A7-35, 92 of the 95 pass. Three fail by design of this setup:
`rv32ui-p-fence_i` (fetches and data use separate memories),
`rv32ui-p-ma_data` (no misaligned access) and `rv32mi-p-pmpaddr` (no PMP).

The core's Debug Module is reached the same way:

```bash
hio cpu halt               # also: step, regs, resume, reset --halt, info
```

The console has a debug prompt as well (Ctrl-A c); [doc/debug.md](doc/debug.md)
walks through a session.

## Size

LUT and FF counts, block RAM in 36 Kb blocks, after place and route. The
core is the DUT alone; the design adds the harness and the memory behind it
(block RAM, or the board's memory controller; the PYNQ-Z1's is hard silicon
in its PS and is not counted).

| Target | Clock | Core LUT / FF / BRAM / DSP | Design LUT / FF / BRAM / DSP |
|---|---|---|---|
| `digilent/arty-a7-35` | 50 MHz | 3,088 / 1,030 / 1 / 0 | 9,436 / 6,656 / 17 / 0 |
| `digilent/pynq-z1` | 50 MHz | 3,199 / 1,030 / 1 / 0 | 4,158 / 2,174 / 17 / 0 |
| `xilinx/vcu118` | 50 MHz | 3,204 / 1,094 / 0 / 0 | 22,543 / 23,387 / 41.5 / 3 |

## Files

| | |
|---|---|
| `rtl/hazard3_top.veryl` | the DUT: Hazard3 with a fetch port, an AXI4 data port and its Debug Module |
| `rtl/hazard3.v` | Hazard3 and its Debug Module in one file (`make hazard3`) |
| `Harness.toml` | where each port goes |
| `asm/smoke.S` | the test program (`make asm`) |
| `bsp/` | startup, console (RTT, or the UART on QEMU) and exit for the firmware |
| `apps/` | the firmware: `hello`, `console`, `semihost` |
| `sim/` | the DUT alone in Verilator (`make sim`) |

Put paths for your machine in `local.mk`; see `Makefile`.

## License

MIT (`LICENSE`), except Hazard3 in `rtl/hazard3.v`, which is under the Apache
License 2.0 (`rtl/LICENSE.Hazard3`).
