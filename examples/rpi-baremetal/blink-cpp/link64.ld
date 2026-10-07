/* The firmware loads kernel8.img at 0x80000 and jumps to its first byte. */
ENTRY(_start)

SECTIONS
{
  . = 0x80000;
  .text : { KEEP(*(.text.boot)) *(.text .text.*) }
  .rodata : { *(.rodata .rodata.*) }
  .data : { *(.data .data.*) }
  .bss (NOLOAD) : ALIGN(16) {
    __bss_start = .;
    *(.bss .bss.* COMMON)
    . = ALIGN(16);
    __bss_end = .;
  }
  /* Our own stack, so nothing the firmware left below 0x80000 is touched. */
  .stack (NOLOAD) : ALIGN(16) {
    . += 64K;
    __stack_top = .;
  }
  /DISCARD/ : { *(.comment) *(.note*) *(.eh_frame*) }
}
