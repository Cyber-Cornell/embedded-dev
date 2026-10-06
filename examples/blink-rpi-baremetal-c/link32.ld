/* The firmware loads kernel.img at 0x8000 and jumps to its first byte. */
ENTRY(_start)

SECTIONS
{
  . = 0x8000;
  .text : { KEEP(*(.text.boot)) *(.text .text.*) }
  .rodata : { *(.rodata .rodata.*) }
  .ARM.exidx : { *(.ARM.exidx*) }
  .data : { *(.data .data.*) }
  .bss (NOLOAD) : ALIGN(16) {
    __bss_start = .;
    *(.bss .bss.* COMMON)
    . = ALIGN(16);
    __bss_end = .;
  }
  /* Our own stack, so nothing the firmware left below 0x8000 is touched. */
  .stack (NOLOAD) : ALIGN(16) {
    . += 64K;
    __stack_top = .;
  }
  /DISCARD/ : { *(.comment) *(.note*) *(.eh_frame*) }
}
