//! Blinks GPIO 2, the on-board LED on most ESP32 DevKit boards.
#![no_std]
#![no_main]

use esp_hal::{
    gpio::{Level, Output, OutputConfig},
    main,
    time::{Duration, Instant},
};

esp_bootloader_esp_idf::esp_app_desc!();

#[panic_handler]
fn panic(_info: &core::panic::PanicInfo) -> ! {
    loop {}
}

#[main]
fn main() -> ! {
    let peripherals = esp_hal::init(esp_hal::Config::default());
    let mut led = Output::new(peripherals.GPIO2, Level::Low, OutputConfig::default());

    loop {
        led.toggle();
        let start = Instant::now();
        while start.elapsed() < Duration::from_millis(500) {}
    }
}
