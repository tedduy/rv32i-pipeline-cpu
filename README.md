# RV32IC 5-Stage Pipeline CPU

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

ISA hiện tại là RV32IC cùng `Zicsr`, `Zifencei`, `Zicntr` và `Zmmul`. Phần
`Zca` của compressed extension được giải nén ở fetch stage; PC tiến thêm 2 hoặc
4 byte và fetch buffer ghép được lệnh 32-bit bắt đầu tại nửa trên của một word.
Zmmul cung
cấp `MUL`, `MULH`, `MULHSU` và `MULHU` qua multiplier iterative radix-2. Phần
cứng dùng một bước shift-add mỗi chu kỳ và hoàn tất sau 32 chu kỳ, ưu tiên area
nhỏ cho MCU hơn throughput MUL. Pipeline giữ instruction ở EX cho tới khi kết
quả sẵn sàng. Các phép chia của full M extension chưa được triển khai.

Illegal instruction, truy cập CSR không được hỗ trợ và địa chỉ load/store lệch
alignment đều tạo precise exception trước khi instruction gây lỗi tạo side
effect. Core dùng `IALIGN=16`; `mepc[1]` được giữ lại và target control-flow chỉ
cần căn hàng theo 2 byte.

## Commit/retire interface

Khi một instruction hoàn tất theo đúng thứ tự chương trình, core phát một xung
`o_commit_valid` kèm theo:

- `o_commit_pc`, `o_commit_instruction`: PC và encoding gốc của lệnh đã retire;
  lệnh compressed được zero-extend từ 16 lên 32 bit.
- `o_commit_rd_write`, `o_commit_rd_addr`, `o_commit_rd_data`: thay đổi register kiến trúc.
- `o_commit_mem_write`, `o_commit_mem_addr`, `o_commit_mem_wdata`, `o_commit_mem_wstrb`: side effect của store.

Bubble, instruction bị flush và chu kỳ đang chờ memory không tạo commit. Interface
này phù hợp để làm scoreboard, trace hoặc lockstep checker mà không phải đọc các
tín hiệu debug nội bộ.

## Bắt đầu đọc từ đâu?

Đọc theo thứ tự sau để hiểu thiết kế nhanh nhất:

1. [`rtl/logical/rv32i_core.sv`](rtl/logical/rv32i_core.sv) — native-bus core `rv32i_core`, kết nối toàn bộ datapath và control path.
2. [`rtl/logical/pipeline/`](rtl/logical/pipeline/) — bốn ranh giới của pipeline.
3. [`rtl/logical/stages/fetch/rv32c_fetch_buffer.sv`](rtl/logical/stages/fetch/rv32c_fetch_buffer.sv) và
   [`rtl/logical/stages/decode/rv32c_decompressor.sv`](rtl/logical/stages/decode/rv32c_decompressor.sv) — fetch và giải nén RV32C.
4. [`rtl/logical/stages/execute/alu_unit.sv`](rtl/logical/stages/execute/alu_unit.sv) — datapath thực thi.
5. [`rtl/logical/hazard/`](rtl/logical/hazard/) — stall, flush và forwarding.
6. [`rtl/sim/integration/tb_rv32i_pipeline.sv`](rtl/sim/integration/tb_rv32i_pipeline.sv) — luồng kiểm thử toàn CPU.

## Cấu trúc repo

```text
rv32i-pipeline-cpu/
├── rtl/
│   ├── logical/              # Technology-independent synthesizable RTL
│   │   ├── rv32i_core.sv
│   │   ├── rv32i_top.sv
│   │   ├── stages/           # Fetch, decode, execute, memory, system
│   │   ├── pipeline/         # IF/ID, ID/EX, EX/MEM, MEM/WB
│   │   ├── hazard/           # Forwarding và hazard detection
│   │   ├── bus/              # Native-to-AHB-Lite bridge
│   │   └── common/           # Adder và mux dùng chung
│   ├── sim/                  # Unit, integration, ACT4 và gate-level TB
│   ├── syn/                  # Synthesis flows
│   ├── sdc/                  # Timing constraints
│   ├── lint/                 # Lint rules và waivers
│   ├── cdc/                  # Clock-domain crossing collateral
│   ├── rdc/                  # Reset-domain crossing collateral
│   └── doc/                  # RTL và verification documents
├── fpga/
│   └── de2_115/
├── asic/
│   └── sky130/netlist/
├── scripts/
└── Makefile
```

## Quy ước đặt tên

- Quy ước đầy đủ nằm tại [`rtl/doc/coding_style.md`](rtl/doc/coding_style.md).
- Một module SystemVerilog chính trên mỗi file.
- Tên file trùng tên module và dùng `lower_snake_case`.
- Testbench dùng tiền tố `tb_`.
- Tín hiệu stage dùng tiền tố `if_`, `id_`, `ex_`, `mem_`, `wb_`.
- `rv32i_core` là native-bus core; `rv32i_top` là public AHB-Lite wrapper.
- FPGA wrapper có thể dùng trực tiếp `rv32i_core` với memory subsystem của board.

## Chạy simulation

Yêu cầu:

- QuestaSim hoặc ModelSim (`vlib`, `vlog`, `vsim`).
- GNU Make.

```bash
# Compile RTL và toàn bộ RTL testbench
make rtl-compile

# Chạy toàn bộ unit testbench
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

- [`rtl/sim/filelist.f`](rtl/sim/filelist.f) — RTL và testbench.
- [`rtl/sim/filelist_netlist.f`](rtl/sim/filelist_netlist.f) — Sky130 netlist và gate-level testbench.

## Architectural compliance (ACT4)

Thư mục [`rtl/sim/compliance/act4/`](rtl/sim/compliance/act4/) chứa cấu hình cho flow ACT4 chính
thức. Profile hiện tại kiểm tra `I`, `Zca`, `Zicsr`, `Zifencei`, `Zicntr` và
`Zmmul`; machine-mode `Sm` cung cấp architectural context. `ExceptionsSm` được
điều chỉnh cho `IALIGN=16`, còn `ExceptionsZc` kiểm tra illegal compressed
encoding và `C.EBREAK`.

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

# Chỉ chạy 26 ELF compressed-integer
make act-zca

# Sinh và chạy compressed exception suite
make act-zc-exceptions-generate
make act-zc-exceptions

# Chỉ chạy sáu ELF Zicsr
make act-zicsr
```

Có thể override `ACT_ROOT`, `ACT_TOOL_ROOT` hoặc `ACT_ELF_DIR` nếu muốn dùng
một installation khác.

`rtl/sim/compliance/tb_act.sv` cung cấp RAM thống nhất 1 MiB, UART mô phỏng tại
`0x1000_0000` và thanh ghi pass/fail tại `0x2000_0000`. Script Python đọc trực
tiếp các segment ELF32 little-endian nên bước chạy DUT không phụ thuộc `objcopy`.

## Bare-metal C firmware

`rtl/sim/firmware/smoke/` chứa startup assembly, linker script và chương trình C
freestanding được biên dịch cho `rv32ic_zicsr_zifencei_zmmul` và link tại reset
vector `0x0000_0000`. Firmware khởi tạo stack,
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

Flow tại [`rtl/syn/dc/run.tcl`](rtl/syn/dc/run.tcl) tổng hợp trực tiếp RTL hiện tại,
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

- [`rtl/doc/verification_report.md`](rtl/doc/verification_report.md)
- [`rtl/doc/performance_analysis.md`](rtl/doc/performance_analysis.md)

Kết quả xác minh gần nhất cho phần RV32C: RTL regression 30/30, ACT4 86/86 và
firmware smoke 1/1. Các báo cáo chi tiết trên vẫn ghi lại số liệu area/timing của
phiên bản trước RV32C và cần được cập nhật sau lần synthesis kế tiếp.
