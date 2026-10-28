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
0x20000  rvfi              region, 64k (1k x 64 bytes) -- `hio read rvfi 0x0 8`

0x200000  dmem_base_jtag    0x00000000
0x200004  dmem_base_pcie    0x00000000
0x200008  rvfi_run          0x00000000
0x20000c  rvfi_pause        0x00000000
0x200010  rvfi_count        0x00000000
0x200014  rvfi_wrapped      0x00000000
0x200018  rvfi_depth        0x00000400  (1k entries)
0x20001c  rvfi_arm          0x00000000
0x200020  rvfi_after        0x00000000
0x200024  rvfi_tmask        0x000000000000000000000000
0x200030  rvfi_tvalue       0x000000000000000000000000
0x20003c  rvfi_hit          0x00000000
0x200040  rvfi_hit_at       0x00000000
0x200044  tcm_depth         0x00004000  (16k entries)
0x200048  tcm_oor           0x00000000
0x20004c  dmem_calib        0x00000001
0x200050  dmem_depth        0x04000000  (64M entries)
0x200054  dmem_oor          0x00000000
0x200058  dut_reset         0x00000000
0x20005c  dut_reset_state   0x00000000
0x3ffff4  harness_timeout   0x00000000
0x3ffff8  harness_magic     0x5648524e
0x3ffffc  harness_map_hash  0x17ddb762
(hio)
```

`read dmem 0x100 4` reads memory the same way. `cpu` goes back to the CPU
commands. **Ctrl-A c** goes back to the console, and the program's waiting
output shows.

## 5. Record what the CPU ran

The harness keeps the last 1024 instructions the CPU retired, in FPGA memory
(`rvfi` above). `trace start` starts recording, and `trace dump` prints the
records, one per line: the cycle, the cycles since the line before, the mode,
the PC, the instruction, the register it wrote, and the memory it read (`ld`)
or wrote (`st`) with the byte mask.

While the CPU is stopped, the debugger's own work is not recorded. After a
`step`, the trace holds just the stepped instructions:

```console
(hio cpu) halt
hart 0 halted at pc 0x80000b86 <<rtt_target::DownChannel>::read+0x2c> (halt request)
=> 0x80000b86:  0230000f  fence   r,rw
(hio cpu) trace start
rvfi: recording
(hio cpu) step 3
pc 0x80000b8a <<rtt_target::DownChannel>::read+0x30> (single step)
=> 0x80000b8a:  008a2503  lw      a0,8(s4)
pc 0x80000b8e <<rtt_target::DownChannel>::read+0x34> (single step)
=> 0x80000b8e:  00ab3633  sltu    a2,s6,a0
pc 0x80000b92 <<rtt_target::DownChannel>::read+0x38> (single step)
=> 0x80000b92:  00aab533  sltu    a0,s5,a0
(hio cpu) trace dump
  50847623         M 80000b86  0230000f  fence   r,rw                      intr
  51753775 +906152  M 80000b8a  008a2503  lw      a0,8(s4)                  intr  a0=00000040  ld [80011b74]=00000040 m1111
  52657272 +903497  M 80000b8e  00ab3633  sltu    a2,s6,a0                  intr  a2=00000001
```

Hazard3 marks the first instruction after the debugger lets it go with
`intr`, so each stepped one has it.

With a breakpoint, the trace shows how the CPU got there. Here it stops
where the program echoes a key, in `_print`. Start the trace, let the CPU
go, switch to the console (**Ctrl-A c**) and type `a`. The key is not
echoed yet, because the CPU stops before it prints it, and the prompt comes
back by itself:

```console
(hio cpu) break hazard3_bsp::_print
breakpoint 0 at 0x80000592 <hazard3_bsp::_print>
(hio cpu) trace start
rvfi: recording
(hio cpu) resume
hart 0 running

hart 0 halted at pc 0x80000592 <hazard3_bsp::_print> (breakpoint)
=> 0x80000592:  1141      addi    sp,sp,-16
(hio cpu) trace dump --last 13
 150304175     +1  M 80000580  8082      ret
 150304177     +2  M 800003aa  8905      andi    a0,a0,1                   a0=00000001
 150304178     +1  M 800003ac  d97d      beqz    a0,0x800003a2
 150304179     +1  M 800003ae  0ff5f513  zext.b  a0,a1                     a0=00000061
 150304180     +1  M 800003b2  01450c63  beq     a0,s4,0x800003ca
 150304192    +12  M 800003b6  c42a      sw      a0,8(sp)                  st [800fffa8]=00000061 m1111
 150304204    +12  M 800003b8  c84e      sw      s3,16(sp)                 st [800fffb0]=800fffa8 m1111
 150304216    +12  M 800003ba  ca4a      sw      s2,20(sp)                 st [800fffb4]=80001934 m1111
 150304217     +1  M 800003bc  080c      addi    a1,sp,16                  a1=800fffb0
 150304218     +1  M 800003be  8526      mv      a0,s1                     a0=800101f3
 150304219     +1  M 800003c0  00000097  auipc   ra,0x0                    ra=800003c0
 150304220     +1  M 800003c4  1d2080e7  jalr    466(ra)                   ra=800003c8
 150304222     +2  M 80000592  1141      addi    sp,sp,-16                 trap
(13 of 20149931 records; the older ones were overwritten)
```

`getc` returns with a key (`a0=1`), the key is `a` (0x61), it is not `q`
(`s4`), and `main` calls `_print`. The breakpoint stops the CPU before the
last instruction runs, so that line is marked `trap`. `break --clear`
removes the breakpoint.

A trigger catches a moment without stopping the CPU. Here the trace freezes
4 records after the first one at 0x8000054c, where the RTT read returns to
`getc`:

```console
(hio cpu) break --clear
cleared 1 breakpoint
(hio cpu) resume
hart 0 running
(hio cpu) trace start --when pc_rdata=0x8000054c --after 4
rvfi: recording, until pc_rdata=0x8000054c and 4 after
(hio cpu) trace status
rvfi: frozen after the trigger, 61 records since the start, 61 in the ring of 1024
rvfi: triggered at record 56, and kept 4 after it
(hio cpu) trace dump --last 10
       422         M 80000c3c  4a22      lw      s4,8(sp)                  s4=00000071  ld [800fff78]=00000071 m1111
       446    +24  M 80000c3e  4a92      lw      s5,4(sp)                  s5=0000005b  ld [800fff74]=0000005b m1111
       470    +24  M 80000c40  4b02      lw      s6,0(sp)                  s6=0000005b  ld [800fff70]=0000005b m1111
       471     +1  M 80000c42  6105      addi    sp,sp,32                  sp=800fff90
       473     +2  M 80000c44  8082      ret
       475     +2  M 8000054c  85aa      mv      a1,a0                     a1=00000000  <= trigger
       476     +1  M 8000054e  8526      mv      a0,s1                     a0=00000000
       500    +24  M 80000550  4010      lw      a2,0(s0)                  a2=ffffffff  ld [80011b94]=ffffffff m1111
       524    +24  M 80000552  00314403  lbu     s0,3(sp)                  s0=00000000  ld [800fff90]=00000000 m1000
       525     +1  M 80000556  15fd      addi    a1,a1,-1                  a1=ffffffff
```

`--when` tests the fields that `trigger` names in `Harness.toml`: `pc_rdata`,
`trap` and `mem_addr`. `value/mask` tests some bits, and several `--when`
must all hold. `--now --after N` keeps the next N + 1 records, with no
condition. The frozen ring reads the same each time, until the next
`trace start`. A ring that is still recording changes while it is read, so
freeze it with a trigger, or `trace stop` it first.

## 6. Leave

Press **Ctrl-A x**, at the console or at the prompt. `hio` exits, and the
program goes on running on the board. To come back to its console later, without loading it again:

```console
$ hio cpu console target/riscv32imac-unknown-none-elf/debug/console
```

More in the `hio` guide (`doc/guide-hio.md` in veryl-harness): `info`,
`cpu boot --halt` to stop at the first instruction, and the other `trace`
options.
