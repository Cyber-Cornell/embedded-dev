// Bare-metal blink of an LED on GPIO 17 (header pin 11, with a resistor to
// ground). No OS: the GPU firmware loads the kernel image from the SD card and
// jumps to _start (start64.S / start32.S), which calls main.
//   kernel8.img (aarch64): Pi 3, 4, 5, Zero 2 W, told apart by CPU type
//   kernel.img  (ARMv6):   Pi Zero, Zero W
#include <stdbool.h>
#include <stdint.h>

#define LED_GPIO 17
#define BLINK_DELAY_US 500000

#define REG(addr) (*(volatile uint32_t*)(uintptr_t)(addr))

// GPIO block of the BCM2835 (Zero), BCM2837 (Pi 3, Zero 2 W) and BCM2711
// (Pi 4), relative to the SoC's peripheral base.
#define GPFSEL(base, n) REG((base) + 0x200000 + (4 * (uintptr_t)(n)))
#define GPSET0(base) REG((base) + 0x20001c)
#define GPCLR0(base) REG((base) + 0x200028)

static uintptr_t gpio_base;  // peripheral base of the chip driving the header
static bool led_on;

static void bcm_gpio_init(uintptr_t peripheral_base) {
  gpio_base = peripheral_base;
  unsigned shift = (LED_GPIO % 10) * 3;
  uint32_t fsel = GPFSEL(gpio_base, LED_GPIO / 10);
  // Function 001 = output.
  GPFSEL(gpio_base, LED_GPIO / 10) = (fsel & ~(7u << shift)) | (1u << shift);
}

static void bcm_gpio_toggle(void) {
  led_on = !led_on;
  if (led_on) {
    GPSET0(gpio_base) = 1u << LED_GPIO;
  } else {
    GPCLR0(gpio_base) = 1u << LED_GPIO;
  }
}

#if defined(__aarch64__)

// Pi 5: the header is wired to the RP1 I/O chip, which the bootloader maps at
// 0x1f00000000 over PCIe (config.txt keeps the link up with pciex4_reset=0).
// Its GPIO block works like the RP2040's.
#define RP1_IO_BANK0 0x1f000d0000ull  // per pin: STATUS, CTRL
#define RP1_SYS_RIO0 0x1f000e0000ull  // registered I/O: OUT, OE, IN
#define RP1_PADS_BANK0 0x1f000f0000ull
#define RP1_XOR 0x1000  // atomic register aliases
#define RP1_SET 0x2000
#define RIO_OUT 0x0
#define RIO_OE 0x4
#define FUNCSEL_SYS_RIO 5
#define PAD_OUTPUT_DISABLE (1u << 7)

static bool is_pi5;

static void rp1_gpio_init(void) {
  is_pi5 = true;
  REG(RP1_IO_BANK0 + (8ull * LED_GPIO) + 4) = FUNCSEL_SYS_RIO;
  REG(RP1_PADS_BANK0 + 4 + (4ull * LED_GPIO)) &= ~PAD_OUTPUT_DISABLE;
  REG(RP1_SYS_RIO0 + RP1_SET + RIO_OE) = 1u << LED_GPIO;
}

#define CORTEX_A53 0xd03  // Pi 3, Zero 2 W (BCM2837)
#define CORTEX_A72 0xd08  // Pi 4 (BCM2711)
#define CORTEX_A76 0xd0b  // Pi 5 (BCM2712)

static unsigned cpu_part(void) {
  uint64_t midr;
  __asm__ volatile("mrs %0, midr_el1" : "=r"(midr));
  return (midr >> 4) & 0xfff;
}

static void led_init(void) {
  switch (cpu_part()) {
    case CORTEX_A76:
      rp1_gpio_init();
      break;
    case CORTEX_A72:
      // BCM2711 in its default "low peripheral" mode
      bcm_gpio_init(0xfe000000);
      break;
    default:
      bcm_gpio_init(0x3f000000);
      break;
  }
}

static void led_toggle(void) {
  if (is_pi5) {
    REG(RP1_SYS_RIO0 + RP1_XOR + RIO_OUT) = 1u << LED_GPIO;
  } else {
    bcm_gpio_toggle();
  }
}

// The Arm generic timer; the firmware sets its frequency (19.2 or 54 MHz).
static uint64_t counter(void) {
  uint64_t count;
  __asm__ volatile("isb; mrs %0, cntpct_el0" : "=r"(count));
  return count;
}

static void delay_us(uint32_t us) {
  uint64_t freq;
  __asm__ volatile("mrs %0, cntfrq_el0" : "=r"(freq));
  const uint64_t start = counter();
  const uint64_t ticks = freq * us / 1000000;
  while (counter() - start < ticks) {
  }
}

#else  // ARMv6: Pi Zero / Zero W (BCM2835)

#define PERIPHERAL_BASE 0x20000000u
// Free-running 1 MHz counter.
#define SYSTIMER_CLO REG(PERIPHERAL_BASE + 0x3004)

static void led_init(void) { bcm_gpio_init(PERIPHERAL_BASE); }
static void led_toggle(void) { bcm_gpio_toggle(); }

static void delay_us(uint32_t us) {
  uint32_t start = SYSTIMER_CLO;
  while (SYSTIMER_CLO - start < us) {
  }
}

#endif

int main(void) {
  led_init();
  for (;;) {
    led_toggle();
    delay_us(BLINK_DELAY_US);
  }
}
