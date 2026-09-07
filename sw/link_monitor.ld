/* Resident monitor occupies the lower half of the 4 KiB unified RAM. */
OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    MONITOR (rwx) : ORIGIN = 0x00000000, LENGTH = 2K
}

SECTIONS
{
    . = ORIGIN(MONITOR);
    .text : ALIGN(4)
    {
        KEEP(*(.init))
        *(.text .text.*)
        *(.rodata .rodata.*)
    } > MONITOR
    .data : ALIGN(4) { *(.data .data.*) } > MONITOR
    .bss (NOLOAD) : ALIGN(4)
    {
        __bss_start = .;
        *(.bss .bss.*)
        *(COMMON)
        __bss_end = .;
    } > MONITOR

    /* The top 512 bytes remain stack space during a load. */
    __stack_top = 0x00001000;
    ASSERT(__bss_end <= 0x00000800, "monitor exceeds reserved lower 2 KiB")
}
