#ifndef UART_H
#define UART_H

void uart_putc(char c);
void uart_puts(const char *s);
void uart_put_u32(unsigned int value);
void uart_put_hex32(unsigned int value);
int uart_rx_ready(void);
char uart_getc(void);

#endif
