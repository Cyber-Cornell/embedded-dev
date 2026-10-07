#include <stdint.h>

// Register-level blink of the on-board LED (GPIO 25) of the Raspberry Pi Pico
// (RP2040) and Pico 2 (RP2350), with no SDK calls. The SDK defines PICO_RP2350
// from PICO_BOARD. The Pico W / Pico 2 W LEDs hang off the CYW43 wireless chip
// instead, and only the RP2350's Arm cores are covered.
#if PICO_RP2350
#define RESETS_BASE 0x40020000u
#define IO_BANK0_BASE 0x40028000u
#define PADS_BANK0_BASE 0x40038000u
#define SIO_GPIO_OUT_XOR_OFFSET 0x28u
#define SIO_GPIO_OE_SET_OFFSET 0x38u
#define RESET_IO_BANK0 (1u << 6)
#define RESET_PADS_BANK0 (1u << 9)
#else
#define RESETS_BASE 0x4000c000u
#define IO_BANK0_BASE 0x40014000u
#define PADS_BANK0_BASE 0x4001c000u
#define SIO_GPIO_OUT_XOR_OFFSET 0x1cu
#define SIO_GPIO_OE_SET_OFFSET 0x24u
#define RESET_IO_BANK0 (1u << 5)
#define RESET_PADS_BANK0 (1u << 8)
#endif
#define SIO_BASE 0xd0000000u

// Every peripheral register has an atomic bit-clear alias at +0x3000.
#define ATOMIC_CLEAR 0x3000u
#define REG(addr) (*(volatile uint32_t*)(addr))

#define RESETS_RESET_CLR REG(RESETS_BASE + ATOMIC_CLEAR + 0x0u)
#define RESETS_RESET_DONE REG(RESETS_BASE + 0x8u)
#define IO_BANK0_GPIO_CTRL(n) REG(IO_BANK0_BASE + 0x4u + (8u * (n)))
#define PADS_BANK0_GPIO_CLR(n) \
  REG(PADS_BANK0_BASE + ATOMIC_CLEAR + 0x4u + (4u * (n)))
#define SIO_GPIO_OE_SET REG(SIO_BASE + SIO_GPIO_OE_SET_OFFSET)
#define SIO_GPIO_OUT_XOR REG(SIO_BASE + SIO_GPIO_OUT_XOR_OFFSET)

#define GPIO_FUNC_SIO 5u
#define PAD_ISO (1u << 8)  // RP2350 only: pad isolated until cleared

#define LED_PIN 25u

static void delay(volatile uint32_t count) {
  while (count--) {
  }
}

int main(void) {
  // Take the GPIO blocks out of reset and wait until they are ready.
  const uint32_t blocks = RESET_IO_BANK0 | RESET_PADS_BANK0;
  RESETS_RESET_CLR = blocks;
  while ((RESETS_RESET_DONE & blocks) != blocks) {
  }

  IO_BANK0_GPIO_CTRL(LED_PIN) = GPIO_FUNC_SIO;  // pin driven by the SIO block
  PADS_BANK0_GPIO_CLR(LED_PIN) = PAD_ISO;  // reserved (and 0) on the RP2040
  SIO_GPIO_OE_SET = 1u << LED_PIN;

  for (;;) {
    SIO_GPIO_OUT_XOR = 1u << LED_PIN;
    delay(5000000);  // ~0.25 s at the SDK's 125 / 150 MHz system clock
  }
}
