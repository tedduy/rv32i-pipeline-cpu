"""Full-width, self-checking program-counter transition coverage."""

import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, ReadOnly, RisingEdge


@cocotb.test()
async def captures_full_width_next_pc(dut):
    rng = random.Random(0x5043)
    dut.i_arst_n.value = 0
    dut.i_pc.value = 0
    cocotb.start_soon(Clock(dut.i_clk, 10, unit="ns").start())
    await RisingEdge(dut.i_clk)
    await FallingEdge(dut.i_clk)
    dut.i_arst_n.value = 1

    values = [0, 0xFFFF_FFFF, 0xAAAA_AAAA, 0x5555_5555]
    values.extend(rng.getrandbits(32) for _ in range(64))
    for value in values:
        dut.i_pc.value = value
        await RisingEdge(dut.i_clk)
        await ReadOnly()
        assert int(dut.o_pc.value) == value
        await FallingEdge(dut.i_clk)
