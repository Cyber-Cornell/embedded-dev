#include <stdint.h>
#include <string.h>

extern uint32_t _bss_start, _bss_end;

int main(void);

#define RTC_CNTL_BASE 0x3ff48000u
#define TIMG0_BASE 0x3ff5f000u

// Watchdog config registers are write-protected unless this key is written.
#define WDT_WRITE_KEY 0x50d83aa1u
#define WDT_EN (1u << 31)

static void wdt_disable(uintptr_t config0, uintptr_t wprotect,
                        uint32_t flashboot_en) {
  volatile uint32_t *const cfg = (volatile uint32_t *)config0;
  volatile uint32_t *const lock = (volatile uint32_t *)wprotect;
  *lock = WDT_WRITE_KEY;
  *cfg &= ~(WDT_EN | flashboot_en);
  *lock = 0;
}

// The ROM calls this once it has copied the image into RAM. It runs on the
// ROM's stack with interrupts off and the CPU on the 40 MHz crystal.
void call_start_cpu0(void) {
  memset(&_bss_start, 0, (size_t)((char *)&_bss_end - (char *)&_bss_start));

  // When booting from flash the ROM arms the RTC watchdog and Timer Group 0's
  // watchdog ("flashboot protection"); they would reset the chip in ~1 s.
  wdt_disable(RTC_CNTL_BASE + 0x8cu, RTC_CNTL_BASE + 0xa4u, 1u << 10);
  wdt_disable(TIMG0_BASE + 0x48u, TIMG0_BASE + 0x64u, 1u << 14);

  main();
  for (;;) {
  }
}
