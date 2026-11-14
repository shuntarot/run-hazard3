//! Load latency, in core cycles (mcycle).
//!
//! Every test is a pointer chase: each load reads the address of the next,
//! so no two loads overlap and the time per load is its latency. One pointer
//! sits in each 64-byte line, as it would on a core with caches. Hazard3 has
//! none, so this shows DRAM throughout, and the 1-cycle tcm next to it.
//!
//! 1. Latency against the size of the working set, lines in random order.
//! 2. The same, lines in address order: shows DRAM page hits, if any.
//! 3. Loads from tcm, the block RAM that holds the code.
//! 4. Several chases that do not depend on each other, side by side: whether
//!    the core keeps more than one load in flight.

#![no_std]
#![no_main]

use core::ptr::{addr_of, read_volatile, write_volatile};

use hazard3_bsp::{entry, exit, println, riscv};
use riscv::register::mcycle;

const LINE: usize = 64;
/// DRAM past the program's data and the RTT console: nothing else uses it.
const BUF: usize = 0x8200_0000;
/// The end of tcm.
const TCM_END: usize = 0x8001_0000;

const KB: usize = 1024;
const MB: usize = 1024 * KB;

const SIZES: &[usize] = &[KB, 4 * KB, 16 * KB, 64 * KB, 256 * KB, MB, 4 * MB, 16 * MB];

extern "C" {
    /// The end of the code, in tcm (riscv-rt's link.x).
    static __etext: u8;
}

/// xorshift32: a fixed seed, so every run chases the same order.
struct Rng(u32);

impl Rng {
    fn next(&mut self) -> u32 {
        let mut x = self.0;
        x ^= x << 13;
        x ^= x >> 17;
        x ^= x << 5;
        self.0 = x;
        x
    }
}

fn line(base: usize, i: usize) -> *mut usize {
    (base + i * LINE) as *mut usize
}

/// Links `n` lines at `base` into one cycle: line i holds the index of the
/// line after it, then its address. Random order is Sattolo's shuffle, which
/// turns the identity into a single cycle.
fn link(base: usize, n: usize, random: bool, rng: &mut Rng) -> usize {
    unsafe {
        for i in 0..n {
            let next = if random { i } else { (i + 1) % n };
            write_volatile(line(base, i), next);
        }
        if random {
            for i in (1..n).rev() {
                let j = rng.next() as usize % i;
                let a = read_volatile(line(base, i));
                let b = read_volatile(line(base, j));
                write_volatile(line(base, i), b);
                write_volatile(line(base, j), a);
            }
        }
        for i in 0..n {
            let next = read_volatile(line(base, i));
            write_volatile(line(base, i), base + next * LINE);
        }
    }
    base
}

/// Follows the chain for `8 * rounds` loads and returns the cycles taken and
/// where it stopped.
#[inline(never)]
fn chase(mut p: usize, rounds: usize) -> (u64, usize) {
    let t0 = mcycle::read64();
    for _ in 0..rounds {
        unsafe {
            p = read_volatile(p as *const usize);
            p = read_volatile(p as *const usize);
            p = read_volatile(p as *const usize);
            p = read_volatile(p as *const usize);
            p = read_volatile(p as *const usize);
            p = read_volatile(p as *const usize);
            p = read_volatile(p as *const usize);
            p = read_volatile(p as *const usize);
        }
    }
    (mcycle::read64() - t0, p)
}

/// Chases side by side, one pointer each, for `4 * rounds` loads each.
macro_rules! chase_side_by_side {
    ($name:ident, $($p:ident),+) => {
        #[inline(never)]
        fn $name($(mut $p: usize,)+ rounds: usize) -> u64 {
            let t0 = mcycle::read64();
            for _ in 0..rounds {
                unsafe {
                    $($p = read_volatile($p as *const usize);)+
                    $($p = read_volatile($p as *const usize);)+
                    $($p = read_volatile($p as *const usize);)+
                    $($p = read_volatile($p as *const usize);)+
                }
            }
            let t = mcycle::read64() - t0;
            core::hint::black_box(($($p,)+));
            t
        }
    };
}

chase_side_by_side!(chase1, a);
chase_side_by_side!(chase2, a, b);
chase_side_by_side!(chase3, a, b, c);
chase_side_by_side!(chase4, a, b, c, d);

/// One row: a size (or a count when `unit` is empty) and cycles per load.
fn show(v: usize, unit: &str, cycles: u64, loads: usize) {
    let c = cycles * 100 / loads as u64;
    println!("{:>8}{:<2} {:>5}.{:02}", v, unit, c / 100, c % 100);
}

fn show_size(bytes: usize, cycles: u64, loads: usize) {
    if bytes.is_multiple_of(MB) {
        show(bytes / MB, "M", cycles, loads);
    } else {
        show(bytes / KB, "K", cycles, loads);
    }
}

/// The chain from `start` must come back to it after exactly `n` loads, and
/// stay inside the `n` lines from `base`.
fn check_cycle(base: usize, start: usize, n: usize) {
    let mut p = start;
    for step in 1..=n {
        p = unsafe { read_volatile(p as *const usize) };
        if p < base || p >= base + n * LINE || !p.is_multiple_of(LINE) {
            println!("bad chain: step {step} of {n} reads {p:#x}");
            exit(1);
        }
        if p == start && step != n {
            println!("bad chain: back at the start after {step} of {n}");
            exit(1);
        }
    }
    if p != start {
        println!("bad chain: not back at the start after {n}");
        exit(1);
    }
}

/// Latency per load over `size` bytes of lines at `base`: one pass to warm
/// up, then at least two passes and 16384 loads, timed.
fn by_size(base: usize, size: usize, random: bool, rng: &mut Rng) -> (u64, usize) {
    let n = size / LINE;
    let p = link(base, n, random, rng);
    check_cycle(base, p, n);
    let (_, p) = chase(p, n.div_ceil(8));
    let rounds = (2 * n).max(16384) / 8;
    let (cycles, _) = chase(p, rounds);
    (cycles, rounds * 8)
}

#[entry]
fn main() -> ! {
    let mut rng = Rng(0x9e37_79b9);

    println!("memlat: load latency, cycles per load (mcycle)");

    println!();
    println!("1. working set, lines in random order");
    println!("{:>10} {:>8}", "size", "cycles");
    for &size in SIZES {
        let (cycles, loads) = by_size(BUF, size, true, &mut rng);
        show_size(size, cycles, loads);
    }

    println!();
    println!("2. working set, lines in address order");
    println!("{:>10} {:>8}", "size", "cycles");
    for &size in &[8 * KB, 64 * KB, MB, 16 * MB] {
        let (cycles, loads) = by_size(BUF, size, false, &mut rng);
        show_size(size, cycles, loads);
    }

    println!();
    println!("3. tcm, past the code");
    println!("{:>10} {:>8}", "size", "cycles");
    {
        let base = (addr_of!(__etext) as usize).next_multiple_of(LINE);
        let size = KB;
        if base + size > TCM_END {
            println!("no room in tcm past the code at {base:#x}");
            exit(1);
        }
        let (cycles, loads) = by_size(base, size, true, &mut rng);
        show_size(size, cycles, loads);
    }

    println!();
    println!("4. independent chases side by side over 16M, cycles per load");
    println!("{:>10} {:>8}", "chases", "cycles");
    {
        let n = 16 * MB / LINE;
        let p0 = link(BUF, n, true, &mut rng);
        // Start points a quarter of the cycle apart, so the chases never meet.
        let mut starts = [p0; 4];
        let mut p = p0;
        for (s, start) in starts.iter_mut().enumerate() {
            if s > 0 {
                let (_, q) = chase(p, n / 4 / 8);
                p = q;
            }
            *start = p;
        }
        let rounds = 4096;
        let [a, b, c, d] = starts;
        show(1, "", chase1(a, rounds), rounds * 4);
        show(2, "", chase2(a, b, rounds), rounds * 4 * 2);
        show(3, "", chase3(a, b, c, rounds), rounds * 4 * 3);
        show(4, "", chase4(a, b, c, d, rounds), rounds * 4 * 4);
    }

    println!();
    println!("memlat: done");
    exit(0)
}
