"""Reusable full-width capture checks for each pipeline-register stage."""

import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, ReadOnly, RisingEdge


EXCLUDED_INPUTS = {"i_clk", "i_arst_n", "i_stall", "i_flush"}


def mirrored_ports(dut):
    pairs = []
    for name in dir(dut):
        if not name.startswith("i_") or name in EXCLUDED_INPUTS:
            continue
        output_name = f"o_{name[2:]}"
        if hasattr(dut, output_name):
            pairs.append((getattr(dut, name), getattr(dut, output_name)))
    if not pairs:
        raise AssertionError("pipeline register exposes no mirrored payload/control ports")
    return pairs


@cocotb.test()
async def captures_and_holds_all_exposed_fields(dut):
    rng = random.Random(0x50495045)
    dut.i_arst_n.value = 0
    dut.i_stall.value = 0
    if hasattr(dut, "i_flush"):
        dut.i_flush.value = 0
    pairs = mirrored_ports(dut)
    for input_signal, _ in pairs:
        input_signal.value = 0

    cocotb.start_soon(Clock(dut.i_clk, 10, unit="ns").start())
    await RisingEdge(dut.i_clk)
    await FallingEdge(dut.i_clk)
    dut.i_arst_n.value = 1

    patterns = (0, -1, 0xAAAA_AAAA, 0x5555_5555)
    for cycle in range(68):
        expected = []
        for input_signal, output_signal in pairs:
            width = len(input_signal)
            mask = (1 << width) - 1
            source = patterns[cycle] if cycle < len(patterns) else rng.getrandbits(width)
            value = source & mask
            input_signal.value = value
            expected.append((output_signal, value))
        await RisingEdge(dut.i_clk)
        await ReadOnly()
        for output_signal, value in expected:
            assert int(output_signal.value) == value
        await FallingEdge(dut.i_clk)

    held = [(output_signal, int(output_signal.value)) for _, output_signal in pairs]
    dut.i_stall.value = 1
    for input_signal, _ in pairs:
        input_signal.value = rng.getrandbits(len(input_signal))
    await RisingEdge(dut.i_clk)
    await ReadOnly()
    for output_signal, value in held:
        assert int(output_signal.value) == value
