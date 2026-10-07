#include <cstdint>

// Register-level blink of the on-board LED (GPIO 25) of the Raspberry Pi Pico
// (RP2040) and Pico 2 (RP2350), with no SDK calls. The SDK defines PICO_RP2350
// from PICO_BOARD. The Pico W / Pico 2 W LEDs hang off the CYW43 wireless chip
// instead, and only the RP2350's Arm cores are covered.
namespace {

struct Chip {
  std::uintptr_t resets, io_bank0, pads_bank0;
  std::uintptr_t sio_gpio_out_xor, sio_gpio_oe_set;  // SIO register offsets
  std::uint32_t reset_io_bank0, reset_pads_bank0;    // RESETS bits
  unsigned num_gpios;
};

#if PICO_RP2350
constexpr Chip kChip{0x40020000, 0x40028000, 0x40038000, 0x28,
                     0x38,       1u << 6,    1u << 9,    48};
#else
constexpr Chip kChip{0x4000c000, 0x40014000, 0x4001c000, 0x1c,
                     0x24,       1u << 5,    1u << 8,    30};
#endif
constexpr std::uintptr_t kSioBase = 0xd0000000;
// Every peripheral register has an atomic bit-clear alias at +0x3000.
constexpr std::uintptr_t kAtomicClear = 0x3000;

inline volatile std::uint32_t& reg(std::uintptr_t addr) {
  return *reinterpret_cast<volatile std::uint32_t*>(addr);
}

void unreset(std::uint32_t mask) {
  reg(kChip.resets + kAtomicClear + 0x0) = mask;      // RESET
  while ((reg(kChip.resets + 0x8) & mask) != mask) {  // RESET_DONE
  }
}

template <unsigned Pin>
class SioOutputPin {
  static_assert(Pin < 32, "this example drives GPIO 0-31 only");
  static_assert(Pin < kChip.num_gpios, "no such GPIO on this chip");
  static constexpr std::uint32_t kGpioFuncSio = 5;
  static constexpr std::uint32_t kPadIso = 1u << 8;  // RP2350: pad isolation

 public:
  SioOutputPin() {
    reg(kChip.io_bank0 + 0x4 + (8 * Pin)) = kGpioFuncSio;  // GPIOn_CTRL
    reg(kChip.pads_bank0 + kAtomicClear + 0x4 + (4 * Pin)) = kPadIso;
    reg(kSioBase + kChip.sio_gpio_oe_set) = 1u << Pin;
  }

  void toggle() { reg(kSioBase + kChip.sio_gpio_out_xor) = 1u << Pin; }
};

void delay(std::uint32_t count) {
  volatile std::uint32_t remaining = count;
  while (remaining != 0) {
    remaining = remaining - 1;
  }
}

}  // namespace

int main() {
  unreset(kChip.reset_io_bank0 | kChip.reset_pads_bank0);

  SioOutputPin<25> led;
  for (;;) {
    led.toggle();
    delay(5'000'000);  // ~0.25 s at the SDK's 125 / 150 MHz system clock
  }
}
