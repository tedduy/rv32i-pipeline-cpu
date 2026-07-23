# Verilator structural coverage and architectural functional coverage.

# Format: top-level:test-module:coverage-file-stem
COVERAGE_SUITES := \
	tdrv32_core:test_core:core \
	rv32c_decompressor:test_decompressor:decompressor \
	load_store_unit:test_load_store:load_store \
	branch_unit:test_branch:branch \
	csr_file:test_csr:csr \
	control_unit:test_control:control \
	rv32c_fetch_buffer:test_fetch_buffer:fetch_buffer \
	program_counter:test_program_counter:program_counter \
	jump_unit:test_jump:jump \
	if_id_register:test_pipeline_register:if_id_register \
	id_ex_register:test_pipeline_register:id_ex_register \
	ex_mem_register:test_pipeline_register:ex_mem_register \
	mem_wb_register:test_pipeline_register:mem_wb_register \
	iterative_multiplier:test_iterative_multiplier:multiplier \
	iterative_divider:test_iterative_divider:divider
COVERAGE_STEMS := $(foreach suite,$(COVERAGE_SUITES),$(word 3,$(subst :, ,$(suite))))
CORE_HIGH_COVERAGE := build/coverage/core_high.dat
COVERAGE_FILES := $(addprefix build/coverage/,$(addsuffix .dat,$(COVERAGE_STEMS))) \
	$(CORE_HIGH_COVERAGE)
COVERAGE_DATABASE := build/coverage/coverage.dat
COVERAGE_REPORT := build/coverage/code_coverage.json
COVERAGE_POLICY := verification/coverage_policy.json
FUNCTIONAL_COVERAGE_REPORT := build/coverage/functional_coverage.json
RV32C_FUNCTIONAL_COVERAGE_REPORT := build/coverage/rv32c_functional_coverage.json

.PHONY: coverage

coverage: check-cocotb
	@$(call require_tool,verilator_coverage)
	@mkdir -p build/coverage
	@rm -f $(COVERAGE_FILES) "$(FUNCTIONAL_COVERAGE_REPORT)" \
		"$(RV32C_FUNCTIONAL_COVERAGE_REPORT)"
	@set -e; \
	for suite in $(COVERAGE_SUITES); do \
		IFS=: read -r top tests stem <<< "$$suite"; \
		PATH="$(VENV_BIN):$$PATH" $(MAKE) --no-print-directory \
			-C "$(COCOTB_DIR)" SIM=verilator RTL_COVERAGE=1 \
			COCOTB_TOPLEVEL="$$top" COCOTB_TEST_MODULES="$$tests" \
			COVERAGE_FILE="$$stem.dat" \
			FUNCTIONAL_COVERAGE_FILE="$(abspath $(FUNCTIONAL_COVERAGE_REPORT))" \
			RV32C_FUNCTIONAL_COVERAGE_FILE="$(abspath $(RV32C_FUNCTIONAL_COVERAGE_REPORT))"; \
	done
	@PATH="$(VENV_BIN):$$PATH" $(MAKE) --no-print-directory \
		-C "$(COCOTB_DIR)" SIM=verilator RTL_COVERAGE=1 \
		COCOTB_TOPLEVEL=tdrv32_core \
		COCOTB_TEST_MODULES=test_core_high_address \
		COVERAGE_FILE=core_high.dat \
		SIM_BUILD="$(abspath build/cocotb/verilator-coverage-core-high)" \
		EXTRA_ARGS="-GRESET_VECTOR=0xA5A50000"
	@verilator_coverage --annotate-min 1 \
		--annotate build/coverage/annotated $(COVERAGE_FILES)
	@verilator_coverage --write "$(COVERAGE_DATABASE)" \
		$(COVERAGE_FILES)
	@"$(VENV_BIN)/python" verification/check_code_coverage.py \
		"$(COVERAGE_DATABASE)" --policy "$(COVERAGE_POLICY)" \
		--report "$(COVERAGE_REPORT)"
	@"$(VENV_BIN)/python" verification/cocotb/functional_coverage.py \
		"$(FUNCTIONAL_COVERAGE_REPORT)"
	@"$(VENV_BIN)/python" verification/cocotb/functional_coverage.py \
		"$(RV32C_FUNCTIONAL_COVERAGE_REPORT)"
