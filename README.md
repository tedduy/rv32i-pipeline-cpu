# RV32I Pipeline CPU - 5-Stage Implementation

## Mục đích

Dự án này là một **CPU RISC-V RV32I 5-stage pipeline** được implement hoàn chỉnh bằng SystemVerilog, hỗ trợ đầy đủ 37 instructions cơ bản của RV32I ISA.

**Dành cho:**
- Học tập kiến trúc máy tính và thiết kế CPU
- Hiểu rõ cơ chế pipeline và xử lý hazards
- Đồ án tốt nghiệp / Thesis về Computer Architecture
- Thực hành thiết kế digital với FPGA
- Nghiên cứu RISC-V ISA

## Tính năng

- ✅ **Full RV32I ISA** - 37 instructions
- ✅ **5-Stage Pipeline** - IF → ID → EX → MEM → WB
- ✅ **Data Forwarding** - Giảm thiểu pipeline stalls
- ✅ **Hazard Detection** - Xử lý load-use và control hazards
- ✅ **Branch/Jump Support** - Với pipeline flushing
- ✅ **100% Verified** - 51/51 register writes verified
- ✅ **FPGA Tested** - Chạy thành công trên DE2-115

## How to Run

### Yêu cầu
- QuestaSim hoặc ModelSim
- Python 3.6+
- Make (optional)

### 1. Chạy Unit Tests (10 tests)

Test từng module riêng lẻ:

```bash
# Chạy tất cả unit tests
make unit

# Chạy test cụ thể
make run TB=tb_alu_unit
make run TB=tb_control_unit

# Xem waveform
make wave TB=tb_alu_unit
```

### 2. Chạy Pipeline Integration Test

Test toàn bộ pipeline với 75 instructions:

```bash
make pipeline
```

### 3. Chạy Full Verification

Verify 51 register writes với expected values:

```bash
make verify
```

### 4. Chạy tất cả tests

```bash
# Compile + unit tests + pipeline + verification
make all
```

### 5. Các lệnh khác

```bash
# Compile only
make compile

# Clean
make clean

# Help
make help
```

## Kết quả mong đợi

### Unit Tests
```
==========================================
Running All Unit Tests (10 tests)
==========================================

--- Running: tb_alu_unit ---
✓ PASSED (11 tests)

--- Running: tb_reg_file ---
✓ PASSED (10 tests)

...

==========================================
✓ Unit tests complete: 10/10 PASSED
✓ Logs saved in: sim/logs/
==========================================
```

### Full Verification
```
✓✓✓ FULL VERIFICATION PASSED! ✓✓✓

Summary:
  • 76 instructions executed successfully
  • 51/51 register writes verified (100.0%)
  • 0 errors, 0 critical warnings

CPU IS FUNCTIONALLY CORRECT!
```

## Performance

- **CPI (Cycles Per Instruction)**: 1.12
- **Pipeline Efficiency**: 89.3%
- **Fmax (FPGA)**: 63.34 MHz
- **Target Clock**: 50 MHz

## Cấu trúc dự án

```
rv32i-pipeline-cpu/
├── rtl/                    # RTL source code
│   ├── core/              # Core CPU modules
│   │   ├── stages/        # Pipeline stages (ALU, Control, etc.)
│   │   ├── pipeline/      # Pipeline registers
│   │   └── hazard/        # Hazard detection & forwarding
│   ├── common/            # Common modules (mux, adder)
│   └── top/               # Top-level module
├── tb/                    # Testbenches
│   ├── unit_test/         # Unit tests (10 tests)
│   ├── tb_rv32i_pipeline.sv      # Pipeline integration test
│   └── tb_full_verification.sv   # Full verification test
├── sim/                   # Simulation files
│   ├── logs/              # Log files
│   └── scripts/           # Python automation scripts
├── fpga/                  # FPGA implementation (DE2-115)
├── docs/                  # Documentation
├── Makefile              # Build automation
├── compile.f             # File list for compilation
└── README.md             # This file
```

## Supported Instructions (37)

- **Arithmetic & Logic (10)**: ADD, SUB, AND, OR, XOR, SLT, SLTU, SLL, SRL, SRA
- **Immediate (9)**: ADDI, ANDI, ORI, XORI, SLTI, SLTIU, SLLI, SRLI, SRAI
- **Load/Store (8)**: LW, LH, LB, LHU, LBU, SW, SH, SB
- **Branch (6)**: BEQ, BNE, BLT, BGE, BLTU, BGEU
- **Jump (2)**: JAL, JALR
- **Upper Immediate (2)**: LUI, AUIPC

## Documentation

- `README.md` - Project overview (this file)
- `tb/unit_test/README.md` - Unit tests documentation
- `docs/VERIFICATION_REPORT.md` - Verification report
- `docs/PERFORMANCE_ANALYSIS.md` - Performance analysis
- `fpga/README.md` - FPGA implementation guide

## FPGA Implementation

Đã test thành công trên **Terasic DE2-115**:
- FPGA: Cyclone IV E EP4CE115F29C7
- Clock: 50 MHz
- Resource: ~10% Logic Elements
- Debug features: 8 display modes, 9 status LEDs

Xem `fpga/README.md` để biết chi tiết.

## License

Educational purposes only.

---

**Status:** ✅ Fully verified and tested

**Last Updated:** December 7, 2025
