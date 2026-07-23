"""Architectural and native-bus protocol tests for rv32i_core."""

import os

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge

import functional_coverage
from native_memory import NativeMemory
from reference_model import generate_random_program
from riscv import (
    ECALL,
    MRET,
    WFI,
    add,
    addi,
    and_,
    auipc,
    beq,
    bge,
    bgeu,
    blt,
    bltu,
    bne,
    c_add,
    c_addi,
    c_li,
    c_mv,
    csrr,
    csrrci,
    csrrsi,
    csrrwi,
    csrw,
    div,
    divu,
    jal,
    jalr,
    lui,
    lw,
    mul,
    mulh,
    mulhsu,
    mulhu,
    or_,
    rem,
    remu,
    sll,
    slli,
    slt,
    sltu,
    sra,
    srai,
    srl,
    srli,
    sub,
    sw,
    u32,
    xor,
)


CSR_MSTATUS = 0x300
CSR_MIE = 0x304
CSR_MTVEC = 0x305
CSR_MSCRATCH = 0x340
CSR_MEPC = 0x341
CSR_MCAUSE = 0x342
CSR_MTVAL = 0x343


PROGRAM = [
    addi(1, 0, 5),   # x1 = 5
    addi(2, 1, 7),   # x2 = 12, exercises dependency forwarding
    sw(2, 0, 0),     # memory[0] = 12
    lw(3, 0, 0),     # x3 = 12
    addi(4, 3, 1),   # x4 = 13, exercises load-use interlock
    jal(0, 0),       # stop loop
]

EXPECTED_COMMITS = [
    (0x00, PROGRAM[0], 1, 5),
    (0x04, PROGRAM[1], 2, 12),
    (0x08, PROGRAM[2], 0, 0),
    (0x0C, PROGRAM[3], 3, 12),
    (0x10, PROGRAM[4], 4, 13),
]


async def initialize(dut) -> None:
    dut.i_arst_n.value = 0
    dut.i_irq_software.value = 0
    dut.i_irq_timer.value = 0
    dut.i_irq_external.value = 0
    dut.i_time.value = 0

    cocotb.start_soon(Clock(dut.i_clk, 10, unit="ns").start())
    cocotb.start_soon(functional_coverage.monitor(dut))
    for _ in range(4):
        await RisingEdge(dut.i_clk)
    await FallingEdge(dut.i_clk)
    dut.i_arst_n.value = 1


async def collect_commits(dut, count: int, timeout_cycles: int = 300):
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


async def collect_register_writes(
    dut,
    count: int,
    timeout_cycles: int = 3000,
    forbidden_commit_pcs=frozenset(),
    forbid_committed_store: bool = False,
):
    writes = []
    for _ in range(timeout_cycles):
        await RisingEdge(dut.i_clk)
        if int(dut.o_commit_valid.value):
            commit_pc = int(dut.o_commit_pc.value)
            assert commit_pc not in forbidden_commit_pcs, (
                f"faulting/trapping instruction at PC 0x{commit_pc:08x} retired"
            )
            if forbid_committed_store:
                assert not int(dut.o_commit_mem_write.value), (
                    "faulting store appeared on the commit interface"
                )

        if int(dut.o_commit_valid.value) and int(dut.o_commit_rd_write.value):
            writes.append(
                (
                    int(dut.o_commit_pc.value),
                    int(dut.o_commit_rd_addr.value),
                    int(dut.o_commit_rd_data.value),
                )
            )
            if len(writes) == count:
                return writes
    raise AssertionError(f"timeout: observed {len(writes)}/{count} register writes")


async def run_program(dut, *, instruction_wait: int, data_wait: int):
    memory = NativeMemory(
        dut,
        instruction_wait=instruction_wait,
        data_wait=data_wait,
    )
    memory.load_words(PROGRAM)
    memory_task = cocotb.start_soon(memory.run())
    try:
        await initialize(dut)
        commits = await collect_commits(dut, len(EXPECTED_COMMITS))
        return memory, commits
    finally:
        memory_task.cancel()


@cocotb.test()
async def boot_and_retire(dut):
    memory, commits = await run_program(dut, instruction_wait=0, data_wait=0)

    assert commits == EXPECTED_COMMITS
    assert memory.read_word(0) == 12
    assert memory.store_count == 1


@cocotb.test()
async def native_wait_state_protocol(dut):
    memory, commits = await run_program(dut, instruction_wait=2, data_wait=3)

    assert commits == EXPECTED_COMMITS
    assert memory.read_word(0) == 12
    assert memory.store_count == 1, "store request was accepted more than once"
    assert any(request.read for request in memory.data_accepts)
    assert any(request.write for request in memory.data_accepts)


@cocotb.test()
async def rv32i_datapath_control_flow_and_hazards(dut):
    program = [
        addi(1, 0, -1),
        addi(2, 0, 1),
        add(3, 1, 2),
        sub(4, 2, 1),
        sll(5, 2, 2),
        slt(6, 1, 2),
        sltu(7, 1, 2),
        xor(8, 1, 2),
        srl(9, 1, 2),
        sra(10, 1, 2),
        or_(11, 1, 2),
        and_(12, 1, 2),
        slli(13, 2, 4),
        srli(14, 1, 4),
        srai(15, 1, 4),
        lui(16, 0x12345),
        auipc(17, 0),
        addi(20, 0, 0x400),
        sw(16, 20, 0),
        lw(18, 20, 0),
        addi(19, 18, 1),
        beq(19, 19, 8),
        addi(21, 0, 0x6AD),
        addi(21, 0, 21),
        jal(22, 8),
        addi(23, 0, 0x6AD),
        addi(23, 0, 23),
    ]

    jalr_target = (len(program) + 3) * 4
    jalr_pc = (len(program) + 1) * 4
    program.extend(
        [
            addi(24, 0, jalr_target),
            jalr(25, 24, 0),
            addi(26, 0, 0x6AD),
            addi(26, 0, 26),
            jal(0, 0),
        ]
    )

    expected = [
        (0x00, 1, u32(-1)),
        (0x04, 2, 1),
        (0x08, 3, 0),
        (0x0C, 4, 2),
        (0x10, 5, 2),
        (0x14, 6, 1),
        (0x18, 7, 0),
        (0x1C, 8, u32(-2)),
        (0x20, 9, 0x7FFF_FFFF),
        (0x24, 10, u32(-1)),
        (0x28, 11, u32(-1)),
        (0x2C, 12, 1),
        (0x30, 13, 16),
        (0x34, 14, 0x0FFF_FFFF),
        (0x38, 15, u32(-1)),
        (0x3C, 16, 0x1234_5000),
        (0x40, 17, 0x40),
        (0x44, 20, 0x400),
        (0x4C, 18, 0x1234_5000),
        (0x50, 19, 0x1234_5001),
        (0x5C, 21, 21),
        (0x60, 22, 0x64),
        (0x68, 23, 23),
        (0x6C, 24, jalr_target),
        (jalr_pc, 25, jalr_pc + 4),
        (jalr_target, 26, 26),
    ]

    memory = NativeMemory(dut, instruction_wait=1, data_wait=2)
    memory.load_words(program)
    memory_task = cocotb.start_soon(memory.run())
    try:
        await initialize(dut)
        writes = await collect_register_writes(dut, len(expected))
    finally:
        memory_task.cancel()

    assert writes == expected
    assert memory.read_word(0x400) == 0x1234_5000
    assert memory.store_count == 1


@cocotb.test()
async def rv32m_corner_cases(dut):
    program = [
        addi(1, 0, -7),
        addi(2, 0, 3),
        mul(3, 1, 2),
        mulh(4, 1, 2),
        mulhsu(5, 1, 2),
        mulhu(6, 1, 2),
        div(7, 1, 2),
        divu(8, 1, 2),
        rem(9, 1, 2),
        remu(10, 1, 2),
        div(11, 1, 0),
        divu(12, 1, 0),
        rem(13, 1, 0),
        remu(14, 1, 0),
        lui(15, 0x80000),
        addi(16, 0, -1),
        div(17, 15, 16),
        rem(18, 15, 16),
        jal(0, 0),
    ]
    expected = [
        (0x00, 1, u32(-7)),
        (0x04, 2, 3),
        (0x08, 3, u32(-21)),
        (0x0C, 4, u32(-1)),
        (0x10, 5, u32(-1)),
        (0x14, 6, 2),
        (0x18, 7, u32(-2)),
        (0x1C, 8, 0x5555_5553),
        (0x20, 9, u32(-1)),
        (0x24, 10, 0),
        (0x28, 11, u32(-1)),
        (0x2C, 12, u32(-1)),
        (0x30, 13, u32(-7)),
        (0x34, 14, u32(-7)),
        (0x38, 15, 0x8000_0000),
        (0x3C, 16, u32(-1)),
        (0x40, 17, 0x8000_0000),
        (0x44, 18, 0),
    ]

    memory = NativeMemory(dut)
    memory.load_words(program)
    memory_task = cocotb.start_soon(memory.run())
    try:
        await initialize(dut)
        writes = await collect_register_writes(
            dut,
            len(expected),
            timeout_cycles=5000,
        )
    finally:
        memory_task.cancel()

    assert writes == expected


@cocotb.test()
async def rv32c_mixed_width_fetch_and_forwarding(dut):
    halfwords = [
        c_li(1, 5),
        c_addi(1, 3),
        c_li(2, -2),
        c_add(1, 2),
        c_mv(3, 1),
        c_addi(3, 1),
        jal(0, 0) & 0xFFFF,
        jal(0, 0) >> 16,
    ]
    expected = [
        (0x00, 1, 5),
        (0x02, 1, 8),
        (0x04, 2, u32(-2)),
        (0x06, 1, 6),
        (0x08, 3, 6),
        (0x0A, 3, 7),
    ]

    memory = NativeMemory(dut, instruction_wait=1)
    memory.load_halfwords(halfwords)
    memory_task = cocotb.start_soon(memory.run())
    try:
        await initialize(dut)
        writes = await collect_register_writes(dut, len(expected))
    finally:
        memory_task.cancel()

    assert writes == expected


@cocotb.test()
async def constrained_random_architectural_scoreboard(dut):
    seed = int(os.environ.get("CORE_RANDOM_SEED", "0xc0c07b"), 0)
    random_program = generate_random_program(seed, instruction_count=200)
    dut._log.info(
        "random seed=0x%x instructions=%d expected_writes=%d",
        seed,
        len(random_program.words) - 1,
        len(random_program.expected_writes),
    )

    memory = NativeMemory(dut, instruction_wait=1, data_wait=2)
    memory.load_words(random_program.words)
    memory_task = cocotb.start_soon(memory.run())
    try:
        await initialize(dut)
        writes = await collect_register_writes(
            dut,
            len(random_program.expected_writes),
            timeout_cycles=20_000,
        )
    finally:
        memory_task.cancel()

    assert writes == random_program.expected_writes, (
        f"architectural mismatch with CORE_RANDOM_SEED=0x{seed:x}"
    )
    for address, expected in random_program.expected_memory.items():
        assert memory.read_word(address) == expected, (
            f"memory mismatch at 0x{address:08x}, seed=0x{seed:x}"
        )


@cocotb.test()
async def machine_csr_ecall_and_mret(dut):
    program = [
        addi(1, 0, 0x101),
        csrw(CSR_MTVEC, 1),
        csrrwi(5, CSR_MSCRATCH, 3),
        csrr(6, CSR_MSCRATCH),
        addi(2, 0, 5),
        ECALL,
        addi(3, 0, 7),
        csrr(7, CSR_MCAUSE),
        csrr(8, CSR_MEPC),
        jal(0, 0),
    ]
    handler = [
        csrr(4, CSR_MEPC),
        addi(4, 4, 4),
        csrw(CSR_MEPC, 4),
        MRET,
    ]
    expected = [
        (0x00, 1, 0x101),
        (0x08, 5, 0),
        (0x0C, 6, 3),
        (0x10, 2, 5),
        (0x100, 4, 0x14),
        (0x104, 4, 0x18),
        (0x18, 3, 7),
        (0x1C, 7, 11),
        (0x20, 8, 0x18),
    ]

    memory = NativeMemory(dut, instruction_wait=1)
    memory.load_words(program)
    memory.load_words(handler, 0x100)
    memory_task = cocotb.start_soon(memory.run())
    try:
        await initialize(dut)
        writes = await collect_register_writes(
            dut,
            len(expected),
            forbidden_commit_pcs={0x14},
        )
    finally:
        memory_task.cancel()

    assert writes == expected


@cocotb.test()
async def machine_external_interrupt_is_precise(dut):
    program = [
        addi(6, 0, 0x100),
        csrw(CSR_MTVEC, 6),
        addi(1, 0, 8),
        slli(1, 1, 8),
        csrw(CSR_MIE, 1),
        csrrsi(0, CSR_MSTATUS, 8),
        addi(2, 0, 1),
        addi(3, 3, 1),
        csrr(9, CSR_MSTATUS),
        addi(7, 0, 7),
        jal(0, 0),
    ]
    handler = [
        csrr(4, CSR_MEPC),
        addi(5, 0, 9),
        csrr(8, CSR_MCAUSE),
        MRET,
    ]
    expected = [
        (0x00, 6, 0x100),
        (0x08, 1, 8),
        (0x0C, 1, 0x800),
        (0x100, 4, 0x18),
        (0x104, 5, 9),
        (0x108, 8, 0x8000_000B),
        (0x18, 2, 1),
        (0x1C, 3, 1),
        (0x20, 9, 0x1888),
        (0x24, 7, 7),
    ]

    memory = NativeMemory(dut)
    memory.load_words(program)
    memory.load_words(handler, 0x100)
    memory_task = cocotb.start_soon(memory.run())
    writes = []
    irq_cleared = False
    try:
        await initialize(dut)
        dut.i_irq_external.value = 1

        for _ in range(500):
            await RisingEdge(dut.i_clk)
            if int(dut.o_commit_valid.value) and int(dut.o_commit_rd_write.value):
                writes.append(
                    (
                        int(dut.o_commit_pc.value),
                        int(dut.o_commit_rd_addr.value),
                        int(dut.o_commit_rd_data.value),
                    )
                )

            if not irq_cleared and (
                int(dut.o_imem_valid.value)
                and int(dut.o_imem_addr.value) == 0x100
            ):
                await FallingEdge(dut.i_clk)
                dut.i_irq_external.value = 0
                irq_cleared = True

            if len(writes) == len(expected):
                break
        else:
            raise AssertionError(
                f"timeout: observed {len(writes)}/{len(expected)} register writes"
            )
    finally:
        dut.i_irq_external.value = 0
        memory_task.cancel()

    assert irq_cleared, "external interrupt did not redirect to mtvec"
    assert writes == expected
    assert sum(1 for pc, _, _ in writes if pc == 0x18) == 1


@cocotb.test()
async def wfi_sleep_wake_and_interrupt_entry(dut):
    program = [
        addi(1, 0, 0x100),
        csrw(CSR_MTVEC, 1),
        lui(2, 0x1),
        srli(2, 2, 1),
        csrw(CSR_MIE, 2),
        WFI,
        addi(10, 0, 1),
        csrrsi(0, CSR_MSTATUS, 8),
        WFI,
        addi(12, 0, 1),
        jal(0, 0),
    ]
    handler = [
        addi(11, 11, 1),
        MRET,
    ]

    memory = NativeMemory(dut)
    memory.load_words(program)
    memory.load_words(handler, 0x100)
    memory_task = cocotb.start_soon(memory.run())
    writes = []
    wfi_commits = 0
    sleep_count = 0
    try:
        await initialize(dut)

        for _ in range(600):
            await RisingEdge(dut.i_clk)
            if int(dut.o_commit_valid.value):
                if int(dut.o_commit_instruction.value) == WFI:
                    wfi_commits += 1
                if int(dut.o_commit_rd_write.value):
                    writes.append(
                        (
                            int(dut.o_commit_pc.value),
                            int(dut.o_commit_rd_addr.value),
                            int(dut.o_commit_rd_data.value),
                        )
                    )

            if int(dut.o_core_sleep.value):
                assert not int(dut.o_imem_valid.value), (
                    "instruction request remained active while sleeping"
                )
                if not int(dut.i_irq_external.value):
                    sleep_count += 1
                    await FallingEdge(dut.i_clk)
                    dut.i_irq_external.value = 1

            if int(dut.i_irq_external.value):
                if sleep_count == 1 and not int(dut.o_core_sleep.value):
                    await FallingEdge(dut.i_clk)
                    dut.i_irq_external.value = 0
                elif (
                    sleep_count == 2
                    and int(dut.o_imem_valid.value)
                    and int(dut.o_imem_addr.value) == 0x100
                ):
                    await FallingEdge(dut.i_clk)
                    dut.i_irq_external.value = 0

            if any(rd == 12 and data == 1 for _, rd, data in writes):
                break
        else:
            raise AssertionError("timeout waiting for both WFI wake-up paths")
    finally:
        dut.i_irq_external.value = 0
        memory_task.cancel()

    expected = [
        (0x00, 1, 0x100),
        (0x08, 2, 0x1000),
        (0x0C, 2, 0x800),
        (0x18, 10, 1),
        (0x100, 11, 1),
        (0x24, 12, 1),
    ]
    assert writes == expected
    assert sleep_count == 2
    assert wfi_commits == 2


@cocotb.test()
async def instruction_load_and_store_access_faults_are_precise(dut):
    program = [
        addi(1, 0, 0x100),
        csrw(CSR_MTVEC, 1),
        jal(0, 0x78),
    ]
    fault_region = [
        addi(0, 0, 0),
        addi(10, 0, 1),
        addi(2, 0, 0x200),
        lw(11, 2, 0),
        addi(12, 0, 1),
        sw(10, 2, 4),
        addi(13, 0, 1),
        jal(0, 0),
    ]
    handler = [
        csrr(4, CSR_MCAUSE),
        csrr(5, CSR_MTVAL),
        csrr(6, CSR_MEPC),
        addi(6, 6, 4),
        csrw(CSR_MEPC, 6),
        addi(7, 7, 1),
        MRET,
    ]
    expected = [
        (0x00, 1, 0x100),
        (0x100, 4, 1),
        (0x104, 5, 0x80),
        (0x108, 6, 0x80),
        (0x10C, 6, 0x84),
        (0x114, 7, 1),
        (0x84, 10, 1),
        (0x88, 2, 0x200),
        (0x100, 4, 5),
        (0x104, 5, 0x200),
        (0x108, 6, 0x8C),
        (0x10C, 6, 0x90),
        (0x114, 7, 2),
        (0x90, 12, 1),
        (0x100, 4, 7),
        (0x104, 5, 0x204),
        (0x108, 6, 0x94),
        (0x10C, 6, 0x98),
        (0x114, 7, 3),
        (0x98, 13, 1),
    ]

    memory = NativeMemory(
        dut,
        instruction_error_addresses={0x80},
        data_error_addresses={0x200, 0x204},
    )
    memory.load_words(program)
    memory.load_words(fault_region, 0x80)
    memory.load_words(handler, 0x100)
    memory_task = cocotb.start_soon(memory.run())
    try:
        await initialize(dut)
        writes = await collect_register_writes(
            dut,
            len(expected),
            timeout_cycles=5000,
            forbidden_commit_pcs={0x80, 0x8C, 0x94},
            forbid_committed_store=True,
        )
    finally:
        memory_task.cancel()

    assert writes == expected
    assert memory.store_count == 0


@cocotb.test()
async def synchronous_exception_matrix_and_fence_i(dut):
    ebreak = 0x0010_0073
    fence_i = 0x0000_100F
    lw_misaligned = (1 << 20) | (0b010 << 12) | (2 << 7) | 0x03
    sw_misaligned = (1 << 7) | (0b010 << 12) | 0x23
    csrrc_mscratch = (
        (CSR_MSCRATCH << 20) | (0b011 << 12) | (3 << 7) | 0x73
    )
    program = [
        addi(1, 0, 0x100),
        csrw(CSR_MTVEC, 1),
        0xFFFF_FFFF,
        ebreak,
        lw_misaligned,
        sw_misaligned,
        fence_i,
        csrrci(4, CSR_MSCRATCH, 1),
        csrrc_mscratch,
        jal(0, 0),
    ]
    handler = [
        csrr(10, CSR_MCAUSE),
        csrr(11, CSR_MEPC),
        addi(11, 11, 4),
        csrw(CSR_MEPC, 11),
        MRET,
    ]

    memory = NativeMemory(dut)
    memory.load_words(program)
    memory.load_words(handler, 0x100)
    memory_task = cocotb.start_soon(memory.run())
    causes = []
    committed_pcs = []
    fence_seen = False
    try:
        await initialize(dut)
        for cycle in range(1000):
            await FallingEdge(dut.i_clk)
            dut.i_time.value = (cycle << 32) | (0xFFFF_FFFF - cycle)
            await RisingEdge(dut.i_clk)
            if not int(dut.o_commit_valid.value):
                continue
            pc = int(dut.o_commit_pc.value)
            committed_pcs.append(pc)
            if int(dut.o_commit_instruction.value) == fence_i:
                fence_seen = True
            if (
                int(dut.o_commit_rd_write.value)
                and int(dut.o_commit_rd_addr.value) == 10
            ):
                causes.append(int(dut.o_commit_rd_data.value))
            if (
                int(dut.o_commit_rd_write.value)
                and int(dut.o_commit_rd_addr.value) == 3
            ):
                break
        else:
            raise AssertionError("timeout waiting for synchronous exception matrix")
    finally:
        memory_task.cancel()

    assert causes == [2, 3, 4, 6]
    assert not ({0x08, 0x0C, 0x10, 0x14} & set(committed_pcs))
    assert fence_seen


@cocotb.test()
async def software_and_timer_interrupt_priority(dut):
    program = [
        addi(1, 0, 0x100),
        csrw(CSR_MTVEC, 1),
        addi(2, 0, 0x88),
        csrw(CSR_MIE, 2),
        csrrsi(0, CSR_MSTATUS, 8),
        addi(3, 3, 1),
        jal(0, -4),
    ]
    handler = [
        csrr(12, CSR_MCAUSE),
        MRET,
    ]
    memory = NativeMemory(dut)
    memory.load_words(program)
    memory.load_words(handler, 0x100)
    memory_task = cocotb.start_soon(memory.run())
    causes = []
    phase = 0
    try:
        await initialize(dut)
        for cycle in range(1000):
            await FallingEdge(dut.i_clk)
            dut.i_time.value = (cycle << 32) | cycle
            if phase == 0 and cycle > 20:
                dut.i_irq_software.value = 1
            elif phase == 1:
                dut.i_irq_software.value = 0
                dut.i_irq_timer.value = 1
            await RisingEdge(dut.i_clk)
            if (
                int(dut.o_commit_valid.value)
                and int(dut.o_commit_rd_write.value)
                and int(dut.o_commit_rd_addr.value) == 12
            ):
                causes.append(int(dut.o_commit_rd_data.value))
                if phase == 0:
                    phase = 1
                else:
                    break
        else:
            raise AssertionError("timeout waiting for software/timer interrupts")
    finally:
        dut.i_irq_software.value = 0
        dut.i_irq_timer.value = 0
        memory_task.cancel()

    assert causes == [0x8000_0003, 0x8000_0007]


@cocotb.test()
async def subword_memory_and_complete_branch_matrix(dut):
    def load(rd, rs1, immediate, funct3):
        imm = immediate & 0xFFF
        return (imm << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | 0x03

    def store(rs2, rs1, immediate, funct3):
        imm = immediate & 0xFFF
        return (
            ((imm >> 5) << 25)
            | (rs2 << 20)
            | (rs1 << 15)
            | (funct3 << 12)
            | ((imm & 0x1F) << 7)
            | 0x23
        )

    program = [
        addi(1, 0, -1),
        addi(2, 0, 0),
        add(3, 1, 1),
        addi(4, 0, 0x400),
        store(2, 4, 8, 0b000),
        store(2, 4, 9, 0b000),
        store(2, 4, 10, 0b000),
        store(2, 4, 11, 0b000),
        store(2, 4, 8, 0b001),
        store(2, 4, 10, 0b001),
        store(1, 4, 0, 0b000),
        store(1, 4, 1, 0b000),
        store(1, 4, 2, 0b000),
        store(1, 4, 3, 0b000),
        store(1, 4, 0, 0b001),
        store(1, 4, 2, 0b001),
        load(5, 4, 0, 0b000),
        load(6, 4, 1, 0b000),
        load(7, 4, 2, 0b000),
        load(8, 4, 3, 0b000),
        load(9, 4, 0, 0b100),
        load(10, 4, 1, 0b100),
        load(11, 4, 2, 0b100),
        load(12, 4, 3, 0b100),
        load(13, 4, 0, 0b001),
        load(14, 4, 2, 0b001),
        load(15, 4, 0, 0b101),
        load(16, 4, 2, 0b101),
        load(17, 4, 4, 0b000),
        load(18, 4, 5, 0b000),
        load(19, 4, 6, 0b000),
        load(20, 4, 7, 0b000),
        load(21, 4, 4, 0b100),
        load(22, 4, 5, 0b100),
        load(23, 4, 6, 0b100),
        load(24, 4, 7, 0b100),
        load(25, 4, 4, 0b001),
        load(26, 4, 6, 0b001),
        load(27, 4, 4, 0b101),
        load(28, 4, 6, 0b101),
        addi(29, 0, 0),
        beq(0, 0, 8),
        addi(29, 29, 1),
        beq(0, 1, 8),
        addi(29, 29, 1),
        bne(0, 1, 8),
        addi(29, 29, 1),
        bne(0, 0, 8),
        addi(29, 29, 1),
        blt(1, 0, 8),
        addi(29, 29, 1),
        blt(0, 1, 8),
        addi(29, 29, 1),
        bge(0, 1, 8),
        addi(29, 29, 1),
        bge(1, 0, 8),
        addi(29, 29, 1),
        bltu(0, 1, 8),
        addi(29, 29, 1),
        bltu(1, 0, 8),
        addi(29, 29, 1),
        bgeu(1, 0, 8),
        addi(29, 29, 1),
        bgeu(0, 1, 8),
        addi(29, 29, 1),
        addi(30, 29, 0),
        jal(0, 0),
    ]
    memory = NativeMemory(dut)
    memory.load_words(program)
    memory.load_words([0x80FF_7F01], 0x404)
    memory_task = cocotb.start_soon(memory.run())
    try:
        await initialize(dut)
        commits = await collect_commits(
            dut,
            len(program) - 7,
            timeout_cycles=1000,
        )
    finally:
        memory_task.cancel()

    assert memory.read_word(0x400) == 0xFFFF_FFFF
    assert commits[-1][2:] == (30, 6)
