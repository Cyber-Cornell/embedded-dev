#include "pico/stdlib.h"

#ifdef CYW43_WL_GPIO_LED_PIN
#include "pico/cyw43_arch.h"
#endif

#define BLINK_DELAY_MS 500

// PICO_DEFAULT_LED_PIN comes from the board header selected by PICO_BOARD
// (GPIO 25 on the Pico / Pico 2). Wireless boards route the LED through the
// CYW43 chip instead, exposed as CYW43_WL_GPIO_LED_PIN.
static int led_init(void) {
#if defined(PICO_DEFAULT_LED_PIN)
  gpio_init(PICO_DEFAULT_LED_PIN);
  gpio_set_dir(PICO_DEFAULT_LED_PIN, GPIO_OUT);
  return PICO_OK;
#elif defined(CYW43_WL_GPIO_LED_PIN)
  return cyw43_arch_init();
#else
#error "No LED pin defined for this board"
#endif
}

static void led_set(bool on) {
#if defined(PICO_DEFAULT_LED_PIN)
  gpio_put(PICO_DEFAULT_LED_PIN, on);
#elif defined(CYW43_WL_GPIO_LED_PIN)
  cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, on);
#endif
}

int main(void) {
  if (led_init() != PICO_OK) {
    return -1;
  }

  while (true) {
    led_set(true);
    sleep_ms(BLINK_DELAY_MS);
    led_set(false);
    sleep_ms(BLINK_DELAY_MS);
  }
}
