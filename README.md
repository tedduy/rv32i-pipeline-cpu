# RV32IMC 5-Stage Pipeline CPU

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

ISA hiện tại là RV32IMC cùng `Zicsr`, `Zifencei` và `Zicntr`. Phần
`Zca` của compressed extension được giải nén ở fetch stage; PC tiến thêm 2 hoặc
4 byte và fetch buffer ghép được lệnh 32-bit bắt đầu tại nửa trên của một word.
Full M cung cấp bốn phép nhân qua multiplier iterative và `DIV`, `DIVU`, `REM`,
`REMU` qua divider restoring radix-2. Cả hai datapath thực hiện một bước mỗi
chu kỳ và hoàn tất sau 32 chu kỳ, ưu tiên area nhỏ cho MCU hơn throughput.
Pipeline giữ instruction ở EX cho tới khi kết quả sẵn sàng.

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
4. [`rtl/logical/stages/execute/`](rtl/logical/stages/execute/) — ALU cùng multiplier/divider iterative.
5. [`rtl/logical/hazard/`](rtl/logical/hazard/) — stall, flush và forwarding.
6. [`verification/cocotb/test_core.py`](verification/cocotb/test_core.py) — scoreboard và kiểm thử toàn CPU qua public interface.

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
│   ├── lint/                 # Verilator lint policy
│   ├── sim/                  # ACT4 harness và firmware mô phỏng
│   ├── syn/                  # Synthesis flows
│   ├── sdc/                  # Timing constraints
│   ├── cdc/                  # Clock-domain crossing collateral
│   ├── rdc/                  # Reset-domain crossing collateral
│   └── doc/                  # RTL và verification documents
├── verification/
│   ├── cocotb/               # Testbench kiến trúc và unit coverage
│   └── formal/               # SymbiYosys properties
├── mk/                       # Các flow được Makefile nạp
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

## Quick start cho checkout mới

Flow mặc định chỉ dùng công cụ open-source:

- GNU Make, `curl`, `tar` và Python 3 có hỗ trợ `venv`.
- OSS CAD Suite: Verilator, Icarus Verilog, Yosys, SymbiYosys và Boolector.
- Cocotb được cài riêng vào `.venv` để tương thích với Python của hệ thống.

Cài OSS CAD Suite vào repo (Linux x64):

```bash
mkdir -p .tools
curl -L --fail --retry 3 \
  -o /tmp/oss-cad-suite.tgz \
  https://github.com/YosysHQ/oss-cad-suite-build/releases/download/2026-05-08/oss-cad-suite-linux-x64-20260508.tgz
tar -xzf /tmp/oss-cad-suite.tgz -C .tools
```

Mỗi terminal mới cần kích hoạt toolchain, sau đó tạo môi trường Python:

```bash
source .tools/oss-cad-suite/environment
make verification-setup
make doctor
```

Các lệnh thường dùng:

```bash
make test       # Cocotb trên cả Verilator và Icarus
make lint       # Dùng setup và ghi report trong rtl/lint/
make coverage   # Code-coverage ratchet + functional bins 100%
make ci         # Lint + test + random + coverage + synthesis + formal
make clean      # Xóa toàn bộ artifact trong build/
```

`make help` là mục lục các flow. Chi tiết verification nằm trong
[`verification/README.md`](verification/README.md). CI GitHub chạy cùng lệnh
`make ci`, nên kết quả local và pull request dùng chung một quality gate.

ACT4 và RISC-V GCC là dependency tùy chọn, không cần để chạy `make ci`. Chúng
chỉ cần cho architectural compliance và firmware smoke test; kiểm tra môi
trường riêng bằng `make act-tools-check`.

## Architectural compliance (ACT4)

Thư mục [`rtl/sim/compliance/act4/`](rtl/sim/compliance/act4/) chứa cấu hình cho flow ACT4 chính
thức. Profile hiện tại kiểm tra `I`, `M`, `Zca`, `Zicsr`, `Zifencei` và
`Zicntr`; machine-mode `Sm` cung cấp architectural context. `ExceptionsSm` được
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

# Chạy tám ELF multiply/divide của full M
make act-m
```

Có thể override `ACT_ROOT`, `ACT_TOOL_ROOT` hoặc `ACT_ELF_DIR` nếu muốn dùng
một installation khác.

`rtl/sim/compliance/tb_act.sv` cung cấp RAM thống nhất 1 MiB, UART mô phỏng tại
`0x1000_0000` và thanh ghi pass/fail tại `0x2000_0000`. Script Python đọc trực
tiếp các segment ELF32 little-endian nên bước chạy DUT không phụ thuộc `objcopy`.

## Bare-metal C firmware

`rtl/sim/firmware/smoke/` chứa startup assembly, linker script và chương trình C
freestanding được biên dịch cho `rv32imc_zicsr_zifencei` và link tại reset
vector `0x0000_0000`. Firmware khởi tạo stack,
xóa `.bss`, cài `mtvec`, kiểm tra tám lệnh M, đọc `cycle`/`instret`, thực thi
`FENCE.I` và in kết quả qua UART mô phỏng tại `0x1000_0000`.

Flow dùng GCC nằm trong `.tools/act4/toolchain/`, không sửa `PATH` hoặc cài
toolchain vào hệ thống:

```bash
# Tạo ELF, map và disassembly trong build/firmware/smoke/
make firmware-build

# Compile ELF harness bằng Icarus rồi chạy firmware
make firmware-run
```

Firmware báo pass bằng cách ghi giá trị `1` tới thanh ghi trạng thái mô phỏng
tại `0x2000_0000`. Exception hoặc interrupt ngoài dự kiến đi vào `trap_entry`
và báo fail.

## Synthesis sanity check

`make synth-yosys` đọc đúng production file list, kiểm tra hierarchy và tổng
hợp `rv32i_core`. Đây là synthesizability gate trong `make ci`; kết quả nằm tại
`build/synth/yosys/rv32i_core/`. Có thể chọn top khác bằng
`make synth-yosys SYNTH_TOP=rv32i_top`.

## FPGA

Wrapper và Quartus project DE2-115 nằm tại [`fpga/de2_115/`](fpga/de2_115/).

Top-level FPGA là `de2_115_top`; top-level CPU vẫn là `rv32i_top`.

## Tài liệu kết quả

- [`rtl/doc/verification_report.md`](rtl/doc/verification_report.md)
- [`rtl/doc/performance_analysis.md`](rtl/doc/performance_analysis.md)

Kết quả xác minh gần nhất cho RV32IMC: RTL regression 32/32, ACT4 90/90 và
firmware smoke 1/1. Các báo cáo chi tiết trên vẫn ghi lại số liệu area/timing của
phiên bản trước RV32C và cần được cập nhật sau lần synthesis kế tiếp.
