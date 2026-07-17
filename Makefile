# ==============================================================================
# Makefile for RV32I Pipeline CPU - QuestaSim, VCS and Verdi
# ==============================================================================

.PHONY: help all clean compile rtl-compile gl-compile run unit pipeline verify gl wave wave-gl \
	vcs vcs-compile vcs-run vcs-gui verdi distclean

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
	@echo "  make vcs-gui TB=<name>     - Run the VCS executable in Verdi GUI mode"
	@echo "  make verdi TB=<name>       - Open the compiled VCS design in Verdi"
	@echo "  Default TB: tb_rv32i_pipeline"
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
	@echo ""
	@echo "Integration Tests:"
	@echo "  tb_rv32i_pipeline, tb_full_verification, tb_load_use_hazard"
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
	@echo "=========================================="
	@echo "Compiling with VCS: $(VCS_TOP)"
	@echo "=========================================="
	@$(VCS) $(VCS_FLAGS) -top $(VCS_TOP) -f $(RTL_FILELIST) \
		-o $(VCS_SIMV) -l $(LOG_DIR)/vcs_compile_$(VCS_TOP).log
	@echo "VCS executable: $(VCS_SIMV)"

# Friendly alias: compile and run with VCS.
vcs: vcs-run

vcs-run: vcs-compile
	@echo "=========================================="
	@echo "Running with VCS: $(VCS_TOP)"
	@echo "=========================================="
	@$(VCS_SIMV) -l $(LOG_DIR)/vcs_$(VCS_TOP).log
	@echo "VCS log: $(LOG_DIR)/vcs_$(VCS_TOP).log"

# Start the simulation executable with the integrated Verdi GUI.
vcs-gui: vcs-compile
	@command -v $(VERDI) >/dev/null 2>&1 || { echo "Error: Verdi executable '$(VERDI)' not found"; exit 1; }
	@$(VCS_SIMV) -gui=verdi

# Open the elaborated VCS design database for source/debug inspection.
verdi: vcs-compile
	@command -v $(VERDI) >/dev/null 2>&1 || { echo "Error: Verdi executable '$(VERDI)' not found"; exit 1; }
	@$(VERDI) -dbdir $(VCS_SIMV).daidir -top $(VCS_TOP)

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
