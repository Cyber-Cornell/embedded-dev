// Entry point of kernel8.img. The firmware starts every 64-bit Pi at EL2 with
// the MMU and caches off; only core 0 runs the program, the others sleep.
  .section .text.boot, "ax"
  .global _start
_start:
  mrs x0, mpidr_el1
  and x0, x0, #0xffff // core number: Aff0 on Cortex-A53/A72, Aff1 on A76 (Pi 5)
  cbnz x0, park

  adrp x0, __stack_top
  add x0, x0, :lo12:__stack_top
  mov sp, x0

  adrp x0, __bss_start
  add x0, x0, :lo12:__bss_start
  adrp x1, __bss_end
  add x1, x1, :lo12:__bss_end
1:
  cmp x0, x1
  b.hs 2f
  str xzr, [x0], #8
  b 1b
2:
  bl main
park:
  wfe
  b park
