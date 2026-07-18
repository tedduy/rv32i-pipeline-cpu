#include <stdint.h>

#define UART_TX_ADDR 0x10000000u

static volatile uint32_t *const uart_tx = (volatile uint32_t *)UART_TX_ADDR;
static volatile uint32_t test_sink;

static void uart_putc(char character)
{
    *uart_tx = (uint32_t)(uint8_t)character;
}

static void uart_puts(const char *text)
{
    while (*text != '\0') {
        uart_putc(*text);
        ++text;
    }
}

static uint32_t read_cycle(void)
{
    uint32_t value;
    __asm__ volatile ("csrr %0, cycle" : "=r" (value));
    return value;
}

static uint32_t read_instret(void)
{
    uint32_t value;
    __asm__ volatile ("csrr %0, instret" : "=r" (value));
    return value;
}

static uint32_t execute_mul(uint32_t lhs, uint32_t rhs)
{
    uint32_t result;
    __asm__ volatile ("mul %0, %1, %2" : "=r" (result) : "r" (lhs), "r" (rhs));
    return result;
}

static uint32_t execute_mulh(int32_t lhs, int32_t rhs)
{
    uint32_t result;
    __asm__ volatile ("mulh %0, %1, %2" : "=r" (result) : "r" (lhs), "r" (rhs));
    return result;
}

static uint32_t execute_mulhsu(int32_t lhs, uint32_t rhs)
{
    uint32_t result;
    __asm__ volatile ("mulhsu %0, %1, %2" : "=r" (result) : "r" (lhs), "r" (rhs));
    return result;
}

static uint32_t execute_mulhu(uint32_t lhs, uint32_t rhs)
{
    uint32_t result;
    __asm__ volatile ("mulhu %0, %1, %2" : "=r" (result) : "r" (lhs), "r" (rhs));
    return result;
}

int main(void)
{
    uint32_t cycle_before = read_cycle();
    uint32_t instret_before = read_instret();

    if (execute_mul((uint32_t)-2, 3u) != 0xfffffffau)
        return 2;
    if (execute_mulh(-2, 3) != 0xffffffffu)
        return 3;
    if (execute_mulhsu(-2, 0xffffffffu) != 0xfffffffeu)
        return 4;
    if (execute_mulhu(0xffffffffu, 0xffffffffu) != 0xfffffffeu)
        return 5;

    /* Keep real C-generated arithmetic and memory traffic in the ELF. */
    for (uint32_t index = 1; index <= 8; ++index)
        test_sink += index * 3u;

    if (test_sink != 108u)
        return 6;
    if (read_cycle() <= cycle_before)
        return 7;
    if (read_instret() <= instret_before)
        return 8;

    __asm__ volatile ("fence.i" ::: "memory");
    uart_puts("RV32I bare-metal C smoke test: PASS\n");
    return 1;
}
