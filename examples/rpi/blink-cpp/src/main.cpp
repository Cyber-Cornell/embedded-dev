// Blinks an LED on GPIO 17 (header pin 11, with a resistor to ground) of a
// Raspberry Pi 3, 4, 5, Zero, Zero W or Zero 2 W, through the kernel's GPIO
// character device (/dev/gpiochipN, uAPI v2). Needs no libraries, root or
// device tree changes; the default user is in the `gpio` group.
#include <fcntl.h>
#include <linux/gpio.h>
#include <sys/ioctl.h>
#include <unistd.h>

#include <algorithm>
#include <array>
#include <chrono>
#include <cstdio>
#include <filesystem>
#include <string_view>
#include <system_error>
#include <thread>
#include <utility>

namespace {

using namespace std::chrono_literals;

constexpr unsigned kLedGpio = 17;
constexpr auto kBlinkDelay = 500ms;

// Labels of the chip that drives the 40-pin header. Its gpiochip number varies
// (the Pi 5's RP1 was gpiochip4 on older kernels), so look it up by label.
constexpr std::array<std::string_view, 3> kHeaderChips = {
    "pinctrl-bcm2835", // Pi Zero, Zero W, Zero 2 W, 3
    "pinctrl-bcm2711", // Pi 4
    "pinctrl-rp1",     // Pi 5
};

// Owns a file descriptor and closes it on scope exit.
class Fd {
public:
  explicit Fd(int fd = -1) : fd_(fd) {}
  Fd(Fd &&other) noexcept : fd_(std::exchange(other.fd_, -1)) {}
  Fd &operator=(Fd &&other) noexcept {
    std::swap(fd_, other.fd_);
    return *this;
  }
  ~Fd() {
    if (fd_ >= 0) close(fd_);
  }
  int get() const { return fd_; }
  explicit operator bool() const { return fd_ >= 0; }

private:
  int fd_;
};

[[noreturn]] void fail(const char *what) {
  throw std::system_error(errno, std::generic_category(), what);
}

Fd openHeaderChip() {
  for (const auto &entry : std::filesystem::directory_iterator("/dev")) {
    if (!entry.path().filename().string().starts_with("gpiochip")) continue;
    Fd chip(open(entry.path().c_str(), O_RDWR | O_CLOEXEC));
    gpiochip_info info{};
    if (chip && ioctl(chip.get(), GPIO_GET_CHIPINFO_IOCTL, &info) == 0 &&
        std::ranges::find(kHeaderChips, std::string_view(info.label)) != kHeaderChips.end()) {
      return chip;
    }
  }
  return Fd();
}

class OutputLine {
public:
  OutputLine(const Fd &chip, unsigned offset) {
    gpio_v2_line_request req{};
    req.offsets[0] = offset;
    req.num_lines = 1;
    std::snprintf(req.consumer, sizeof req.consumer, "blink");
    req.config.flags = GPIO_V2_LINE_FLAG_OUTPUT;
    if (ioctl(chip.get(), GPIO_V2_GET_LINE_IOCTL, &req) < 0) fail("request GPIO line");
    line_ = Fd(req.fd); // the line is released when this closes
  }

  void toggle() {
    values_.bits ^= 1;
    if (ioctl(line_.get(), GPIO_V2_LINE_SET_VALUES_IOCTL, &values_) < 0) fail("set GPIO line");
  }

private:
  Fd line_;
  gpio_v2_line_values values_{.bits = 0, .mask = 1};
};

} // namespace

int main() {
  try {
    Fd chip = openHeaderChip();
    if (!chip) {
      std::fprintf(stderr, "no Raspberry Pi GPIO header chip found in /dev\n");
      return 1;
    }
    OutputLine led(chip, kLedGpio);
    for (;;) {
      led.toggle();
      std::this_thread::sleep_for(kBlinkDelay);
    }
  } catch (const std::exception &e) {
    std::fprintf(stderr, "%s\n", e.what());
    return 1;
  }
}
