#include <ti/driverlib/dl_common.h>
#include <ti/driverlib/dl_gpio.h>

#include <cstdint>

// Blinks the blue channel of the LP-MSPM0L2228's RGB LED (LED4) with TI's
// DriverLib. Blue is PA23 (jumper J4), red PB10 (J5), green PB9 (J6).
namespace {

// Cycles to wait after powering a peripheral, as in TI's SysConfig output.
constexpr std::uint32_t kPowerStartupDelay = 16;
// The CPU runs at 32 MHz (SYSOSC) out of reset: 16M cycles = 0.5 s.
constexpr std::uint32_t kHalfPeriod = 16'000'000;

class OutputPin {
 public:
  // pincm is the pin's IOMUX pin control register, e.g. IOMUX_PINCM67 (PA23).
  OutputPin(GPIO_Regs* port, std::uint32_t pin, IOMUX_PINCM pincm)
      : port_(port), pin_(pin) {
    DL_GPIO_initDigitalOutput(pincm);
    DL_GPIO_clearPins(port_, pin_);
    DL_GPIO_enableOutput(port_, pin_);
  }

  void toggle() { DL_GPIO_togglePins(port_, pin_); }

 private:
  GPIO_Regs* port_;
  std::uint32_t pin_;
};

void powerOn(GPIO_Regs* port) {
  DL_GPIO_reset(port);
  DL_GPIO_enablePower(port);
  DL_Common_delayCycles(kPowerStartupDelay);
}

}  // namespace

int main() {
  powerOn(GPIOA);

  OutputPin led(GPIOA, DL_GPIO_PIN_23, IOMUX_PINCM67);
  for (;;) {
    led.toggle();
    DL_Common_delayCycles(kHalfPeriod);
  }
}
