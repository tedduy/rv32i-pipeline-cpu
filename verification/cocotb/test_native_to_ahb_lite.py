"""Protocol tests for the native-to-AHB-Lite bridge."""

import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer


async def initialize(dut):
    dut.i_arst_n.value = 0
    dut.i_native_valid.value = 0
    dut.i_native_write.value = 0
    dut.i_native_addr.value = 0
    dut.i_native_wdata.value = 0
    dut.i_native_size.value = 0
    dut.i_hrdata.value = 0
    dut.i_hready.value = 0
    dut.i_hresp.value = 0
    cocotb.start_soon(Clock(dut.i_clk, 10, unit="ns").start())

    for _ in range(3):
        await RisingEdge(dut.i_clk)
    await FallingEdge(dut.i_clk)
    dut.i_arst_n.value = 1


async def accept_address(dut, *, address, write, write_data, size, waits):
    await FallingEdge(dut.i_clk)
    dut.i_native_valid.value = 1
    dut.i_native_write.value = write
    dut.i_native_addr.value = address
    dut.i_native_wdata.value = write_data
    dut.i_native_size.value = size
    dut.i_hready.value = 0
    await Timer(1, unit="ps")

    for _ in range(waits):
        assert int(dut.o_htrans.value) == 0b10
        assert int(dut.o_haddr.value) == address
        assert int(dut.o_hwrite.value) == write
        assert int(dut.o_hsize.value) == size
        assert not int(dut.o_busy.value)
        assert not int(dut.o_native_ready.value)
        await RisingEdge(dut.i_clk)
        await FallingEdge(dut.i_clk)

    dut.i_hready.value = 1
    await Timer(1, unit="ps")
    assert int(dut.o_htrans.value) == 0b10
    await RisingEdge(dut.i_clk)


async def complete_response(dut, *, read_data, error, waits):
    await FallingEdge(dut.i_clk)
    dut.i_hready.value = 0
    dut.i_hrdata.value = read_data
    dut.i_hresp.value = error
    await Timer(1, unit="ps")

    for _ in range(waits):
        assert int(dut.o_htrans.value) == 0
        assert int(dut.o_busy.value)
        assert not int(dut.o_native_ready.value)
        await RisingEdge(dut.i_clk)
        await FallingEdge(dut.i_clk)

    dut.i_hready.value = 1
    await Timer(1, unit="ps")
    assert int(dut.o_native_ready.value)
    assert int(dut.o_native_error.value) == error
    assert int(dut.o_native_rdata.value) == read_data
    await RisingEdge(dut.i_clk)
    await FallingEdge(dut.i_clk)
    dut.i_native_valid.value = 0
    dut.i_hready.value = 0
    dut.i_hresp.value = 0


@cocotb.test()
async def read_write_wait_states_and_error_response(dut):
    await initialize(dut)

    assert int(dut.o_hburst.value) == 0
    assert int(dut.o_hprot.value) == 0b0011
    assert int(dut.o_hmastlock.value) == 0
    assert int(dut.o_htrans.value) == 0
    assert not int(dut.o_busy.value)

    await accept_address(
        dut,
        address=0x1234_5678,
        write=0,
        write_data=0,
        size=2,
        waits=3,
    )
    await complete_response(
        dut,
        read_data=0xDEAD_BEEF,
        error=0,
        waits=2,
    )

    write_data = 0xA5C3_7E19
    await accept_address(
        dut,
        address=0x0000_0102,
        write=1,
        write_data=write_data,
        size=1,
        waits=1,
    )

    # Native payload may change after address acceptance; AHB write data must
    # remain the value captured with the accepted request.
    await FallingEdge(dut.i_clk)
    dut.i_native_addr.value = 0xFFFF_FFFC
    dut.i_native_wdata.value = 0x1111_2222
    dut.i_hready.value = 0
    await Timer(1, unit="ps")
    assert int(dut.o_hwdata.value) == write_data
    await RisingEdge(dut.i_clk)

    await complete_response(
        dut,
        read_data=0xCAFE_BABE,
        error=1,
        waits=1,
    )

    # Exercise both transition directions on full-width request and response
    # payloads so the bridge remains part of the production toggle gate.
    patterns = [
        (0xFFFF_FFFC, 1, 0xFFFF_FFFF, 0, 0xFFFF_FFFF),
        (0x0000_0000, 0, 0x0000_0000, 1, 0x0000_0000),
        (0xAAAA_AAA8, 1, 0x5555_5555, 2, 0xAAAA_AAAA),
        (0x5555_5554, 0, 0xAAAA_AAAA, 2, 0x5555_5555),
    ]
    for address, write, data, size, response in patterns:
        await accept_address(
            dut,
            address=address,
            write=write,
            write_data=data,
            size=size,
            waits=0,
        )
        await complete_response(
            dut,
            read_data=response,
            error=0,
            waits=0,
        )

    await FallingEdge(dut.i_clk)
    await Timer(1, unit="ps")
    assert int(dut.o_htrans.value) == 0
    assert not int(dut.o_busy.value)
    assert not int(dut.o_native_ready.value)


@cocotb.test()
async def reset_recovers_from_address_and_data_phases(dut):
    await initialize(dut)

    await FallingEdge(dut.i_clk)
    dut.i_native_valid.value = 1
    dut.i_native_write.value = 1
    dut.i_native_addr.value = 0x1234_5678
    dut.i_native_wdata.value = 0x89AB_CDEF
    dut.i_native_size.value = 2
    dut.i_hready.value = 0
    await Timer(1, unit="ps")
    assert int(dut.o_htrans.value) == 0b10

    dut.i_arst_n.value = 0
    dut.i_native_valid.value = 0
    await RisingEdge(dut.i_clk)
    await FallingEdge(dut.i_clk)
    await Timer(1, unit="ps")
    assert int(dut.o_htrans.value) == 0
    assert not int(dut.o_busy.value)
    assert not int(dut.o_native_ready.value)

    dut.i_arst_n.value = 1
    dut.i_native_valid.value = 1
    dut.i_hready.value = 1
    await RisingEdge(dut.i_clk)
    await FallingEdge(dut.i_clk)
    await Timer(1, unit="ps")
    assert int(dut.o_busy.value)

    dut.i_hready.value = 0
    dut.i_arst_n.value = 0
    dut.i_native_valid.value = 0
    await RisingEdge(dut.i_clk)
    await FallingEdge(dut.i_clk)
    await Timer(1, unit="ps")
    assert not int(dut.o_busy.value)
    assert int(dut.o_htrans.value) == 0

    dut.i_native_valid.value = 0
    dut.i_arst_n.value = 1


@cocotb.test()
async def deterministic_random_backpressure_is_exactly_once(dut):
    await initialize(dut)
    rng = random.Random(0xA4B1_17E)
    completed = []

    for index in range(48):
        address = rng.getrandbits(32) & ~0x3
        write = rng.getrandbits(1)
        write_data = rng.getrandbits(32)
        size = rng.randrange(3)
        address_waits = rng.randrange(5)
        response_waits = rng.randrange(6)
        error = int(index % 11 == 0)
        response_waits = max(response_waits, error)
        response = rng.getrandbits(32)

        await accept_address(
            dut,
            address=address,
            write=write,
            write_data=write_data,
            size=size,
            waits=address_waits,
        )

        # The bridge owns a single outstanding transfer and must keep the
        # accepted payload stable regardless of later native input changes.
        await FallingEdge(dut.i_clk)
        dut.i_native_addr.value = rng.getrandbits(32)
        dut.i_native_wdata.value = rng.getrandbits(32)
        dut.i_hready.value = 0
        await Timer(1, unit="ps")
        assert int(dut.o_haddr.value) == address
        assert int(dut.o_hwdata.value) == write_data
        await RisingEdge(dut.i_clk)

        await complete_response(
            dut,
            read_data=response,
            error=error,
            waits=response_waits,
        )
        completed.append((address, write, write_data, size, error, response))

    assert len(completed) == 48
