//! Register-level blink of the blue channel of the LP-MSPM0L2228's RGB LED
//! (LED4), without a HAL or PAC. Blue is PA23 (jumper J4), red PB10 (J5),
//! green PB9 (J6). Addresses and keys are from the MSPM0 SDK's mspm0l222x.h,
//! hw_gpio.h and hw_iomux.h.
#![no_std]
#![no_main]

use core::arch::asm;
use core::panic::PanicInfo;
use core::ptr::write_volatile;

use cortex_m_rt::entry;

const GPIOA_BASE: usize = 0x400A_0000;
const GPIOA_PWREN: usize = GPIOA_BASE + 0x800;
const GPIOA_RSTCTL: usize = GPIOA_BASE + 0x804;
const GPIOA_DOUTTGL31_0: usize = GPIOA_BASE + 0x12B0;
const GPIOA_DOESET31_0: usize = GPIOA_BASE + 0x12D0;
const IOMUX_BASE: usize = 0x4042_8000;

/// Address of pin control register PINCMn (numbered from 1, as in the
/// datasheet).
const fn iomux_pincm(n: usize) -> usize {
    IOMUX_BASE + 4 * n
}

// Power-enable and reset registers only accept writes that carry their key in
// the top byte.
const PWREN_KEY: u32 = 0x2600_0000;
const PWREN_ENABLE: u32 = 1 << 0;
const RSTCTL_KEY: u32 = 0xB100_0000;
const RSTCTL_RESETSTKYCLR: u32 = 1 << 1;
const RSTCTL_RESETASSERT: u32 = 1 << 0;
const PINCM_PC: u32 = 1 << 7; // pin connected to its peripheral
const PINCM_PF_GPIO: u32 = 1; // peripheral function 1 is GPIO on every pin

const LED_PIN: u32 = 23; // PA23
const LED_PINCM: usize = 67; // PA23's pin control register

/// Writes a memory-mapped register. Only used with the fixed peripheral
/// addresses above.
fn write_reg(addr: usize, value: u32) {
    unsafe { write_volatile(addr as *mut u32, value) }
}

fn delay(count: u32) {
    for _ in 0..count {
        unsafe { asm!("nop") };
    }
}

#[entry]
fn main() -> ! {
    // Reset GPIOA, then power it up and give it time to start.
    write_reg(
        GPIOA_RSTCTL,
        RSTCTL_KEY | RSTCTL_RESETSTKYCLR | RSTCTL_RESETASSERT,
    );
    write_reg(GPIOA_PWREN, PWREN_KEY | PWREN_ENABLE);
    delay(16);

    write_reg(iomux_pincm(LED_PINCM), PINCM_PC | PINCM_PF_GPIO);
    write_reg(GPIOA_DOESET31_0, 1 << LED_PIN);

    loop {
        write_reg(GPIOA_DOUTTGL31_0, 1 << LED_PIN);
        delay(3_000_000); // the core runs from the 32 MHz SYSOSC after reset
    }
}

#[panic_handler]
fn panic(_: &PanicInfo) -> ! {
    loop {}
}
