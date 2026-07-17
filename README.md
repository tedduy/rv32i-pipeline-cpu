# RV32I 5-Stage Pipeline CPU

CPU RISC-V 32-bit triển khai bằng SystemVerilog, sử dụng pipeline 5 tầng:

```text
IF → ID → EX → MEM → WB
```

Thiết kế có data forwarding, load-use hazard detection và flush khi branch/jump. Instruction memory và data memory nằm ngoài CPU; hai giao tiếp dùng handshake `valid`/`ready` để core có thể chờ ROM, Flash, SRAM hoặc interconnect của MCU. Repo đồng thời chứa unit test, integration test, wrapper FPGA DE2-115 và netlist Sky130.

Địa chỉ khởi động được cấu hình qua tham số `RESET_VECTOR` của `rv32i_top`; giá trị mặc định là `0x0000_0000`.

## Bắt đầu đọc từ đâu?

Đọc theo thứ tự sau để hiểu thiết kế nhanh nhất:

1. [`rtl/rv32i_top.sv`](rtl/rv32i_top.sv) — kết nối toàn bộ datapath và control path.
2. [`rtl/pipeline/`](rtl/pipeline/) — bốn ranh giới của pipeline.
3. [`rtl/stages/decode/control_unit.sv`](rtl/stages/decode/control_unit.sv) — giải mã instruction.
4. [`rtl/stages/execute/alu_unit.sv`](rtl/stages/execute/alu_unit.sv) — datapath thực thi.
5. [`rtl/hazard/`](rtl/hazard/) — stall, flush và forwarding.
6. [`tb/integration/tb_rv32i_pipeline.sv`](tb/integration/tb_rv32i_pipeline.sv) — luồng kiểm thử toàn CPU.

## Cấu trúc repo

```text
rv32i-pipeline-cpu/
├── rtl/
│   ├── rv32i_top.sv
│   ├── stages/
│   │   ├── fetch/            # IF: PC và model instruction memory bên ngoài core
│   │   ├── decode/           # ID: control, immediate, register file
│   │   ├── execute/          # EX: ALU, branch và jump
│   │   └── memory/           # MEM: load/store và model data memory bên ngoài core
│   ├── pipeline/             # IF/ID, ID/EX, EX/MEM, MEM/WB
│   ├── hazard/               # Forwarding và hazard detection
│   └── common/               # Adder và mux dùng chung
├── tb/
│   ├── unit/
│   ├── integration/
│   └── gate_level/
├── fpga/
│   └── de2_115/
├── asic/
│   └── sky130/netlist/
├── docs/
├── filelist.f
├── filelist_netlist.f
├── wave_tb_rv32i_pipeline.do
└── Makefile
```

## Quy ước đặt tên

- Một module SystemVerilog chính trên mỗi file.
- Tên file trùng tên module và dùng `lower_snake_case`.
- Testbench dùng tiền tố `tb_`.
- Tín hiệu stage dùng tiền tố `if_`, `id_`, `ex_`, `mem_`, `wb_`.
- `rv32i_top` được giữ ổn định làm entry point cho RTL, FPGA và ASIC.

## Chạy simulation

Yêu cầu:

- QuestaSim hoặc ModelSim (`vlib`, `vlog`, `vsim`).
- GNU Make.

```bash
# Compile RTL và toàn bộ RTL testbench
make rtl-compile

# Chạy 10 unit testbench
make unit

# Chạy pipeline integration test
make pipeline

# Chạy write-back verification
make verify

# Mở waveform của pipeline
make wave TB=tb_rv32i_pipeline

# Xóa simulation artifacts
make clean
```

`make compile` là alias của `make rtl-compile`; gate-level không còn bị compile bắt buộc cùng RTL.

## Gate-level simulation

Netlist được lưu tại:

```text
asic/sky130/netlist/rv32i_top.v
```

Gate-level simulation cần Sky130 PDK:

```bash
make gl PDK_ROOT=/path/to/sky130/pdk
```

Hai file list được dùng là:

- [`filelist.f`](filelist.f) — RTL và testbench.
- [`filelist_netlist.f`](filelist_netlist.f) — Sky130 netlist và gate-level testbench.

## FPGA

Wrapper và Quartus project DE2-115 nằm tại [`fpga/de2_115/`](fpga/de2_115/).

Top-level FPGA là `de2_115_top`; top-level CPU vẫn là `rv32i_top`.

## Tài liệu kết quả

- [`docs/verification_report.md`](docs/verification_report.md)
- [`docs/performance_analysis.md`](docs/performance_analysis.md)

Các báo cáo trên ghi lại kết quả của phiên bản trước refactor. Cần chạy lại simulation trên máy có QuestaSim trước khi phát hành tag mới.
