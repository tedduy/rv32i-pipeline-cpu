import cocotb
from cocotb.triggers import Timer


@cocotb.test()
async def sleep_requires_core_request_and_idle_buses(dut):
    for core_sleep in range(2):
        for instruction_busy in range(2):
            for data_busy in range(2):
                dut.i_core_sleep.value = core_sleep
                dut.i_instruction_busy.value = instruction_busy
                dut.i_data_busy.value = data_busy
                await Timer(1, unit="ps")

                expected = core_sleep and not instruction_busy and not data_busy
                assert int(dut.o_core_sleep.value) == expected
