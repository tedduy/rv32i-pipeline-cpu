# Implementation Plan: RV32A (Atomics) Extension

Mục tiêu của plan này là thêm hỗ trợ tập lệnh RV32A vào vi xử lý TDRV32. RV32A rất quan trọng để chạy FreeRTOS an toàn (hỗ trợ các Mutex, Semaphore, và Queue thread-safe).

## User Review Required

> [!WARNING]
> **Pipeline Stall & AMO ALU**: Để thực hiện các lệnh AMO (VD: `amoadd.w`) trong 1 pipeline 5-stage truyền thống mà không làm phức tạp hóa Decode stage (bằng cách tách thành 2 micro-ops), tôi đề xuất thêm một **bộ AMO ALU nhỏ ngay trong MEM stage**. MEM stage sẽ thực hiện quá trình: Đọc Memory -> Tính toán AMO -> Ghi Memory. Quá trình này sẽ làm MEM stage bị stall thêm vài chu kỳ (thông qua tín hiệu `o_stall`), nhưng giữ cho pipeline sạch sẽ và dễ thiết kế.
> Bạn có đồng ý với thiết kế này không?

## Proposed Changes

### 1. Phân loại lệnh và Control Unit

#### [MODIFY] `rtl/logical/stages/decode/control_unit.sv`
- Nhận diện `OP_AMO` (opcode `7'b0101111`).
- Giải mã 2 nhóm lệnh:
  - **LR/SC**: `lr.w` và `sc.w`.
  - **AMOs**: `amoswap.w`, `amoadd.w`, `amoxor.w`, `amoand.w`, `amoor.w`, `amomin.w`, `amomax.w`, `amominu.w`, `amomaxu.w`.
- Tạo các tín hiệu điều khiển mới: `o_amo_en`, `o_amo_op` đẩy qua EX và tới MEM stage.

### 2. EX/MEM Pipeline Register

#### [MODIFY] `rtl/logical/pipeline/ex_mem_register.sv`
- Truyền các tín hiệu AMO (`amo_en`, `amo_op`) từ EX sang MEM.
- Truyền giá trị của `rs2` (đã được forward) vào MEM stage để làm toán hạng thứ 2 cho lệnh AMO.

### 3. Load/Store Unit & MEM Stage

#### [MODIFY] `rtl/logical/stages/memory/load_store_unit.sv` (hoặc module tương đương quản lý MEM)
- **Hỗ trợ LR/SC**:
  - Thêm 1 thanh ghi `reservation_addr` và 1 bit `reservation_valid`.
  - Khi gặp `lr.w`: Đọc bộ nhớ, lưu địa chỉ vào `reservation_addr`, set `reservation_valid = 1`.
  - Khi gặp `sc.w`: Kiểm tra địa chỉ có khớp và `valid` không. Nếu đúng -> Ghi bộ nhớ và trả về `0` cho `rd`. Nếu sai -> Bỏ qua ghi và trả về `1` cho `rd`.
- **Hỗ trợ AMOs (Read-Modify-Write State Machine)**:
  - Thêm một State Machine nhỏ: `IDLE` -> `READ` -> `MODIFY_WRITE` -> `DONE`.
  - Thêm **AMO ALU** hỗ trợ các phép tính cơ bản.
  - Assert tín hiệu `stall` cho pipeline trong quá trình thực hiện nhiều chu kỳ truy cập bus.

#### [MODIFY] `rtl/logical/system/csr_file.sv`
- Xóa `reservation_valid` mỗi khi xảy ra Exception / Trap (Interrupt). (Gửi tín hiệu `clear_reservation` từ CSR tới LSU).

### 4. Cấu hình Compiler & Test

#### [MODIFY] `mk/firmware.mk`
- Đổi cờ biên dịch từ `-march=rv32imc` sang `-march=rv32imac`.

#### [NEW] `verification/cocotb/test_atomics.py`
- Viết testbench chạy các lệnh A-extension cơ bản để đảm bảo AMO tính toán đúng và LR/SC tuân thủ nguyên tắc reservation.

## Verification Plan

### Automated Tests
- Chạy lại toàn bộ `make ci`. (Bao gồm random-regression nếu sửa được lỗi môi trường, và RISC-V Formal cho tập lệnh A).
- Chạy firmware test mới chứa mã ASM kiểm tra các lệnh AMO.

### Manual Verification
- Dịch FreeRTOS với cờ `-march=rv32imac` và kiểm tra xem FreeRTOS có sử dụng cấu trúc `lr.w`/`sc.w` thay vì tắt ngắt toàn cục khi thao tác context hay không.
