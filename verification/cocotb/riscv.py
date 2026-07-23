"""Small RV32 instruction encoder used by directed core tests."""


def u32(value: int) -> int:
    return value & 0xFFFF_FFFF


def _signed(value: int, width: int) -> int:
    limit = 1 << width
    if not -(limit // 2) <= value < (limit // 2):
        raise ValueError(f"{value} does not fit a signed {width}-bit immediate")
    return value & (limit - 1)


def _r_type(
    rd: int,
    rs1: int,
    rs2: int,
    funct3: int,
    funct7: int = 0,
) -> int:
    return (
        (funct7 << 25)
        | (rs2 << 20)
        | (rs1 << 15)
        | (funct3 << 12)
        | (rd << 7)
        | 0x33
    )


def _i_type(rd: int, rs1: int, immediate: int, funct3: int, opcode: int) -> int:
    imm = _signed(immediate, 12)
    return (imm << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode


def _branch(rs1: int, rs2: int, immediate: int, funct3: int) -> int:
    imm = _signed(immediate, 13)
    if imm & 1:
        raise ValueError("branch target must be two-byte aligned")
    return (
        (((imm >> 12) & 1) << 31)
        | (((imm >> 5) & 0x3F) << 25)
        | (rs2 << 20)
        | (rs1 << 15)
        | (funct3 << 12)
        | (((imm >> 1) & 0xF) << 8)
        | (((imm >> 11) & 1) << 7)
        | 0x63
    )


def addi(rd: int, rs1: int, immediate: int) -> int:
    return _i_type(rd, rs1, immediate, 0b000, 0x13)


def slti(rd: int, rs1: int, immediate: int) -> int:
    return _i_type(rd, rs1, immediate, 0b010, 0x13)


def sltiu(rd: int, rs1: int, immediate: int) -> int:
    return _i_type(rd, rs1, immediate, 0b011, 0x13)


def xori(rd: int, rs1: int, immediate: int) -> int:
    return _i_type(rd, rs1, immediate, 0b100, 0x13)


def ori(rd: int, rs1: int, immediate: int) -> int:
    return _i_type(rd, rs1, immediate, 0b110, 0x13)


def andi(rd: int, rs1: int, immediate: int) -> int:
    return _i_type(rd, rs1, immediate, 0b111, 0x13)


def slli(rd: int, rs1: int, shift: int) -> int:
    if not 0 <= shift < 32:
        raise ValueError("RV32 shift amount must be in [0, 31]")
    return _i_type(rd, rs1, shift, 0b001, 0x13)


def srli(rd: int, rs1: int, shift: int) -> int:
    if not 0 <= shift < 32:
        raise ValueError("RV32 shift amount must be in [0, 31]")
    return _i_type(rd, rs1, shift, 0b101, 0x13)


def srai(rd: int, rs1: int, shift: int) -> int:
    if not 0 <= shift < 32:
        raise ValueError("RV32 shift amount must be in [0, 31]")
    return _i_type(rd, rs1, (0b0100000 << 5) | shift, 0b101, 0x13)


def add(rd: int, rs1: int, rs2: int) -> int:
    return _r_type(rd, rs1, rs2, 0b000)


def sub(rd: int, rs1: int, rs2: int) -> int:
    return _r_type(rd, rs1, rs2, 0b000, 0b0100000)


def sll(rd: int, rs1: int, rs2: int) -> int:
    return _r_type(rd, rs1, rs2, 0b001)


def slt(rd: int, rs1: int, rs2: int) -> int:
    return _r_type(rd, rs1, rs2, 0b010)


def sltu(rd: int, rs1: int, rs2: int) -> int:
    return _r_type(rd, rs1, rs2, 0b011)


def xor(rd: int, rs1: int, rs2: int) -> int:
    return _r_type(rd, rs1, rs2, 0b100)


def srl(rd: int, rs1: int, rs2: int) -> int:
    return _r_type(rd, rs1, rs2, 0b101)


def sra(rd: int, rs1: int, rs2: int) -> int:
    return _r_type(rd, rs1, rs2, 0b101, 0b0100000)


def or_(rd: int, rs1: int, rs2: int) -> int:
    return _r_type(rd, rs1, rs2, 0b110)


def and_(rd: int, rs1: int, rs2: int) -> int:
    return _r_type(rd, rs1, rs2, 0b111)


def lui(rd: int, upper: int) -> int:
    if not 0 <= upper < (1 << 20):
        raise ValueError("LUI immediate must be a 20-bit value")
    return (upper << 12) | (rd << 7) | 0x37


def auipc(rd: int, upper: int) -> int:
    if not 0 <= upper < (1 << 20):
        raise ValueError("AUIPC immediate must be a 20-bit value")
    return (upper << 12) | (rd << 7) | 0x17


def lw(rd: int, rs1: int, immediate: int) -> int:
    return _i_type(rd, rs1, immediate, 0b010, 0x03)


def sw(rs2: int, rs1: int, immediate: int) -> int:
    imm = _signed(immediate, 12)
    return (
        ((imm >> 5) << 25)
        | (rs2 << 20)
        | (rs1 << 15)
        | (0b010 << 12)
        | ((imm & 0x1F) << 7)
        | 0x23
    )


def beq(rs1: int, rs2: int, immediate: int) -> int:
    return _branch(rs1, rs2, immediate, 0b000)


def bne(rs1: int, rs2: int, immediate: int) -> int:
    return _branch(rs1, rs2, immediate, 0b001)


def blt(rs1: int, rs2: int, immediate: int) -> int:
    return _branch(rs1, rs2, immediate, 0b100)


def bge(rs1: int, rs2: int, immediate: int) -> int:
    return _branch(rs1, rs2, immediate, 0b101)


def bltu(rs1: int, rs2: int, immediate: int) -> int:
    return _branch(rs1, rs2, immediate, 0b110)


def bgeu(rs1: int, rs2: int, immediate: int) -> int:
    return _branch(rs1, rs2, immediate, 0b111)


def jal(rd: int, immediate: int) -> int:
    imm = _signed(immediate, 21)
    if imm & 1:
        raise ValueError("JAL target must be two-byte aligned")
    return (
        (((imm >> 20) & 1) << 31)
        | (((imm >> 1) & 0x3FF) << 21)
        | (((imm >> 11) & 1) << 20)
        | (((imm >> 12) & 0xFF) << 12)
        | (rd << 7)
        | 0x6F
    )


def jalr(rd: int, rs1: int, immediate: int) -> int:
    return _i_type(rd, rs1, immediate, 0b000, 0x67)


def _m_op(rd: int, rs1: int, rs2: int, funct3: int) -> int:
    return _r_type(rd, rs1, rs2, funct3, 0b0000001)


def mul(rd: int, rs1: int, rs2: int) -> int:
    return _m_op(rd, rs1, rs2, 0b000)


def mulh(rd: int, rs1: int, rs2: int) -> int:
    return _m_op(rd, rs1, rs2, 0b001)


def mulhsu(rd: int, rs1: int, rs2: int) -> int:
    return _m_op(rd, rs1, rs2, 0b010)


def mulhu(rd: int, rs1: int, rs2: int) -> int:
    return _m_op(rd, rs1, rs2, 0b011)


def div(rd: int, rs1: int, rs2: int) -> int:
    return _m_op(rd, rs1, rs2, 0b100)


def divu(rd: int, rs1: int, rs2: int) -> int:
    return _m_op(rd, rs1, rs2, 0b101)


def rem(rd: int, rs1: int, rs2: int) -> int:
    return _m_op(rd, rs1, rs2, 0b110)


def remu(rd: int, rs1: int, rs2: int) -> int:
    return _m_op(rd, rs1, rs2, 0b111)


def c_addi(rd: int, immediate: int) -> int:
    if rd == 0 and immediate != 0:
        raise ValueError("C.ADDI with rd=x0 is reserved")
    imm = _signed(immediate, 6)
    return (
        (((imm >> 5) & 1) << 12)
        | (rd << 7)
        | ((imm & 0x1F) << 2)
        | 0b01
    )


def c_li(rd: int, immediate: int) -> int:
    if rd == 0:
        raise ValueError("C.LI requires rd != x0")
    imm = _signed(immediate, 6)
    return (
        (0b010 << 13)
        | (((imm >> 5) & 1) << 12)
        | (rd << 7)
        | ((imm & 0x1F) << 2)
        | 0b01
    )


def c_mv(rd: int, rs2: int) -> int:
    if rd == 0 or rs2 == 0:
        raise ValueError("C.MV requires nonzero registers")
    return (0b1000 << 12) | (rd << 7) | (rs2 << 2) | 0b10


def c_add(rd: int, rs2: int) -> int:
    if rd == 0 or rs2 == 0:
        raise ValueError("C.ADD requires nonzero registers")
    return (0b1001 << 12) | (rd << 7) | (rs2 << 2) | 0b10


def _csr(rd: int, csr: int, operand: int, funct3: int) -> int:
    if not 0 <= csr < (1 << 12):
        raise ValueError("CSR address must be 12 bits")
    if not 0 <= operand < 32:
        raise ValueError("CSR register/uimm operand must be 5 bits")
    return (
        (csr << 20)
        | (operand << 15)
        | (funct3 << 12)
        | (rd << 7)
        | 0x73
    )


def csrrw(rd: int, csr: int, rs1: int) -> int:
    return _csr(rd, csr, rs1, 0b001)


def csrrs(rd: int, csr: int, rs1: int) -> int:
    return _csr(rd, csr, rs1, 0b010)


def csrrwi(rd: int, csr: int, immediate: int) -> int:
    return _csr(rd, csr, immediate, 0b101)


def csrrsi(rd: int, csr: int, immediate: int) -> int:
    return _csr(rd, csr, immediate, 0b110)


def csrrci(rd: int, csr: int, immediate: int) -> int:
    return _csr(rd, csr, immediate, 0b111)


def csrw(csr: int, rs1: int) -> int:
    return csrrw(0, csr, rs1)


def csrr(rd: int, csr: int) -> int:
    return csrrs(rd, csr, 0)


ECALL = 0x0000_0073
MRET = 0x3020_0073
WFI = 0x1050_0073
