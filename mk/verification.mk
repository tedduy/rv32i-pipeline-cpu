# Open-source lint, simulation, coverage, formal and synthesis flows.

COCOTB_DIR := verification/cocotb
ICARUS_WRAPPERS := $(CURDIR)/scripts/icarus-cocotb
RANDOM_SEEDS ?= 0x5eed1234 0x1badb002 0xdeadbeef

SYNTH_TOP ?= rv32i_core
YOSYS_DIR := build/synth/yosys/$(SYNTH_TOP)

LINT_CONFIG := rtl/lint/verilator.vlt
LINT_REPORT_DIR := rtl/lint/reports
LINT_REPORT := $(LINT_REPORT_DIR)/verilator_lint.log

# Format: top-level:test-module:coverage-file-stem
COVERAGE_SUITES := \
	rv32i_core:test_core:core \
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

.PHONY: verification-setup check-cocotb lint \
	cocotb-verilator cocotb-iverilog random-regression coverage formal \
	synth-yosys

verification-setup:
	@$(SYSTEM_PYTHON) -m venv "$(VENV)"
	@"$(VENV_BIN)/python" -m pip install --upgrade pip
	@"$(VENV_BIN)/python" -m pip install -r verification/requirements.txt

check-cocotb:
	@test -x "$(VENV_BIN)/cocotb-config" || { \
		echo "Missing Cocotb environment. Run: make verification-setup"; \
		exit 1; \
	}

lint:
	@$(call require_tool,$(VERILATOR))
	@mkdir -p "$(LINT_REPORT_DIR)"
	@set -o pipefail; \
	$(VERILATOR) --lint-only --timing --Wall \
		"$(LINT_CONFIG)" --top-module rv32i_top -f "$(RTL_FILELIST)" \
		2>&1 | tee "$(LINT_REPORT)"

cocotb-verilator: check-cocotb
	@PATH="$(VENV_BIN):$$PATH" $(MAKE) --no-print-directory \
		-C "$(COCOTB_DIR)" SIM=verilator

cocotb-iverilog: check-cocotb
	@PATH="$(VENV_BIN):$$PATH" $(MAKE) --no-print-directory \
		-C "$(COCOTB_DIR)" SIM=icarus ICARUS_BIN_DIR="$(ICARUS_WRAPPERS)"

random-regression: check-cocotb
	@set -e; \
	for seed in $(RANDOM_SEEDS); do \
		echo "Constrained-random seed $$seed"; \
		PATH="$(VENV_BIN):$$PATH" CORE_RANDOM_SEED="$$seed" \
			COCOTB_TEST_FILTER=constrained_random \
			$(MAKE) --no-print-directory -C "$(COCOTB_DIR)" SIM=verilator; \
	done

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
		COCOTB_TOPLEVEL=rv32i_core \
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

formal:
	@$(call require_tool,$(SBY))
	@$(SBY) -f verification/formal/rv32i_core_protocol.sby

synth-yosys:
	@$(call require_tool,$(YOSYS))
	@mkdir -p "$(YOSYS_DIR)"
	@$(YOSYS) -q -l "$(YOSYS_DIR)/yosys.log" -p \
		'read_verilog -sv $(RTL_SOURCES); hierarchy -check -top $(SYNTH_TOP); proc; opt; check -assert; synth -top $(SYNTH_TOP); check -assert; stat'
