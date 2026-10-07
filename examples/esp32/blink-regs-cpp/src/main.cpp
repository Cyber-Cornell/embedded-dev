#include <cstdint>

// Register-level blink of GPIO 2, the on-board LED on most ESP32 DevKit
// clones, with no ESP-IDF. Change the pin for your board.
namespace {

constexpr std::uintptr_t kGpioBase = 0x3ff44000;
constexpr std::uintptr_t kIoMuxBase = 0x3ff49000;

inline volatile std::uint32_t &reg(std::uintptr_t addr) {
  return *reinterpret_cast<volatile std::uint32_t *>(addr);
}

// IO_MUX register offset of each GPIO; the order is irregular.
constexpr std::uintptr_t kIoMuxOffset[] = {
    0x44, 0x88, 0x40, 0x84, 0x48, 0x6c, 0x60, 0x64, 0x68, 0x54, 0x58,
    0x5c, 0x34, 0x38, 0x30, 0x3c, 0x4c, 0x50, 0x70, 0x74, 0x78, 0x7c,
    0x80, 0x8c, 0,    0x24, 0x28, 0x2c, 0,    0,    0,    0};

template <unsigned Pin>
class GpioOutput {
  static_assert(Pin < 32 && kIoMuxOffset[Pin] != 0,
                "pin must be an output-capable GPIO in the first bank");
  static constexpr unsigned kMcuSelShift = 12;
  // IO_MUX function 3: plain GPIO.
  static constexpr std::uint32_t kMcuSelGpio = 2;
  // GPIO matrix signal that drives the pin from GPIO_OUT.
  static constexpr std::uint32_t kSigGpioOutIdx = 256;

 public:
  GpioOutput() {
    auto &mux = reg(kIoMuxBase + kIoMuxOffset[Pin]);
    mux = (mux & ~(7u << kMcuSelShift)) | (kMcuSelGpio << kMcuSelShift);
    reg(kGpioBase + 0x530 + (4 * Pin)) = kSigGpioOutIdx;  // FUNCn_OUT_SEL_CFG
    reg(kGpioBase + 0x24) = 1u << Pin;                    // ENABLE_W1TS
  }

  // GPIO_OUT
  void toggle() { reg(kGpioBase + 0x04) = reg(kGpioBase + 0x04) ^ (1u << Pin); }
};

void delay(std::uint32_t count) {
  volatile std::uint32_t remaining = count;
  while (remaining != 0) {
    remaining = remaining - 1;
  }
}

}  // namespace

int main() {
  GpioOutput<2> led;
  for (;;) {
    led.toggle();
    delay(2'000'000);
  }
}
