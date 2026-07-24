"""Reusable non-pipelined AHB-Lite memory model."""

from dataclasses import dataclass
from typing import Optional, Set

from cocotb.triggers import FallingEdge, RisingEdge


@dataclass(frozen=True)
class AHBRequest:
    address: int
    write: int
    size: int
    protection: int


class AHBLiteMemory:
    """AHB-Lite slave model for the deliberately non-pipelined CPU masters."""

    def __init__(
        self,
        dut,
        *,
        output_prefix: str,
        input_prefix: str,
        size: int = 4096,
        wait_states: int = 0,
        error_addresses: Optional[Set[int]] = None,
        instruction_port: bool = False,
    ) -> None:
        self.dut = dut
        self.output_prefix = output_prefix
        self.input_prefix = input_prefix
        self.data = bytearray(size)
        self.wait_states = wait_states
        self.error_addresses = error_addresses or set()
        self.instruction_port = instruction_port

        self.accepted: list[AHBRequest] = []
        self.completed: list[AHBRequest] = []
        self.store_count = 0

        self._pending: AHBRequest | None = None
        self._remaining = 0
        self._error_announced = False

    def _output(self, name):
        return getattr(self.dut, f"{self.output_prefix}{name}")

    def _input(self, name):
        return getattr(self.dut, f"{self.input_prefix}{name}")

    def load_words(self, words: list[int], address: int = 0) -> None:
        for index, word in enumerate(words):
            base = address + 4 * index
            self.data[base : base + 4] = int(word).to_bytes(4, "little")

    def read_word(self, address: int) -> int:
        base = address & ~0x3
        if base < 0 or base + 4 > len(self.data):
            return 0x0000_0013 if self.instruction_port else 0
        return int.from_bytes(self.data[base : base + 4], "little")

    def _capture_address(self) -> AHBRequest:
        request = AHBRequest(
            address=int(self._output("haddr").value),
            write=int(self._output("hwrite").value),
            size=int(self._output("hsize").value),
            protection=int(self._output("hprot").value),
        )
        assert int(self._output("hburst").value) == 0, "only SINGLE bursts are supported"
        assert int(self._output("hmastlock").value) == 0
        assert request.size <= 2, f"illegal RV32 AHB transfer size {request.size}"
        if self.instruction_port:
            assert not request.write, "instruction AHB port attempted a write"
            assert request.size == 2, "instruction fetch must be word-sized"
        return request

    def _write(self, request: AHBRequest) -> None:
        width = 1 << request.size
        if request.address < 0 or request.address + width > len(self.data):
            raise AssertionError(f"write to unmapped address 0x{request.address:08x}")

        write_data = int(self._output("hwdata").value)
        for offset in range(width):
            lane = (request.address + offset) & 0x3
            self.data[request.address + offset] = (
                write_data >> (8 * lane)
            ) & 0xFF
        self.store_count += 1

    async def run(self) -> None:
        self._input("hrdata").value = 0
        self._input("hready").value = 0
        self._input("hresp").value = 0

        while True:
            await FallingEdge(self.dut.i_clk)
            completing = None
            accepting = None

            if self._pending is None:
                self._input("hready").value = 1
                self._input("hresp").value = 0
                if int(self._output("htrans").value) == 0b10:
                    accepting = self._capture_address()
            elif self._remaining:
                self._input("hready").value = 0
                self._input("hresp").value = 0
                self._remaining -= 1
            elif (
                self._pending.address in self.error_addresses
                and not self._error_announced
            ):
                # AHB-Lite ERROR is a two-cycle response: the first cycle
                # extends the transfer and the second completes it.
                self._input("hready").value = 0
                self._input("hresp").value = 1
                self._error_announced = True
            else:
                completing = self._pending
                self._input("hrdata").value = self.read_word(
                    completing.address
                )
                self._input("hresp").value = int(
                    completing.address in self.error_addresses
                )
                self._input("hready").value = 1

            await RisingEdge(self.dut.i_clk)

            if completing is not None:
                if (
                    completing.write
                    and completing.address not in self.error_addresses
                ):
                    self._write(completing)
                self.completed.append(completing)
                self._pending = None
            elif accepting is not None:
                self.accepted.append(accepting)
                self._pending = accepting
                self._remaining = self.wait_states
                self._error_announced = False
