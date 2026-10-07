//! Register-level blink of LED1 (P1.0) on the MSP-EXP430G2ET LaunchPad,
//! without a PAC.
#![no_std]
#![no_main]

use core::hint::black_box;
use core::panic::PanicInfo;
use core::ptr::{read_volatile, write_volatile};

use msp430_rt::entry;

const WDTCTL: usize = 0x0120;
const WDTPW: u16 = 0x5a00;
const WDTHOLD: u16 = 0x0080;
const P1OUT: usize = 0x0021;
const P1DIR: usize = 0x0022;

const LED1: u8 = 1 << 0;

/// Read-modify-writes an 8-bit peripheral register at one of the fixed
/// addresses above.
fn modify_reg8(addr: usize, f: impl FnOnce(u8) -> u8) {
    unsafe { write_volatile(addr as *mut u8, f(read_volatile(addr as *const u8))) }
}

#[entry]
fn main() -> ! {
    // Stop the watchdog timer.
    unsafe { write_volatile(WDTCTL as *mut u16, WDTPW | WDTHOLD) };

    modify_reg8(P1DIR, |r| r | LED1);
    modify_reg8(P1OUT, |r| r & !LED1);

    loop {
        modify_reg8(P1OUT, |r| r ^ LED1);
        for i in 0..20_000u16 {
            black_box(i);
        }
    }
}

#[panic_handler]
fn panic(_: &PanicInfo) -> ! {
    loop {}
}
