//! Talks to the host by semihosting alone, so the same program works under
//! `hio cpu boot` and on QEMU. Exits with 3, so the status is seen to come
//! through.

#![no_std]
#![no_main]

use hazard3_bsp::{entry, semihosting};

#[entry]
fn main() -> ! {
    semihosting::write("hello from semihosting\n");
    semihosting::exit(3)
}
