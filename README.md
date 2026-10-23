# run-hazard3

Runs the [Hazard3](https://github.com/Wren6991/Hazard3) RISC-V core (RV32IMAC,
Zbb, Zifencei, counters, Debug Module) on a Digilent Arty A7-35 with
[veryl-harness](https://github.com/shuntarot/uharness).

One address space: 64 KB of FPGA memory from 0x8000_0000 (`tcm`), the board's
DDR3 right after it (`dmem`), and a CLINT-style timer at 0x0200_0000
(`mtime` counts the 50 MHz core clock).

## Requirements

- Veryl, with `veryl-harness` and `hio`
- Vivado
- An Arty A7-35 on USB
- Rust through rustup, for the firmware
- `qemu-system-riscv32`, to run the firmware without the board

## Run

```bash
veryl harness gen --target digilent/arty-a7-35
make -C hns/syn
hio program
hio run bringup.hio       # loads asm/smoke.elf and reads back what it wrote
```

Firmware in Rust: `hio cpu boot` loads it and shows its RTT console (Ctrl-A x
leaves). If `gen` wrote somewhere other than `hns/`, change `HIO_REGS` in
`.cargo/config.toml`.

```bash
cargo run -p hello
cargo run -p console
cargo run-emu -p console   # the same on QEMU
```

The core's Debug Module: `hio cpu halt` (also `step`, `regs`, `resume`);
[doc/debug.md](doc/debug.md) walks through a session.

riscv-tests: `scripts/riscv-tests.sh <riscv-tests>/share/riscv-tests/isa`
(built for RV32).

## NuttX

`nuttx/` is a chip and a board for [NuttX](https://nuttx.apache.org/), kept
outside its tree. `nsh` runs on the RTT console.

```bash
export NUTTX_DIR=<nuttx checkout>   # with nuttx-apps at ../apps
nuttx/build.sh
hio cpu boot $NUTTX_DIR/nuttx
```

## mruby/c

`picoruby/` runs a Ruby script with [mruby/c](https://github.com/mrubyc/mrubyc)
(the VM of PicoRuby's FemtoRuby). Needs a PicoRuby checkout with its host
compiler (`MRUBY_CONFIG=build_config/picorbc.rb rake`).

```bash
make -C picoruby PICORUBY=<picoruby checkout>   # SCRIPTS="a.rb b.rb" for tasks
hio cpu boot picoruby/picoruby.elf
make -C sim picoruby                            # the same in Verilator
```

Speed and test results: [doc/performance.md](doc/performance.md).

## Size

LUT and FF counts, block RAM in 36 Kb blocks, after place and route. The core
is the DUT alone; the design adds the harness and the memory behind it.

| Target | Clock | Core LUT / FF / BRAM / DSP | Design LUT / FF / BRAM / DSP |
|---|---|---|---|
| `digilent/arty-a7-35` | 50 MHz | 3,300 / 1,202 / 1 / 0 | 9,632 / 6,828 / 17 / 0 |
| `digilent/pynq-z1` | 50 MHz | 3,246 / 1,069 / 1 / 0 | 4,171 / 2,213 / 17 / 0 |
| `xilinx/vcu118` | 50 MHz | 3,329 / 1,133 / 0 / 0 | 22,674 / 23,417 / 41.5 / 3 |

The PYNQ-Z1's DRAM is in the PS and not counted. The PYNQ-Z1 and VCU118 rows
are from before the timer, which adds about 150 LUTs and 130 FFs.

## Files

| | |
|---|---|
| `rtl/hazard3_top.veryl` | the DUT: one bus split into a memory port, an AXI4 port and the timer |
| `rtl/hazard3.v` | Hazard3 and its Debug Module in one file |
| `Harness.toml` | where each port goes |
| `bsp/`, `apps/` | the Rust firmware |
| `nuttx/` | NuttX chip, board and `build.sh` |
| `picoruby/` | mruby/c firmware |
| `asm/`, `sim/` | the test program, and the DUT in Verilator |

Put paths for your machine in `local.mk`; see `Makefile`.

## License

MIT or Apache-2.0, at your option. Hazard3 (`rtl/hazard3.v`) and `nuttx/` are
under the Apache License 2.0 only.
