#include "uart.h"

int main(void)
{
    uart_puts("UART RX echo app. Type text:\r\n");
    for (;;) {
        char c = uart_getc();
        if (c == '\r' || c == '\n') {
            uart_puts("\r\n");
        } else {
            uart_putc(c);
        }
    }
}
