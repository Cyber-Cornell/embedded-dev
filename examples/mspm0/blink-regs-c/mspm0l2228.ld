/*
 * MSPM0L2228 (LP-MSPM0L2228): 256K flash, 32K SRAM.
 *
 * Flash starts at 0, where the core reads the vector table after reset (the
 * ROM boot code runs first and then hands over to it). To put the program
 * behind a bootloader, move FLASH's ORIGIN up and have the bootloader point
 * SCB->VTOR there before jumping to the program's reset handler.
 *
 * The NONMAIN configuration flash (BCR/BSL settings, 0x41C00000) is
 * deliberately not described here: nothing is ever linked into it. A bad
 * NONMAIN write can lock the device permanently.
 */
ENTRY(Reset_Handler)

MEMORY
{
  FLASH (rx)  : ORIGIN = 0x00000000, LENGTH = 256K
  RAM   (rwx) : ORIGIN = 0x20200000, LENGTH = 32K
}

_estack = ORIGIN(RAM) + LENGTH(RAM);

SECTIONS
{
  .isr_vector : { KEEP(*(.isr_vector)) } > FLASH

  .text :
  {
    *(.text*)
    *(.rodata*)
    . = ALIGN(4);
  } > FLASH

  /* C++ global constructors, run by the reset handler. */
  .init_array :
  {
    __init_array_start = .;
    KEEP(*(SORT(.init_array.*)))
    KEEP(*(.init_array*))
    __init_array_end = .;
  } > FLASH

  _sidata = LOADADDR(.data);
  .data :
  {
    _sdata = .;
    *(.data*)
    . = ALIGN(4);
    _edata = .;
  } > RAM AT > FLASH

  .bss (NOLOAD) :
  {
    _sbss = .;
    *(.bss*)
    *(COMMON)
    . = ALIGN(4);
    _ebss = .;
  } > RAM
}
