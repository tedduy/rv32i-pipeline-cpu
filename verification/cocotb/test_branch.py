"""Decision-table test for every RV32I branch relation."""

import cocotb
from cocotb.triggers import Timer


@cocotb.test()
async def all_branch_types_taken_and_not_taken(dut):
    vectors = [
        (0b000, 5, 5, True), (0b000, 5, 6, False),
        (0b001, 5, 6, True), (0b001, 5, 5, False),
        (0b100, 0xFFFF_FFFF, 1, True), (0b100, 1, 0xFFFF_FFFF, False),
        (0b101, 1, 0xFFFF_FFFF, True), (0b101, 0xFFFF_FFFF, 1, False),
        (0b110, 1, 2, True), (0b110, 2, 1, False),
        (0b111, 2, 1, True), (0b111, 1, 2, False),
        (0b010, 0, 0, False),
    ]
    for enabled in (0, 1):
        for branch_type, lhs, rhs, condition in vectors:
            dut.i_branch_en.value = enabled
            dut.i_branch_type.value = branch_type
            dut.i_rs1_data.value = lhs
            dut.i_rs2_data.value = rhs
            await Timer(1, unit="ns")
            assert int(dut.o_branch_taken.value) == bool(enabled and condition)
