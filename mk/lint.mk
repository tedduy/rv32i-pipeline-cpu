# Production RTL lint policy and report.

LINT_CONFIG := rtl/lint/verilator.vlt
LINT_REPORT_DIR := rtl/lint/reports
LINT_REPORT := $(LINT_REPORT_DIR)/verilator_lint.log

.PHONY: lint

lint:
	@$(call require_tool,$(VERILATOR))
	@mkdir -p "$(LINT_REPORT_DIR)"
	@set -o pipefail; \
	$(VERILATOR) --lint-only --timing --Wall \
		"$(LINT_CONFIG)" --top-module tdrv32_top -f "$(RTL_FILELIST)" \
		2>&1 | tee "$(LINT_REPORT)"
