/*
 * ESP32 linker script for a program that the mask ROM loads straight from
 * flash offset 0x1000, where ESP-IDF's second-stage bootloader normally sits.
 * The ROM copies each segment of the image into RAM and calls the entry point,
 * so everything lives in internal SRAM: no flash cache or MMU setup needed.
 *
 * The regions are the ones ESP-IDF v5.5 links its own bootloader to
 * (components/bootloader/subproject/main/ld/esp32/bootloader.ld), which keep
 * clear of the ROM loader's stack and data while it is still copying.
 */
ENTRY(call_start_cpu0)

MEMORY
{
  /* SRAM0 instruction bus; the first 1K is skipped as in ESP-IDF. IRAM only
     allows 32-bit accesses, so read-only data goes in DRAM. */
  iram (RWX) : ORIGIN = 0x40080400, LENGTH = 0xFC00
  /* SRAM2 data bus, above the ROM loader's stack. */
  dram (RW)  : ORIGIN = 0x3FFF0000, LENGTH = 0x6000
}

SECTIONS
{
  /* Xtensa L32R loads literals from lower addresses, so they come first. */
  .iram.text : ALIGN(4)
  {
    *(.literal .text .literal.* .text.*)
  } > iram

  .dram.rodata : ALIGN(4)
  {
    *(.rodata .rodata.* .sdata2 .sdata2.*)
    . = ALIGN(4);
    __init_array_start = .;
    KEEP(*(SORT(.init_array.*)))
    KEEP(*(.init_array .ctors))
    __init_array_end = .;
  } > dram

  .dram.data : ALIGN(4)
  {
    *(.data .data.* .sdata .sdata.*)
  } > dram

  /* The ROM loader only copies loadable segments; startup zeroes .bss. */
  .dram.bss (NOLOAD) : ALIGN(4)
  {
    _bss_start = .;
    *(.bss .bss.* .sbss .sbss.* COMMON)
    . = ALIGN(4);
    _bss_end = .;
  } > dram

  /DISCARD/ : { *(.comment) *(.note*) *(.eh_frame*) }
}
