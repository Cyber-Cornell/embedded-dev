//! Register-level blink of the Nucleo-F401RE user LED (LD2 on PA5), without a
//! HAL or PAC.
#![no_std]
#![no_main]

use core::arch::asm;
use core::panic::PanicInfo;
use core::ptr::{read_volatile, write_volatile};

use cortex_m_rt::entry;

const RCC_AHB1ENR: usize = 0x4002_3800 + 0x30;
const GPIOA_BASE: usize = 0x4002_0000;
const GPIOA_MODER: usize = GPIOA_BASE;
const GPIOA_ODR: usize = GPIOA_BASE + 0x14;

const LED_PIN: u32 = 5;

/// Reads a memory-mapped register. Only used with the fixed peripheral
/// addresses above.
fn read_reg(addr: usize) -> u32 {
    unsafe { read_volatile(addr as *const u32) }
}

fn write_reg(addr: usize, value: u32) {
    unsafe { write_volatile(addr as *mut u32, value) }
}

fn modify_reg(addr: usize, f: impl FnOnce(u32) -> u32) {
    write_reg(addr, f(read_reg(addr)));
}

fn delay(count: u32) {
    for _ in 0..count {
        unsafe { asm!("nop") };
    }
}

#[entry]
fn main() -> ! {
    modify_reg(RCC_AHB1ENR, |r| r | 1 << 0); // GPIOA clock enable

    // PA5 -> general-purpose output
    modify_reg(GPIOA_MODER, |r| {
        (r & !(3 << (LED_PIN * 2))) | 1 << (LED_PIN * 2)
    });

    loop {
        modify_reg(GPIOA_ODR, |r| r ^ 1 << LED_PIN);
        delay(1_000_000); // the core runs from the 16 MHz HSI after reset
    }
}

#[panic_handler]
fn panic(_: &PanicInfo) -> ! {
    loop {}
}
