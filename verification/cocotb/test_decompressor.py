"""Exhaustive, self-checking RV32C/Zca decompressor verification."""

import json
import os
from pathlib import Path

import cocotb
from cocotb.triggers import Timer

from rv32c_oracle import decompress_rv32c


LEGAL_BINS = {
    "c.addi4spn",
    "c.lw",
    "c.sw",
    "c.nop",
    "c.addi",
    "c.jal",
    "c.li",
    "c.addi16sp",
    "hint.c.lui.rd0",
    "c.lui",
    "c.srli",
    "c.srai",
    "c.andi",
    "c.sub",
    "c.xor",
    "c.or",
    "c.and",
    "c.j",
    "c.beqz",
    "c.bnez",
    "c.slli",
    "c.lwsp",
    "c.jr",
    "c.mv",
    "c.ebreak",
    "c.jalr",
    "c.add",
    "c.swsp",
}

ILLEGAL_BINS = {
    "reserved.c.addi4spn.zero",
    "reserved.q0.funct3_001",
    "reserved.q0.funct3_011",
    "reserved.q0.funct3_100",
    "reserved.q0.funct3_101",
    "reserved.q0.funct3_111",
    "reserved.c.addi16sp.zero",
    "reserved.c.lui.zero",
    "reserved.c.srli.shamt5",
    "reserved.c.srai.shamt5",
    "reserved.ca.rv32.subw_addw",
    "reserved.c.slli.shamt5",
    "reserved.c.lwsp.rd0",
    "reserved.c.jr.rd0",
    "reserved.q2.funct3_001",
    "reserved.q2.funct3_011",
    "reserved.q2.funct3_101",
    "reserved.q2.funct3_111",
    "not_compressed.q3",
}


@cocotb.test()
async def exhaustive_compressed_encoding_space(dut):
    """Compare every possible input against an independent architectural model."""

    bin_counts = {}
    legal_observations = set()
    illegal_observations = set()
    representative = {}

    for parcel in range(1 << 16):
        expected = decompress_rv32c(parcel)
        bin_counts[expected.coverage_bin] = bin_counts.get(expected.coverage_bin, 0) + 1
        (illegal_observations if expected.illegal else legal_observations).add(
            expected.coverage_bin
        )
        representative.setdefault(expected.coverage_bin, parcel)

        dut.i_instruction.value = parcel
        await Timer(1, unit="ns")

        actual_instruction = int(dut.o_instruction.value)
        actual_illegal = bool(int(dut.o_illegal.value))
        assert actual_illegal == expected.illegal, (
            f"parcel 0x{parcel:04x} ({expected.coverage_bin}): "
            f"illegal={actual_illegal}, expected {expected.illegal}"
        )
        assert actual_instruction == expected.instruction, (
            f"parcel 0x{parcel:04x} ({expected.coverage_bin}): "
            f"instruction=0x{actual_instruction:08x}, "
            f"expected 0x{expected.instruction:08x}"
        )

    assert legal_observations == LEGAL_BINS, (
        f"legal coverage mismatch: missing={sorted(LEGAL_BINS - legal_observations)}, "
        f"unexpected={sorted(legal_observations - LEGAL_BINS)}"
    )
    assert illegal_observations == ILLEGAL_BINS, (
        f"illegal coverage mismatch: missing={sorted(ILLEGAL_BINS - illegal_observations)}, "
        f"unexpected={sorted(illegal_observations - ILLEGAL_BINS)}"
    )

    report_path = os.environ.get("RV32C_FUNCTIONAL_COVERAGE_FILE")
    if report_path:
        path = Path(report_path)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            json.dumps(
                {
                    "required_bins": sorted(LEGAL_BINS | ILLEGAL_BINS),
                    "counts": dict(sorted(bin_counts.items())),
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )

    dut._log.info(
        "RV32C exhaustive coverage: %d encodings, %d legal bins, "
        "%d illegal/reserved bins",
        sum(bin_counts.values()),
        len(legal_observations),
        len(illegal_observations),
    )
    dut._log.debug("Representative encodings: %s", representative)
