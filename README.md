# RV32I 5-Stage Pipeline CPU

CPU RISC-V 32-bit triển khai bằng SystemVerilog, sử dụng pipeline 5 tầng:

```text
IF → ID → EX → MEM → WB
```

Thiết kế có data forwarding, load-use hazard detection và flush khi branch/jump. Instruction memory và data memory nằm ngoài CPU; hai giao tiếp dùng handshake `valid`/`ready` để core có thể chờ ROM, Flash, SRAM hoặc interconnect của MCU. Repo đồng thời chứa unit test, integration test, wrapper FPGA DE2-115 và netlist Sky130.

Địa chỉ khởi động được cấu hình qua tham số `RESET_VECTOR` của `rv32i_top`; giá trị mặc định là `0x0000_0000`.

Core hỗ trợ các lệnh CSR của extension Zicsr, `ECALL`, `EBREAK` và `MRET` trong
machine mode. Các CSR hiện có gồm `mstatus`, `mie`, `mtvec`, `mscratch`, `mepc`,
`mcause`, `mtval`, `mip`, `mcycle`, `minstret`, `misa` và nhóm machine
identification/configuration CSR. `mhartid` cùng các ID có thể cấu hình bằng
tham số top-level. Ba ngõ vào interrupt đồng bộ với clock hỗ trợ machine
software, timer và external interrupt.

ISA hiện tại là RV32I cùng `Zicsr`, `Zifencei`, `Zicntr` và `Zmmul`. Zmmul cung
cấp `MUL`, `MULH`, `MULHSU` và `MULHU` qua multiplier iterative radix-2. Phần
cứng dùng một bước shift-add mỗi chu kỳ và hoàn tất sau 32 chu kỳ, ưu tiên area
nhỏ cho MCU hơn throughput MUL. Pipeline giữ instruction ở EX cho tới khi kết
quả sẵn sàng. Các phép chia của full M extension chưa được triển khai.

Illegal instruction, truy cập CSR không được hỗ trợ, địa chỉ load/store lệch
alignment và target branch/jump lệch `IALIGN=32` đều tạo precise exception trước
khi instruction gây lỗi tạo side effect.

## Commit/retire interface

Khi một instruction hoàn tất theo đúng thứ tự chương trình, core phát một xung
`o_commit_valid` kèm theo:

- `o_commit_pc`, `o_commit_instruction`: PC và mã lệnh đã retire.
- `o_commit_rd_write`, `o_commit_rd_addr`, `o_commit_rd_data`: thay đổi register kiến trúc.
- `o_commit_mem_write`, `o_commit_mem_addr`, `o_commit_mem_wdata`, `o_commit_mem_wstrb`: side effect của store.

Bubble, instruction bị flush và chu kỳ đang chờ memory không tạo commit. Interface
này phù hợp để làm scoreboard, trace hoặc lockstep checker mà không phải đọc các
tín hiệu debug nội bộ.

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
│   │   ├── memory/           # MEM: load/store và model data memory bên ngoài core
│   │   └── system/           # Machine-mode CSR và trap state
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

# Kiểm tra thứ tự retire và side effect
make vcs TB=tb_commit_interface

# Kiểm tra CSR, ECALL, trap handler và MRET
make vcs TB=tb_machine_csr_trap

# Kiểm tra machine external interrupt
make vcs TB=tb_machine_external_interrupt

# Kiểm tra illegal instruction và misaligned access
make vcs TB=tb_machine_exceptions

# Kiểm tra misa và nhóm machine identification CSR
make vcs TB=tb_machine_identification_csrs

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

## Architectural compliance (ACT4)

Thư mục [`compliance/act4/`](compliance/act4/) chứa cấu hình cho flow ACT4 chính
thức. Profile hiện tại kiểm tra `I`, `Zicsr`, `Zifencei`, `Zicntr` và `Zmmul`;
machine-mode `Sm` cung cấp architectural context và bộ ExceptionsSm có target
riêng.

Môi trường local nằm trong `.tools/act4/` và không được đưa vào Git. Nó không
sửa `PATH`, `.bashrc` hay package hệ thống. Kiểm tra installation bằng:

```bash
make act-tools-check

# Sinh các self-checking ELF chính thức vào build/act4/generated/
make act-generate

# Chạy một ELF
make act-run ELF=/path/to/test.elf

# Chạy toàn bộ ELF vừa sinh
make act-regression

# Chỉ chạy sáu ELF Zicsr
make act-zicsr
```

Có thể override `ACT_ROOT`, `ACT_TOOL_ROOT` hoặc `ACT_ELF_DIR` nếu muốn dùng
một installation khác.

`tb/compliance/tb_act.sv` cung cấp RAM thống nhất 1 MiB, UART mô phỏng tại
`0x1000_0000` và thanh ghi pass/fail tại `0x2000_0000`. Script Python đọc trực
tiếp các segment ELF32 little-endian nên bước chạy DUT không phụ thuộc `objcopy`.

## Bare-metal C firmware

`software/smoke/` chứa startup assembly, linker script và chương trình C
freestanding được link tại reset vector `0x0000_0000`. Firmware khởi tạo stack,
xóa `.bss`, cài `mtvec`, kiểm tra bốn lệnh Zmmul, đọc `cycle`/`instret`, thực thi
`FENCE.I` và in kết quả qua UART mô phỏng tại `0x1000_0000`.

Flow dùng GCC nằm trong `.tools/act4/toolchain/`, không sửa `PATH` hoặc cài
toolchain vào hệ thống:

```bash
# Tạo ELF, map và disassembly trong build/firmware/smoke/
make firmware-build

# Compile ELF harness bằng VCS rồi chạy firmware
make firmware-run
```

Firmware báo pass bằng cách ghi giá trị `1` tới thanh ghi trạng thái mô phỏng
tại `0x2000_0000`. Exception hoặc interrupt ngoài dự kiến đi vào `trap_entry`
và báo fail.

## Synthesis với Design Compiler

Flow tại [`synth/dc/run.tcl`](synth/dc/run.tcl) tổng hợp trực tiếp RTL hiện tại,
tạo netlist và các báo cáo area, timing, QoR trong `build/synth/dc/`. Mặc định
flow tổng hợp native core `rv32i_core` với clock 10 ns (100 MHz):

```bash
make synth-dc

# Bao gồm hai bridge AHB-Lite của public top
make synth-dc-ahb
```

Multiplier radix-2 có thanh ghi accumulator, multiplicand và multiplier nội
bộ. Mỗi bước phải đóng timing trong một clock bình thường; flow không áp dụng
multicycle timing exception cho datapath này. Báo cáo riêng
`timing_multiplier.rpt` kiểm tra các đường timing bên trong multiplier.

Mặc định project dùng Sky130 HD tại corner `tt, 25 C, 1.80 V` thông qua symlink
`.tools/pdk-sky130`. Trên máy hiện tại, tạo liên kết tới PDK dùng chung bằng:

```bash
ln -s /home/shared/PDK/pdk-sky130 .tools/pdk-sky130
```

Có thể chọn corner hoặc standard-cell library khác bằng cách override:

```bash
make synth-dc \
  SYNTH_LIBRARY=/path/to/standard_cells.db \
  SYNTH_CLOCK_PERIOD=10.0
```

Kết quả chính nằm trong `build/synth/dc/rv32i_core/reports/`; netlist và SDC nằm
trong `build/synth/dc/rv32i_core/netlist/`.

## FPGA

Wrapper và Quartus project DE2-115 nằm tại [`fpga/de2_115/`](fpga/de2_115/).

Top-level FPGA là `de2_115_top`; top-level CPU vẫn là `rv32i_top`.

## Tài liệu kết quả

- [`docs/verification_report.md`](docs/verification_report.md)
- [`docs/performance_analysis.md`](docs/performance_analysis.md)

Các báo cáo trên ghi lại kết quả của phiên bản trước refactor. Cần chạy lại simulation trên máy có QuestaSim trước khi phát hành tag mới.
