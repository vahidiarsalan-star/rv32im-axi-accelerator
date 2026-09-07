/* Memory layout for soc_top.v: 4 KiB unified instruction/data RAM at 0x0. */
OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 4K
}

SECTIONS
{
    . = ORIGIN(RAM);

    .text : ALIGN(4)
    {
        KEEP(*(.init))
        *(.text .text.*)
        *(.rodata .rodata.*)
    } > RAM

    .data : ALIGN(4)
    {
        *(.data .data.*)
    } > RAM

    .bss (NOLOAD) : ALIGN(4)
    {
        __bss_start = .;
        *(.bss .bss.*)
        *(COMMON)
        __bss_end = .;
    } > RAM

    __stack_top = ORIGIN(RAM) + LENGTH(RAM);

    ASSERT(__stack_top >= __bss_end, "firmware exceeds 4 KiB RAM")
}
