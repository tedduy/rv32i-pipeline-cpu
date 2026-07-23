"""Functional coverage sampled from architectural commit and native bus events."""

from __future__ import annotations

from collections import Counter
import json
import os
from pathlib import Path

from cocotb.triggers import RisingEdge


RV32I = {
    "lui", "auipc", "jal", "jalr",
    "beq", "bne", "blt", "bge", "bltu", "bgeu",
    "lb", "lh", "lw", "lbu", "lhu", "sb", "sh", "sw",
    "addi", "slti", "sltiu", "xori", "ori", "andi", "slli", "srli", "srai",
    "add", "sub", "sll", "slt", "sltu", "xor", "srl", "sra", "or", "and",
}
RV32M = {"mul", "mulh", "mulhsu", "mulhu", "div", "divu", "rem", "remu"}
CSR = {"csrrw", "csrrs", "csrrc", "csrrwi", "csrrsi", "csrrci"}
# ECALL/EBREAK trap before retirement, so their architectural evidence is the
# corresponding trap-cause bin rather than an impossible commit bin.
SYSTEM = {"mret", "wfi", "fence.i"}
BRANCHES = {"beq", "bne", "blt", "bge", "bltu", "bgeu"}

REQUIRED_BINS = (
    {f"instruction.{name}" for name in RV32I | RV32M | CSR | SYSTEM}
    | {f"branch.{name}.{outcome}" for name in BRANCHES for outcome in ("taken", "not_taken")}
    | {
        "bus.ifetch.wait_0", "bus.ifetch.wait_1", "bus.ifetch.wait_2plus",
        "bus.load.wait_0", "bus.load.wait_2plus",
        "bus.store.wait_0", "bus.store.wait_2plus",
        "bus.ifetch.error", "bus.load.error", "bus.store.error",
        "memory.load.byte.lane_0", "memory.load.byte.lane_1",
        "memory.load.byte.lane_2", "memory.load.byte.lane_3",
        "memory.load.half.lane_0", "memory.load.half.lane_2",
        "memory.load.word.lane_0",
        "memory.store.byte.lane_0", "memory.store.byte.lane_1",
        "memory.store.byte.lane_2", "memory.store.byte.lane_3",
        "memory.store.half.lane_0", "memory.store.half.lane_2",
        "memory.store.word.lane_0",
        "trap.exception.1", "trap.exception.2", "trap.exception.3",
        "trap.exception.4", "trap.exception.5", "trap.exception.6",
        "trap.exception.7", "trap.exception.11",
        "trap.interrupt.3", "trap.interrupt.7", "trap.interrupt.11",
    }
)

_counts: Counter[str] = Counter()
_report_path: Path | None = None


def _write_report() -> None:
    if _report_path is None:
        return
    _report_path.parent.mkdir(parents=True, exist_ok=True)
    _report_path.write_text(
        json.dumps(
            {
                "required_bins": sorted(REQUIRED_BINS),
                "counts": dict(sorted(_counts.items())),
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )


def hit(name: str) -> None:
    if name not in _counts:
        _counts[name] = 1
        _write_report()
    else:
        _counts[name] += 1


def decode_instruction(instruction: int) -> str | None:
    if instruction & 0x3 != 0x3:
        return None
    opcode = instruction & 0x7F
    funct3 = (instruction >> 12) & 0x7
    funct7 = (instruction >> 25) & 0x7F
    if opcode == 0x37:
        return "lui"
    if opcode == 0x17:
        return "auipc"
    if opcode == 0x6F:
        return "jal"
    if opcode == 0x67:
        return "jalr"
    if opcode == 0x63:
        return {0: "beq", 1: "bne", 4: "blt", 5: "bge", 6: "bltu", 7: "bgeu"}.get(funct3)
    if opcode == 0x03:
        return {0: "lb", 1: "lh", 2: "lw", 4: "lbu", 5: "lhu"}.get(funct3)
    if opcode == 0x23:
        return {0: "sb", 1: "sh", 2: "sw"}.get(funct3)
    if opcode == 0x13:
        if funct3 == 1:
            return "slli"
        if funct3 == 5:
            return "srai" if instruction & (1 << 30) else "srli"
        return {0: "addi", 2: "slti", 3: "sltiu", 4: "xori", 6: "ori", 7: "andi"}.get(funct3)
    if opcode == 0x33:
        if funct7 == 1:
            return ("mul", "mulh", "mulhsu", "mulhu", "div", "divu", "rem", "remu")[funct3]
        if funct3 == 0:
            return "sub" if instruction & (1 << 30) else "add"
        if funct3 == 5:
            return "sra" if instruction & (1 << 30) else "srl"
        return {1: "sll", 2: "slt", 3: "sltu", 4: "xor", 6: "or", 7: "and"}.get(funct3)
    if opcode == 0x0F and funct3 == 1:
        return "fence.i"
    if opcode == 0x73:
        if instruction == 0x00000073:
            return "ecall"
        if instruction == 0x00100073:
            return "ebreak"
        if instruction == 0x30200073:
            return "mret"
        if instruction == 0x10500073:
            return "wfi"
        return {1: "csrrw", 2: "csrrs", 3: "csrrc", 5: "csrrwi", 6: "csrrsi", 7: "csrrci"}.get(funct3)
    return None


def _wait_bin(wait_cycles: int) -> str:
    return "wait_0" if wait_cycles == 0 else "wait_1" if wait_cycles == 1 else "wait_2plus"


async def monitor(dut) -> None:
    global _report_path
    configured = os.environ.get("FUNCTIONAL_COVERAGE_FILE")
    if not configured:
        return
    _report_path = Path(configured)
    pending_branch: tuple[int, int, str] | None = None
    waits = {"ifetch": 0, "data": 0}

    while True:
        await RisingEdge(dut.i_clk)
        if not int(dut.i_arst_n.value):
            pending_branch = None
            waits = {"ifetch": 0, "data": 0}
            continue

        imem_valid = int(dut.o_imem_valid.value)
        imem_ready = int(dut.i_imem_ready.value)
        if imem_valid and not imem_ready:
            waits["ifetch"] += 1
        elif imem_valid and imem_ready:
            hit(f"bus.ifetch.{_wait_bin(waits['ifetch'])}")
            if int(dut.i_imem_error.value):
                hit("bus.ifetch.error")
            waits["ifetch"] = 0

        dmem_valid = int(dut.o_dmem_valid.value)
        dmem_ready = int(dut.i_dmem_ready.value)
        if dmem_valid and not dmem_ready:
            waits["data"] += 1
        elif dmem_valid and dmem_ready:
            operation = "store" if int(dut.o_dmem_write.value) else "load"
            hit(f"bus.{operation}.{_wait_bin(waits['data'])}")
            if int(dut.i_dmem_error.value):
                hit(f"bus.{operation}.error")
            size = int(dut.o_dmem_size.value)
            lane = int(dut.o_dmem_addr.value) & 0x3
            width = ("byte", "half", "word")[size]
            hit(f"memory.{operation}.{width}.lane_{lane}")
            waits["data"] = 0

        if not int(dut.o_commit_valid.value):
            continue
        pc = int(dut.o_commit_pc.value)
        instruction = int(dut.o_commit_instruction.value)
        name = decode_instruction(instruction)

        if pending_branch is not None:
            branch_pc, length, branch_name = pending_branch
            outcome = "not_taken" if pc == branch_pc + length else "taken"
            hit(f"branch.{branch_name}.{outcome}")
            pending_branch = None

        if name is not None:
            hit(f"instruction.{name}")
            if name in BRANCHES:
                pending_branch = (pc, 4, name)

        if (
            name in CSR
            and ((instruction >> 20) & 0xFFF) == 0x342
            and int(dut.o_commit_rd_write.value)
        ):
            cause = int(dut.o_commit_rd_data.value)
            category = "interrupt" if cause >> 31 else "exception"
            hit(f"trap.{category}.{cause & 0x7FFF_FFFF}")


def check_report(path: Path) -> int:
    data = json.loads(path.read_text(encoding="utf-8"))
    required = set(data["required_bins"])
    counts = data["counts"]
    missing = sorted(name for name in required if not counts.get(name, 0))
    hit_count = len(required) - len(missing)
    percent = 100.0 * hit_count / len(required)
    print(f"Functional coverage: {hit_count}/{len(required)} bins ({percent:.2f}%)")
    if missing:
        print("Missing mandatory functional bins:")
        for name in missing:
            print(f"  {name}")
        return 1
    print("Functional coverage gate: PASS (100.00%)")
    return 0


if __name__ == "__main__":
    import sys

    raise SystemExit(check_report(Path(sys.argv[1])))
