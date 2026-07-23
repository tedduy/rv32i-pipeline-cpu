# Reproducible project-local tool bootstrap.

.PHONY: setup tools-setup tools-versions oss-cad-setup \
	riscv-toolchain-setup

setup: tools-setup verification-setup

tools-setup: oss-cad-setup riscv-toolchain-setup riscv-formal-setup
	@echo "Tools ready under $(TOOLS_DIR)"
	@echo "Run: make doctor"

tools-versions:
	@$(call require_tool,$(IVERILOG))
	@$(call require_tool,$(VERILATOR))
	@$(call require_tool,$(YOSYS))
	@$(call require_tool,$(SBY))
	@$(IVERILOG) -V 2>/dev/null | head -n 1
	@$(VERILATOR) --version
	@$(YOSYS) -V
	@$(SBY) --version

oss-cad-setup:
	@bash scripts/setup_tools.sh oss-cad

riscv-toolchain-setup:
	@bash scripts/setup_tools.sh riscv-toolchain
