#include "system.h"

#define UART_TX_ADDR 0x10000000u

static volatile uint32_t *const uart_tx = (volatile uint32_t *)UART_TX_ADDR;

void uart_putc(char character)
{
    *uart_tx = (uint32_t)(uint8_t)character;
}

void uart_puts(const char *text)
{
    while (*text != '\0') {
        uart_putc(*text);
        ++text;
    }
}

uint32_t read_cycle(void)
{
    uint32_t value;
    __asm__ volatile ("csrr %0, cycle" : "=r" (value));
    return value;
}

uint32_t read_instret(void)
{
    uint32_t value;
    __asm__ volatile ("csrr %0, instret" : "=r" (value));
    return value;
}

void *memset(void *s, int c, uint32_t n)
{
    unsigned char *p = (unsigned char *)s;
    while (n--) {
        *p++ = (unsigned char)c;
    }
    return s;
}

void *memcpy(void *dest, const void *src, uint32_t n)
{
    unsigned char *d = (unsigned char *)dest;
    const unsigned char *s = (const unsigned char *)src;
    while (n--) {
        *d++ = *s++;
    }
    return dest;
}
