# RV32I 5-Stage Pipeline CPU

![Status](https://img.shields.io/badge/Status-Verified-success)
![ISA](https://img.shields.io/badge/ISA-RV32I-blue)
![FPGA](https://img.shields.io/badge/FPGA-DE2--115-orange)

## Tổng quan

Bộ vi xử lý **RISC-V 32-bit (RV32I)** theo kiến trúc **5-stage pipeline** (IF, ID, EX, MEM, WB) bằng **SystemVerilog**.

**Tính năng:**
- ✅ Hỗ trợ đầy đủ 37 instructions RV32I
- ✅ Data Forwarding (Data Bypassing)
- ✅ Hazard Detection & Pipeline Stall
- ✅ Branch/Jump Flushing
- ✅ CPI = 1.12, IPC = 0.89 (hiệu suất 89%)
- ✅ 100% kiểm chứng thành công (51/51 test cases)
- ✅ Triển khai thành công trên FPGA DE2-115

---

## Kiến trúc Pipeline

```
┌─────┐    ┌─────┐    ┌─────┐    ┌─────┐    ┌─────┐
│ IF  │ -> │ ID  │ -> │ EX  │ -> │ MEM │ -> │ WB  │
└─────┘    └─────┘    └─────┘    └─────┘    └─────┘
```

**5 Stages:**
1. **IF**: Instruction Fetch (PC + Instruction Memory)
2. **ID**: Instruction Decode (Control Unit + Register File + Immediate Gen)
3. **EX**: Execute (ALU + Branch + Jump + Forwarding Unit)
4. **MEM**: Memory Access (Data Memory + Load/Store Unit)
5. **WB**: Write Back (ghi kết quả về Register File)

**Hazard Handling:**
- Data Forwarding Unit: giải quyết RAW hazards
- Hazard Detection Unit: phát hiện Load-Use hazards
- Pipeline Flushing: xử lý Branch/Jump

---

## Cấu trúc Dự án

```
rv32i-pipeline-cpu/
├── rtl/                    # Mã nguồn RTL
│   ├── top/                # rv32i_top.sv
│   ├── core/
│   │   ├── stages/         # ALU, Control, RegFile, Memory...
│   │   ├── pipeline/       # IF_ID, ID_EX, EX_MEM, MEM_WB
│   │   └── hazard/         # Forwarding, Hazard Detection
│   └── common/             # Adder, Mux
├── tb/                     # Testbenches
│   ├── unit_test/          # 10 unit tests
│   └── tb_full_verification.sv  # Test chính (51 cases)
├── fpga/                   # FPGA DE2-115
│   ├── de2_115_top.sv
│   └── de2_115_pins.tcl
├── docs/                   # Tài liệu
├── thesis/                 # Luận văn LaTeX
└── Makefile
```

---

## Hướng dẫn Sử dụng

### Yêu cầu
- QuestaSim/ModelSim (SystemVerilog simulator)
- Intel Quartus Prime (cho FPGA)
- Make, Bash

### Chạy Simulation

```bash
# Clone dự án
git clone <repo-url>
cd rv32i-pipeline-cpu

# Chạy Full Verification (quan trọng nhất)
make verify

# Chạy Unit Tests (10 tests)
make unit

# Chạy test cụ thể
make run TB=tb_alu_unit

# Xem waveform
make wave TB=tb_full_verification

# Xem tất cả lệnh
make help

# Dọn dẹp
make clean
```

### FPGA Implementation

Chi tiết xem: [`fpga/README.md`](fpga/README.md)

```bash
# Mở Quartus Prime → Open Project: fpga/rv32i_top.qpf
# Processing → Start Compilation
# Tools → Programmer → Program FPGA
```

---

## Kết quả Kiểm chứng

**Simulation Results:**
```
Total Cycles:        84
Total Instructions:  75
CPI:                 1.12
IPC:                 0.89
Test Cases:          51/51 PASSED ✓
```

**Performance:**
| Metric | Value | Ideal | Efficiency |
|--------|-------|-------|------------|
| CPI | 1.12 | 1.00 | 89.3% |
| IPC | 0.89 | 1.00 | 89.0% |

**Test Coverage:**
- ✅ 37/37 instructions (R, I, Load, Store, Branch, Jump, U-type)
- ✅ Data forwarding
- ✅ Hazard detection
- ✅ Branch/Jump flushing

Chi tiết: [`docs/VERIFICATION_REPORT.md`](docs/VERIFICATION_REPORT.md)

---

## Tài liệu

- [`docs/VERIFICATION_REPORT.md`](docs/VERIFICATION_REPORT.md) - Báo cáo kiểm chứng
- [`docs/PERFORMANCE_ANALYSIS.md`](docs/PERFORMANCE_ANALYSIS.md) - Phân tích hiệu năng
- [`fpga/README.md`](fpga/README.md) - Hướng dẫn FPGA
- [`thesis/README.md`](thesis/README.md) - Biên dịch luận văn

**RISC-V References:**
- [RISC-V ISA Specification](https://riscv.org/technical/specifications/)
- RV32I Base Integer v2.2

---

**© 2025 RV32I Pipeline CPU Project**
