#include <stdint.h>
#include "../common/system.h"

static volatile uint32_t test_sink;

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

static int32_t execute_div(int32_t lhs, int32_t rhs)
{
    int32_t result;
    __asm__ volatile ("div %0, %1, %2" : "=r" (result) : "r" (lhs), "r" (rhs));
    return result;
}

static uint32_t execute_divu(uint32_t lhs, uint32_t rhs)
{
    uint32_t result;
    __asm__ volatile ("divu %0, %1, %2" : "=r" (result) : "r" (lhs), "r" (rhs));
    return result;
}

static int32_t execute_rem(int32_t lhs, int32_t rhs)
{
    int32_t result;
    __asm__ volatile ("rem %0, %1, %2" : "=r" (result) : "r" (lhs), "r" (rhs));
    return result;
}

static uint32_t execute_remu(uint32_t lhs, uint32_t rhs)
{
    uint32_t result;
    __asm__ volatile ("remu %0, %1, %2" : "=r" (result) : "r" (lhs), "r" (rhs));
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
    if (execute_div(-7, 3) != -2)
        return 6;
    if (execute_rem(-7, 3) != -1)
        return 7;
    if (execute_divu(0xffffffffu, 2u) != 0x7fffffffu)
        return 8;
    if (execute_remu(0xffffffffu, 2u) != 1u)
        return 9;
    if (execute_div(123, 0) != -1 || execute_rem(123, 0) != 123)
        return 10;

    /* Keep real C-generated arithmetic and memory traffic in the ELF. */
    for (uint32_t index = 1; index <= 8; ++index)
        test_sink += index * 3u;

    if (test_sink != 108u)
        return 11;
    if (read_cycle() <= cycle_before)
        return 12;
    if (read_instret() <= instret_before)
        return 13;

    __asm__ volatile ("fence.i" ::: "memory");
    uart_puts("RV32IMC bare-metal C smoke test: PASS\n");
    return 1;
}
