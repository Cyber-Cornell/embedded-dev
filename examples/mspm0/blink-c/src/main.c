#include <stdint.h>
#include <ti/driverlib/dl_common.h>
#include <ti/driverlib/dl_gpio.h>

// Blinks the blue channel of the LP-MSPM0L2228's RGB LED (LED4) with TI's
// DriverLib. Blue is PA23 (jumper J4), red PB10 (J5), green PB9 (J6).
#define LED_PORT GPIOA
#define LED_PIN DL_GPIO_PIN_23
#define LED_IOMUX IOMUX_PINCM67  // PA23's pin control register

// Cycles to wait after powering a peripheral, as in TI's SysConfig output.
#define POWER_STARTUP_DELAY 16u
// The CPU runs at 32 MHz (SYSOSC) out of reset: 16M cycles = 0.5 s.
#define HALF_PERIOD 16000000u

int main(void) {
  DL_GPIO_reset(LED_PORT);
  DL_GPIO_enablePower(LED_PORT);
  DL_Common_delayCycles(POWER_STARTUP_DELAY);

  DL_GPIO_initDigitalOutput(LED_IOMUX);
  DL_GPIO_clearPins(LED_PORT, LED_PIN);
  DL_GPIO_enableOutput(LED_PORT, LED_PIN);

  for (;;) {
    DL_GPIO_togglePins(LED_PORT, LED_PIN);
    DL_Common_delayCycles(HALF_PERIOD);
  }
}
