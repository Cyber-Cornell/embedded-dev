/*
 * MSP430G2553 linker script (16K flash, 512B RAM) for msp430-rt.
 *
 * This is msp430-rt 0.4.1's linker script (link.x, as its build script
 * generates it without the `device` feature) combined with this project's
 * memory.x into one file. Changes from the original:
 *   - memory.x is pasted in place of `INCLUDE memory.x`.
 * Edit MEMORY to relocate the program, e.g. behind a bootloader.
 *
 * Original: https://github.com/rust-embedded/msp430-rt
 * msp430-rt is dual-licensed MIT OR Apache-2.0; used here under MIT:
 *
 * Copyright (c) 2017 Jorge Aparicio
 *
 * Permission is hereby granted, free of charge, to any
 * person obtaining a copy of this software and associated
 * documentation files (the "Software"), to deal in the
 * Software without restriction, including without
 * limitation the rights to use, copy, modify, merge,
 * publish, distribute, sublicense, and/or sell copies of
 * the Software, and to permit persons to whom the Software
 * is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice
 * shall be included in all copies or substantial portions
 * of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF
 * ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
 * TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
 * PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT
 * SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 * CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
 * IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

/* MSP430G2553: 16K flash (incl. 32-byte vector table), 512B RAM. */
MEMORY
{
  RAM : ORIGIN = 0x0200, LENGTH = 0x0200
  ROM : ORIGIN = 0xC000, LENGTH = 0x3FE0
  VECTORS : ORIGIN = 0xFFE0, LENGTH = 0x20
}

/* Stack starts at the end of RAM. */
_stack_start = ORIGIN(RAM) + LENGTH(RAM);

/* Entry point */
ENTRY(Reset);
EXTERN(__RESET_VECTOR);

/* Create an undefined reference to the INTERRUPTS symbol. This is required to
   force the linker to *not* drop the INTERRUPTS symbol if it comes from an
   object file that's passed to the linker *before* this crate */
EXTERN(__INTERRUPTS);

/* Provide a default for __VECTORS_END_ADDR. Can be overriden in the user memory.x file */
PROVIDE(__VECTORS_END_ADDR = 0x10000);

/* # Pre-initialization function */
/* If the user overrides this using the `pre_init!` macro or by creating a `__pre_init` function,
then the function this points to will be called before the RAM is initialized. */
PROVIDE(PreInit = PreInit_);

/* # Default interrupt handler */
EXTERN(DefaultHandler); /* If this line is not here, all unused interrupt
                           handlers will be zeroed out instead of doing
                           to the DefaultHandler! */
PROVIDE(DefaultHandler = DefaultHandler_);

/* XXX Are there use cases for making this user overridable? */
_stack_start = ORIGIN(RAM) + LENGTH(RAM);

SECTIONS
{
  .vector_table ORIGIN(VECTORS) : ALIGN(2)
  {
    KEEP(*(.vector_table.interrupts));
    KEEP(*(.__RESET_VECTOR));
  } > VECTORS

  .text ORIGIN(ROM) :
  {
    /* Put the reset handler at the beginning of the .text section */
    KEEP(*(.Reset));

    *(.text .text.*);
  } > ROM

  .rodata : ALIGN(2)
  {
    *(.rodata .rodata.*);
    . = ALIGN(2);
  } > ROM

  .bss : ALIGN(2)
  {
    _sbss = .;
    *(.bss .bss.*);
    . = ALIGN(2);
    _ebss = .;
  } > RAM

  .data : ALIGN(2)
  {
    _sidata = LOADADDR(.data);
    _sdata = .;
    *(.data .data.*);
    . = ALIGN(2);
    _edata = .;
  } > RAM AT > ROM

  /* fake output .got section */
  /* Dynamic relocations are unsupported. This section is only used to detect
     relocatable code in the input files and raise an error if relocatable code
     is found */
  .got :
  {
    _sgot = .;
    KEEP(*(.got .got.*));
    _egot = .;
  } > RAM AT > ROM

  /* The heap starts right after the .bss + .data section ends */
  _sheap = _edata;
}

/* Do not exceed this mark in the error messages below                                    | */
ASSERT(ORIGIN(VECTORS) + LENGTH(VECTORS) == __VECTORS_END_ADDR, "
ERROR(msp430-rt): The VECTORS memory region must end at address 0x10000. Check memory.x");

ASSERT(ADDR(.vector_table) + SIZEOF(.vector_table) == __VECTORS_END_ADDR, "
ERROR(msp430-rt): .vector_table is shorter than expected.
Possible solutions, from most likely to less likely:
- Link to a svd2rust generated pac crate, if you are not
- Fix _sinterrupts in memory.x; it doesn't match the number of interrupts provided by the
  pac crate
- Disable the 'device' feature of msp430-rt to build a generic application; a dependency
may be enabling it
- Override __VECTORS_END_ADDR if your vector table is not placed at the regular vector location
");

ASSERT(_sgot == _egot, "
ERROR(msp430-rt): .got section detected in the input object files
Dynamic relocations are not supported. If you are linking to C code compiled using
the 'cc' crate then modify your build script to compile the C code _without_
the -fPIC flag. See the documentation of the `cc::Build.pic` method for details.");
/* Do not exceed this mark in the error messages above                                    | */
