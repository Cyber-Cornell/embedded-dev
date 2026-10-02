#include <msp430.h>

// MSP-EXP430G2ET LaunchPad: LED1 (red) on P1.0, LED2 (green) on P1.6.
#define LED1 BIT0
#define LED2 BIT6

// LED2 toggles from a Timer_A interrupt while the CPU sleeps in LPM0;
// LED1 is driven from a busy-wait loop between wake-ups.
__attribute__((interrupt(TIMER0_A0_VECTOR))) void timer_a0_isr(void) {
  P1OUT ^= LED2;
  __bic_SR_register_on_exit(LPM0_bits); // return to main() awake
}

int main(void) {
  WDTCTL = WDTPW | WDTHOLD; // stop the watchdog timer

  P1DIR |= LED1 | LED2;
  P1OUT &= ~(LED1 | LED2);

  TA0CCR0 = 50000;
  TA0CCTL0 = CCIE;
  TA0CTL = TASSEL_2 | MC_1 | ID_3; // SMCLK / 8, up mode

  for (;;) {
    __bis_SR_register(LPM0_bits | GIE); // sleep until the timer fires
    P1OUT ^= LED1;
    __delay_cycles(10000);
  }
}
