#include "driver/gpio.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

// GPIO 2 drives the on-board LED on most ESP32 DevKit clones; change it for
// your board (boards with an addressable RGB LED need the led_strip component).
#define LED_GPIO GPIO_NUM_2
#define BLINK_PERIOD_MS 500

static const char *TAG = "blink";

void app_main(void) {
  gpio_reset_pin(LED_GPIO);
  gpio_set_direction(LED_GPIO, GPIO_MODE_OUTPUT);

  bool on = false;
  while (true) {
    ESP_LOGI(TAG, "LED %s", on ? "on" : "off");
    gpio_set_level(LED_GPIO, on);
    on = !on;
    vTaskDelay(pdMS_TO_TICKS(BLINK_PERIOD_MS));
  }
}
