# Bare-metal smoke firmware built with the project-local RISC-V toolchain and
# executed by Cocotb on Verilator.

RISCV_PREFIX ?= $(RISCV_TOOLCHAIN_DIR)/bin/riscv32-none-elf-
FW_CC := $(RISCV_PREFIX)gcc
FW_OBJDUMP := $(RISCV_PREFIX)objdump
FW_SIZE := $(RISCV_PREFIX)size

FW_DIR := firmware/smoke
FW_BUILD_DIR := build/firmware/smoke
FW_ELF := $(FW_BUILD_DIR)/smoke.elf
FW_ARCH ?= rv32imc_zicsr_zifencei
FW_MAX_CYCLES ?= 100000
FW_COCOTB_BUILD := $(CURDIR)/build/cocotb/verilator-firmware

FW_CFLAGS := -march=$(FW_ARCH) -mabi=ilp32 -mcmodel=medlow \
	-msmall-data-limit=0 -O2 -g -ffreestanding -fno-builtin -fno-common \
	-ffunction-sections -fdata-sections -Wall -Wextra -Werror
FW_LDFLAGS := -nostdlib -nostartfiles -Wl,--gc-sections,--no-relax \
	-Wl,-Map,$(FW_BUILD_DIR)/smoke.map -T $(FW_DIR)/linker.ld

.PHONY: firmware-build firmware-run firmware-run-verilator

firmware-build:
	@test -x "$(FW_CC)" || { \
		echo "Missing RISC-V compiler: $(FW_CC)"; \
		echo "Run: make riscv-toolchain-setup"; \
		exit 1; \
	}
	@mkdir -p "$(FW_BUILD_DIR)"
	@$(FW_CC) $(FW_CFLAGS) $(FW_LDFLAGS) \
		$(FW_DIR)/start.S $(FW_DIR)/main.c -o "$(FW_ELF)"
	@$(FW_OBJDUMP) -d -S "$(FW_ELF)" > "$(FW_BUILD_DIR)/smoke.dump"
	@$(FW_SIZE) "$(FW_ELF)"

firmware-run: firmware-run-verilator

firmware-run-verilator: firmware-build check-cocotb
	@PATH="$(VENV_BIN):$$PATH" $(MAKE) --no-print-directory \
		-C verification/cocotb SIM=verilator \
		SIM_BUILD="$(FW_COCOTB_BUILD)" \
		COCOTB_TEST_MODULES=test_firmware \
		COCOTB_TEST_FILTER= \
		FIRMWARE_ELF="$(abspath $(FW_ELF))" \
		FIRMWARE_MAX_CYCLES="$(FW_MAX_CYCLES)"
