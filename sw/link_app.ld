/* Uploaded applications use 0x800..0xDFF; 0xE00..0xFFF is stack. */
OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    APP (rwx) : ORIGIN = 0x00000800, LENGTH = 0x600
}

SECTIONS
{
    . = ORIGIN(APP);
    .text : ALIGN(4)
    {
        KEEP(*(.init))
        *(.text .text.*)
        *(.rodata .rodata.*)
    } > APP
    .data : ALIGN(4) { *(.data .data.*) } > APP
    .bss (NOLOAD) : ALIGN(4)
    {
        __bss_start = .;
        *(.bss .bss.*)
        *(COMMON)
        __bss_end = .;
    } > APP

    __stack_top = 0x00001000;
    ASSERT(__bss_end <= 0x00000e00, "application exceeds upload region")
}
