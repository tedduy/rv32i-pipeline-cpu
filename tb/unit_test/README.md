# Unit Tests cho RISC-V Pipeline CPU

## Mục đích

Unit tests này được tạo để **verify chức năng của từng module riêng lẻ** trong RISC-V pipeline CPU. Mỗi test kiểm tra một module cụ thể để đảm bảo nó hoạt động đúng trước khi tích hợp vào hệ thống hoàn chỉnh.

**Dành cho:**
- Phát hiện lỗi logic trong từng module
- Debug nhanh khi có vấn đề
- Regression testing khi sửa code
- Đảm bảo chất lượng code trước khi integration

## Danh sách Tests

### 1. **tb_alu_unit.sv** - ALU Unit
- Arithmetic operations (ADD, SUB)
- Logical operations (AND, OR, XOR)
- Comparison operations (SLT, SLTU)
- Shift operations (SLL, SRL, SRA)
- Zero flag

### 2. **tb_reg_file.sv** - Register File
- Reset functionality
- x0 always returns 0
- Write and read operations
- Dual read ports
- Initial values

### 3. **tb_imm_gen.sv** - Immediate Generator
- I-type immediate (ADDI, LOAD, JALR)
- S-type immediate (STORE)
- B-type immediate (BRANCH)
- U-type immediate (LUI, AUIPC)
- J-type immediate (JAL)

### 4. **tb_branch_unit.sv** - Branch Unit
- BEQ (Branch if Equal)
- BNE (Branch if Not Equal)
- BLT (Branch if Less Than - signed)
- BGE (Branch if Greater or Equal - signed)
- BLTU (Branch if Less Than - unsigned)
- BGEU (Branch if Greater or Equal - unsigned)
- Branch enable control

### 5. **tb_jump_unit.sv** - Jump Unit
- JAL (Jump and Link)
- JALR (Jump and Link Register)
- Return address calculation
- LSB clearing for JALR

### 6. **tb_load_store_unit.sv** - Load/Store Unit
- Load operations (LB, LH, LW, LBU, LHU)
- Store operations (SB, SH, SW)
- Byte enable generation
- Sign extension

### 7. **tb_control_unit.sv** - Control Unit
- R-type instructions (ADD, SUB, AND, OR, etc.)
- I-type instructions (ADDI, ANDI, etc.)
- Load instructions (LW, LB, etc.)
- Store instructions (SW, SB, etc.)
- Branch instructions (BEQ, BNE, etc.)
- Jump instructions (JAL, JALR)
- U-type instructions (LUI, AUIPC)

### 8. **tb_program_counter.sv** - Program Counter
- Reset functionality
- PC update
- Sequential increment
- Jump (non-sequential)

### 9. **tb_instruction_mem.sv** - Instruction Memory
- Reset test
- Sequential read
- Random access
- Boundary addresses
- Word alignment

### 10. **tb_data_memory.sv** - Data Memory
- Reset test
- Word write/read
- Byte write/read
- Halfword write/read
- Multiple addresses
- Read enable control

## How to Run

### Yêu cầu
- QuestaSim/ModelSim
- Make

### Chạy từng test riêng lẻ

```bash
# Chạy test cụ thể
make run TB=tb_alu_unit
make run TB=tb_reg_file
make run TB=tb_control_unit

# Xem waveform
make wave TB=tb_alu_unit
```

### Chạy tất cả unit tests

```bash
# Chạy 10 unit tests
make unit
```

### Chạy toàn bộ (unit + integration)

```bash
# Compile + unit tests + pipeline + verification
make all
```

### Các lệnh khác

```bash
# Compile only
make compile

# Clean
make clean

# Help
make help
```

## Kết quả

Mỗi test sẽ hiển thị:
- ✓ PASSED - Test thành công
- ✗ FAILED - Test thất bại

Logs được lưu tự động trong `sim/logs/`:
- `tb_alu_unit.log`
- `tb_reg_file.log`
- ...
- `unit_tests_summary.log` (tổng hợp)

## Cấu trúc Test

Mỗi testbench được tổ chức theo:
- **Tasks**: Phân chia theo chức năng cần test
- **Clean code**: Dễ đọc, dễ maintain
- **Simple**: Chỉ test đúng chức năng cơ bản
- **Pass/Fail reporting**: Hiển thị rõ ràng kết quả

## Ví dụ Output

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
