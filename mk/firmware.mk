# Bare-metal smoke firmware built with the project-local ACT4 toolchain.

RISCV_PREFIX ?= $(ACT_TOOL_ROOT)/toolchain/bin/riscv32-none-elf-
FW_CC := $(RISCV_PREFIX)gcc
FW_OBJDUMP := $(RISCV_PREFIX)objdump
FW_SIZE := $(RISCV_PREFIX)size

FW_DIR := firmware/smoke
FW_BUILD_DIR := build/firmware/smoke
FW_ELF := $(FW_BUILD_DIR)/smoke.elf
FW_ARCH ?= rv32imc_zicsr_zifencei

FW_CFLAGS := -march=$(FW_ARCH) -mabi=ilp32 -mcmodel=medlow \
	-msmall-data-limit=0 -O2 -g -ffreestanding -fno-builtin -fno-common \
	-ffunction-sections -fdata-sections -Wall -Wextra -Werror
FW_LDFLAGS := -nostdlib -nostartfiles -Wl,--gc-sections,--no-relax \
	-Wl,-Map,$(FW_BUILD_DIR)/smoke.map -T $(FW_DIR)/linker.ld

.PHONY: firmware-build firmware-run

firmware-build:
	@test -x "$(FW_CC)" || { \
		echo "Missing RISC-V compiler: $(FW_CC)"; exit 1; \
	}
	@mkdir -p "$(FW_BUILD_DIR)"
	@$(FW_CC) $(FW_CFLAGS) $(FW_LDFLAGS) \
		$(FW_DIR)/start.S $(FW_DIR)/main.c -o "$(FW_ELF)"
	@$(FW_OBJDUMP) -d -S "$(FW_ELF)" > "$(FW_BUILD_DIR)/smoke.dump"
	@$(FW_SIZE) "$(FW_ELF)"

firmware-run: firmware-build act-compile
	@python3 scripts/run_act.py "$(FW_ELF)" --simv "$(ACT_SIMV)" \
		--work-dir "$(FW_BUILD_DIR)" --max-cycles 100000 \
		--suite-name "Firmware smoke test"
