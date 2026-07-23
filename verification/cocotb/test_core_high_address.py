"""Verify the parameterized core boots and retires at a high reset vector."""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge

from native_memory import NativeMemory
from riscv import addi, jal


RESET_VECTOR = 0xA5A5_0000


class HighAddressMemory(NativeMemory):
    def read_word(self, address: int) -> int:
        return super().read_word((address - RESET_VECTOR) & 0xFFFF_FFFF)


@cocotb.test()
async def retires_from_high_reset_vector(dut):
    memory = HighAddressMemory(dut)
    program = [
        addi(1, 0, 0x5A5),
        addi(2, 1, -0x123),
        jal(0, 0),
    ]
    memory.load_words(program)
    memory_task = cocotb.start_soon(memory.run())

    dut.i_arst_n.value = 0
    dut.i_irq_software.value = 0
    dut.i_irq_timer.value = 0
    dut.i_irq_external.value = 0
    dut.i_time.value = 0xA55A_F00F_5AA5_0FF0
    cocotb.start_soon(Clock(dut.i_clk, 10, unit="ns").start())
    try:
        for _ in range(4):
            await RisingEdge(dut.i_clk)
        await FallingEdge(dut.i_clk)
        dut.i_arst_n.value = 1

        commits = []
        for _ in range(100):
            await RisingEdge(dut.i_clk)
            if int(dut.o_commit_valid.value):
                commits.append(
                    (
                        int(dut.o_commit_pc.value),
                        int(dut.o_commit_rd_addr.value),
                        int(dut.o_commit_rd_data.value),
                    )
                )
                if len(commits) == 2:
                    break
        else:
            raise AssertionError("timeout waiting for high-address retirement")
    finally:
        memory_task.cancel()

    assert commits == [
        (RESET_VECTOR, 1, 0x5A5),
        (RESET_VECTOR + 4, 2, 0x482),
    ]
