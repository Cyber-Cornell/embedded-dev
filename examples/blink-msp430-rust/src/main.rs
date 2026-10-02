//! Blinks LED1 (P1.0) on the MSP-EXP430G2ET LaunchPad.
#![no_std]
#![no_main]

use msp430_rt::entry;
use msp430g2553::Peripherals;
use panic_msp430 as _;

#[entry]
fn main() -> ! {
    let p = Peripherals::take().unwrap();

    // Stop the watchdog timer.
    p.WATCHDOG_TIMER
        .wdtctl
        .write(|w| unsafe { w.wdtpw().bits(0x5A) }.wdthold().set_bit());

    p.PORT_1_2.p1dir.modify(|_, w| w.p0().set_bit());
    p.PORT_1_2.p1out.modify(|_, w| w.p0().clear_bit());

    loop {
        p.PORT_1_2.p1out.modify(|r, w| w.p0().bit(!r.p0().bit()));
        for _ in 0..20_000 {
            msp430::asm::nop();
        }
    }
}
