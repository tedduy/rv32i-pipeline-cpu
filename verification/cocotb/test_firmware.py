"""Execute the bare-metal smoke ELF through the core's native interfaces."""

import os
from collections import deque
from pathlib import Path
from typing import Optional

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge

from elf_to_mem import load_segments
from native_memory import DataRequest, NativeMemory


RAM_BYTES = 1024 * 1024
UART_ADDR = 0x1000_0000
STATUS_ADDR = 0x2000_0000
MTIME_ADDR = 0x4000_0000
MTIMECMP_ADDR = 0x4000_0008


async def initialize(dut) -> None:
    dut.i_arst_n.value = 0
    dut.i_irq_software.value = 0
    dut.i_irq_timer.value = 0
    dut.i_irq_external.value = 0
    dut.i_time.value = 0

    cocotb.start_soon(Clock(dut.i_clk, 10, unit="ns").start())
    for _ in range(4):
        await RisingEdge(dut.i_clk)
    await FallingEdge(dut.i_clk)
    dut.i_arst_n.value = 1


@cocotb.test()
async def bare_metal_smoke(dut):
    elf_path = Path(os.environ["FIRMWARE_ELF"])
    max_cycles = int(os.environ.get("FIRMWARE_MAX_CYCLES", "100000"), 0)
    uart = bytearray()
    status = {"value": None}
    mtimecmp = {"value": (1 << 64) - 1}
    cycle_counter = {"value": 0}

    def handle_mmio_write(request: DataRequest) -> bool:
        if request.address == UART_ADDR:
            uart.append(request.write_data & 0xFF)
            return True
        if request.address == STATUS_ADDR:
            status["value"] = request.write_data
            return True
        if request.address == MTIMECMP_ADDR:
            mtimecmp["value"] = (mtimecmp["value"] & 0xFFFFFFFF00000000) | (request.write_data & 0xFFFFFFFF)
            return True
        if request.address == MTIMECMP_ADDR + 4:
            mtimecmp["value"] = (mtimecmp["value"] & 0x00000000FFFFFFFF) | ((request.write_data & 0xFFFFFFFF) << 32)
            return True
        return False

    def handle_mmio_read(address: int) -> Optional[int]:
        if address == MTIME_ADDR:
            return cycle_counter["value"] & 0xFFFFFFFF
        if address == MTIME_ADDR + 4:
            return (cycle_counter["value"] >> 32) & 0xFFFFFFFF
        if address == MTIMECMP_ADDR:
            return mtimecmp["value"] & 0xFFFFFFFF
        if address == MTIMECMP_ADDR + 4:
            return (mtimecmp["value"] >> 32) & 0xFFFFFFFF
        return None

    memory = NativeMemory(
        dut,
        size=RAM_BYTES,
        mmio_write=handle_mmio_write,
        mmio_read=handle_mmio_read,
    )
    for address, data in load_segments(elf_path, RAM_BYTES):
        memory.load_bytes(data, address)

    recent_commits = deque(maxlen=16)
    memory_task = cocotb.start_soon(memory.run())
    try:
        await initialize(dut)
        for cycle in range(1, max_cycles + 1):
            await RisingEdge(dut.i_clk)
            dut.i_time.value = cycle
            cycle_counter["value"] = cycle
            dut.i_irq_timer.value = 1 if cycle >= mtimecmp["value"] else 0

            if int(dut.o_commit_valid.value):
                recent_commits.append(
                    (
                        int(dut.o_commit_pc.value),
                        int(dut.o_commit_instruction.value),
                    )
                )

            if status["value"] is not None:
                output = uart.decode("ascii", errors="replace")
                cocotb.log.info("Firmware UART:\n%s", output.rstrip())
                assert status["value"] == 1, (
                    f"firmware reported failure code {status['value']}; "
                    f"recent commits={list(recent_commits)}"
                )
                return

        raise AssertionError(
            f"firmware timeout after {max_cycles} cycles; "
            f"UART={uart.decode('ascii', errors='replace')!r}; "
            f"recent commits={list(recent_commits)}"
        )
    finally:
        memory_task.cancel()
