/* MSP430G2553: 16K flash (incl. 32-byte vector table), 512B RAM. */
MEMORY
{
  RAM : ORIGIN = 0x0200, LENGTH = 0x0200
  ROM : ORIGIN = 0xC000, LENGTH = 0x3FE0
  VECTORS : ORIGIN = 0xFFE0, LENGTH = 0x20
}

/* Stack starts at the end of RAM. */
_stack_start = ORIGIN(RAM) + LENGTH(RAM);
