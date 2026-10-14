# run-hazard3

Runs the [Hazard3](https://github.com/Wren6991/Hazard3) RISC-V core (RV32IMAC)
on a Digilent Arty A7-35 with
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
console, and exits with its status; Ctrl-A x leaves.

```bash
cargo run -p hello
cargo run -p console
cargo run-emu -p console   # the same on QEMU's virt machine
```

## Files

| | |
|---|---|
| `rtl/hazard3_top.veryl` | the DUT: Hazard3 with a fetch port and an AXI4 data port |
| `rtl/hazard3.v` | Hazard3 in one file (`make hazard3`) |
| `Harness.toml` | where each port goes |
| `asm/smoke.S` | the test program (`make asm`) |
| `bsp/` | startup, console (RTT, or the UART on QEMU) and exit for the firmware |
| `apps/` | the firmware: `hello`, `console` |
| `sim/` | the DUT alone in Verilator (`make sim`) |

Put paths for your machine in `local.mk`; see `Makefile`.

## License

MIT (`LICENSE`), except Hazard3 in `rtl/hazard3.v`, which is under the Apache
License 2.0 (`rtl/LICENSE.Hazard3`).
