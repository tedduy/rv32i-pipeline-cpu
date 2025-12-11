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
├── fpga/                    # FPGA Set Up
├── rtl/                    # RTL Source Code
│   ├── top/                # rv32i_top.sv
│   ├── core/
│   │   ├── stages/         # ALU, Control, RegFile, Memory...
│   │   ├── pipeline/       # IF_ID, ID_EX, EX_MEM, MEM_WB
│   │   └── hazard/         # Forwarding, Hazard Detection
│   └── common/             # Adder, Mux
├── tb/                     # Testbenches
│   ├── unit_test/          # 10 unit tests
│   └── tb_rv32i_gl.sv            # Gate-level testbench
│   └── tb_rv32i_pipeline.sv      # System testbench
├── openlane/               # OpenLane ASIC Synthesis
│   ├── rv32i_top.v         # Gate-level netlist
│   └── rv32i_top.sdf       # Timing annotation
├── docs/                   # Documentation
└── Makefile                # Build automation
```

---

## Hướng dẫn Sử dụng

### Yêu cầu
- QuestaSim/ModelSim (SystemVerilog simulator)
- Intel Quartus Prime (cho FPGA)
- Make, Bash

### Quick Start

```bash
# Clone project
git clone https://github.com/tedduy/rv32i-pipeline-cpu
cd rv32i-pipeline-cpu

# Compile all (RTL + Gate-level)
make compile

# Run RTL simulation
make pipeline

# Run unit tests
make unit

# Run gate-level simulation
make gl

# View waveform
make wave TB=tb_rv32i_pipeline

# Clean
make clean

# Help
make help
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

## Gate-Level Simulation

```bash
# Compile RTL + Gate-level netlist
make compile

# Run gate-level simulation
make gl

# View detailed log
cat logs/gl_simulation.log
```

**Gate-Level Results:**
- ✅ 76/76 tests PASSED
- ✅ Synthesized with OpenLane (Sky130 PDK)
- ✅ Area: 0.81 mm², Frequency: 50 MHz
- ✅ Timing verified with SDF annotation

---

## Documentation

**RISC-V References:**
- [RISC-V ISA Specification](https://riscv.org/technical/specifications/)
- [RISC-V User Manual](https://five-embeddev.com/riscv-user-isa-manual/)
- [OpenLane Documentation](https://openlane.readthedocs.io/)

---

**© 2025 RV32I Pipeline CPU Project**
