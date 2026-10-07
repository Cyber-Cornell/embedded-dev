// Bare-metal blink of an LED on GPIO 17 (header pin 11, with a resistor to
// ground). No OS: the GPU firmware loads the kernel image from the SD card and
// jumps to _start (start64.S / start32.S), which calls main.
//   kernel8.img (aarch64): Pi 3, 4, 5, Zero 2 W, told apart by CPU type
//   kernel.img  (ARMv6):   Pi Zero, Zero W
#include <cstdint>

namespace {

constexpr unsigned kLedGpio = 17;
constexpr std::uint32_t kBlinkDelayUs = 500'000;

inline volatile std::uint32_t& reg(std::uintptr_t addr) {
  return *reinterpret_cast<volatile std::uint32_t*>(addr);
}

// GPIO block of the BCM2835 (Zero), BCM2837 (Pi 3, Zero 2 W) and BCM2711
// (Pi 4), relative to the SoC's peripheral base.
class BcmGpioPin {
 public:
  BcmGpioPin(std::uintptr_t peripheralBase, unsigned pin)
      : base_(peripheralBase + 0x200000), pin_(pin) {
    volatile std::uint32_t& fsel = reg(base_ + (4 * std::uintptr_t{pin / 10}));
    const unsigned shift = (pin % 10) * 3;
    fsel = (fsel & ~(7u << shift)) | (1u << shift);  // 001 = output
  }

  void toggle() {
    on_ = !on_;
    reg(base_ + (on_ ? kGpset0 : kGpclr0)) = 1u << pin_;
  }

 private:
  static constexpr std::uintptr_t kGpset0 = 0x1c;
  static constexpr std::uintptr_t kGpclr0 = 0x28;
  std::uintptr_t base_;
  unsigned pin_;
  bool on_ = false;
};

#if defined(__aarch64__)

// Pi 5: the header is wired to the RP1 I/O chip, which the bootloader maps at
// 0x1f00000000 over PCIe (config.txt keeps the link up with pciex4_reset=0).
// Its GPIO block works like the RP2040's.
class Rp1GpioPin {
 public:
  explicit Rp1GpioPin(unsigned pin) : pin_(pin) {
    reg(kIoBank0 + (8 * std::uintptr_t{pin}) + 4) = kFuncselSysRio;  // CTRL
    volatile std::uint32_t& pad =
        reg(kPadsBank0 + 4 + (4 * std::uintptr_t{pin}));
    pad = pad & ~kPadOutputDisable;
    reg(kSysRio0 + kSet + kRioOe) = 1u << pin;
  }

  void toggle() const { reg(kSysRio0 + kXor + kRioOut) = 1u << pin_; }

 private:
  // Per pin: STATUS, CTRL.
  static constexpr std::uintptr_t kIoBank0 = 0x1f000d0000;
  // Registered I/O: OUT, OE, IN.
  static constexpr std::uintptr_t kSysRio0 = 0x1f000e0000;
  static constexpr std::uintptr_t kPadsBank0 = 0x1f000f0000;
  static constexpr std::uintptr_t kXor = 0x1000;  // atomic register aliases
  static constexpr std::uintptr_t kSet = 0x2000;
  static constexpr std::uintptr_t kRioOut = 0x0;
  static constexpr std::uintptr_t kRioOe = 0x4;
  static constexpr std::uint32_t kFuncselSysRio = 5;
  static constexpr std::uint32_t kPadOutputDisable = 1u << 7;
  unsigned pin_;
};

enum class CpuPart : unsigned {
  CortexA53 = 0xd03,  // Pi 3, Zero 2 W (BCM2837)
  CortexA72 = 0xd08,  // Pi 4 (BCM2711)
  CortexA76 = 0xd0b,  // Pi 5 (BCM2712)
};

CpuPart cpuPart() {
  std::uint64_t midr;
  asm volatile("mrs %0, midr_el1" : "=r"(midr));
  return static_cast<CpuPart>((midr >> 4) & 0xfff);
}

// The Arm generic timer; the firmware sets its frequency (19.2 or 54 MHz).
std::uint64_t counter() {
  std::uint64_t count;
  asm volatile("isb; mrs %0, cntpct_el0" : "=r"(count));
  return count;
}

void delayUs(std::uint32_t us) {
  std::uint64_t freq;
  asm volatile("mrs %0, cntfrq_el0" : "=r"(freq));
  const std::uint64_t start = counter();
  const std::uint64_t ticks = freq * us / 1'000'000;
  while (counter() - start < ticks) {
  }
}

#else  // ARMv6: Pi Zero / Zero W (BCM2835)

constexpr std::uintptr_t kPeripheralBase = 0x20000000;

void delayUs(std::uint32_t us) {
  // Free-running 1 MHz counter.
  volatile std::uint32_t& clo = reg(kPeripheralBase + 0x3004);
  const std::uint32_t start = clo;
  while (clo - start < us) {
  }
}

#endif

template <class Pin>
[[noreturn]] void blink(Pin led) {
  for (;;) {
    led.toggle();
    delayUs(kBlinkDelayUs);
  }
}

}  // namespace

int main() {
#if defined(__aarch64__)
  switch (cpuPart()) {
    case CpuPart::CortexA76:
      blink(Rp1GpioPin(kLedGpio));
    case CpuPart::CortexA72:
      // BCM2711 in its default "low peripheral" mode
      blink(BcmGpioPin(0xfe000000, kLedGpio));
    default:
      blink(BcmGpioPin(0x3f000000, kLedGpio));
  }
#else
  blink(BcmGpioPin(kPeripheralBase, kLedGpio));
#endif
}
