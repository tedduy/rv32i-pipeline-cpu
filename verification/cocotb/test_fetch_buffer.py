"""Protocol-state coverage for aligned, held and cross-word fetches."""

import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge


async def drive_response(dut, *, pc, data, error=0, consume=1):
    await FallingEdge(dut.i_clk)
    dut.i_pc.value = pc
    dut.i_response_data.value = data
    dut.i_response_error.value = error
    dut.i_consume.value = consume
    dut.i_response_valid.value = 1
    await RisingEdge(dut.i_clk)
    await FallingEdge(dut.i_clk)
    dut.i_response_valid.value = 0


@cocotb.test()
async def aligned_held_fault_and_cross_word_paths(dut):
    for name in ("i_flush", "i_consume", "i_response_valid", "i_response_error"):
        getattr(dut, name).value = 0
    dut.i_pc.value = 0
    dut.i_response_data.value = 0
    dut.i_arst_n.value = 0
    cocotb.start_soon(Clock(dut.i_clk, 10, unit="ns").start())
    await RisingEdge(dut.i_clk)
    await FallingEdge(dut.i_clk)
    dut.i_arst_n.value = 1

    await drive_response(dut, pc=0, data=0x0000_0013)
    await drive_response(dut, pc=0, data=0x0000_0001, consume=0)
    await FallingEdge(dut.i_clk)
    dut.i_consume.value = 1
    await RisingEdge(dut.i_clk)

    await drive_response(dut, pc=0, data=0xFFFF_FFFF, error=1, consume=0)
    await FallingEdge(dut.i_clk)
    dut.i_consume.value = 1
    await RisingEdge(dut.i_clk)

    # 32-bit instruction starts at upper half: first and second bus words.
    await drive_response(dut, pc=2, data=0x0093_0001, consume=1)
    await drive_response(dut, pc=2, data=0xBEEF_1234, consume=0)
    await FallingEdge(dut.i_clk)
    dut.i_consume.value = 1
    await RisingEdge(dut.i_clk)

    await drive_response(dut, pc=2, data=0x0093_0001, consume=1)
    await drive_response(dut, pc=2, data=0, error=1, consume=1)

    # Full-width held and cross-word responses verify that every payload bit
    # survives the buffering path, instead of merely toggling low opcodes.
    rng = random.Random(0x46455443)
    for _ in range(32):
        aligned = (rng.getrandbits(32) & ~0x3) | 0x3
        await drive_response(dut, pc=0, data=aligned, consume=0)
        assert int(dut.o_raw_instruction.value) == aligned
        await FallingEdge(dut.i_clk)
        dut.i_consume.value = 1
        await RisingEdge(dut.i_clk)

        first = (rng.getrandbits(32) & ~(0x3 << 16)) | (0x3 << 16)
        second = rng.getrandbits(32)
        await drive_response(dut, pc=2, data=first)
        await drive_response(dut, pc=2, data=second, consume=0)
        expected = ((second & 0xFFFF) << 16) | (first >> 16)
        assert int(dut.o_raw_instruction.value) == expected
        await FallingEdge(dut.i_clk)
        dut.i_consume.value = 1
        await RisingEdge(dut.i_clk)

    await FallingEdge(dut.i_clk)
    dut.i_flush.value = 1
    await RisingEdge(dut.i_clk)
    await FallingEdge(dut.i_clk)
    dut.i_flush.value = 0
