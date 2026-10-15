//! Semihosting: the host does the work for the program.
//!
//! Under `hio cpu boot` the debugger answers, and on QEMU QEMU does
//! (`-semihosting`), so a program that uses only this runs on both. Each call
//! halts the core until the host answers; the RTT console is the fast path.

use core::sync::atomic::{AtomicUsize, Ordering};

const SYS_OPEN: usize = 0x01;
const SYS_WRITE: usize = 0x05;
const SYS_EXIT_EXTENDED: usize = 0x20;

/// `ADP_Stopped_ApplicationExit`: the program ended as it meant to.
const APPLICATION_EXIT: usize = 0x20026;

/// The terminal's handle, once opened; `usize::MAX` before.
static TERMINAL: AtomicUsize = AtomicUsize::new(usize::MAX);

/// Calls the host: operation `op`, parameter `arg`, result back.
fn call(op: usize, arg: usize) -> usize {
    let mut a0 = op;
    // SAFETY: the three instructions are the semihosting call. They must stay
    // uncompressed and together, which is how the host knows the `ebreak`.
    unsafe {
        core::arch::asm!(
            ".option push",
            ".option norvc",
            "slli x0, x0, 0x1f",
            "ebreak",
            "srai x0, x0, 7",
            ".option pop",
            inout("a0") a0,
            in("a1") arg,
            options(nostack),
        );
    }
    a0
}

fn terminal() -> usize {
    let open = TERMINAL.load(Ordering::Relaxed);
    if open != usize::MAX {
        return open;
    }
    // Mode 4 is "w": standard output.
    let name = b":tt\0";
    let block = [name.as_ptr() as usize, 4, 3];
    let handle = call(SYS_OPEN, block.as_ptr() as usize);
    TERMINAL.store(handle, Ordering::Relaxed);
    handle
}

/// Writes to the host's terminal.
pub fn write(text: &str) {
    let block = [terminal(), text.as_ptr() as usize, text.len()];
    call(SYS_WRITE, block.as_ptr() as usize);
}

/// Ends the program; the host exits with `code`.
pub fn exit(code: u8) -> ! {
    let block = [APPLICATION_EXIT, usize::from(code)];
    call(SYS_EXIT_EXTENDED, block.as_ptr() as usize);
    loop {
        riscv::asm::wfi();
    }
}
