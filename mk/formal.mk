# Protocol properties and RVFI ISA checks.

RISCV_FORMAL_REV := c992aa61fdfe0846c5ed90324c596202a1c69b76
RISCV_FORMAL_DIR := $(TOOLS_DIR)/riscv-formal
RISCV_FORMAL_CORE_DIR := $(RISCV_FORMAL_DIR)/cores/tdrv32
FORMAL_RENDERER := scripts/render_formal_configs.py
PROTOCOL_FORMAL_TEMPLATE := verification/formal/protocol/tdrv32_core_protocol.sby.in
PROTOCOL_FORMAL_CONFIG := build/formal/protocol/tdrv32_core_protocol.sby
AHB_FORMAL_TEMPLATE := verification/formal/ahb/native_to_ahb_lite_protocol.sby.in
AHB_FORMAL_CONFIG := build/formal/ahb/native_to_ahb_lite_protocol.sby
TOP_AHB_FORMAL_TEMPLATE := verification/formal/ahb/tdrv32_top_ahb_protocol.sby.in
TOP_AHB_FORMAL_CONFIG := build/formal/ahb/tdrv32_top_ahb_protocol.sby
RISCV_FORMAL_TEMPLATE := verification/formal/riscv/checks.cfg.in
RISCV_FORMAL_CONFIG := $(CURDIR)/build/formal/riscv/checks.cfg
RISCV_FORMAL_JOBS ?= 4

.PHONY: formal riscv-formal-setup riscv-formal-generate riscv-formal \
	riscv-formal-all

formal:
	@$(call require_tool,$(SBY))
	@$(SYSTEM_PYTHON) "$(FORMAL_RENDERER)" \
		--filelist "$(RTL_FILELIST)" \
		--template "$(PROTOCOL_FORMAL_TEMPLATE)" \
		--output "$(PROTOCOL_FORMAL_CONFIG)" \
		--format protocol
	@$(SYSTEM_PYTHON) "$(FORMAL_RENDERER)" \
		--filelist "$(RTL_FILELIST)" \
		--template "$(AHB_FORMAL_TEMPLATE)" \
		--output "$(AHB_FORMAL_CONFIG)" \
		--format protocol
	@$(SYSTEM_PYTHON) "$(FORMAL_RENDERER)" \
		--filelist "$(RTL_FILELIST)" \
		--template "$(TOP_AHB_FORMAL_TEMPLATE)" \
		--output "$(TOP_AHB_FORMAL_CONFIG)" \
		--format protocol
	@$(SBY) -f "$(PROTOCOL_FORMAL_CONFIG)"
	@$(SBY) -f "$(AHB_FORMAL_CONFIG)"
	@$(SBY) -f "$(TOP_AHB_FORMAL_CONFIG)"

riscv-formal-setup:
	@if [ ! -d "$(RISCV_FORMAL_DIR)/.git" ]; then \
		mkdir -p "$(dir $(RISCV_FORMAL_DIR))"; \
		git clone https://github.com/YosysHQ/riscv-formal.git \
			"$(RISCV_FORMAL_DIR)"; \
	fi
	@git -C "$(RISCV_FORMAL_DIR)" cat-file -e \
		"$(RISCV_FORMAL_REV)^{commit}" 2>/dev/null || \
		git -C "$(RISCV_FORMAL_DIR)" fetch --quiet origin "$(RISCV_FORMAL_REV)"
	@git -C "$(RISCV_FORMAL_DIR)" checkout --quiet --detach "$(RISCV_FORMAL_REV)"
	@test "$$(git -C "$(RISCV_FORMAL_DIR)" rev-parse HEAD)" = \
		"$(RISCV_FORMAL_REV)"

riscv-formal-generate: riscv-formal-setup
	@$(SYSTEM_PYTHON) "$(FORMAL_RENDERER)" \
		--filelist "$(RTL_FILELIST)" \
		--template "$(RISCV_FORMAL_TEMPLATE)" \
		--output "$(RISCV_FORMAL_CONFIG)" \
		--format riscv
	@mkdir -p "$(RISCV_FORMAL_CORE_DIR)"
	@cp "$(RISCV_FORMAL_CONFIG)" "$(RISCV_FORMAL_CORE_DIR)/checks.cfg"
	@cd "$(RISCV_FORMAL_CORE_DIR)" && \
		"$(SYSTEM_PYTHON)" ../../checks/genchecks.py
	@sed -i '/^\[file defines\.sv\]$$/a `define TDRV32_FORMAL_REG_HISTORY' \
		"$(RISCV_FORMAL_CORE_DIR)/checks/reg_ch0.sby"

riscv-formal: riscv-formal-generate
	@$(call require_tool,$(SBY))
	@$(MAKE) --no-print-directory -j$(RISCV_FORMAL_JOBS) \
		-C "$(RISCV_FORMAL_CORE_DIR)/checks"
	@set -e; \
	for status in "$(RISCV_FORMAL_CORE_DIR)"/checks/*/status; do \
		grep -q '^PASS ' "$$status" || { \
			echo "riscv-formal failed: $${status%/status}"; \
			exit 1; \
		}; \
	done

riscv-formal-all: riscv-formal-setup
	@$(call require_tool,$(SBY))
	@$(SYSTEM_PYTHON) "$(FORMAL_RENDERER)" \
		--filelist "$(RTL_FILELIST)" \
		--template "$(RISCV_FORMAL_TEMPLATE)" \
		--output "$(RISCV_FORMAL_CONFIG)" \
		--format riscv
	@mkdir -p "$(RISCV_FORMAL_CORE_DIR)"
	@awk 'BEGIN { skip=0 } \
		/^\[filter-checks\]/ { skip=1; next } \
		skip && /^\[/ { skip=0 } \
		!skip { print }' "$(RISCV_FORMAL_CONFIG)" \
		> "$(RISCV_FORMAL_CORE_DIR)/checks-all.cfg"
	@cd "$(RISCV_FORMAL_CORE_DIR)" && \
		"$(SYSTEM_PYTHON)" ../../checks/genchecks.py checks-all
	@sed -i '/^\[file defines\.sv\]$$/a `define TDRV32_FORMAL_REG_HISTORY' \
		"$(RISCV_FORMAL_CORE_DIR)/checks-all/reg_ch0.sby"
	@$(MAKE) --no-print-directory -j$(RISCV_FORMAL_JOBS) \
		-C "$(RISCV_FORMAL_CORE_DIR)/checks-all"
	@set -e; \
	for status in "$(RISCV_FORMAL_CORE_DIR)"/checks-all/*/status; do \
		grep -q '^PASS ' "$$status" || { \
			echo "riscv-formal failed: $${status%/status}"; \
			exit 1; \
		}; \
	done
