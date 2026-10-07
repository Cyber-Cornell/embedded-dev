//! Register-level blink of GPIO 2, the on-board LED on most ESP32 DevKit
//! clones, without esp-hal or ESP-IDF. The mask ROM loads the program from
//! flash offset 0x1000 (in place of ESP-IDF's second-stage bootloader) into
//! RAM and calls `call_start_cpu0`.
#![no_std]
#![no_main]

use core::panic::PanicInfo;
use core::ptr::{addr_of_mut, read_volatile, write_volatile};

const RTC_CNTL_BASE: usize = 0x3ff4_8000;
const TIMG0_BASE: usize = 0x3ff5_f000;
const GPIO_BASE: usize = 0x3ff4_4000;
const IO_MUX_BASE: usize = 0x3ff4_9000;

/// Watchdog config registers are write-protected unless this key is written.
const WDT_WRITE_KEY: u32 = 0x50d8_3aa1;
const WDT_EN: u32 = 1 << 31;

const GPIO_OUT: usize = GPIO_BASE + 0x04;
const GPIO_ENABLE_W1TS: usize = GPIO_BASE + 0x24;
const GPIO_FUNC0_OUT_SEL_CFG: usize = GPIO_BASE + 0x530;
const IO_MUX_GPIO2: usize = IO_MUX_BASE + 0x40; // per-pin offsets are irregular
const MCU_SEL_SHIFT: u32 = 12;
const MCU_SEL_GPIO: u32 = 2; // IO_MUX function 3: plain GPIO
const SIG_GPIO_OUT_IDX: u32 = 256; // GPIO matrix: drive the pin from GPIO_OUT

const LED_PIN: usize = 2;

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

fn wdt_disable(config0: usize, wprotect: usize, flashboot_en: u32) {
    write_reg(wprotect, WDT_WRITE_KEY);
    modify_reg(config0, |r| r & !(WDT_EN | flashboot_en));
    write_reg(wprotect, 0);
}

fn delay(count: u32) {
    for i in 0..count {
        core::hint::black_box(i);
    }
}

unsafe extern "C" {
    static mut _bss_start: u32;
    static mut _bss_end: u32;
}

/// Entry point, called by the ROM once it has copied the image into RAM. It
/// runs on the ROM's stack with interrupts off and the CPU on the 40 MHz
/// crystal.
#[unsafe(no_mangle)]
extern "C" fn call_start_cpu0() -> ! {
    // Zero .bss (the ROM only copies loadable segments).
    unsafe {
        let mut p = addr_of_mut!(_bss_start);
        while p < addr_of_mut!(_bss_end) {
            write_volatile(p, 0);
            p = p.add(1);
        }
    }

    // When booting from flash the ROM arms the RTC watchdog and Timer Group 0's
    // watchdog ("flashboot protection"); they would reset the chip in ~1 s.
    wdt_disable(RTC_CNTL_BASE + 0x8c, RTC_CNTL_BASE + 0xa4, 1 << 10);
    wdt_disable(TIMG0_BASE + 0x48, TIMG0_BASE + 0x64, 1 << 14);

    modify_reg(IO_MUX_GPIO2, |r| {
        (r & !(7 << MCU_SEL_SHIFT)) | MCU_SEL_GPIO << MCU_SEL_SHIFT
    });
    write_reg(GPIO_FUNC0_OUT_SEL_CFG + 4 * LED_PIN, SIG_GPIO_OUT_IDX);
    write_reg(GPIO_ENABLE_W1TS, 1 << LED_PIN);

    loop {
        modify_reg(GPIO_OUT, |r| r ^ 1 << LED_PIN);
        delay(2_000_000);
    }
}

#[panic_handler]
fn panic(_: &PanicInfo) -> ! {
    loop {}
}
