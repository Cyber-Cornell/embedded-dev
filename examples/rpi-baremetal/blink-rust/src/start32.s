// Entry point of kernel.img. The firmware starts the Pi Zero's ARM1176 in ARM
// state and SVC mode, with the MMU and caches off.
  .section .text.boot, "ax"
  .arm
  .fpu vfp
  .global _start
_start:
  ldr sp, =__stack_top

  // Enable the VFP (coprocessors 10 and 11) for hard-float code.
  mrc p15, 0, r0, c1, c0, 2
  orr r0, r0, #(0xf << 20)
  mcr p15, 0, r0, c1, c0, 2
  mov r0, #0
  mcr p15, 0, r0, c7, c5, 4 // flush the prefetch buffer (ARMv6's ISB)
  mov r0, #0x40000000 // FPEXC.EN
  vmsr fpexc, r0

  ldr r0, =__bss_start
  ldr r1, =__bss_end
  mov r2, #0
1:
  cmp r0, r1
  strlo r2, [r0], #4
  blo 1b

  bl main
park:
  b park
