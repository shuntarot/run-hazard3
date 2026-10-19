# Debugging the CPU

`cargo run` loads the firmware and opens its console. The same terminal also
has a debug prompt: you can stop the CPU, look at its registers, step it, and
go on, without leaving the console. This page walks through one session.

The keys:

| Key | What it does |
|---|---|
| Ctrl-A c | switch between the console and the debug prompt |
| Ctrl-A x | leave `hio`; the program keeps running |

## 1. Start the program

```console
$ cargo run -p console
     Running `hio cpu boot target/riscv32imac-unknown-none-elf/debug/console`
ok: the DUT is held in reset. Release it with: hio reset --release
  0x0080000000 -> tcm  7190 bytes
  0x0080010000 -> dmem  2844 bytes
  0x0080010b1c -> dmem  4 bytes
ok: the DUT is running
hio: connected to RTT at 0x80011b24; Ctrl-A c debug prompt, Ctrl-A x leaves
Hazard3 console
  misa      0x40801105 ACIMX
  mvendorid 0x00000000
  marchid   0x0000001b
  mimpid    0x01010100
  sections  .rodata 0xaaaa5555 .data 0x12345678 .bss 0x00000000 -> ok
type something; q exits
```

The program is running, and what you type goes to it.

## 2. Open the debug prompt, stop the CPU, read its registers

Press **Ctrl-A c**. The prompt `(hio cpu)` appears. The program still runs;
its output waits until you go back to the console.

`halt` stops the CPU. `hio` shows where it stopped, by function name:

```console
(hio cpu) halt
hart 0 halted at pc 0x80000c42 <<rtt_target::DownChannel>::read+0xe8> (halt request)
```

Here the program was waiting for a key, inside the RTT read.

`regs` shows the integer registers and the main CSRs:

```console
(hio cpu) regs
  x0 zero 0x00000000    x1 ra   0x8000054c    x2 sp   0x800fff70    x3 gp   0x8001131c
  x4 tp   0x00000000    x5 t0   0x00000a73    x6 t1   0x00000010    x7 t2   0x00000073
  x8 s0   0x80011b94    x9 s1   0x00000000   x10 a0   0x00000000   x11 a1   0x00000000
 x12 a2   0x00000001   x13 a3   0x80011b9c   x14 a4   0x80010bf4   x15 a5   0x00000018
 x16 a6   0x0a737469   x17 a7   0x0a730000   x18 s2   0x80001934   x19 s3   0x800fffa8
 x20 s4   0x00000071   x21 s5   0x0000005b   x22 s6   0x0000005b   x23 s7   0x00000000
 x24 s8   0x00000000   x25 s9   0x00000000   x26 s10  0x00000000   x27 s11  0x00000000
 x28 t3   0x800fff26   x29 t4   0x00000002   x30 t5   0x00000000   x31 t6   0x00000000
mstatus   0x00001800
misa      0x40801105
mie       0x00000000
mtvec     0x800000f8
mscratch  0x00000000
mepc      0x00000000
mcause    0x00000000
mtval     0x00000000
mip       0x00000000
dcsr      0x400086c3
dpc       0x80000c42
halted at pc 0x80000c42 <<rtt_target::DownChannel>::read+0xe8> (halt request)
```

`dpc` is where the CPU will go on from. `regs <name>` reads one register,
for example `regs a0` or `regs mstatus`.

## 3. Step

`step` runs one instruction and stops again (`step 3` runs three). Each step
prints the new PC and its function:

```console
(hio cpu) step
pc 0x80000c44 <<rtt_target::DownChannel>::read+0xea> (single step)
(hio cpu) step
pc 0x8000054c <hazard3_bsp::getc+0x44> (single step)
```

The second step returned from the RTT read to its caller, `getc`: the new PC
is the `ra` that `regs` showed before. `regs` again shows what changed, here
the stack pointer, which moved back by the read's stack frame:

```console
(hio cpu) regs
  x0 zero 0x00000000    x1 ra   0x8000054c    x2 sp   0x800fff90    x3 gp   0x8001131c
  ...
dpc       0x8000054c
halted at pc 0x8000054c <hazard3_bsp::getc+0x44> (single step)
```

## 4. Go on, and use the other `hio` commands

`resume` lets the CPU run again:

```console
(hio cpu) resume
hart 0 running
```

The prompt starts at the CPU commands. `hio` goes to the other commands,
the ones you would type after `hio` in a shell. For example `dump` lists the
harness registers and memories:

```console
(hio cpu) hio
(hio) dump
0x0000  tcm               region, 64k (16k x 4 bytes) -- `hio read tcm 0x0 8`
0x100000  dmem              region, 256M (64M x 4 bytes) -- `hio read dmem 0x0 8`
0x10000  dmi               region, 512 (128 x 4 bytes) -- `hio read dmi 0x0 8`

0x200000  dmem_base_jtag    0x00000000
0x200004  dmem_base_pcie    0x00000000
0x200008  tcm_depth         0x00004000  (16k entries)
0x20000c  tcm_oor           0x00000000
0x200010  dmem_calib        0x00000001
0x200014  dmem_depth        0x04000000  (64M entries)
0x200018  dmem_oor          0x00000000
0x20001c  dut_reset         0x00000000
0x200020  dut_reset_state   0x00000000
0x3ffff4  harness_timeout   0x00000000
0x3ffff8  harness_magic     0x5648524e
0x3ffffc  harness_map_hash  0xeeff33af
(hio)
```

`read dmem 0x100 4` reads memory the same way. `cpu` goes back to the CPU
commands. **Ctrl-A c** goes back to the console, and the program's waiting
output shows.

## 5. Leave

Press **Ctrl-A x**, at the console or at the prompt. `hio` exits, and the
program goes on running on the board. To come back to its console later, without loading it again:

```console
$ hio cpu console target/riscv32imac-unknown-none-elf/debug/console
```

More in the `hio` guide (`doc/guide-hio.md` in veryl-harness): breakpoints
(`break <function>`), `info`, and `cpu boot --halt` to stop at the first
instruction.
