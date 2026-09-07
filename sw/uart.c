#include "uart.h"

#define UART_DATA   (*(volatile unsigned int *)0x80000000u)
#define UART_STATUS (*(volatile unsigned int *)0x80000004u)

#define UART_TX_BUSY  (1u << 0)
#define UART_RX_READY (1u << 1)

void uart_putc(char c)
{
    while (UART_STATUS & UART_TX_BUSY) {
        /* Wait until the single-byte UART transmitter is idle. */
    }
    UART_DATA = (unsigned char)c;
}

int uart_rx_ready(void)
{
    return (UART_STATUS & UART_RX_READY) != 0u;
}

char uart_getc(void)
{
    while (!uart_rx_ready()) {
        /* Wait for a byte in the hardware receive FIFO. */
    }
    // Reading UART_DATA returns and removes the oldest received byte.
    return (char)(unsigned char)UART_DATA;
}

void uart_puts(const char *s)
{
    while (*s != '\0') {
        uart_putc(*s++);
    }
}

// Decimal output without / or %. This keeps the demo strictly RV32I: the
// current core has no M-extension divide instruction or compiler runtime.
void uart_put_u32(unsigned int value)
{
    static const unsigned int places[10] = {
        1000000000u, 100000000u, 10000000u, 1000000u, 100000u,
        10000u, 1000u, 100u, 10u, 1u
    };
    unsigned int started = 0u;
    unsigned int i;

    for (i = 0u; i < 10u; i++) {
        unsigned int digit = 0u;
        while (value >= places[i]) {
            value -= places[i];
            digit++;
        }
        if (started || digit != 0u || i == 9u) {
            uart_putc((char)('0' + digit));
            started = 1u;
        }
    }
}


void uart_put_hex32(unsigned int value)
{
    static const char hex[] = "0123456789ABCDEF";
    unsigned int shift = 28u;

    for (;;) {
        uart_putc(hex[(value >> shift) & 0x0fu]);
        if (shift == 0u) {
            break;
        }
        shift -= 4u;
    }
}
