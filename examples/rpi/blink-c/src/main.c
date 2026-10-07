// Blinks an LED on GPIO 17 (header pin 11, with a resistor to ground) of a
// Raspberry Pi 3, 4, 5, Zero, Zero W or Zero 2 W, through the kernel's GPIO
// character device (/dev/gpiochipN, uAPI v2). Needs no libraries, root or
// device tree changes; the default user is in the `gpio` group.
#include <dirent.h>
#include <fcntl.h>
#include <linux/gpio.h>
#include <stdio.h>
#include <string.h>
#include <sys/ioctl.h>
#include <time.h>
#include <unistd.h>

#define LED_GPIO 17
#define BLINK_DELAY_MS 500

// Labels of the chip that drives the 40-pin header. Its gpiochip number varies
// (the Pi 5's RP1 was gpiochip4 on older kernels), so look it up by label.
static const char *const HEADER_CHIPS[] = {
    "pinctrl-bcm2835", // Pi Zero, Zero W, Zero 2 W, 3
    "pinctrl-bcm2711", // Pi 4
    "pinctrl-rp1",     // Pi 5
};

static int open_header_chip(void) {
  DIR *dev = opendir("/dev");
  if (!dev) return -1;
  struct dirent *entry;
  while ((entry = readdir(dev))) {
    if (strncmp(entry->d_name, "gpiochip", 8) != 0) continue;
    char path[300];
    snprintf(path, sizeof path, "/dev/%s", entry->d_name);
    int fd = open(path, O_RDWR | O_CLOEXEC);
    if (fd < 0) continue;
    struct gpiochip_info info = {0};
    if (ioctl(fd, GPIO_GET_CHIPINFO_IOCTL, &info) == 0) {
      for (size_t i = 0; i < sizeof HEADER_CHIPS / sizeof *HEADER_CHIPS; i++) {
        if (strcmp(info.label, HEADER_CHIPS[i]) == 0) {
          closedir(dev);
          return fd;
        }
      }
    }
    close(fd);
  }
  closedir(dev);
  return -1;
}

int main(void) {
  int chip = open_header_chip();
  if (chip < 0) {
    fprintf(stderr, "no Raspberry Pi GPIO header chip found in /dev\n");
    return 1;
  }

  struct gpio_v2_line_request req = {
      .offsets = {LED_GPIO},
      .num_lines = 1,
      .consumer = "blink",
      .config.flags = GPIO_V2_LINE_FLAG_OUTPUT,
  };
  if (ioctl(chip, GPIO_V2_GET_LINE_IOCTL, &req) < 0) {
    perror("request GPIO line");
    return 1;
  }
  close(chip);

  // The line stays claimed until req.fd closes, i.e. when the process exits.
  struct gpio_v2_line_values values = {.mask = 1};
  const struct timespec delay = {0, BLINK_DELAY_MS * 1000000L};
  for (;;) {
    values.bits ^= 1;
    if (ioctl(req.fd, GPIO_V2_LINE_SET_VALUES_IOCTL, &values) < 0) {
      perror("set GPIO line");
      return 1;
    }
    nanosleep(&delay, NULL);
  }
}
