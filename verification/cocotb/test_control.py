"""Decode legality and control-output coverage over all opcode families."""

import cocotb
from cocotb.triggers import Timer


@cocotb.test()
async def decode_all_opcode_funct_combinations(dut):
    special = [0x0000_0073, 0x0010_0073, 0x3020_0073, 0x1050_0073]
    for instruction in special:
        dut.i_instruction.value = instruction
        await Timer(1, unit="ns")
        assert not int(dut.o_illegal.value)

    for opcode in range(128):
        for funct3 in range(8):
            for funct7 in (0, 1, 0x20, 0x7F):
                dut.i_instruction.value = (
                    (funct7 << 25) | (funct3 << 12) | opcode
                )
                await Timer(1, unit="ns")
                for name in (
                    "o_reg_write", "o_mem_read", "o_mem_write", "o_jal",
                    "o_jalr", "o_csr_en", "o_ecall", "o_ebreak", "o_mret",
                    "o_wfi", "o_fence_i", "o_illegal",
                ):
                    int(getattr(dut, name).value)
