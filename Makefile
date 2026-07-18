# ==============================================================================
# Makefile for RV32I Pipeline CPU - QuestaSim, VCS and Verdi
# ==============================================================================

.PHONY: help all clean compile rtl-compile gl-compile run unit pipeline verify gl wave wave-gl \
	vcs vcs-compile vcs-run vcs-gui vcs-regression verdi act-tools-check act-generate act-compile act-run \
	act-regression act-zicsr act-sm-prepare act-sm-generate act-sm-exceptions distclean

# Default target
.DEFAULT_GOAL := help

# ==============================================================================
# Configuration
# ==============================================================================

# Simulator
SIM = vsim
VLOG = vlog
VLIB = vlib
VCS = vcs
VERDI = verdi

# Directories
WORK_DIR = work
WORK_GL_DIR = work_gl
LOG_DIR = logs
VCS_BUILD_ROOT = build/vcs
ACT_CONFIG = compliance/act4/test_config.yaml
ACT_WORK_DIR = build/act4
ACT_MAX_CYCLES ?= 1000000
ACT_EXTENSIONS ?= I,Zicsr
ACT_EXCLUDE_EXTENSIONS ?=
ACT_TOOL_ROOT ?= $(CURDIR)/.tools/act4
ACT_ROOT ?= $(ACT_TOOL_ROOT)/riscv-arch-test
ACT_ELF_DIR ?= $(ACT_WORK_DIR)/generated/rv32i-pipeline/elfs
ACT_SM_PATCHES = compliance/act4/patches/0001-split-exceptions-sm.patch \
	compliance/act4/patches/0002-fix-ialign32-trap-resume.patch
ACT_ENV = env \
	PATH="$(ACT_TOOL_ROOT)/bin:$(ACT_TOOL_ROOT)/toolchain/bin:$(ACT_TOOL_ROOT)/sail/bin:$$PATH" \
	MISE_DATA_DIR="$(ACT_TOOL_ROOT)/mise-data" \
	MISE_CACHE_DIR="$(ACT_TOOL_ROOT)/mise-cache" \
	MISE_CONFIG_DIR="$(ACT_TOOL_ROOT)/mise-config" \
	MISE_STATE_DIR="$(ACT_TOOL_ROOT)/mise-state" \
	MISE_YES=1 \
	MISE_OFFLINE=1 \
	UV_CACHE_DIR="$(ACT_TOOL_ROOT)/uv-cache" \
	UV_PYTHON_INSTALL_DIR="$(ACT_TOOL_ROOT)/python" \
	XDG_DATA_HOME="$(ACT_TOOL_ROOT)/xdg-data" \
	XDG_CACHE_HOME="$(ACT_TOOL_ROOT)/xdg-cache" \
	XDG_CONFIG_HOME="$(ACT_TOOL_ROOT)/xdg-config"

# Compile flags
VLOG_FLAGS = -sv +acc -work $(WORK_DIR)
VLOG_GL_FLAGS = +acc -work $(WORK_GL_DIR)

# Simulation flags
VSIM_FLAGS = -c -work $(WORK_DIR)
VSIM_GL_FLAGS = -c -suppress 12110 -work $(WORK_GL_DIR)

# VCS/Verdi configuration. Override with TB=<testbench>; the pipeline
# integration test is used when TB is omitted.
VCS_TOP = $(if $(TB),$(TB),tb_rv32i_pipeline)
VCS_BUILD_DIR = $(VCS_BUILD_ROOT)/$(VCS_TOP)
VCS_SIMV = $(VCS_BUILD_DIR)/simv
VCS_FLAGS = -full64 -sverilog -timescale=1ns/1ps
VCS_FLAGS += -debug_access+all -kdb
VCS_FLAGS += -Mdir=$(VCS_BUILD_DIR)/csrc

# File lists
RTL_FILELIST = filelist.f
GL_FILELIST = filelist_netlist.f

# Sky130 PDK used only by gate-level simulation
PDK_ROOT ?=
SKY130_PRIMITIVES = $(PDK_ROOT)/sky130B/libs.ref/sky130_fd_sc_hd/verilog/primitives.v
SKY130_LIB = $(PDK_ROOT)/sky130B/libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v
PIPELINE_WAVE = wave_tb_rv32i_pipeline.do

# Unit test list
UNIT_TESTS = tb_alu_unit tb_register_file tb_immediate_generator tb_branch_unit \
             tb_jump_unit tb_load_store_unit tb_control_unit tb_program_counter \
             tb_instruction_memory tb_data_memory
UNIT_TESTS += tb_native_to_ahb_lite

INTEGRATION_TESTS = tb_rv32i_pipeline tb_full_verification tb_load_use_hazard \
                    tb_memory_wait_states tb_reset_vector tb_commit_interface \
                    tb_machine_csr_trap tb_machine_external_interrupt \
                    tb_machine_exceptions tb_machine_identification_csrs
INTEGRATION_TESTS += tb_bus_access_faults
INTEGRATION_TESTS += tb_ahb_lite_interface
INTEGRATION_TESTS += tb_wfi_sleep

VCS_REGRESSION_TESTS = $(UNIT_TESTS) $(INTEGRATION_TESTS)

# ==============================================================================
# Help
# ==============================================================================

help:
	@echo "=========================================="
	@echo "RV32I Pipeline CPU - Makefile"
	@echo "=========================================="
	@echo ""
	@echo "RTL Simulation Commands:"
	@echo "  make compile          - Compile RTL and testbenches"
	@echo "  make rtl-compile      - Compile RTL and testbenches"
	@echo "  make run TB=<name>    - Run specific testbench"
	@echo "  make wave TB=<name>   - Open an RTL testbench in the waveform viewer"
	@echo "  make unit             - Run all unit tests (10 tests)"
	@echo "  make pipeline         - Run pipeline integration test"
	@echo "  make verify           - Run write-back verification"
	@echo "  make all              - Compile + run all tests"
	@echo ""
	@echo "Synopsys VCS/Verdi Commands:"
	@echo "  make vcs TB=<name>         - Compile and run a testbench with VCS"
	@echo "  make vcs-compile TB=<name> - Compile a testbench with VCS"
	@echo "  make vcs-run TB=<name>     - Compile and run a testbench with VCS"
	@echo "  make vcs-regression        - Run all unit/integration tests with VCS"
	@echo "  make vcs-gui TB=<name>     - Run the VCS executable in Verdi GUI mode"
	@echo "  make verdi TB=<name>       - Open the compiled VCS design in Verdi"
	@echo "  Default TB: tb_rv32i_pipeline"
	@echo ""
	@echo "RISC-V ACT4 Compliance Commands:"
	@echo "  make act-tools-check    - Verify the local ACT4 installation"
	@echo "  make act-generate       - Generate official RV32I self-checking ELFs"
	@echo "  make act-run ELF=/path/to/test.elf"
	@echo "  make act-regression     - Run all generated RV32I ELFs"
	@echo "  make act-zicsr          - Run only the six generated Zicsr ELFs"
	@echo "  make act-sm-generate    - Generate the privileged ExceptionsSm ELF"
	@echo "  make act-sm-exceptions  - Run the generated ExceptionsSm ELF"
	@echo ""
	@echo "Gate-Level Simulation Commands:"
	@echo "  make gl-compile       - Compile Sky130 netlist and GL testbench"
	@echo "  make gl               - Run gate-level simulation"
	@echo "  make wave-gl          - Open gate-level simulation with GUI"
	@echo ""
	@echo "Utility Commands:"
	@echo "  make clean            - Clean all generated files"
	@echo ""
	@echo "Examples:"
	@echo "  make run TB=tb_alu_unit           - Test ALU only"
	@echo "  make wave TB=tb_alu_unit          - View ALU waveform"
	@echo "  make run TB=tb_rv32i_pipeline     - Test pipeline"
	@echo "  make unit                         - Test all 10 units"
	@echo "  make gl                           - Run gate-level sim"
	@echo "  make vcs TB=tb_rv32i_pipeline    - Compile and run with VCS"
	@echo "  make verdi TB=tb_rv32i_pipeline  - Open the VCS design in Verdi"
	@echo ""
	@echo "Unit Tests Available:"
	@echo "  tb_alu_unit, tb_register_file, tb_immediate_generator, tb_branch_unit"
	@echo "  tb_jump_unit, tb_load_store_unit, tb_control_unit, tb_program_counter"
	@echo "  tb_instruction_memory, tb_data_memory"
	@echo "  tb_native_to_ahb_lite"
	@echo ""
	@echo "Integration Tests:"
	@echo "  tb_rv32i_pipeline, tb_full_verification, tb_load_use_hazard"
	@echo "  tb_memory_wait_states"
	@echo "  tb_reset_vector, tb_commit_interface, tb_machine_csr_trap"
	@echo "  tb_machine_external_interrupt"
	@echo "  tb_machine_exceptions"
	@echo "  tb_machine_identification_csrs"
	@echo "  tb_bus_access_faults"
	@echo "  tb_ahb_lite_interface"
	@echo "  tb_wfi_sleep"
	@echo ""
	@echo "Gate-Level:"
	@echo "  Run 3 (Best Config) - 0.81mm², 50MHz, 0 DRC violations"
	@echo ""
	@echo "=========================================="

# ==============================================================================
# Main Targets
# ==============================================================================

# Compile RTL and testbenches. Keep `compile` as the friendly default alias.
compile: rtl-compile

rtl-compile:
	@echo "=========================================="
	@echo "Compiling RTL and Testbench..."
	@echo "=========================================="
	@if [ ! -d $(WORK_DIR) ]; then $(VLIB) $(WORK_DIR); fi
	@$(VLOG) $(VLOG_FLAGS) -f $(RTL_FILELIST)
	@echo ""
	@echo "✓ RTL Compilation complete!"
	@echo "=========================================="

# Compile one RTL testbench with Synopsys VCS and generate the KDB database
# consumed by Verdi. VCS compilation is top-specific, so each testbench gets
# an independent build directory.
vcs-compile:
	@command -v $(VCS) >/dev/null 2>&1 || { echo "Error: VCS executable '$(VCS)' not found"; exit 1; }
	@mkdir -p $(VCS_BUILD_DIR) $(LOG_DIR)
	@if [ ! -x "$(VCS_SIMV)" ] && [ -f "$(VCS_SIMV).daidir/.vcs.timestamp" ]; then \
		echo "Removing stale VCS timestamp (simv is missing)..."; \
		$(RM) "$(VCS_SIMV).daidir/.vcs.timestamp"; \
	fi
	@echo "=========================================="
	@echo "Compiling with VCS: $(VCS_TOP)"
	@echo "=========================================="
	@$(VCS) $(VCS_FLAGS) -top $(VCS_TOP) -f $(RTL_FILELIST) \
		-o $(VCS_SIMV) -l $(LOG_DIR)/vcs_compile_$(VCS_TOP).log
	@test -x "$(VCS_SIMV)" || { \
		echo "Error: VCS finished without creating executable '$(VCS_SIMV)'"; \
		echo "Check $(LOG_DIR)/vcs_compile_$(VCS_TOP).log and the VCS license connection."; \
		exit 1; \
	}
	@echo "VCS executable: $(VCS_SIMV)"

# Friendly alias: compile and run with VCS.
vcs: vcs-run

vcs-run: vcs-compile
	@echo "=========================================="
	@echo "Running with VCS: $(VCS_TOP)"
	@echo "=========================================="
	@$(VCS_SIMV) -l $(LOG_DIR)/vcs_$(VCS_TOP).log
	@echo "VCS log: $(LOG_DIR)/vcs_$(VCS_TOP).log"

# Run every RTL unit and integration test with VCS. Each test has a separate
# executable because VCS elaboration is top-specific.
vcs-regression:
	@command -v $(VCS) >/dev/null 2>&1 || { echo "Error: VCS executable '$(VCS)' not found"; exit 1; }
	@mkdir -p $(LOG_DIR)
	@echo "=========================================="
	@echo "Running VCS RTL Regression ($(words $(VCS_REGRESSION_TESTS)) tests)"
	@echo "=========================================="
	@passed=0; failed=0; failed_tests=""; \
	for test in $(VCS_REGRESSION_TESTS); do \
		echo "Running: $$test..."; \
		driver_log="$(LOG_DIR)/vcs_driver_$$test.log"; \
		if $(MAKE) --no-print-directory vcs-run TB=$$test > "$$driver_log" 2>&1 && \
		   grep -Eq "ALL TESTS PASSED|TEST PASSED|CPU IS FUNCTIONALLY CORRECT|Test Status: PASSED" \
		       "$(LOG_DIR)/vcs_$$test.log"; then \
			echo "  ✓ PASSED"; \
			passed=$$((passed + 1)); \
		else \
			echo "  ✗ FAILED (see $$driver_log)"; \
			failed=$$((failed + 1)); \
			failed_tests="$$failed_tests $$test"; \
		fi; \
	done; \
	echo ""; \
	echo "VCS regression: $$passed/$(words $(VCS_REGRESSION_TESTS)) passed"; \
	if [ $$failed -ne 0 ]; then \
		echo "Failed tests:$$failed_tests"; \
		exit 1; \
	fi

# Start the simulation executable with the integrated Verdi GUI.
vcs-gui: vcs-compile
	@command -v $(VERDI) >/dev/null 2>&1 || { echo "Error: Verdi executable '$(VERDI)' not found"; exit 1; }
	@$(VCS_SIMV) -gui=verdi

# Open the elaborated VCS design database for source/debug inspection.
verdi: vcs-compile
	@command -v $(VERDI) >/dev/null 2>&1 || { echo "Error: Verdi executable '$(VERDI)' not found"; exit 1; }
	@$(VERDI) -dbdir $(VCS_SIMV).daidir -top $(VCS_TOP)

# Keep ACT4 and all of its dependencies local to this repository. Nothing in
# this environment is added to the user's login shell or system PATH.
act-tools-check:
	@test -x "$(ACT_TOOL_ROOT)/bin/mise" || { echo "Missing local mise"; exit 1; }
	@test -x "$(ACT_TOOL_ROOT)/toolchain/bin/riscv32-none-elf-gcc" || { echo "Missing local RISC-V GCC"; exit 1; }
	@test -x "$(ACT_TOOL_ROOT)/sail/bin/sail_riscv_sim" || { echo "Missing local Sail model"; exit 1; }
	@test -f "$(ACT_ROOT)/Makefile" || { echo "Missing local riscv-arch-test checkout"; exit 1; }
	@$(ACT_ENV) riscv32-none-elf-gcc --version | head -n 1
	@$(ACT_ENV) sail_riscv_sim --version
	@$(ACT_ENV) mise --version

# Generate official ACT4 self-checking ELFs with the local tool environment.
act-generate: act-tools-check
	@mkdir -p "$(abspath $(ACT_WORK_DIR))/generated"
	@$(ACT_ENV) $(MAKE) -C "$(ACT_ROOT)" \
		CONFIG_FILES="$(abspath $(ACT_CONFIG))" \
		WORKDIR="$(abspath $(ACT_WORK_DIR))/generated" \
		EXTENSIONS="$(ACT_EXTENSIONS)" \
		EXCLUDE_EXTENSIONS="$(ACT_EXCLUDE_EXTENSIONS)"

# Compile the unified-memory ACT4 harness once; it can run every generated ELF.
act-compile: TB=tb_act
act-compile: vcs-compile

act-run: act-compile
	@if [ -z "$(ELF)" ]; then \
		echo "Error: specify ELF=/path/to/act4-test.elf"; \
		exit 1; \
	fi
	@python3 scripts/run_act.py "$(ELF)" --simv "$(VCS_BUILD_ROOT)/tb_act/simv" \
		--work-dir "$(ACT_WORK_DIR)" --max-cycles "$(ACT_MAX_CYCLES)"

act-regression: act-compile
	@python3 scripts/run_act.py "$(ACT_ELF_DIR)" --simv "$(VCS_BUILD_ROOT)/tb_act/simv" \
		--work-dir "$(ACT_WORK_DIR)" --max-cycles "$(ACT_MAX_CYCLES)"

# Convenience target for the Zicsr subset; avoids passing a long ACT_ELF_DIR.
act-zicsr: ACT_ELF_DIR := $(ACT_WORK_DIR)/generated/rv32i-pipeline/elfs/rv32i/Zicsr
act-zicsr: act-regression

# Apply the project-local ACT4 split reproducibly. Accept both a clean checkout
# and an already-patched local tool tree.
act-sm-prepare: act-tools-check
	@set -e; \
	for patch in $(addprefix $(CURDIR)/,$(ACT_SM_PATCHES)); do \
		if git -C "$(ACT_ROOT)" apply --check "$$patch" >/dev/null 2>&1; then \
			git -C "$(ACT_ROOT)" apply "$$patch"; \
		elif git -C "$(ACT_ROOT)" apply --reverse --check "$$patch" >/dev/null 2>&1; then \
			:; \
		else \
			echo "Error: ACT4 patch does not match this checkout: $$patch"; \
			exit 1; \
		fi; \
	done

# ACT4 caches generated assembly independently of the extension filter. Remove
# only stale ExceptionsSm sources/ELFs, then regenerate the suite as 8 ELFs.
act-sm-generate: act-sm-prepare
	@find "$(ACT_ROOT)/tests/priv/ExceptionsSm" -maxdepth 1 -type f -name '*.S' -delete 2>/dev/null || true
	@find "$(abspath $(ACT_WORK_DIR))/generated/rv32i-pipeline/elfs/priv/ExceptionsSm" \
		-type f -delete 2>/dev/null || true
	@$(ACT_ENV) $(MAKE) -C "$(ACT_ROOT)" -B tests \
		EXTENSIONS=ExceptionsSm EXCLUDE_EXTENSIONS=
	@mkdir -p "$(abspath $(ACT_WORK_DIR))/generated"
	@$(ACT_ENV) $(MAKE) -C "$(ACT_ROOT)" \
		CONFIG_FILES="$(abspath $(ACT_CONFIG))" \
		WORKDIR="$(abspath $(ACT_WORK_DIR))/generated" \
		EXTENSIONS=ExceptionsSm EXCLUDE_EXTENSIONS=

act-sm-exceptions: ACT_ELF_DIR := $(ACT_WORK_DIR)/generated/rv32i-pipeline/elfs/priv/ExceptionsSm
act-sm-exceptions: act-regression

# Compile the generated Sky130 netlist independently from RTL.
gl-compile:
	@if [ -z "$(PDK_ROOT)" ]; then \
		echo "Error: set PDK_ROOT to your Sky130 PDK installation"; \
		exit 1; \
	fi
	@echo "=========================================="
	@echo "Compiling Gate-Level Netlist..."
	@if [ ! -d $(WORK_GL_DIR) ]; then $(VLIB) $(WORK_GL_DIR); fi
	@echo "[1/2] Compiling Sky130 PDK..."
	@$(VLOG) $(VLOG_GL_FLAGS) -suppress 2892 +define+USE_POWER_PINS \
		"$(SKY130_PRIMITIVES)" \
		"$(SKY130_LIB)" > /dev/null 2>&1 || (echo "Error compiling Sky130 PDK"; exit 1)
	@echo "[2/2] Compiling Gate-Level Netlist and Testbench..."
	@$(VLOG) $(VLOG_GL_FLAGS) -suppress 2892 +define+USE_POWER_PINS \
		-f "$(GL_FILELIST)" > /dev/null 2>&1 || (echo "Error compiling gate-level design"; exit 1)
	@echo "✓ Gate-level compilation complete!"
	@echo "=========================================="

# Run specific testbench
run: rtl-compile
	@if [ -z "$(TB)" ]; then \
		echo "Error: Please specify TB=<testbench_name>"; \
		echo "Example: make run TB=tb_alu_unit"; \
		exit 1; \
	fi
	@mkdir -p $(LOG_DIR)
	@echo "=========================================="
	@echo "Running: $(TB)"
	@echo "=========================================="
	@$(SIM) $(VSIM_FLAGS) $(WORK_DIR).$(TB) -do "run -all; quit -f" | tee $(LOG_DIR)/$(TB).log
	@echo ""
	@echo "✓ Simulation complete!"
	@echo "✓ Log saved: $(LOG_DIR)/$(TB).log"
	@echo "=========================================="

# Run an RTL testbench with the waveform viewer
wave: rtl-compile
	@if [ -z "$(TB)" ]; then \
		echo "Error: Please specify TB=<testbench_name>"; \
		echo "Example: make wave TB=tb_alu_unit"; \
		exit 1; \
	fi
	@echo "=========================================="
	@echo "Running with GUI: $(TB)"
	@echo "=========================================="
	@if [ "$(TB)" = "tb_rv32i_pipeline" ] && [ -f $(PIPELINE_WAVE) ]; then \
		$(SIM) -gui $(WORK_DIR).$(TB) -do $(PIPELINE_WAVE); \
	else \
		$(SIM) -gui $(WORK_DIR).$(TB) -do "add wave -r /*; run -all"; \
	fi

# Run the synthesized Sky130 design with the waveform viewer
wave-gl: gl-compile
	@$(SIM) -gui -work $(WORK_GL_DIR) $(WORK_GL_DIR).tb_rv32i_gl \
		-do "add wave -r /*; run -all"

# Run all unit tests (clean output)
unit: rtl-compile
	@mkdir -p $(LOG_DIR)
	@echo "=========================================="
	@echo "Running All Unit Tests (10 tests)"
	@echo "=========================================="
##	@echo "" > $(LOG_DIR)/unit_tests_summary.log
	@passed=0; total=0; \
	for test in $(UNIT_TESTS); do \
		echo ""; \
		echo "--- Running: $$test ---"; \
		$(SIM) $(VSIM_FLAGS) $(WORK_DIR).$$test -do "run -all; quit -f" > $(LOG_DIR)/$$test.log 2>&1; \
		if grep -q "ALL TESTS PASSED" $(LOG_DIR)/$$test.log; then \
			count=$$(grep "Passed:" $(LOG_DIR)/$$test.log | tail -1 | sed 's/.*Passed: \([0-9]*\).*/\1/'); \
			echo "✓ PASSED ($$count tests)"; \
			echo "$$test: PASSED ($$count tests)" >> $(LOG_DIR)/unit_tests_summary.log; \
			passed=$$((passed + 1)); \
		else \
			echo "✗ FAILED (see log for details)"; \
			echo "$$test: FAILED" >> $(LOG_DIR)/unit_tests_summary.log; \
		fi; \
		total=$$((total + 1)); \
	done; \
	echo ""; \
	echo "=========================================="; \
	echo "✓ Unit tests complete: $$passed/$$total PASSED"; \
	echo "✓ Logs saved in: $(LOG_DIR)/"; \
	echo "=========================================="

# Run pipeline integration test (clean output)
pipeline: rtl-compile
	@mkdir -p $(LOG_DIR)
	@echo "=========================================="
	@echo "Running Pipeline Integration Test"
	@echo "=========================================="
	@$(SIM) $(VSIM_FLAGS) $(WORK_DIR).tb_rv32i_pipeline -do "run -all; quit -f" > $(LOG_DIR)/tb_rv32i_pipeline.log 2>&1
	@echo ""
	@if grep -q "Test Status: PASSED" $(LOG_DIR)/tb_rv32i_pipeline.log; then \
		echo "✓ Pipeline test PASSED"; \
		grep "Total Instructions Executed:" $(LOG_DIR)/tb_rv32i_pipeline.log | sed 's/#//g' | xargs echo "  "; \
		grep "CPI (Cycles Per Instruction):" $(LOG_DIR)/tb_rv32i_pipeline.log | sed 's/#//g' | xargs echo "  "; \
	else \
		echo "✗ Pipeline test FAILED or status unknown"; \
	fi
	@echo "✓ Log saved: $(LOG_DIR)/tb_rv32i_pipeline.log"
	@echo "=========================================="

# Run full verification test (clean output)
verify: rtl-compile
	@mkdir -p $(LOG_DIR)
	@echo "=========================================="
	@echo "Running Full Verification Test"
	@echo "=========================================="
	@$(SIM) $(VSIM_FLAGS) $(WORK_DIR).tb_full_verification -do "run -all; quit -f" > $(LOG_DIR)/tb_full_verification.log 2>&1
	@echo ""
	@if grep -q "Verification Summary" $(LOG_DIR)/tb_full_verification.log; then \
		echo "✓ Verification test PASSED"; \
		grep "Total Instructions Executed:" $(LOG_DIR)/tb_full_verification.log | sed 's/#//g' | xargs echo "  "; \
		grep "Instructions Checked:" $(LOG_DIR)/tb_full_verification.log | sed 's/#//g' | xargs echo "  "; \
		errors=$$(grep "Errors:" $(LOG_DIR)/tb_full_verification.log | tail -1 | sed 's/.*Errors: \([0-9]*\).*/\1/'); \
		if [ "$$errors" = "0" ]; then \
			echo "  ✓ No errors found"; \
		else \
			echo "  ✗ $$errors errors found"; \
		fi; \
	else \
		echo "✗ Verification test FAILED or status unknown"; \
	fi
	@echo "✓ Log saved: $(LOG_DIR)/tb_full_verification.log"
	@echo "=========================================="

# Compile and run all tests
all: rtl-compile
	@mkdir -p $(LOG_DIR)
	@echo "=========================================="
	@echo "Running All Tests"
	@echo "=========================================="
	@echo ""
	@echo "=== Unit Tests (10 tests) ==="
	@echo "" > $(LOG_DIR)/unit_tests_summary.log
	@passed=0; total=0; \
	for test in $(UNIT_TESTS); do \
		echo "Running: $$test..."; \
		$(SIM) $(VSIM_FLAGS) $(WORK_DIR).$$test -do "run -all; quit -f" > $(LOG_DIR)/$$test.log 2>&1; \
		if grep -q "ALL TESTS PASSED" $(LOG_DIR)/$$test.log; then \
			count=$$(grep "Passed:" $(LOG_DIR)/$$test.log | tail -1 | sed 's/.*Passed: \([0-9]*\).*/\1/'); \
			echo "  ✓ $$test: PASSED ($$count tests)"; \
			echo "$$test: PASSED ($$count tests)" >> $(LOG_DIR)/unit_tests_summary.log; \
			passed=$$((passed + 1)); \
		else \
			echo "  ✗ $$test: FAILED"; \
			echo "$$test: FAILED" >> $(LOG_DIR)/unit_tests_summary.log; \
		fi; \
		total=$$((total + 1)); \
	done; \
	echo "Unit tests: $$passed/$$total PASSED"; \
	echo ""
	@echo "=== Pipeline Integration Test ==="
	@echo "Running: tb_rv32i_pipeline..."
	@$(SIM) $(VSIM_FLAGS) $(WORK_DIR).tb_rv32i_pipeline -do "run -all; quit -f" > $(LOG_DIR)/tb_rv32i_pipeline.log 2>&1
	@if grep -q "Test Status: PASSED" $(LOG_DIR)/tb_rv32i_pipeline.log; then \
		echo "  ✓ Pipeline test: PASSED"; \
	else \
		echo "  ✗ Pipeline test: FAILED"; \
	fi
	@echo ""
	@echo "=== Full Verification Test ==="
	@echo "Running: tb_full_verification..."
	@$(SIM) $(VSIM_FLAGS) $(WORK_DIR).tb_full_verification -do "run -all; quit -f" > $(LOG_DIR)/tb_full_verification.log 2>&1
	@if grep -q "Verification Summary" $(LOG_DIR)/tb_full_verification.log; then \
		errors=$$(grep "Errors:" $(LOG_DIR)/tb_full_verification.log | tail -1 | sed 's/.*Errors: \([0-9]*\).*/\1/'); \
		if [ "$$errors" = "0" ]; then \
			echo "  ✓ Verification test: PASSED (0 errors)"; \
		else \
			echo "  ✗ Verification test: FAILED ($$errors errors)"; \
		fi; \
	else \
		echo "  ✗ Verification test: FAILED"; \
	fi
	@echo ""
	@echo "=========================================="
	@echo "✓ All tests complete!"
	@echo "✓ All logs saved in: $(LOG_DIR)/"
	@echo "=========================================="

# ==============================================================================
# Gate-Level Simulation Targets
# ==============================================================================

# Run gate-level simulation (command-line)
gl: gl-compile
	@mkdir -p $(LOG_DIR)
	@echo ""
	@echo "=========================================="
	@echo "Running Gate-Level Simulation"
	@echo "Run 3: 0.81mm², 50MHz, 50.95% util"
	@echo "=========================================="
	@$(SIM) $(VSIM_GL_FLAGS) $(WORK_GL_DIR).tb_rv32i_gl \
		-do "run -all; quit -f" > $(LOG_DIR)/gl_simulation.log 2>&1
	@echo ""
	@if grep -q "ALL.*TESTS PASSED" $(LOG_DIR)/gl_simulation.log; then \
		passed=$$(grep "PASSED:" $(LOG_DIR)/gl_simulation.log | tail -1 | sed 's/.*PASSED: *\([0-9]*\).*/\1/'); \
		total=$$(grep "Instructions:" $(LOG_DIR)/gl_simulation.log | sed 's/.*Instructions: *\([0-9]*\).*/\1/'); \
		cycles=$$(grep "Total Cycles:" $(LOG_DIR)/gl_simulation.log | sed 's/.*Total Cycles: *\([0-9]*\).*/\1/'); \
		echo "✓ Gate-Level Simulation: PASSED ($$passed tests)"; \
		echo "  Total Instructions: $$total"; \
		echo "  Total Cycles: $$cycles"; \
	else \
		echo "✗ Gate-Level Simulation: FAILED"; \
		echo "  Check log for details: $(LOG_DIR)/gl_simulation.log"; \
	fi
	@echo ""
	@echo "✓ Full log saved: $(LOG_DIR)/gl_simulation.log"
	@echo "=========================================="

# ==============================================================================
# Utility Targets
# ==============================================================================

# Clean all generated files
clean:
	@echo "=========================================="
	@echo "Cleaning all generated files..."
	@echo "=========================================="
	@rm -rf $(WORK_DIR) $(WORK_GL_DIR)
	@rm -rf $(VCS_BUILD_ROOT)
	@rm -rf *.wlf *.vcd
	@rm -rf transcript
	@rm -rf vsim.wlf vsim_stacktrace.vstf
	@rm -rf $(LOG_DIR)/*.log 2>/dev/null || true
	@echo ""
	@echo "✓ Clean complete!"
	@echo "=========================================="

# Deep clean (including backup)
distclean: clean
	@rm -rf Makefile.backup
	@find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@echo "✓ Deep clean complete!"

# ==============================================================================
# End of Makefile
# ==============================================================================
