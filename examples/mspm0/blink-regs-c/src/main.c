#include <stdint.h>

// Register-level blink of the blue channel of the LP-MSPM0L2228's RGB LED
// (LED4), with no SDK or DriverLib. Blue is PA23 (jumper J4), red PB10 (J5),
// green PB9 (J6). Addresses and keys are from the MSPM0 SDK's mspm0l222x.h,
// hw_gpio.h and hw_iomux.h.
#define GPIOA_BASE 0x400A0000u
#define IOMUX_BASE 0x40428000u

#define REG(addr) (*(volatile uint32_t*)(addr))

// Each peripheral has its own power-enable and reset registers, which only
// accept writes that carry the register's key in the top byte.
#define GPIOA_PWREN REG(GPIOA_BASE + 0x800u)
#define GPIOA_RSTCTL REG(GPIOA_BASE + 0x804u)
#define GPIOA_DOUTTGL31_0 REG(GPIOA_BASE + 0x12B0u)
#define GPIOA_DOESET31_0 REG(GPIOA_BASE + 0x12D0u)
// Pin control register PINCMn (numbered from 1, as in the datasheet).
#define IOMUX_PINCM(n) REG(IOMUX_BASE + (4u * (n)))

#define PWREN_KEY 0x26000000u
#define PWREN_ENABLE (1u << 0)
#define RSTCTL_KEY 0xB1000000u
#define RSTCTL_RESETSTKYCLR (1u << 1)
#define RSTCTL_RESETASSERT (1u << 0)
#define PINCM_PC (1u << 7)  // pin connected to its peripheral
#define PINCM_PF_GPIO 1u    // peripheral function 1 is GPIO on every pin

#define LED_PIN 23u    // PA23
#define LED_PINCM 67u  // PA23's pin control register

static void delay(volatile uint32_t count) {
  while (count--) {
  }
}

int main(void) {
  // Reset GPIOA, then power it up and give it time to start.
  GPIOA_RSTCTL = RSTCTL_KEY | RSTCTL_RESETSTKYCLR | RSTCTL_RESETASSERT;
  GPIOA_PWREN = PWREN_KEY | PWREN_ENABLE;
  delay(16);

  IOMUX_PINCM(LED_PINCM) = PINCM_PC | PINCM_PF_GPIO;
  GPIOA_DOESET31_0 = 1u << LED_PIN;

  for (;;) {
    GPIOA_DOUTTGL31_0 = 1u << LED_PIN;
    delay(1600000);  // ~0.5 s at the 32 MHz reset clock
  }
}
