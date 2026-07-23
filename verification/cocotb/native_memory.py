"""Reusable native instruction/data memory model for the RV32 core."""

from dataclasses import dataclass
from typing import Callable, Optional, Set

from cocotb.triggers import FallingEdge, RisingEdge


@dataclass(frozen=True)
class DataRequest:
    read: int
    write: int
    address: int
    write_data: int
    write_strobes: int
    size: int


class NativeMemory:
    """Cycle-accurate valid/ready memory with deterministic wait states."""

    def __init__(
        self,
        dut,
        *,
        size: int = 4096,
        instruction_wait: int = 0,
        data_wait: int = 0,
        instruction_error_addresses: Optional[Set[int]] = None,
        data_error_addresses: Optional[Set[int]] = None,
        mmio_write: Optional[Callable[[DataRequest], bool]] = None,
    ) -> None:
        self.dut = dut
        self.data = bytearray(size)
        self.instruction_wait = instruction_wait
        self.data_wait = data_wait
        self.instruction_error_addresses = instruction_error_addresses or set()
        self.data_error_addresses = data_error_addresses or set()
        self.mmio_write = mmio_write

        self.instruction_accepts: list[int] = []
        self.data_accepts: list[DataRequest] = []
        self.store_count = 0

        self._imem_active = False
        self._imem_remaining = 0
        self._imem_request = 0
        self._imem_accepted = False

        self._dmem_active = False
        self._dmem_remaining = 0
        self._dmem_request: DataRequest | None = None
        self._dmem_accepted = False

    def load_words(self, words: list[int], address: int = 0) -> None:
        for index, word in enumerate(words):
            base = address + 4 * index
            self.data[base : base + 4] = int(word).to_bytes(4, "little")

    def load_halfwords(self, halfwords: list[int], address: int = 0) -> None:
        for index, halfword in enumerate(halfwords):
            base = address + 2 * index
            self.data[base : base + 2] = int(halfword).to_bytes(2, "little")

    def load_bytes(self, data: bytes, address: int = 0) -> None:
        end = address + len(data)
        if address < 0 or end > len(self.data):
            raise ValueError(
                f"image range 0x{address:x}..0x{end:x} exceeds "
                f"{len(self.data)}-byte memory"
            )
        self.data[address:end] = data

    def read_word(self, address: int) -> int:
        base = address & ~0x3
        if base < 0 or base + 4 > len(self.data):
            return 0
        return int.from_bytes(self.data[base : base + 4], "little")

    def _sample_data_request(self) -> DataRequest:
        return DataRequest(
            read=int(self.dut.o_dmem_read.value),
            write=int(self.dut.o_dmem_write.value),
            address=int(self.dut.o_dmem_addr.value),
            write_data=int(self.dut.o_dmem_wdata.value),
            write_strobes=int(self.dut.o_dmem_wstrb.value),
            size=int(self.dut.o_dmem_size.value),
        )

    def _write(self, request: DataRequest) -> None:
        if self.mmio_write is not None and self.mmio_write(request):
            self.store_count += 1
            return

        base = request.address & ~0x3
        if base < 0 or base + 4 > len(self.data):
            raise AssertionError(
                f"write to unmapped address 0x{request.address:08x}"
            )
        for lane in range(4):
            if request.write_strobes & (1 << lane):
                self.data[base + lane] = (request.write_data >> (8 * lane)) & 0xFF
        self.store_count += 1

    def _drive_instruction(self) -> None:
        if self._imem_accepted:
            self._imem_active = False
            self._imem_accepted = False
            self.dut.i_imem_ready.value = 0
            self.dut.i_imem_error.value = 0

        if not self._imem_active and int(self.dut.o_imem_valid.value):
            self._imem_active = True
            self._imem_remaining = self.instruction_wait
            self._imem_request = int(self.dut.o_imem_addr.value)

        if self._imem_active:
            assert int(self.dut.o_imem_addr.value) == self._imem_request, (
                "instruction request changed while ready was low"
            )
            self.dut.i_imem_rdata.value = self.read_word(self._imem_request)
            self.dut.i_imem_error.value = int(
                self._imem_request in self.instruction_error_addresses
            )
            if self._imem_remaining == 0:
                self.dut.i_imem_ready.value = 1
            else:
                self._imem_remaining -= 1
                self.dut.i_imem_ready.value = 0

    def _drive_data(self) -> None:
        if self._dmem_accepted:
            self._dmem_active = False
            self._dmem_accepted = False
            self.dut.i_dmem_ready.value = 0
            self.dut.i_dmem_error.value = 0

        if not self._dmem_active and int(self.dut.o_dmem_valid.value):
            self._dmem_active = True
            self._dmem_remaining = self.data_wait
            self._dmem_request = self._sample_data_request()

        if self._dmem_active:
            current = self._sample_data_request()
            assert current == self._dmem_request, "data request changed while ready was low"
            assert self._dmem_request is not None
            self.dut.i_dmem_rdata.value = self.read_word(self._dmem_request.address)
            self.dut.i_dmem_error.value = int(
                self._dmem_request.address in self.data_error_addresses
            )
            if self._dmem_remaining == 0:
                self.dut.i_dmem_ready.value = 1
            else:
                self._dmem_remaining -= 1
                self.dut.i_dmem_ready.value = 0

    async def run(self) -> None:
        self.dut.i_imem_ready.value = 0
        self.dut.i_imem_rdata.value = 0x00000013
        self.dut.i_imem_error.value = 0
        self.dut.i_dmem_ready.value = 0
        self.dut.i_dmem_rdata.value = 0
        self.dut.i_dmem_error.value = 0

        while True:
            await FallingEdge(self.dut.i_clk)
            self._drive_instruction()
            self._drive_data()

            await RisingEdge(self.dut.i_clk)
            if self._imem_active and int(self.dut.o_imem_valid.value):
                if int(self.dut.i_imem_ready.value):
                    self.instruction_accepts.append(self._imem_request)
                    self._imem_accepted = True

            if self._dmem_active and int(self.dut.o_dmem_valid.value):
                if int(self.dut.i_dmem_ready.value):
                    assert self._dmem_request is not None
                    self.data_accepts.append(self._dmem_request)
                    if (
                        self._dmem_request.write
                        and self._dmem_request.address
                        not in self.data_error_addresses
                    ):
                        self._write(self._dmem_request)
                    self._dmem_accepted = True
