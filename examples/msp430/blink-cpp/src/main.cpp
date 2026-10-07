#include <msp430.h>

// MSP-EXP430G2ET LaunchPad: LED1 (red) on P1.0, LED2 (green) on P1.6.
namespace {

// A pin on port 1, chosen at compile time so it costs no RAM or code size.
template <unsigned char Mask>
struct Port1Output {
  static void init() {
    P1DIR |= Mask;
    P1OUT &= ~Mask;
  }
  static void toggle() { P1OUT ^= Mask; }
};

using Led1 = Port1Output<BIT0>;
using Led2 = Port1Output<BIT6>;

}  // namespace

// LED2 toggles from a Timer_A interrupt while the CPU sleeps in LPM0;
// LED1 is driven from a busy-wait loop between wake-ups.
extern "C" __attribute__((interrupt(TIMER0_A0_VECTOR))) void timer_a0_isr() {
  Led2::toggle();
  __bic_SR_register_on_exit(LPM0_bits);  // return to main() awake
}

int main() {
  WDTCTL = WDTPW | WDTHOLD;  // stop the watchdog timer

  Led1::init();
  Led2::init();

  TA0CCR0 = 50000;
  TA0CCTL0 = CCIE;
  TA0CTL = TASSEL_2 | MC_1 | ID_3;  // SMCLK / 8, up mode

  for (;;) {
    __bis_SR_register(LPM0_bits | GIE);  // sleep until the timer fires
    Led1::toggle();
    __delay_cycles(10000);
  }
}
