"""End-to-end execution through the dual AHB-Lite top-level."""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge

from ahb_memory import AHBLiteMemory
from riscv import (
    WFI,
    addi,
    csrr,
    csrw,
    jal,
    lb,
    lbu,
    lh,
    lhu,
    lw,
    sb,
    sh,
    sw,
)


CSR_MTVEC = 0x305
CSR_MEPC = 0x341
CSR_MCAUSE = 0x342


PROGRAM = [
    addi(1, 0, 5),
    addi(2, 1, 7),
    sw(2, 0, 0x100),
    lw(3, 0, 0x100),
    addi(4, 3, 1),
    jal(0, 0),
]

EXPECTED_COMMITS = [
    (0x00, PROGRAM[0], 1, 5),
    (0x04, PROGRAM[1], 2, 12),
    (0x08, PROGRAM[2], 0, 0),
    (0x0C, PROGRAM[3], 3, 12),
    (0x10, PROGRAM[4], 4, 13),
]


async def initialize(dut):
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


async def collect_commits(dut, count, timeout_cycles=1000):
    commits = []
    for _ in range(timeout_cycles):
        await RisingEdge(dut.i_clk)
        if int(dut.o_commit_valid.value):
            commits.append(
                (
                    int(dut.o_commit_pc.value),
                    int(dut.o_commit_instruction.value),
                    int(dut.o_commit_rd_addr.value)
                    if int(dut.o_commit_rd_write.value)
                    else 0,
                    int(dut.o_commit_rd_data.value)
                    if int(dut.o_commit_rd_write.value)
                    else 0,
                )
            )
            if len(commits) == count:
                return commits
    raise AssertionError(f"timeout: observed {len(commits)}/{count} commits")


async def collect_register_writes_until(dut, final_rd, timeout_cycles=2000):
    writes = []
    for _ in range(timeout_cycles):
        await RisingEdge(dut.i_clk)
        if int(dut.o_commit_valid.value) and int(dut.o_commit_rd_write.value):
            write = (
                int(dut.o_commit_pc.value),
                int(dut.o_commit_rd_addr.value),
                int(dut.o_commit_rd_data.value),
            )
            writes.append(write)
            if write[1] == final_rd:
                return writes
    raise AssertionError(f"timeout waiting for write to x{final_rd}")


@cocotb.test()
async def executes_with_independent_ahb_wait_states(dut):
    instruction_memory = AHBLiteMemory(
        dut,
        output_prefix="o_iahb_",
        input_prefix="i_iahb_",
        wait_states=2,
        instruction_port=True,
    )
    data_memory = AHBLiteMemory(
        dut,
        output_prefix="o_dahb_",
        input_prefix="i_dahb_",
        wait_states=3,
    )
    instruction_memory.load_words(PROGRAM)

    instruction_task = cocotb.start_soon(instruction_memory.run())
    data_task = cocotb.start_soon(data_memory.run())
    overlap_seen = False
    try:
        await initialize(dut)
        commits = []
        for _ in range(1000):
            await RisingEdge(dut.i_clk)
            overlap_seen |= (
                instruction_memory._pending is not None
                and data_memory._pending is not None
            )
            if int(dut.o_commit_valid.value):
                commits.append(
                    (
                        int(dut.o_commit_pc.value),
                        int(dut.o_commit_instruction.value),
                        int(dut.o_commit_rd_addr.value)
                        if int(dut.o_commit_rd_write.value)
                        else 0,
                        int(dut.o_commit_rd_data.value)
                        if int(dut.o_commit_rd_write.value)
                        else 0,
                    )
                )
                if len(commits) == len(EXPECTED_COMMITS):
                    break
        else:
            raise AssertionError("timeout waiting for top-level commits")
    finally:
        instruction_task.cancel()
        data_task.cancel()

    assert commits == EXPECTED_COMMITS
    assert data_memory.read_word(0x100) == 12
    assert data_memory.store_count == 1
    assert overlap_seen, "instruction and data AHB transfers never overlapped"
    # Retirement can coincide with the next fetch address phase, leaving at
    # most one instruction transfer outstanding when observation stops.
    assert (
        len(instruction_memory.completed)
        <= len(instruction_memory.accepted)
        <= len(instruction_memory.completed) + 1
    )
    assert instruction_memory.completed
    assert len(data_memory.accepted) == len(data_memory.completed) == 2
    assert [request.write for request in data_memory.completed] == [1, 0]
    assert all(
        request.protection == 0b0010
        for request in instruction_memory.completed
    )
    assert all(
        request.protection == 0b0011 for request in data_memory.completed
    )


@cocotb.test()
async def subword_accesses_cover_every_ahb_lane(dut):
    program = [
        addi(20, 0, 0x100),
        addi(1, 0, -1),
        sb(1, 20, 0),
        sb(1, 20, 1),
        sb(1, 20, 2),
        sb(1, 20, 3),
        lb(2, 20, 0),
        lbu(3, 20, 1),
        addi(4, 0, 0x7F),
        sb(4, 20, 2),
        lb(5, 20, 2),
        addi(6, 0, -128),
        sb(6, 20, 3),
        lb(7, 20, 3),
        lbu(8, 20, 3),
        addi(9, 0, 0x123),
        sh(9, 20, 0),
        lh(10, 20, 0),
        lhu(11, 20, 0),
        sh(1, 20, 2),
        lh(12, 20, 2),
        lhu(13, 20, 2),
        jal(0, 0),
    ]
    instruction_memory = AHBLiteMemory(
        dut,
        output_prefix="o_iahb_",
        input_prefix="i_iahb_",
        wait_states=1,
        instruction_port=True,
    )
    data_memory = AHBLiteMemory(
        dut,
        output_prefix="o_dahb_",
        input_prefix="i_dahb_",
        wait_states=2,
    )
    instruction_memory.load_words(program)
    instruction_task = cocotb.start_soon(instruction_memory.run())
    data_task = cocotb.start_soon(data_memory.run())
    try:
        await initialize(dut)
        writes = await collect_register_writes_until(dut, 13)
    finally:
        instruction_task.cancel()
        data_task.cancel()

    register_values = {rd: data for _, rd, data in writes}
    assert register_values[2] == 0xFFFF_FFFF
    assert register_values[3] == 0x0000_00FF
    assert register_values[5] == 0x0000_007F
    assert register_values[7] == 0xFFFF_FF80
    assert register_values[8] == 0x0000_0080
    assert register_values[10] == 0x0000_0123
    assert register_values[11] == 0x0000_0123
    assert register_values[12] == 0xFFFF_FFFF
    assert register_values[13] == 0x0000_FFFF
    assert data_memory.read_word(0x100) == 0xFFFF_0123

    stores = [
        (request.address, request.size)
        for request in data_memory.completed
        if request.write
    ]
    assert stores == [
        (0x100, 0),
        (0x101, 0),
        (0x102, 0),
        (0x103, 0),
        (0x102, 0),
        (0x103, 0),
        (0x100, 1),
        (0x102, 1),
    ]


async def run_fault_program(
    dut,
    *,
    program,
    instruction_errors=frozenset(),
    data_errors=frozenset(),
):
    handler = [
        csrr(5, CSR_MCAUSE),
        csrr(6, CSR_MEPC),
        jal(0, 0),
    ]
    instruction_memory = AHBLiteMemory(
        dut,
        output_prefix="o_iahb_",
        input_prefix="i_iahb_",
        wait_states=1,
        error_addresses=set(instruction_errors),
        instruction_port=True,
    )
    data_memory = AHBLiteMemory(
        dut,
        output_prefix="o_dahb_",
        input_prefix="i_dahb_",
        wait_states=2,
        error_addresses=set(data_errors),
    )
    instruction_memory.load_words(program)
    instruction_memory.load_words(handler, 0x100)
    instruction_task = cocotb.start_soon(instruction_memory.run())
    data_task = cocotb.start_soon(data_memory.run())
    try:
        await initialize(dut)
        writes = await collect_register_writes_until(dut, 6)
    finally:
        instruction_task.cancel()
        data_task.cancel()
    return instruction_memory, data_memory, writes


@cocotb.test()
async def instruction_ahb_error_enters_precise_trap(dut):
    program = [
        addi(1, 0, 0x100),
        csrw(CSR_MTVEC, 1),
        jal(0, 0x78),
        addi(4, 0, 0x444),
    ]
    instruction_memory, _, writes = await run_fault_program(
        dut,
        program=program,
        instruction_errors={0x80},
    )

    register_values = {rd: data for _, rd, data in writes}
    assert register_values[5] == 1
    assert register_values[6] == 0x80
    assert not any(rd == 4 for _, rd, _ in writes)
    assert any(
        request.address == 0x80 for request in instruction_memory.completed
    )


@cocotb.test()
async def data_ahb_error_suppresses_side_effect_and_traps(dut):
    program = [
        addi(1, 0, 0x100),
        csrw(CSR_MTVEC, 1),
        addi(2, 0, 0x200),
        lw(3, 2, 0),
        addi(4, 0, 0x444),
        jal(0, 0),
    ]
    _, data_memory, writes = await run_fault_program(
        dut,
        program=program,
        data_errors={0x200},
    )

    register_values = {rd: data for _, rd, data in writes}
    assert register_values[5] == 5
    assert register_values[6] == 0x0C
    assert not any(rd in (3, 4) for _, rd, _ in writes)
    assert data_memory.store_count == 0
    assert any(
        request.address == 0x200 for request in data_memory.completed
    )


@cocotb.test()
async def store_ahb_error_does_not_modify_memory(dut):
    program = [
        addi(1, 0, 0x100),
        csrw(CSR_MTVEC, 1),
        addi(2, 0, 0x200),
        addi(3, 0, 0x55),
        sw(3, 2, 0),
        addi(4, 0, 0x444),
        jal(0, 0),
    ]
    _, data_memory, writes = await run_fault_program(
        dut,
        program=program,
        data_errors={0x200},
    )

    register_values = {rd: data for _, rd, data in writes}
    assert register_values[5] == 7
    assert register_values[6] == 0x10
    assert not any(rd == 4 for _, rd, _ in writes)
    assert data_memory.read_word(0x200) == 0
    assert data_memory.store_count == 0
    assert any(
        request.address == 0x200 and request.write
        for request in data_memory.completed
    )


@cocotb.test()
async def wfi_retires_and_quiesces_ahb(dut):
    instruction_memory = AHBLiteMemory(
        dut,
        output_prefix="o_iahb_",
        input_prefix="i_iahb_",
        wait_states=5,
        instruction_port=True,
    )
    data_memory = AHBLiteMemory(
        dut,
        output_prefix="o_dahb_",
        input_prefix="i_dahb_",
    )
    instruction_memory.load_words([WFI, jal(0, 0)])
    instruction_task = cocotb.start_soon(instruction_memory.run())
    data_task = cocotb.start_soon(data_memory.run())
    wfi_retired = False
    try:
        await initialize(dut)
        for _ in range(500):
            await RisingEdge(dut.i_clk)
            if (
                int(dut.o_commit_valid.value)
                and int(dut.o_commit_instruction.value) == WFI
            ):
                wfi_retired = True
            if wfi_retired and int(dut.o_core_sleep.value):
                assert int(dut.o_iahb_htrans.value) == 0
                assert int(dut.o_dahb_htrans.value) == 0
                break
        else:
            raise AssertionError("timeout waiting for gated top-level sleep")
    finally:
        instruction_task.cancel()
        data_task.cancel()

    assert wfi_retired
