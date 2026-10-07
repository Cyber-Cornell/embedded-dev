#include <stdint.h>

// Register-level blink of GPIO 2, the on-board LED on most ESP32 DevKit
// clones, with no ESP-IDF. Change LED_PIN for your board (0-31 only, as this
// uses the first GPIO bank).
#define GPIO_BASE 0x3ff44000u
#define IO_MUX_BASE 0x3ff49000u

#define GPIO_OUT (*(volatile uint32_t *)(GPIO_BASE + 0x04u))
#define GPIO_ENABLE_W1TS (*(volatile uint32_t *)(GPIO_BASE + 0x24u))
#define GPIO_FUNC_OUT_SEL_CFG(n) \
  (*(volatile uint32_t *)(GPIO_BASE + 0x530u + (4u * (n))))
// IO_MUX register of GPIO 2; the per-pin offsets are irregular.
#define IO_MUX_GPIO2 (*(volatile uint32_t *)(IO_MUX_BASE + 0x40u))

#define MCU_SEL_SHIFT 12
#define MCU_SEL_GPIO 2u        // IO_MUX function 3: plain GPIO
#define SIG_GPIO_OUT_IDX 256u  // GPIO matrix: drive the pin from GPIO_OUT

#define LED_PIN 2u

static void delay(volatile uint32_t count) {
  while (count--) {
  }
}

int main(void) {
  IO_MUX_GPIO2 =
      (IO_MUX_GPIO2 & ~(7u << MCU_SEL_SHIFT)) | (MCU_SEL_GPIO << MCU_SEL_SHIFT);
  GPIO_FUNC_OUT_SEL_CFG(LED_PIN) = SIG_GPIO_OUT_IDX;
  GPIO_ENABLE_W1TS = 1u << LED_PIN;

  for (;;) {
    GPIO_OUT ^= 1u << LED_PIN;
    delay(2000000);
  }
}
