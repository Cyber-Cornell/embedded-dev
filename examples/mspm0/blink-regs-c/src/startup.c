#include <stdint.h>
#include <string.h>

extern uint32_t _estack, _sidata, _sdata, _edata, _sbss, _ebss;

int main(void);

void Reset_Handler(void) {
  // Copy initialised data from flash and zero .bss before entering main().
  memcpy(&_sdata, &_sidata, (size_t)((char*)&_edata - (char*)&_sdata));
  memset(&_sbss, 0, (size_t)((char*)&_ebss - (char*)&_sbss));

  main();
  for (;;) {
  }
}

void Default_Handler(void) {
  for (;;) {
  }
}

// Minimal vector table: initial stack pointer, reset, then the Cortex-M0+'s
// two core faults. TI's startup_mspm0l222x_gcc.c (MSPM0 SDK) lists every
// peripheral IRQ.
typedef void (*vector_t)(void);
__attribute__((section(".isr_vector"),
               used)) static const vector_t vectors[] = {
    (vector_t)&_estack,  // initial stack pointer
    Reset_Handler,       // reset
    Default_Handler,     // NMI
    Default_Handler,     // HardFault
};
