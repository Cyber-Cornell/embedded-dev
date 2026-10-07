//! Blinks the blue channel of the LP-MSPM0L2228's RGB LED (LED4) with
//! embassy-mspm0. Blue is PA16, red PB10, green PB9, each through a jumper
//! labeled with its pin. (TI's SDK example READMEs say PA23 for blue; the
//! board is wired to PA16.)
#![no_std]
#![no_main]

use embassy_executor::Spawner;
use embassy_mspm0::Config;
use embassy_mspm0::gpio::{Level, Output};
use embassy_time::Timer;
use panic_halt as _;

#[embassy_executor::main]
async fn main(_spawner: Spawner) -> ! {
    let p = embassy_mspm0::init(Config::default());
    let mut led = Output::new(p.PA16, Level::Low);

    loop {
        led.toggle();
        Timer::after_millis(500).await;
    }
}
