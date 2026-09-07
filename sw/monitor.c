#include "uart.h"

#define APP_BASE  0x00000800u
#define APP_LIMIT 0x00000e00u

static unsigned int image_start;
static unsigned int image_words;
static unsigned int image_valid;

static int hex_digit(char c)
{
    if (c >= '0' && c <= '9') return (int)(c - '0');
    if (c >= 'a' && c <= 'f') return (int)(c - 'a') + 10;
    if (c >= 'A' && c <= 'F') return (int)(c - 'A') + 10;
    return -1;
}

static const char *skip_spaces(const char *p)
{
    while (*p == ' ' || *p == '\t') p++;
    return p;
}

static int parse_hex(const char **cursor, unsigned int *value)
{
    const char *p = skip_spaces(*cursor);
    unsigned int result = 0u;
    unsigned int digits = 0u;
    int digit;

    while ((digit = hex_digit(*p)) >= 0) {
        if (digits == 8u) return 0;
        result = (result << 4) | (unsigned int)digit;
        digits++;
        p++;
    }
    if (digits == 0u) return 0;
    *cursor = p;
    *value = result;
    return 1;
}

static int line_end(const char *p)
{
    return *skip_spaces(p) == '\0';
}

static void read_line(char *line, unsigned int capacity)
{
    unsigned int length = 0u;

    for (;;) {
        char c = uart_getc();
        if (c == '\r' || c == '\n') {
            if (length != 0u) {
                line[length] = '\0';
                return;
            }
        } else if (c == '\b' || c == 0x7f) {
            if (length != 0u) length--;
        } else if (length + 1u < capacity) {
            line[length++] = c;
        }
    }
}

static int read_stream_word(unsigned int *value)
{
    unsigned int result = 0u;
    unsigned int digits = 0u;

    while (digits != 8u) {
        char c = uart_getc();
        int digit = hex_digit(c);
        if (digit >= 0) {
            result = (result << 4) | (unsigned int)digit;
            digits++;
        } else if (c == ' ' || c == '\t' || c == '\r' || c == '\n') {
            if (digits != 0u) return 0;
        } else {
            return 0;
        }
    }
    *value = result;
    return 1;
}

static void command_load(const char *args)
{
    unsigned int address;
    unsigned int count;
    unsigned int expected_sum;
    unsigned int actual_sum = 0u;
    unsigned int i;
    volatile unsigned int *destination;

    image_valid = 0u;
    if (!parse_hex(&args, &address) || !parse_hex(&args, &count) ||
        !parse_hex(&args, &expected_sum) || !line_end(args) ||
        (address & 3u) != 0u || address < APP_BASE || address >= APP_LIMIT ||
        count == 0u || count > ((APP_LIMIT - address) >> 2)) {
        uart_puts("ERR RANGE\r\n");
        return;
    }

    destination = (volatile unsigned int *)address;
    for (i = 0u; i < count; i++) {
        unsigned int word;
        if (!read_stream_word(&word)) {
            uart_puts("ERR DATA\r\n");
            return;
        }
        destination[i] = word;
        actual_sum += word;
    }

    if (actual_sum != expected_sum) {
        uart_puts("ERR SUM ");
        uart_put_hex32(actual_sum);
        uart_puts("\r\n");
        return;
    }

    image_start = address;
    image_words = count;
    image_valid = 1u;
    uart_puts("OK ");
    uart_put_hex32(count);
    uart_puts(" WORDS\r\n");
}

static void command_dump(const char *args)
{
    unsigned int address;
    unsigned int count;
    unsigned int i;
    volatile unsigned int *source;

    if (!parse_hex(&args, &address) || !parse_hex(&args, &count) ||
        !line_end(args) || (address & 3u) != 0u ||
        address >= 0x00001000u || count > ((0x00001000u - address) >> 2)) {
        uart_puts("ERR RANGE\r\n");
        return;
    }
    source = (volatile unsigned int *)address;
    for (i = 0u; i < count; i++) {
        uart_put_hex32(address + (i << 2));
        uart_putc(' ');
        uart_put_hex32(source[i]);
        uart_puts("\r\n");
    }
}

static void command_go(const char *args)
{
    unsigned int address;

    if (!parse_hex(&args, &address) || !line_end(args) || !image_valid ||
        address != image_start || (address & 3u) != 0u || image_words == 0u) {
        uart_puts("ERR NO IMAGE\r\n");
        return;
    } else {
        uart_puts("GO ");
        uart_put_hex32(address);
        uart_puts("\r\n");
        // This is deliberately a one-way jump.  Reset the board to return to
        // the resident monitor; an uploaded program owns the CPU and stack.
        __asm__ volatile ("jalr zero, 0(%0)" : : "r" (address));
    }
    for (;;) { }
}

static void help(void)
{
    uart_puts("L addr words sum + 8-hex words\r\n");
    uart_puts("D addr words | G addr | H\r\n");
    uart_puts("App: 00000800..00000DFF\r\n");
}

int main(void)
{
    char line[64];

    uart_puts("\r\nRV32I UART monitor\r\n");
    help();
    for (;;) {
        char command;
        const char *args;
        uart_puts("> ");
        read_line(line, sizeof(line));
        command = line[0];
        if (command >= 'a' && command <= 'z') command -= ('a' - 'A');
        args = line + 1;

        if (command == 'L') command_load(args);
        else if (command == 'D') command_dump(args);
        else if (command == 'G') command_go(args);
        else if (command == 'H') help();
        else uart_puts("ERR CMD\r\n");
    }
}
