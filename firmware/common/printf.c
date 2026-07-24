#include "system.h"
#include <stdarg.h>

static void print_int(int num) {
    if (num == 0) {
        uart_putc('0');
        return;
    }
    if (num < 0) {
        uart_putc('-');
        num = -num;
    }
    char buf[12];
    int i = 0;
    while (num > 0) {
        buf[i++] = (num % 10) + '0';
        num /= 10;
    }
    while (i > 0) {
        uart_putc(buf[--i]);
    }
}

int printf(const char *format, ...) {
    va_list args;
    va_start(args, format);

    while (*format) {
        if (*format == '%') {
            format++;
            if (*format == 'd') {
                print_int(va_arg(args, int));
            } else if (*format == 's') {
                const char *str = va_arg(args, const char*);
                uart_puts(str ? str : "(null)");
            } else if (*format == 'c') {
                uart_putc((char)va_arg(args, int));
            } else if (*format == '%') {
                uart_putc('%');
            }
        } else {
            uart_putc(*format);
        }
        format++;
    }

    va_end(args);
    return 0;
}

// Stub for strcpy, strcmp etc if needed by dhrystone
char *strcpy(char *dest, const char *src) {
    char *d = dest;
    while ((*d++ = *src++) != '\0')
        ;
    return dest;
}

int strcmp(const char *s1, const char *s2) {
    while (*s1 && (*s1 == *s2)) {
        s1++;
        s2++;
    }
    return *(const unsigned char*)s1 - *(const unsigned char*)s2;
}

// Dhrystone requires time() to measure duration
long time(void) {
    // Return cycle count as "time"
    return (long)read_cycle();
}
