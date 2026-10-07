#include <stdint.h>

// Register-level blink for the Nucleo-F401RE user LED (LD2 on PA5), so the
// example needs nothing beyond the toolchain. Real projects would normally use
// the CMSIS device headers / HAL that STM32CubeMX generates.
#define RCC_BASE 0x40023800u
#define GPIOA_BASE 0x40020000u

#define RCC_AHB1ENR (*(volatile uint32_t*)(RCC_BASE + 0x30u))
#define GPIOA_MODER (*(volatile uint32_t*)(GPIOA_BASE + 0x00u))
#define GPIOA_ODR (*(volatile uint32_t*)(GPIOA_BASE + 0x14u))

#define LED_PIN 5u

static void delay(volatile uint32_t count) {
  while (count--) {
  }
}

int main(void) {
  RCC_AHB1ENR |= (1u << 0);  // GPIOA clock enable

  GPIOA_MODER &= ~(3u << (LED_PIN * 2));  // PA5 -> general-purpose output
  GPIOA_MODER |= (1u << (LED_PIN * 2));

  for (;;) {
    GPIOA_ODR ^= (1u << LED_PIN);
    delay(500000);
  }
}
