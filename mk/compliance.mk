# RISC-V Architectural Compatibility Test (ACT4) flow.

ACT_TOOL_ROOT ?= $(CURDIR)/.tools/act4
ACT_ROOT ?= $(ACT_TOOL_ROOT)/riscv-arch-test
ACT_CONFIG := verification/compliance/act4/test_config.yaml
ACT_WORK_DIR ?= build/act4
ACT_SIMV := $(ACT_WORK_DIR)/tb_act.vvp
ACT_ELF_DIR ?= $(ACT_WORK_DIR)/generated/tdrv32/elfs
ACT_MAX_CYCLES ?= 1000000
ACT_MEMORY_BYTES ?= 262144
ACT_EXTENSIONS ?= I,M,Zca,Zicsr,Zifencei,Zicntr,ExceptionsZc
ACT_EXCLUDE_EXTENSIONS ?=

ACT_SM_PATCHES := \
	verification/compliance/act4/patches/0001-split-exceptions-sm.patch \
	verification/compliance/act4/patches/0002-fix-ialign32-trap-resume.patch

ifeq ($(ACT_USE_SYSTEM_TOOLS),1)
ACT_ENV := env
else
ACT_ENV := env \
	PATH="$(ACT_TOOL_ROOT)/bin:$(ACT_TOOL_ROOT)/toolchain/bin:$(ACT_TOOL_ROOT)/sail/bin:$$PATH" \
	MISE_DATA_DIR="$(ACT_TOOL_ROOT)/mise-data" \
	MISE_CACHE_DIR="$(ACT_TOOL_ROOT)/mise-cache" \
	MISE_CONFIG_DIR="$(ACT_TOOL_ROOT)/mise-config" \
	MISE_STATE_DIR="$(ACT_TOOL_ROOT)/mise-state" \
	MISE_YES=1 MISE_OFFLINE=1 \
	UV_CACHE_DIR="$(ACT_TOOL_ROOT)/uv-cache" \
	UV_PYTHON_INSTALL_DIR="$(ACT_TOOL_ROOT)/python" \
	XDG_DATA_HOME="$(ACT_TOOL_ROOT)/xdg-data" \
	XDG_CACHE_HOME="$(ACT_TOOL_ROOT)/xdg-cache" \
	XDG_CONFIG_HOME="$(ACT_TOOL_ROOT)/xdg-config"
endif

ACT_GENERATE_ARGS := \
	CONFIG_FILES="$(abspath $(ACT_CONFIG))" \
	WORKDIR="$(abspath $(ACT_WORK_DIR))/generated"

.PHONY: act-tools-check act-generate act-compile act-run act-regression \
	act-zca act-zc-exceptions-generate act-zc-exceptions act-zicsr \
	act-zifencei act-zicntr act-m act-sm-prepare act-sm-generate \
	act-sm-exceptions

act-tools-check:
	@$(ACT_ENV) sh -c 'command -v mise >/dev/null' || { echo "Missing mise"; exit 1; }
	@$(ACT_ENV) sh -c 'command -v riscv32-none-elf-gcc >/dev/null' || { \
		echo "Missing RISC-V GCC"; exit 1; \
	}
	@$(ACT_ENV) sh -c 'command -v sail_riscv_sim >/dev/null' || { \
		echo "Missing Sail model"; exit 1; \
	}
	@test -f "$(ACT_ROOT)/Makefile" || { \
		echo "Missing local riscv-arch-test checkout"; exit 1; \
	}
	@$(ACT_ENV) riscv32-none-elf-gcc --version | head -n 1
	@$(ACT_ENV) sail_riscv_sim --version
	@$(ACT_ENV) mise --version

act-generate: act-tools-check
	@mkdir -p "$(abspath $(ACT_WORK_DIR))/generated"
	@$(ACT_ENV) $(MAKE) -C "$(ACT_ROOT)" $(ACT_GENERATE_ARGS) \
		EXTENSIONS="$(ACT_EXTENSIONS)" \
		EXCLUDE_EXTENSIONS="$(ACT_EXCLUDE_EXTENSIONS)"

act-compile:
	@$(call require_tool,$(IVERILOG))
	@mkdir -p "$(ACT_WORK_DIR)"
	@$(IVERILOG) -g2012 -Wall -Wimplicit -Wno-timescale -s tb_act \
		-Ptb_act.RAM_BYTES=$(ACT_MEMORY_BYTES) \
		-o "$(ACT_SIMV)" -f "$(RTL_FILELIST)" verification/compliance/tb_act.sv

act-run: act-compile
	@test -n "$(ELF)" || { \
		echo "Specify ELF=/path/to/act4-test.elf"; exit 1; \
	}
	@python3 -u scripts/run_act.py "$(ELF)" --simv "$(ACT_SIMV)" \
		--work-dir "$(ACT_WORK_DIR)" --max-cycles "$(ACT_MAX_CYCLES)" \
		--memory-bytes "$(ACT_MEMORY_BYTES)"

act-regression: act-compile
	@python3 -u scripts/run_act.py "$(ACT_ELF_DIR)" --simv "$(ACT_SIMV)" \
		--work-dir "$(ACT_WORK_DIR)" --max-cycles "$(ACT_MAX_CYCLES)" \
		--memory-bytes "$(ACT_MEMORY_BYTES)"

act-zca: ACT_ELF_DIR := $(ACT_WORK_DIR)/generated/tdrv32/elfs/rv32i/Zca
act-zca: act-regression
act-zc-exceptions: ACT_ELF_DIR := $(ACT_WORK_DIR)/generated/tdrv32/elfs/priv/ExceptionsZc
act-zc-exceptions: act-regression
act-zicsr: ACT_ELF_DIR := $(ACT_WORK_DIR)/generated/tdrv32/elfs/rv32i/Zicsr
act-zicsr: act-regression
act-zifencei: ACT_ELF_DIR := $(ACT_WORK_DIR)/generated/tdrv32/elfs/rv32i/Zifencei
act-zifencei: act-regression
act-zicntr: ACT_ELF_DIR := $(ACT_WORK_DIR)/generated/tdrv32/elfs/rv32i/Zicntr
act-zicntr: act-regression
act-m: ACT_ELF_DIR := $(ACT_WORK_DIR)/generated/tdrv32/elfs/rv32i/M
act-m: act-regression

act-zc-exceptions-generate: act-tools-check
	@$(ACT_ENV) $(MAKE) -C "$(ACT_ROOT)" -B tests \
		EXTENSIONS=ExceptionsZc EXCLUDE_EXTENSIONS=
	@mkdir -p "$(abspath $(ACT_WORK_DIR))/generated"
	@$(ACT_ENV) $(MAKE) -C "$(ACT_ROOT)" $(ACT_GENERATE_ARGS) \
		EXTENSIONS=ExceptionsZc EXCLUDE_EXTENSIONS=

act-sm-prepare: act-tools-check
	@set -e; \
	for patch in $(addprefix $(CURDIR)/,$(ACT_SM_PATCHES)); do \
		if git -C "$(ACT_ROOT)" apply --check "$$patch" >/dev/null 2>&1; then \
			git -C "$(ACT_ROOT)" apply "$$patch"; \
		elif ! git -C "$(ACT_ROOT)" apply --reverse --check "$$patch" >/dev/null 2>&1; then \
			echo "ACT4 patch does not match checkout: $$patch"; \
			exit 1; \
		fi; \
	done

act-sm-generate: act-sm-prepare
	@find "$(ACT_ROOT)/tests/priv/ExceptionsSm" -maxdepth 1 -type f \
		-name '*.S' -delete 2>/dev/null || true
	@find "$(abspath $(ACT_WORK_DIR))/generated/tdrv32/elfs/priv/ExceptionsSm" \
		-type f -delete 2>/dev/null || true
	@$(ACT_ENV) $(MAKE) -C "$(ACT_ROOT)" -B tests \
		EXTENSIONS=ExceptionsSm EXCLUDE_EXTENSIONS=
	@mkdir -p "$(abspath $(ACT_WORK_DIR))/generated"
	@$(ACT_ENV) $(MAKE) -C "$(ACT_ROOT)" $(ACT_GENERATE_ARGS) \
		EXTENSIONS=ExceptionsSm EXCLUDE_EXTENSIONS=

act-sm-exceptions: ACT_ELF_DIR := $(ACT_WORK_DIR)/generated/tdrv32/elfs/priv/ExceptionsSm
act-sm-exceptions: act-regression
