"""Exercise divider normal/special results and explicit consume protocol."""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge


@cocotb.test()
async def all_operations_special_cases_and_done_hold(dut):
    dut.i_arst_n.value = 0
    dut.i_start.value = 0
    dut.i_consume.value = 0
    dut.i_dividend.value = 0
    dut.i_divisor.value = 1
    dut.i_operation.value = 0
    cocotb.start_soon(Clock(dut.i_clk, 10, unit="ns").start())
    await RisingEdge(dut.i_clk)
    await FallingEdge(dut.i_clk)
    dut.i_arst_n.value = 1

    vectors = [
        (0, 0xFFFF_FFF9, 3), (1, 0xFFFF_FFF9, 3),
        (2, 0xFFFF_FFF9, 3), (3, 0xFFFF_FFF9, 3),
        (0, 7, 0), (2, 7, 0),
        (0, 0x8000_0000, 0xFFFF_FFFF),
    ]
    for operation, dividend, divisor in vectors:
        dut.i_operation.value = operation
        dut.i_dividend.value = dividend
        dut.i_divisor.value = divisor
        dut.i_start.value = 1
        await RisingEdge(dut.i_clk)
        await FallingEdge(dut.i_clk)
        dut.i_start.value = 0
        for _ in range(40):
            await RisingEdge(dut.i_clk)
            if int(dut.o_done.value):
                break
        assert int(dut.o_done.value)
        await RisingEdge(dut.i_clk)
        dut.i_consume.value = 1
        await RisingEdge(dut.i_clk)
        await FallingEdge(dut.i_clk)
        dut.i_consume.value = 0
