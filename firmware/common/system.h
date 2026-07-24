#ifndef SYSTEM_H
#define SYSTEM_H

#include <stdint.h>

void uart_putc(char character);
void uart_puts(const char *text);

uint32_t read_cycle(void);
uint32_t read_instret(void);

#endif /* SYSTEM_H */
