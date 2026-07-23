"""Deterministic constrained-random programs with an RV32 architectural model."""

import random
from dataclasses import dataclass
from typing import Dict, List, Tuple

from riscv import (
    add,
    addi,
    and_,
    andi,
    div,
    divu,
    jal,
    lui,
    lw,
    mul,
    mulh,
    mulhsu,
    mulhu,
    or_,
    ori,
    rem,
    remu,
    sll,
    slli,
    slt,
    slti,
    sltiu,
    sltu,
    sra,
    srai,
    srl,
    srli,
    sub,
    sw,
    u32,
    xor,
    xori,
)


RegisterWrite = Tuple[int, int, int]


def s32(value: int) -> int:
    value = u32(value)
    return value if value < 0x8000_0000 else value - 0x1_0000_0000


def signed_quotient(dividend: int, divisor: int) -> int:
    magnitude = abs(dividend) // abs(divisor)
    return -magnitude if (dividend < 0) != (divisor < 0) else magnitude


@dataclass
class RandomProgram:
    words: List[int]
    expected_writes: List[RegisterWrite]
    expected_memory: Dict[int, int]


class _Builder:
    def __init__(self) -> None:
        self.words: List[int] = []
        self.expected_writes: List[RegisterWrite] = []
        self.registers = [0] * 32
        self.memory: Dict[int, int] = {}

    @property
    def pc(self) -> int:
        return 4 * len(self.words)

    def write(self, instruction: int, rd: int, value: int) -> None:
        value = u32(value)
        self.words.append(instruction)
        if rd != 0:
            self.registers[rd] = value
            self.expected_writes.append((self.pc - 4, rd, value))
        self.registers[0] = 0

    def store(self, instruction: int, address: int, value: int) -> None:
        self.words.append(instruction)
        self.memory[address] = u32(value)


def generate_random_program(seed: int, instruction_count: int = 200) -> RandomProgram:
    """Generate a safe straight-line program and its architectural outcome."""

    rng = random.Random(seed)
    builder = _Builder()

    # x31 is reserved as the data-memory base. Seed several registers across
    # the full 32-bit space so the scoreboard stresses every datapath bit, not
    # only the sign extension of small immediates.
    builder.write(addi(31, 0, 0x400), 31, 0x400)
    for rd in range(1, 13):
        value = rng.getrandbits(32)
        upper = ((value + 0x800) >> 12) & 0xFFFFF
        lower = value & 0xFFF
        if lower >= 0x800:
            lower -= 0x1000
        builder.write(lui(rd, upper), rd, upper << 12)
        builder.write(addi(rd, rd, lower), rd, value)

    recent = list(range(1, 13))

    def source_register() -> int:
        if rng.random() < 0.7:
            return rng.choice(recent[-8:])
        return rng.randrange(0, 31)

    def destination_register() -> int:
        rd = rng.randrange(1, 31)
        recent.append(rd)
        return rd

    alu_ops = ("add", "sub", "sll", "slt", "sltu", "xor", "srl", "sra", "or", "and")
    imm_ops = ("addi", "slti", "sltiu", "xori", "ori", "andi", "slli", "srli", "srai")
    m_ops = ("mul", "mulh", "mulhsu", "mulhu", "div", "divu", "rem", "remu")

    for _ in range(instruction_count):
        operation_class = rng.choices(
            ("alu", "immediate", "m", "load", "store"),
            weights=(30, 25, 20, 13, 12),
            k=1,
        )[0]

        if operation_class == "alu":
            op = rng.choice(alu_ops)
            rd, rs1, rs2 = destination_register(), source_register(), source_register()
            a, b = builder.registers[rs1], builder.registers[rs2]
            shift = b & 0x1F
            instruction_and_value = {
                "add": (add(rd, rs1, rs2), a + b),
                "sub": (sub(rd, rs1, rs2), a - b),
                "sll": (sll(rd, rs1, rs2), a << shift),
                "slt": (slt(rd, rs1, rs2), int(s32(a) < s32(b))),
                "sltu": (sltu(rd, rs1, rs2), int(a < b)),
                "xor": (xor(rd, rs1, rs2), a ^ b),
                "srl": (srl(rd, rs1, rs2), a >> shift),
                "sra": (sra(rd, rs1, rs2), s32(a) >> shift),
                "or": (or_(rd, rs1, rs2), a | b),
                "and": (and_(rd, rs1, rs2), a & b),
            }[op]
            builder.write(instruction_and_value[0], rd, instruction_and_value[1])

        elif operation_class == "immediate":
            op = rng.choice(imm_ops)
            rd, rs1 = destination_register(), source_register()
            a = builder.registers[rs1]
            if op in ("slli", "srli", "srai"):
                immediate = rng.randrange(32)
            else:
                immediate = rng.randint(-2048, 2047)
            if op == "addi":
                instruction, value = addi(rd, rs1, immediate), a + immediate
            elif op == "slti":
                instruction, value = slti(rd, rs1, immediate), int(
                    s32(a) < immediate
                )
            elif op == "sltiu":
                instruction, value = sltiu(rd, rs1, immediate), int(
                    a < u32(immediate)
                )
            elif op == "xori":
                instruction, value = xori(rd, rs1, immediate), a ^ u32(immediate)
            elif op == "ori":
                instruction, value = ori(rd, rs1, immediate), a | u32(immediate)
            elif op == "andi":
                instruction, value = andi(rd, rs1, immediate), a & u32(immediate)
            elif op == "slli":
                instruction, value = slli(rd, rs1, immediate), a << immediate
            elif op == "srli":
                instruction, value = srli(rd, rs1, immediate), a >> immediate
            else:
                instruction, value = srai(rd, rs1, immediate), s32(a) >> immediate
            builder.write(instruction, rd, value)

        elif operation_class == "m":
            op = rng.choice(m_ops)
            rd, rs1, rs2 = destination_register(), source_register(), source_register()
            a, b = builder.registers[rs1], builder.registers[rs2]
            sa, sb = s32(a), s32(b)

            if op == "mul":
                instruction, value = mul(rd, rs1, rs2), a * b
            elif op == "mulh":
                instruction, value = mulh(rd, rs1, rs2), (sa * sb) >> 32
            elif op == "mulhsu":
                instruction, value = mulhsu(rd, rs1, rs2), (sa * b) >> 32
            elif op == "mulhu":
                instruction, value = mulhu(rd, rs1, rs2), (a * b) >> 32
            elif op in ("div", "rem"):
                if b == 0:
                    quotient, remainder = -1, sa
                elif sa == -0x8000_0000 and sb == -1:
                    quotient, remainder = sa, 0
                else:
                    quotient = signed_quotient(sa, sb)
                    remainder = sa - quotient * sb
                instruction = div(rd, rs1, rs2) if op == "div" else rem(rd, rs1, rs2)
                value = quotient if op == "div" else remainder
            else:
                quotient = 0xFFFF_FFFF if b == 0 else a // b
                remainder = a if b == 0 else a % b
                instruction = (
                    divu(rd, rs1, rs2) if op == "divu" else remu(rd, rs1, rs2)
                )
                value = quotient if op == "divu" else remainder
            builder.write(instruction, rd, value)

        elif operation_class == "load":
            rd = destination_register()
            offset = 4 * rng.randrange(32)
            value = builder.memory.get(0x400 + offset, 0)
            builder.write(lw(rd, 31, offset), rd, value)

        else:
            rs2 = source_register()
            offset = 4 * rng.randrange(32)
            builder.store(sw(rs2, 31, offset), 0x400 + offset, builder.registers[rs2])

    # A final architectural write is the completion marker. Observing it on
    # the commit interface proves every preceding store has retired before the
    # test compares memory contents.
    builder.write(addi(30, 0, 0x55A), 30, 0x55A)
    builder.words.append(jal(0, 0))
    return RandomProgram(
        words=builder.words,
        expected_writes=builder.expected_writes,
        expected_memory=builder.memory,
    )
