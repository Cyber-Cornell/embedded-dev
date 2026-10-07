#include <chrono>

#include "driver/gpio.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

// GPIO 2 drives the on-board LED on most ESP32 DevKit clones; change it for
// your board (boards with an addressable RGB LED need the led_strip component).
namespace {

using namespace std::chrono_literals;

constexpr gpio_num_t kLedGpio = GPIO_NUM_2;
constexpr auto kBlinkPeriod = 500ms;
constexpr const char *kTag = "blink";

class Led {
 public:
  explicit Led(gpio_num_t pin) : pin_(pin) {
    gpio_reset_pin(pin_);
    gpio_set_direction(pin_, GPIO_MODE_OUTPUT);
  }

  void toggle() {
    on_ = !on_;
    gpio_set_level(pin_, on_);
    ESP_LOGI(kTag, "LED %s", on_ ? "on" : "off");
  }

 private:
  gpio_num_t pin_;
  bool on_ = false;
};

}  // namespace

// ESP-IDF calls app_main with C linkage.
extern "C" void app_main() {
  Led led(kLedGpio);
  while (true) {
    led.toggle();
    vTaskDelay(pdMS_TO_TICKS(std::chrono::milliseconds(kBlinkPeriod).count()));
  }
}
