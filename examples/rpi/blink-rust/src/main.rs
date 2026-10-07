//! Blinks an LED on GPIO 17 (header pin 11, with a resistor to ground) of a
//! Raspberry Pi 3, 4, 5, Zero, Zero W or Zero 2 W, through the kernel's GPIO
//! character device (/dev/gpiochipN). Needs no root or device tree changes;
//! the default user is in the `gpio` group.

use std::thread::sleep;
use std::time::Duration;

use gpiocdev::line::Value;
use gpiocdev::{Request, chip};

const LED_GPIO: u32 = 17;
const BLINK_DELAY: Duration = Duration::from_millis(500);

/// Labels of the chip that drives the 40-pin header. Its gpiochip number
/// varies (the Pi 5's RP1 was gpiochip4 on older kernels), so look it up by
/// label.
const HEADER_CHIPS: [&str; 3] = [
    "pinctrl-bcm2835", // Pi Zero, Zero W, Zero 2 W, 3
    "pinctrl-bcm2711", // Pi 4
    "pinctrl-rp1",     // Pi 5
];

fn header_chip() -> Result<std::path::PathBuf, Box<dyn std::error::Error>> {
    for path in chip::chips()? {
        // Skip chips we can't open; only the header chip matters.
        let Ok(info) = chip::Chip::from_path(&path).and_then(|c| c.info()) else {
            continue;
        };
        if HEADER_CHIPS.contains(&info.label.as_str()) {
            return Ok(path);
        }
    }
    Err("no Raspberry Pi GPIO header chip found in /dev".into())
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    // The line stays claimed until `led` is dropped, i.e. when the process exits.
    let led = Request::builder()
        .on_chip(header_chip()?)
        .with_consumer("blink")
        .with_line(LED_GPIO)
        .as_output(Value::Inactive)
        .request()?;

    let mut value = Value::Inactive;
    loop {
        value = value.not();
        led.set_value(LED_GPIO, value)?;
        sleep(BLINK_DELAY);
    }
}
