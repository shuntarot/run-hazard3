//! Board support for Hazard3 under veryl-harness.
//!
//! An application depends on this crate and nothing else:
//!
//! ```ignore
//! #![no_std]
//! #![no_main]
//!
//! use hazard3_bsp::{entry, exit, println};
//!
//! #[entry]
//! fn main() -> ! {
//!     println!("hello");
//!     exit(0)
//! }
//! ```
//!
//! The console is SEGGER RTT in dmem, which the host reads through the
//! harness window (`hio boot` / `hio console`). It is up before `main`.

#![no_std]

pub use riscv;
pub use riscv_rt::entry;

mod rtt;

#[doc(hidden)]
pub use rtt::_print;

/// Reads one byte the host typed, or `None`. Never blocks.
pub fn getc() -> Option<u8> {
    rtt::getc()
}

/// Ends the program with `code`. `hio boot` exits with the same status.
pub fn exit(code: u8) -> ! {
    rtt::exit(code);
    loop {
        riscv::asm::wfi();
    }
}

/// Sets RTT up before `main`, so a panic in setup still has a console.
#[riscv_rt::post_init]
unsafe fn post_init(_hartid: usize) {
    rtt::init();
}

#[macro_export]
macro_rules! print {
    ($($arg:tt)*) => {
        $crate::_print(core::format_args!($($arg)*))
    };
}

#[macro_export]
macro_rules! println {
    ()            => { $crate::print!("\n") };
    ($($arg:tt)*) => { $crate::print!("{}\n", core::format_args!($($arg)*)) };
}

/// Any exception without its own handler: show where, then stop with 102.
#[export_name = "ExceptionHandler"]
fn exception_handler(trap_frame: &riscv_rt::TrapFrame) -> ! {
    use riscv::register::{mcause, mepc, mtval};
    println!();
    println!("*** exception ***");
    println!("  mcause {:#010x}", mcause::read().bits());
    println!("  mepc   {:#010x}", mepc::read());
    println!("  mtval  {:#010x}", mtval::read());
    println!("  ra     {:#010x}", trap_frame.ra);
    exit(102)
}

/// A panic stops with 101, as a panicking Rust program does.
#[panic_handler]
fn panic(info: &core::panic::PanicInfo) -> ! {
    println!();
    println!("*** panic ***");
    println!("{info}");
    exit(101)
}
