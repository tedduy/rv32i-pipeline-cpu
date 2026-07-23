# Dependency diagnostics for a fresh checkout.

REQUIRED_TOOLS := \
	$(IVERILOG) \
	vvp \
	$(VERILATOR) \
	verilator_coverage \
	$(YOSYS) \
	$(SBY)

.PHONY: doctor

doctor:
	@echo "Required open-source verification tools"
	@missing=0; \
	for tool in $(REQUIRED_TOOLS); do \
		if command -v "$$tool" >/dev/null 2>&1; then \
			printf "  [ok]      %s\n" "$$tool"; \
		else \
			printf "  [missing] %s\n" "$$tool"; \
			missing=1; \
		fi; \
	done; \
	if command -v "$(SYSTEM_PYTHON)" >/dev/null 2>&1; then \
		printf "  [ok]      %s\n" "$(SYSTEM_PYTHON)"; \
	else \
		printf "  [missing] %s\n" "$(SYSTEM_PYTHON)"; \
		missing=1; \
	fi; \
	if test -x "$(VENV_BIN)/cocotb-config"; then \
		printf "  [ok]      Cocotb virtual environment\n"; \
	else \
		printf "  [missing] Cocotb virtual environment\n"; \
		printf "            Run: make verification-setup\n"; \
		missing=1; \
	fi; \
	echo; \
	echo "Optional firmware toolchain"; \
	if test -x "$(RISCV_TOOLCHAIN_DIR)/bin/riscv32-none-elf-gcc"; then \
		echo "  [ok]      RISC-V GCC"; \
	else \
		echo "  [optional] RISC-V GCC is not installed"; \
		echo "             Run: make riscv-toolchain-setup"; \
	fi; \
	echo; \
	echo "Optional ACT4 tools"; \
	if test -x "$(ACT_TOOL_ROOT)/bin/mise" && \
	   test -x "$(ACT_TOOL_ROOT)/toolchain/bin/riscv32-none-elf-gcc" && \
	   test -x "$(ACT_TOOL_ROOT)/sail/bin/sail_riscv_sim" && \
	   test -f "$(ACT_ROOT)/Makefile"; then \
		echo "  [ok]      ACT4 environment"; \
	else \
		echo "  [optional] ACT4 environment is not installed"; \
	fi; \
	echo; \
	if test "$$missing" -ne 0; then \
		echo "Doctor: required dependencies are missing"; \
		exit 1; \
	fi; \
	echo "Doctor: ready to run make ci"
