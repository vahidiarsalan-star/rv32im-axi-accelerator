#include "uart.h"

#define LED_REG (*(volatile unsigned int *)0x80000008u)

static void delay(unsigned int count)
{
    while (count-- != 0u) {
        __asm__ volatile ("nop");
    }
}

int main(void)
{
    unsigned int leds = 0u;
    // volatile prevents GCC from folding these expressions at compile time;
    // the FPGA CPU must execute the loads, ADD, and SUB instructions.
    volatile int a = 37;
    volatile int b = 12;
    int sum = a + b;
    int difference = a - b;

    uart_puts("RV32I C arithmetic demo\r\n");
    uart_puts("37 + 12 = ");
    uart_put_u32((unsigned int)sum);
    uart_puts("\r\n");
    uart_puts("37 - 12 = ");
    uart_put_u32((unsigned int)difference);
    uart_puts("\r\n");

    for (;;) {
        leds ^= 7u;
        LED_REG = leds;
        uart_puts("tick\r\n");
        delay(1000000u);
    }
}
