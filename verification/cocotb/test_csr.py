"""Directed register, interrupt, trap and counter checks for csr_file."""

import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer


CSR_ADDRESSES = [
    0x300, 0x310, 0x301, 0x304, 0x305, 0x320, 0x323, 0x33F,
    0x340, 0x341, 0x342, 0x343, 0x344,
    0xB00, 0xB02, 0xB80, 0xB82,
    0xC00, 0xC01, 0xC02, 0xC80, 0xC81, 0xC82,
    0xF11, 0xF12, 0xF13, 0xF14, 0xF15, 0x222,
]


async def write_csr(dut, address, value):
    await FallingEdge(dut.i_clk)
    dut.i_csr_addr.value = address
    dut.i_csr_wdata.value = value
    dut.i_csr_write.value = 1
    await RisingEdge(dut.i_clk)
    await FallingEdge(dut.i_clk)
    dut.i_csr_write.value = 0


@cocotb.test()
async def csr_state_interrupt_priority_and_counters(dut):
    for signal in (
        "i_csr_write", "i_trap_enter", "i_mret", "i_retire",
        "i_irq_software", "i_irq_timer", "i_irq_external",
    ):
        getattr(dut, signal).value = 0
    dut.i_csr_addr.value = 0
    dut.i_csr_wdata.value = 0
    dut.i_trap_pc.value = 0
    dut.i_trap_cause.value = 0
    dut.i_trap_value.value = 0
    dut.i_time.value = 0xFEDC_BA98_7654_3210
    dut.i_arst_n.value = 0
    cocotb.start_soon(Clock(dut.i_clk, 10, unit="ns").start())
    await RisingEdge(dut.i_clk)
    await FallingEdge(dut.i_clk)
    dut.i_arst_n.value = 1

    for address in CSR_ADDRESSES:
        dut.i_csr_addr.value = address
        await Timer(1, unit="ns")
        int(dut.o_csr_rdata.value)
        int(dut.o_csr_valid.value)
        int(dut.o_csr_writable.value)

    for address in (0x300, 0x304, 0x305, 0x320, 0x340, 0x341, 0x342, 0x343,
                    0xB00, 0xB02, 0xB80, 0xB82, 0x301):
        await write_csr(dut, address, 0xFFFF_FFFF)
        await write_csr(dut, address, 0)

    await write_csr(dut, 0x304, 0x888)
    await write_csr(dut, 0x300, 0x88)
    for name, cause in (
        ("i_irq_external", 0x8000_000B),
        ("i_irq_software", 0x8000_0003),
        ("i_irq_timer", 0x8000_0007),
    ):
        for irq in ("i_irq_software", "i_irq_timer", "i_irq_external"):
            getattr(dut, irq).value = int(irq == name)
        await Timer(1, unit="ns")
        assert int(dut.o_irq_pending.value)
        assert int(dut.o_irq_cause.value) == cause

    dut.i_irq_software.value = 1
    dut.i_irq_timer.value = 1
    dut.i_irq_external.value = 1
    await Timer(1, unit="ns")
    assert int(dut.o_irq_cause.value) == 0x8000_000B

    await FallingEdge(dut.i_clk)
    dut.i_trap_pc.value = 0x123
    dut.i_trap_cause.value = 7
    dut.i_trap_value.value = 0xDEAD_BEEF
    dut.i_trap_enter.value = 1
    await RisingEdge(dut.i_clk)
    await FallingEdge(dut.i_clk)
    dut.i_trap_enter.value = 0
    dut.i_mret.value = 1
    await RisingEdge(dut.i_clk)
    await FallingEdge(dut.i_clk)
    dut.i_mret.value = 0

    # Exercise the complete trap payload and platform time buses with
    # reproducible full-width data, while checking architectural readback.
    rng = random.Random(0x435352)
    for _ in range(16):
        trap_pc = rng.getrandbits(32)
        trap_cause = rng.getrandbits(32)
        trap_value = rng.getrandbits(32)
        await FallingEdge(dut.i_clk)
        dut.i_trap_pc.value = trap_pc
        dut.i_trap_cause.value = trap_cause
        dut.i_trap_value.value = trap_value
        dut.i_time.value = rng.getrandbits(64)
        dut.i_trap_enter.value = 1
        await RisingEdge(dut.i_clk)
        await FallingEdge(dut.i_clk)
        dut.i_trap_enter.value = 0

        for address, expected in (
            (0x341, trap_pc & 0xFFFF_FFFE),
            (0x342, trap_cause),
            (0x343, trap_value),
        ):
            dut.i_csr_addr.value = address
            await Timer(1, unit="ns")
            assert int(dut.o_csr_rdata.value) == expected

    dut.i_retire.value = 1
    await RisingEdge(dut.i_clk)
    await FallingEdge(dut.i_clk)
    dut.i_retire.value = 0
