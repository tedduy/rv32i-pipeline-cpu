"""Full-width reference checks for JAL, JALR and sequential targets."""

import random

import cocotb
from cocotb.triggers import Timer


@cocotb.test()
async def all_modes_and_full_width_operands(dut):
    rng = random.Random(0x4A554D50)
    for compressed in (0, 1):
        for mode in ("sequential", "jal", "jalr"):
            for _ in range(64):
                pc = rng.getrandbits(32)
                rs1 = rng.getrandbits(32)
                immediate = rng.getrandbits(32)
                relative = rng.getrandbits(32)
                dut.i_pc.value = pc
                dut.i_rs1_data.value = rs1
                dut.i_immediate.value = immediate
                dut.i_pc_relative_target.value = relative
                dut.i_compressed.value = compressed
                dut.i_jal.value = int(mode == "jal")
                dut.i_jalr.value = int(mode == "jalr")
                await Timer(1, unit="ns")

                expected_return = (pc + (2 if compressed else 4)) & 0xFFFF_FFFF
                if mode == "jal":
                    expected_target = relative
                elif mode == "jalr":
                    expected_target = (rs1 + immediate) & 0xFFFF_FFFE
                else:
                    expected_target = (pc + 4) & 0xFFFF_FFFF
                assert int(dut.o_return_addr.value) == expected_return
                assert int(dut.o_jump_target.value) == expected_target
