/* MSPM0L2228 (LP-MSPM0L2228): 256K flash, 32K SRAM. The NONMAIN
   configuration flash (0x41C00000) is deliberately left out. */
MEMORY
{
  FLASH : ORIGIN = 0x00000000, LENGTH = 256K
  RAM   : ORIGIN = 0x20200000, LENGTH = 32K
}
