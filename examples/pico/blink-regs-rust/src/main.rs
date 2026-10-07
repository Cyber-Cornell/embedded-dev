//! Register-level blink of the on-board LED (GPIO 25) of the Raspberry Pi
//! Pico (RP2040) and Pico 2 (RP2350), without a HAL or PAC. The chip follows
//! the target; see .cargo/config.toml. The Pico W / Pico 2 W LEDs hang off the
//! CYW43 wireless chip instead.
#![no_std]
#![no_main]

use core::arch::asm;
use core::panic::PanicInfo;
use core::ptr::{read_volatile, write_volatile};

use cortex_m_rt::entry;

/// RP2040: second-stage bootloader for the Pico's W25Q080 flash chip.
#[cfg(not(rp2350))]
#[unsafe(link_section = ".boot2")]
#[used]
pub static BOOT2_FIRMWARE: [u8; 256] = rp2040_boot2::BOOT_LOADER_W25Q080;

/// RP2350: the IMAGE_DEF block the boot ROM needs before it runs the image
/// (the same one the Pico SDK's crt0 embeds).
#[cfg(rp2350)]
#[unsafe(link_section = ".start_block")]
#[used]
pub static IMAGE_DEF: [u32; 5] = [
    0xffff_ded3, // PICOBIN_BLOCK_MARKER_START
    0x1021_0142, // IMAGE_TYPE item: EXE, Arm, secure, RP2350
    0x0000_01ff, // LAST item, block size 1 word
    0x0000_0000, // relative link to the next block: 0 = this block only
    0xab12_3579, // PICOBIN_BLOCK_MARKER_END
];

#[cfg(not(rp2350))]
mod chip {
    pub const RESETS_BASE: usize = 0x4000_c000;
    pub const IO_BANK0_BASE: usize = 0x4001_4000;
    pub const PADS_BANK0_BASE: usize = 0x4001_c000;
    pub const SIO_GPIO_OUT_XOR: usize = 0x1c;
    pub const SIO_GPIO_OE_SET: usize = 0x24;
    pub const RESET_IO_BANK0: u32 = 1 << 5;
    pub const RESET_PADS_BANK0: u32 = 1 << 8;
}

#[cfg(rp2350)]
mod chip {
    pub const RESETS_BASE: usize = 0x4002_0000;
    pub const IO_BANK0_BASE: usize = 0x4002_8000;
    pub const PADS_BANK0_BASE: usize = 0x4003_8000;
    pub const SIO_GPIO_OUT_XOR: usize = 0x28;
    pub const SIO_GPIO_OE_SET: usize = 0x38;
    pub const RESET_IO_BANK0: u32 = 1 << 6;
    pub const RESET_PADS_BANK0: u32 = 1 << 9;
}

use chip::*;

const SIO_BASE: usize = 0xd000_0000;
/// Every peripheral register has an atomic bit-clear alias at +0x3000.
const ATOMIC_CLEAR: usize = 0x3000;

const GPIO_FUNC_SIO: u32 = 5;
/// RP2350 only: the pad stays isolated until this is cleared. Reserved (and 0)
/// on the RP2040.
const PAD_ISO: u32 = 1 << 8;

const LED_PIN: usize = 25;

/// Reads a memory-mapped register. Only used with the fixed peripheral
/// addresses above.
fn read_reg(addr: usize) -> u32 {
    unsafe { read_volatile(addr as *const u32) }
}

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
    // Take the GPIO blocks out of reset and wait until they are ready.
    let mask = RESET_IO_BANK0 | RESET_PADS_BANK0;
    write_reg(RESETS_BASE + ATOMIC_CLEAR, mask); // RESET
    while read_reg(RESETS_BASE + 0x8) & mask != mask {} // RESET_DONE

    write_reg(IO_BANK0_BASE + 0x4 + 8 * LED_PIN, GPIO_FUNC_SIO); // GPIOn_CTRL
    write_reg(PADS_BANK0_BASE + ATOMIC_CLEAR + 0x4 + 4 * LED_PIN, PAD_ISO);
    write_reg(SIO_BASE + SIO_GPIO_OE_SET, 1 << LED_PIN);

    loop {
        write_reg(SIO_BASE + SIO_GPIO_OUT_XOR, 1 << LED_PIN);
        // Nothing sets up the clocks, so the core runs from the ring
        // oscillator (~6 MHz RP2040, ~11 MHz RP2350): a few blinks a second.
        delay(300_000);
    }
}

#[panic_handler]
fn panic(_: &PanicInfo) -> ! {
    loop {}
}
