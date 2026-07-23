"""Exhaustive operation/offset test for load/store lane steering."""

import cocotb
from cocotb.triggers import Timer


def sign_extend(value, bits):
    sign = 1 << (bits - 1)
    return ((value ^ sign) - sign) & 0xFFFF_FFFF


@cocotb.test()
async def all_load_store_types_and_offsets(dut):
    for read_data, store_data in (
        (0, 0),
        (0xFFFF_FFFF, 0xFFFF_FFFF),
        (0x80FF_7F01, 0xA5C3_81E7),
        (0x7F00_80FE, 0x5A3C_7E18),
    ):
        dut.i_mem_read_data.value = read_data
        dut.i_store_data.value = store_data
        for mem_read in (0, 1):
            for mem_write in (0, 1):
                for mem_type in range(8):
                    for offset in range(4):
                        dut.i_mem_read.value = mem_read
                        dut.i_mem_write.value = mem_write
                        dut.i_mem_type.value = mem_type
                        dut.i_byte_offset.value = offset
                        await Timer(1, unit="ns")

                        if not mem_read or mem_type not in (0, 1, 2, 4, 5):
                            expected_load = 0
                        elif mem_type in (0, 4):
                            byte = (read_data >> (8 * offset)) & 0xFF
                            expected_load = byte if mem_type == 4 else sign_extend(byte, 8)
                        elif mem_type in (1, 5):
                            half = (read_data >> (16 * (offset >> 1))) & 0xFFFF
                            expected_load = half if mem_type == 5 else sign_extend(half, 16)
                        else:
                            expected_load = read_data
                        assert int(dut.o_load_data.value) == expected_load

                        if not mem_write or mem_type not in (0, 1, 2):
                            expected_data, expected_strobe = 0, 0
                        elif mem_type == 0:
                            expected_data = (store_data & 0xFF) << (8 * offset)
                            expected_strobe = 1 << offset
                        elif mem_type == 1:
                            expected_data = (store_data & 0xFFFF) << (16 * (offset >> 1))
                            expected_strobe = 0x3 << (2 * (offset >> 1))
                        else:
                            expected_data, expected_strobe = store_data, 0xF
                        assert int(dut.o_store_data.value) == expected_data
                        assert int(dut.o_byte_enable.value) == expected_strobe
