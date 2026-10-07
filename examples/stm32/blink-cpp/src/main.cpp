#include <cstdint>

// Register-level blink for the Nucleo-F401RE user LED (LD2 on PA5), so the
// example needs nothing beyond the toolchain. Real projects would normally use
// the CMSIS device headers / HAL that STM32CubeMX generates.
namespace {

struct GpioRegs {
  volatile std::uint32_t MODER, OTYPER, OSPEEDR, PUPDR, IDR, ODR, BSRR, LCKR,
      AFR[2];
};

constexpr std::uintptr_t kRccAhb1Enr = 0x40023830;
constexpr std::uintptr_t kGpioABase = 0x40020000;

inline GpioRegs& gpioA() { return *reinterpret_cast<GpioRegs*>(kGpioABase); }

template <unsigned Pin>
class OutputPin {
  static_assert(Pin < 16, "GPIO ports have 16 pins");

 public:
  explicit OutputPin(GpioRegs& port) : port_(port) {
    port_.MODER = (port_.MODER & ~(3u << (Pin * 2))) | (1u << (Pin * 2));
  }

  void toggle() { port_.ODR = port_.ODR ^ (1u << Pin); }

 private:
  GpioRegs& port_;
};

void delay(std::uint32_t count) {
  for (volatile std::uint32_t i = 0; i < count; i = i + 1) {
  }
}

}  // namespace

int main() {
  // GPIOA clock enable.
  *reinterpret_cast<volatile std::uint32_t*>(kRccAhb1Enr) |= 1u << 0;

  OutputPin<5> led(gpioA());
  for (;;) {
    led.toggle();
    delay(500'000);
  }
}
