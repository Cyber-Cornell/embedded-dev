/* RP2350 with 4 MiB of QSPI flash (Raspberry Pi Pico 2). */
MEMORY {
    FLASH : ORIGIN = 0x10000000, LENGTH = 4096K
    RAM   : ORIGIN = 0x20000000, LENGTH = 512K
}

SECTIONS {
    /* The boot ROM looks for an IMAGE_DEF block in the first 4 KiB of flash. */
    .start_block : ALIGN(4)
    {
        KEEP(*(.start_block));
    } > FLASH
} INSERT AFTER .vector_table;

/* Move .text after the IMAGE_DEF block. */
_stext = ADDR(.start_block) + SIZEOF(.start_block);
