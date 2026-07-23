"""Independent architectural oracle for the RV32C/Zca decompressor.

The oracle deliberately does not share code or tables with the RTL.  It first
classifies a 16-bit parcel according to the ISA encoding, then constructs the
equivalent RV32I instruction with small, conventional instruction encoders.
Illegal parcels return a NOP, matching the decompressor's documented output
contract; consumers must use ``illegal`` rather than execute that value.
"""

from dataclasses import dataclass


NOP = 0x00000013


@dataclass(frozen=True)
class Decompression:
    instruction: int
    illegal: bool
    coverage_bin: str


def _bits(value: int, high: int, low: int) -> int:
    return (value >> low) & ((1 << (high - low + 1)) - 1)


def _signed(value: int, width: int) -> int:
    sign = 1 << (width - 1)
    return (value ^ sign) - sign


def _i(immediate: int, rs1: int, funct3: int, rd: int, opcode: int) -> int:
    return (
        ((immediate & 0xFFF) << 20)
        | (rs1 << 15)
        | (funct3 << 12)
        | (rd << 7)
        | opcode
    )


def _r(funct7: int, rs2: int, rs1: int, funct3: int, rd: int) -> int:
    return (
        (funct7 << 25)
        | (rs2 << 20)
        | (rs1 << 15)
        | (funct3 << 12)
        | (rd << 7)
        | 0x33
    )


def _s(immediate: int, rs2: int, rs1: int, funct3: int) -> int:
    immediate &= 0xFFF
    return (
        ((immediate >> 5) << 25)
        | (rs2 << 20)
        | (rs1 << 15)
        | (funct3 << 12)
        | ((immediate & 0x1F) << 7)
        | 0x23
    )


def _b(offset: int, rs2: int, rs1: int, funct3: int) -> int:
    immediate = offset & 0x1FFF
    return (
        (((immediate >> 12) & 1) << 31)
        | (((immediate >> 5) & 0x3F) << 25)
        | (rs2 << 20)
        | (rs1 << 15)
        | (funct3 << 12)
        | (((immediate >> 1) & 0xF) << 8)
        | (((immediate >> 11) & 1) << 7)
        | 0x63
    )


def _j(offset: int, rd: int) -> int:
    immediate = offset & 0x1FFFFF
    return (
        (((immediate >> 20) & 1) << 31)
        | (((immediate >> 1) & 0x3FF) << 21)
        | (((immediate >> 11) & 1) << 20)
        | (((immediate >> 12) & 0xFF) << 12)
        | (rd << 7)
        | 0x6F
    )


def _legal(instruction: int, mnemonic: str) -> Decompression:
    return Decompression(instruction & 0xFFFFFFFF, False, mnemonic)


def _illegal(reason: str) -> Decompression:
    return Decompression(NOP, True, reason)


def decompress_rv32c(parcel: int) -> Decompression:
    """Decode one 16-bit parcel under RV32 Zca rules."""

    parcel &= 0xFFFF
    quadrant = parcel & 0x3
    funct3 = _bits(parcel, 15, 13)
    rd = _bits(parcel, 11, 7)
    rs2 = _bits(parcel, 6, 2)
    rdp = 8 + _bits(parcel, 4, 2)
    rs1p = 8 + _bits(parcel, 9, 7)
    rs2p = 8 + _bits(parcel, 4, 2)

    if quadrant == 0:
        if funct3 == 0:  # C.ADDI4SPN
            offset = (
                (_bits(parcel, 10, 7) << 6)
                | (_bits(parcel, 12, 11) << 4)
                | (_bits(parcel, 5, 5) << 3)
                | (_bits(parcel, 6, 6) << 2)
            )
            if offset == 0:
                return _illegal("reserved.c.addi4spn.zero")
            return _legal(_i(offset, 2, 0, rdp, 0x13), "c.addi4spn")
        if funct3 == 2:  # C.LW
            offset = (
                (_bits(parcel, 5, 5) << 6)
                | (_bits(parcel, 12, 10) << 3)
                | (_bits(parcel, 6, 6) << 2)
            )
            return _legal(_i(offset, rs1p, 2, rdp, 0x03), "c.lw")
        if funct3 == 6:  # C.SW
            offset = (
                (_bits(parcel, 5, 5) << 6)
                | (_bits(parcel, 12, 10) << 3)
                | (_bits(parcel, 6, 6) << 2)
            )
            return _legal(_s(offset, rs2p, rs1p, 2), "c.sw")
        return _illegal(f"reserved.q0.funct3_{funct3:03b}")

    if quadrant == 1:
        immediate6 = (_bits(parcel, 12, 12) << 5) | _bits(parcel, 6, 2)
        signed6 = _signed(immediate6, 6)

        if funct3 == 0:  # C.NOP / C.ADDI
            mnemonic = "c.nop" if rd == 0 and signed6 == 0 else "c.addi"
            return _legal(_i(signed6, rd, 0, rd, 0x13), mnemonic)
        if funct3 in (1, 5):  # C.JAL / C.J
            immediate12 = (
                (_bits(parcel, 12, 12) << 11)
                | (_bits(parcel, 8, 8) << 10)
                | (_bits(parcel, 10, 9) << 8)
                | (_bits(parcel, 6, 6) << 7)
                | (_bits(parcel, 7, 7) << 6)
                | (_bits(parcel, 2, 2) << 5)
                | (_bits(parcel, 11, 11) << 4)
                | (_bits(parcel, 5, 3) << 1)
            )
            mnemonic = "c.jal" if funct3 == 1 else "c.j"
            return _legal(_j(_signed(immediate12, 12), 1 if funct3 == 1 else 0), mnemonic)
        if funct3 == 2:  # C.LI
            return _legal(_i(signed6, 0, 0, rd, 0x13), "c.li")
        if funct3 == 3:
            if rd == 2:  # C.ADDI16SP
                offset = (
                    (_bits(parcel, 12, 12) << 9)
                    | (_bits(parcel, 4, 3) << 7)
                    | (_bits(parcel, 5, 5) << 6)
                    | (_bits(parcel, 2, 2) << 5)
                    | (_bits(parcel, 6, 6) << 4)
                )
                if offset == 0:
                    return _illegal("reserved.c.addi16sp.zero")
                return _legal(_i(_signed(offset, 10), 2, 0, 2, 0x13), "c.addi16sp")
            if rd == 0:
                # The architectural HINT is represented by a canonical NOP.
                return _legal(NOP, "hint.c.lui.rd0")
            if immediate6 == 0:
                return _illegal("reserved.c.lui.zero")
            return _legal(((signed6 & 0xFFFFF) << 12) | (rd << 7) | 0x37, "c.lui")
        if funct3 == 4:
            subop = _bits(parcel, 11, 10)
            if subop in (0, 1):  # C.SRLI / C.SRAI
                mnemonic = "c.srli" if subop == 0 else "c.srai"
                if _bits(parcel, 12, 12):
                    return _illegal(f"reserved.{mnemonic}.shamt5")
                funct7 = 0x00 if subop == 0 else 0x20
                return _legal(_i((funct7 << 5) | rs2, rs1p, 5, rs1p, 0x13), mnemonic)
            if subop == 2:  # C.ANDI
                return _legal(_i(signed6, rs1p, 7, rs1p, 0x13), "c.andi")
            if _bits(parcel, 12, 12):
                return _illegal("reserved.ca.rv32.subw_addw")
            operation = _bits(parcel, 6, 5)
            funct7, alu_funct3, mnemonic = (
                (0x20, 0, "c.sub"),
                (0x00, 4, "c.xor"),
                (0x00, 6, "c.or"),
                (0x00, 7, "c.and"),
            )[operation]
            return _legal(_r(funct7, rs2p, rs1p, alu_funct3, rs1p), mnemonic)
        if funct3 in (6, 7):  # C.BEQZ / C.BNEZ
            immediate9 = (
                (_bits(parcel, 12, 12) << 8)
                | (_bits(parcel, 6, 5) << 6)
                | (_bits(parcel, 2, 2) << 5)
                | (_bits(parcel, 11, 10) << 3)
                | (_bits(parcel, 4, 3) << 1)
            )
            mnemonic = "c.beqz" if funct3 == 6 else "c.bnez"
            return _legal(
                _b(_signed(immediate9, 9), 0, rs1p, 0 if funct3 == 6 else 1),
                mnemonic,
            )

    if quadrant == 2:
        if funct3 == 0:  # C.SLLI
            if _bits(parcel, 12, 12):
                return _illegal("reserved.c.slli.shamt5")
            return _legal(_i(rs2, rd, 1, rd, 0x13), "c.slli")
        if funct3 == 2:  # C.LWSP
            offset = (
                (_bits(parcel, 3, 2) << 6)
                | (_bits(parcel, 12, 12) << 5)
                | (_bits(parcel, 6, 4) << 2)
            )
            if rd == 0:
                return _illegal("reserved.c.lwsp.rd0")
            return _legal(_i(offset, 2, 2, rd, 0x03), "c.lwsp")
        if funct3 == 4:
            bit12 = _bits(parcel, 12, 12)
            if bit12 == 0 and rs2 == 0:
                if rd == 0:
                    return _illegal("reserved.c.jr.rd0")
                return _legal(_i(0, rd, 0, 0, 0x67), "c.jr")
            if bit12 == 0:  # C.MV
                return _legal(_r(0, rs2, 0, 0, rd), "c.mv")
            if rs2 == 0:
                if rd == 0:
                    return _legal(0x00100073, "c.ebreak")
                return _legal(_i(0, rd, 0, 1, 0x67), "c.jalr")
            return _legal(_r(0, rs2, rd, 0, rd), "c.add")
        if funct3 == 6:  # C.SWSP
            offset = (_bits(parcel, 8, 7) << 6) | (_bits(parcel, 12, 9) << 2)
            return _legal(_s(offset, rs2, 2, 2), "c.swsp")
        return _illegal(f"reserved.q2.funct3_{funct3:03b}")

    return _illegal("not_compressed.q3")
