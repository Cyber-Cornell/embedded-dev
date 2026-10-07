#include <cstdint>

// Register-level blink of the blue channel of the LP-MSPM0L2228's RGB LED
// (LED4), with no SDK or DriverLib. Blue is PA16, red PB10, green PB9, each
// through a jumper labeled with its pin (TI's SDK example READMEs say PA23
// for blue; the board is wired to PA16). Addresses and keys are from the
// MSPM0 SDK's mspm0l222x.h, hw_gpio.h and hw_iomux.h.
namespace {

constexpr std::uintptr_t kGpioABase = 0x400A0000;
constexpr std::uintptr_t kIomuxBase = 0x40428000;

// Register offsets within a GPIO port.
constexpr std::uintptr_t kPwrEn = 0x800;
constexpr std::uintptr_t kRstCtl = 0x804;
constexpr std::uintptr_t kDoutTgl = 0x12B0;
constexpr std::uintptr_t kDoeSet = 0x12D0;

// Power-enable and reset registers only accept writes that carry their key
// in the top byte.
constexpr std::uint32_t kPwrEnKey = 0x26000000;
constexpr std::uint32_t kPwrEnEnable = 1u << 0;
constexpr std::uint32_t kRstCtlKey = 0xB1000000;
constexpr std::uint32_t kRstCtlResetStkyClr = 1u << 1;
constexpr std::uint32_t kRstCtlResetAssert = 1u << 0;

constexpr std::uint32_t kPincmPc = 1u << 7;  // pin connected to its peripheral
constexpr std::uint32_t kPincmPfGpio = 1;    // function 1 is GPIO on every pin

inline volatile std::uint32_t& reg(std::uintptr_t addr) {
  return *reinterpret_cast<volatile std::uint32_t*>(addr);
}

void delay(std::uint32_t count) {
  for (volatile std::uint32_t i = 0; i < count; i = i + 1) {
  }
}

// Resets and powers up a GPIO port.
void powerOn(std::uintptr_t port) {
  reg(port + kRstCtl) = kRstCtlKey | kRstCtlResetStkyClr | kRstCtlResetAssert;
  reg(port + kPwrEn) = kPwrEnKey | kPwrEnEnable;
  delay(16);
}

// Pincm is the pin's IOMUX pin control register, PINCMn (numbered from 1, as
// in the datasheet).
template <std::uintptr_t Port, unsigned Pin, unsigned Pincm>
class OutputPin {
  static_assert(Pin < 32, "GPIO ports have 32 pins");

 public:
  OutputPin() {
    reg(kIomuxBase + (4 * Pincm)) = kPincmPc | kPincmPfGpio;
    reg(Port + kDoeSet) = 1u << Pin;
  }

  void toggle() { reg(Port + kDoutTgl) = 1u << Pin; }
};

}  // namespace

int main() {
  powerOn(kGpioABase);

  OutputPin<kGpioABase, 16, 42> led;  // PA16, PINCM42
  for (;;) {
    led.toggle();
    delay(1'600'000);  // ~0.5 s at the 32 MHz reset clock
  }
}
