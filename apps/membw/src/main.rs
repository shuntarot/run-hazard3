//! Memory bandwidth, in bytes per core cycle (mcycle).
//!
//! Hazard3 has no FPU and no cache, so:
//!
//! 1. Copy, Scale, Add and Triad of the STREAM benchmark on three arrays of
//!    32-bit integers, 1 MB each, counted as STREAM counts (bytes the kernel
//!    reads and writes), best of three. Twice: arrays back to back, and one
//!    line apart. Floating point would measure the software that does it.
//! 2. Loads only, from DRAM and from tcm, the block RAM that holds the code.
//! 3. Stores only, to DRAM.
//!
//! The loops are unrolled by hand, eight words a round, so the loop itself
//! costs little next to the memory.

#![no_std]
#![no_main]

use core::hint::black_box;
use core::ptr::{read_volatile, write_volatile};

use hazard3_bsp::{entry, exit, println, riscv};
use riscv::register::mcycle;

/// DRAM past the program's data and the RTT console: nothing else uses it.
const BUF: usize = 0x8200_0000;
/// tcm, from the start: the code. Reading it changes nothing.
const TCM: usize = 0x8000_0000;

const KB: usize = 1024;
const MB: usize = 1024 * KB;

/// Words in each STREAM array.
const N: usize = MB / 4;
const TIMES: usize = 3;
/// Times three is a shift and an add: Hazard3 here multiplies one bit a
/// cycle, which would hide the memory.
const SCALAR: u32 = 3;

const SIZES: &[usize] = &[4 * KB, 64 * KB, MB];

/// The core clock on the Arty, for MB/s.
const MHZ: u64 = 50;

/// Array `k`, `gap` bytes past the end of the one before it.
fn array(k: usize, gap: usize) -> *mut u32 {
    (BUF + k * (N * 4 + gap)) as *mut u32
}

/// Runs `f` and returns the cycles it took.
fn timed(f: impl FnOnce()) -> u64 {
    let t0 = mcycle::read64();
    f();
    mcycle::read64() - t0
}

/// Applies `f` to every index, eight at a time. `n` is a multiple of 8.
#[inline(always)]
fn each8(n: usize, mut f: impl FnMut(usize)) {
    let mut i = 0;
    while i < n {
        f(i);
        f(i + 1);
        f(i + 2);
        f(i + 3);
        f(i + 4);
        f(i + 5);
        f(i + 6);
        f(i + 7);
        i += 8;
    }
}

#[inline(never)]
fn copy(a: *const u32, c: *mut u32) {
    each8(N, |i| unsafe { write_volatile(c.add(i), read_volatile(a.add(i))) });
}

#[inline(never)]
fn scale(c: *const u32, b: *mut u32) {
    each8(N, |i| unsafe { write_volatile(b.add(i), SCALAR.wrapping_mul(read_volatile(c.add(i)))) });
}

#[inline(never)]
fn add(a: *const u32, b: *const u32, c: *mut u32) {
    each8(N, |i| unsafe {
        write_volatile(c.add(i), read_volatile(a.add(i)).wrapping_add(read_volatile(b.add(i))))
    });
}

#[inline(never)]
fn triad(b: *const u32, c: *const u32, a: *mut u32) {
    each8(N, |i| unsafe {
        let v = read_volatile(b.add(i)).wrapping_add(SCALAR.wrapping_mul(read_volatile(c.add(i))));
        write_volatile(a.add(i), v)
    });
}

/// Sums `words` 32-bit words from `p`, in eight sums that do not depend on
/// each other.
#[inline(never)]
fn read(p: *const u32, words: usize) -> u32 {
    let mut s = [0u32; 8];
    let mut i = 0;
    while i < words {
        unsafe {
            s[0] = s[0].wrapping_add(read_volatile(p.add(i)));
            s[1] = s[1].wrapping_add(read_volatile(p.add(i + 1)));
            s[2] = s[2].wrapping_add(read_volatile(p.add(i + 2)));
            s[3] = s[3].wrapping_add(read_volatile(p.add(i + 3)));
            s[4] = s[4].wrapping_add(read_volatile(p.add(i + 4)));
            s[5] = s[5].wrapping_add(read_volatile(p.add(i + 5)));
            s[6] = s[6].wrapping_add(read_volatile(p.add(i + 6)));
            s[7] = s[7].wrapping_add(read_volatile(p.add(i + 7)));
        }
        i += 8;
    }
    s.iter().fold(0, |a, &b| a.wrapping_add(b))
}

/// Stores `v` to `words` 32-bit words from `p`.
#[inline(never)]
fn write(p: *mut u32, words: usize, v: u32) {
    let mut i = 0;
    while i < words {
        unsafe {
            write_volatile(p.add(i), v);
            write_volatile(p.add(i + 1), v);
            write_volatile(p.add(i + 2), v);
            write_volatile(p.add(i + 3), v);
            write_volatile(p.add(i + 4), v);
            write_volatile(p.add(i + 5), v);
            write_volatile(p.add(i + 6), v);
            write_volatile(p.add(i + 7), v);
        }
        i += 8;
    }
}

/// One row: a label, bytes per cycle and MB/s at the Arty's clock.
fn show(label: &str, bytes: u64, cycles: u64) {
    let bpc = bytes * 100 / cycles;
    let mbs = bytes * MHZ / cycles;
    println!("{:>10} {:>5}.{:02} {:>8}", label, bpc / 100, bpc % 100, mbs);
}

/// A size in its largest whole unit, as a label.
fn size_label(bytes: usize, buf: &mut [u8; 8]) -> &str {
    let (mut v, unit) = if bytes.is_multiple_of(MB) {
        (bytes / MB, b'M')
    } else {
        (bytes / KB, b'K')
    };
    let mut n = buf.len();
    n -= 1;
    buf[n] = unit;
    loop {
        n -= 1;
        buf[n] = b'0' + (v % 10) as u8;
        v /= 10;
        if v == 0 {
            break;
        }
    }
    core::str::from_utf8(&buf[n..]).unwrap_or("?")
}

/// The values STREAM expects in each array after `TIMES` rounds.
fn expected() -> (u32, u32, u32) {
    let (mut a, mut b, mut c) = (1u32, 2u32, 0u32);
    for _ in 0..TIMES {
        c = a;
        b = SCALAR.wrapping_mul(c);
        c = a.wrapping_add(b);
        a = b.wrapping_add(SCALAR.wrapping_mul(c));
    }
    (a, b, c)
}

fn stream(gap: usize) {
    let (a, b, c) = (array(0, gap), array(1, gap), array(2, gap));
    each8(N, |i| unsafe {
        write_volatile(a.add(i), 1);
        write_volatile(b.add(i), 2);
        write_volatile(c.add(i), 0);
    });

    let mut best = [u64::MAX; 4];
    for _ in 0..TIMES {
        let t = [
            timed(|| copy(a, c)),
            timed(|| scale(c, b)),
            timed(|| add(a, b, c)),
            timed(|| triad(b, c, a)),
        ];
        for (b, t) in best.iter_mut().zip(t) {
            *b = (*b).min(t);
        }
    }

    let words = N as u64 * 4;
    show("Copy", 2 * words, best[0]);
    show("Scale", 2 * words, best[1]);
    show("Add", 3 * words, best[2]);
    show("Triad", 3 * words, best[3]);

    let (ea, eb, ec) = expected();
    for i in 0..N {
        let got = unsafe { (read_volatile(a.add(i)), read_volatile(b.add(i)), read_volatile(c.add(i))) };
        if got != (ea, eb, ec) {
            println!("wrong result at {i}: {got:?}, expected {:?}", (ea, eb, ec));
            exit(1);
        }
    }
}

/// Bytes per cycle of loads over `size` bytes from `p`: a pass to warm up,
/// then at least 1 MB and two passes, timed.
fn loads(label: &str, p: *const u32, size: usize) {
    let words = size / 4;
    let passes = (MB / size).max(2);
    black_box(read(p, words));
    let cycles = timed(|| {
        for _ in 0..passes {
            black_box(read(p, words));
        }
    });
    show(label, (size * passes) as u64, cycles);
}

#[entry]
fn main() -> ! {
    println!("membw: bandwidth, bytes per cycle, and MB/s at {MHZ} MHz");

    println!();
    println!("1. STREAM kernels on 32-bit integers over 3 x 1M, best of {TIMES}");
    for gap in [0, 64] {
        println!("gap between the arrays: {gap} bytes");
        println!("{:>10} {:>8} {:>8}", "kernel", "B/cycle", "MB/s");
        stream(gap);
    }

    let p = BUF as *mut u32;
    let mut label = [0u8; 8];

    println!();
    println!("2. loads only");
    println!("{:>10} {:>8} {:>8}", "size", "B/cycle", "MB/s");
    for &size in SIZES {
        loads(size_label(size, &mut label), p, size);
    }
    loads("tcm 16K", TCM as *const u32, 16 * KB);

    println!();
    println!("3. stores only");
    println!("{:>10} {:>8} {:>8}", "size", "B/cycle", "MB/s");
    for &size in SIZES {
        let words = size / 4;
        let passes = (MB / size).max(2);
        write(p, words, 0);
        let cycles = timed(|| {
            for k in 0..passes {
                write(p, words, k as u32);
            }
        });
        show(size_label(size, &mut label), (size * passes) as u64, cycles);
    }

    println!();
    println!("membw: done");
    exit(0)
}
