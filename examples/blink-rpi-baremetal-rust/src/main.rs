//! Bare-metal blink of an LED on GPIO 17 (header pin 11, with a resistor to
//! ground). No OS: the GPU firmware loads the kernel image from the SD card
//! and jumps to `_start` (start64.s / start32.s), which calls `main`.
//!   kernel8.img (aarch64): Pi 3, 4, 5, Zero 2 W, told apart by CPU type
//!   kernel.img  (ARMv6):   Pi Zero, Zero W
#![no_std]
#![no_main]

use core::arch::global_asm;
use core::panic::PanicInfo;
use core::ptr::{read_volatile, write_volatile};

#[cfg(target_arch = "aarch64")]
global_asm!(include_str!("start64.s"));
#[cfg(target_arch = "arm")]
global_asm!(include_str!("start32.s"));

const LED_GPIO: u32 = 17;
const BLINK_DELAY_US: u32 = 500_000;

/// Reads a memory-mapped register. Only used with the fixed peripheral
/// addresses below, which are always mapped (the MMU is off).
fn read_reg(addr: usize) -> u32 {
    unsafe { read_volatile(addr as *const u32) }
}

fn write_reg(addr: usize, value: u32) {
    unsafe { write_volatile(addr as *mut u32, value) }
}

trait Led {
    fn toggle(&mut self);
}

/// GPIO block of the BCM2835 (Zero), BCM2837 (Pi 3, Zero 2 W) and BCM2711
/// (Pi 4), relative to the SoC's peripheral base.
struct BcmGpioPin {
    base: usize,
    pin: u32,
    on: bool,
}

impl BcmGpioPin {
    const GPSET0: usize = 0x1c;
    const GPCLR0: usize = 0x28;

    fn new(peripheral_base: usize, pin: u32) -> Self {
        let base = peripheral_base + 0x20_0000;
        let fsel = base + 4 * (pin as usize / 10);
        let shift = (pin % 10) * 3;
        write_reg(fsel, (read_reg(fsel) & !(7 << shift)) | (1 << shift)); // 001 = output
        Self { base, pin, on: false }
    }
}

impl Led for BcmGpioPin {
    fn toggle(&mut self) {
        self.on = !self.on;
        let reg = if self.on { Self::GPSET0 } else { Self::GPCLR0 };
        write_reg(self.base + reg, 1 << self.pin);
    }
}

fn blink(mut led: impl Led) -> ! {
    loop {
        led.toggle();
        delay_us(BLINK_DELAY_US);
    }
}

#[cfg(target_arch = "aarch64")]
mod board {
    use super::*;
    use core::arch::asm;

    /// Pi 5: the header is wired to the RP1 I/O chip, which the bootloader
    /// maps at 0x1f00000000 over PCIe (config.txt keeps the link up with
    /// `pciex4_reset=0`). Its GPIO block works like the RP2040's.
    pub struct Rp1GpioPin {
        pin: u32,
    }

    impl Rp1GpioPin {
        const IO_BANK0: usize = 0x1f_000d_0000; // per pin: STATUS, CTRL
        const SYS_RIO0: usize = 0x1f_000e_0000; // registered I/O: OUT, OE, IN
        const PADS_BANK0: usize = 0x1f_000f_0000;
        const XOR: usize = 0x1000; // atomic register aliases
        const SET: usize = 0x2000;
        const RIO_OUT: usize = 0x0;
        const RIO_OE: usize = 0x4;
        const FUNCSEL_SYS_RIO: u32 = 5;
        const PAD_OUTPUT_DISABLE: u32 = 1 << 7;

        pub fn new(pin: u32) -> Self {
            let n = pin as usize;
            write_reg(Self::IO_BANK0 + 8 * n + 4, Self::FUNCSEL_SYS_RIO); // CTRL
            let pad = Self::PADS_BANK0 + 4 + 4 * n;
            write_reg(pad, read_reg(pad) & !Self::PAD_OUTPUT_DISABLE);
            write_reg(Self::SYS_RIO0 + Self::SET + Self::RIO_OE, 1 << pin);
            Self { pin }
        }
    }

    impl Led for Rp1GpioPin {
        fn toggle(&mut self) {
            write_reg(Self::SYS_RIO0 + Self::XOR + Self::RIO_OUT, 1 << self.pin);
        }
    }

    pub const CORTEX_A72: u64 = 0xd08; // Pi 4 (BCM2711)
    pub const CORTEX_A76: u64 = 0xd0b; // Pi 5 (BCM2712)

    pub fn cpu_part() -> u64 {
        let midr: u64;
        unsafe { asm!("mrs {}, midr_el1", out(reg) midr) };
        (midr >> 4) & 0xfff
    }

    /// The Arm generic timer; the firmware sets its frequency (19.2 or 54 MHz).
    fn counter() -> u64 {
        let count: u64;
        unsafe { asm!("isb", "mrs {}, cntpct_el0", out(reg) count) };
        count
    }

    pub fn delay_us(us: u32) {
        let freq: u64;
        unsafe { asm!("mrs {}, cntfrq_el0", out(reg) freq) };
        let (start, ticks) = (counter(), freq * u64::from(us) / 1_000_000);
        while counter() - start < ticks {}
    }
}

#[cfg(target_arch = "aarch64")]
use board::delay_us;

#[cfg(target_arch = "aarch64")]
#[unsafe(no_mangle)]
extern "C" fn main() -> ! {
    match board::cpu_part() {
        board::CORTEX_A76 => blink(board::Rp1GpioPin::new(LED_GPIO)),
        // BCM2711 in its default "low peripheral" mode.
        board::CORTEX_A72 => blink(BcmGpioPin::new(0xfe00_0000, LED_GPIO)),
        _ => blink(BcmGpioPin::new(0x3f00_0000, LED_GPIO)), // Pi 3, Zero 2 W (Cortex-A53)
    }
}

/// ARMv6: Pi Zero / Zero W (BCM2835).
#[cfg(target_arch = "arm")]
const PERIPHERAL_BASE: usize = 0x2000_0000;

#[cfg(target_arch = "arm")]
fn delay_us(us: u32) {
    let clo = PERIPHERAL_BASE + 0x3004; // free-running 1 MHz counter
    let start = read_reg(clo);
    while read_reg(clo).wrapping_sub(start) < us {}
}

#[cfg(target_arch = "arm")]
#[unsafe(no_mangle)]
extern "C" fn main() -> ! {
    blink(BcmGpioPin::new(PERIPHERAL_BASE, LED_GPIO))
}

#[panic_handler]
fn panic(_: &PanicInfo) -> ! {
    loop {}
}
