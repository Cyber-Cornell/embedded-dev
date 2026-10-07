#include "pico/stdlib.h"

#ifdef CYW43_WL_GPIO_LED_PIN
#include "pico/cyw43_arch.h"
#endif

namespace {

constexpr uint32_t kBlinkDelayMs = 500;

// Hides whether the board's LED is a plain GPIO (Pico, Pico 2) or sits behind
// the CYW43 wireless chip (Pico W, Pico 2 W).
class Led {
 public:
  static bool init() {
#if defined(PICO_DEFAULT_LED_PIN)
    gpio_init(PICO_DEFAULT_LED_PIN);
    gpio_set_dir(PICO_DEFAULT_LED_PIN, GPIO_OUT);
    return true;
#elif defined(CYW43_WL_GPIO_LED_PIN)
    return cyw43_arch_init() == PICO_OK;
#else
#error "No LED pin defined for this board"
#endif
  }

  void set(bool on) {
    on_ = on;
#if defined(PICO_DEFAULT_LED_PIN)
    gpio_put(PICO_DEFAULT_LED_PIN, on);
#elif defined(CYW43_WL_GPIO_LED_PIN)
    cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, on);
#endif
  }

  void toggle() { set(!on_); }

 private:
  bool on_ = false;
};

}  // namespace

int main() {
  Led led;
  if (!Led::init()) {
    return -1;
  }

  while (true) {
    led.toggle();
    sleep_ms(kBlinkDelayMs);
  }
}
