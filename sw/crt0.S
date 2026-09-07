/* RV32I reset and C runtime entry point for the 4 KiB on-chip RAM. */

    .section .init
    .globl _start
    .type _start, @function
_start:
    la      sp, __stack_top

    /* The RAM image initializes .text/.rodata/.data.  Only .bss needs zeroing. */
    la      t0, __bss_start
    la      t1, __bss_end
1:
    bgeu    t0, t1, 2f
    sw      zero, 0(t0)
    addi    t0, t0, 4
    j       1b
2:
    call    main

/* Firmware should not return, but remain in a known state if it does. */
3:
    j       3b
