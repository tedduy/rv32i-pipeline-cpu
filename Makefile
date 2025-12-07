# ==============================================================================
# Makefile for RV32I Pipeline CPU - QuestaSim
# ==============================================================================

.PHONY: help all clean compile run unit pipeline verify

# Default target
.DEFAULT_GOAL := help

# ==============================================================================
# Configuration
# ==============================================================================

# Simulator
SIM = vsim
VLOG = vlog
VLIB = vlib

# Directories
WORK_DIR = work
SIM_DIR = sim
LOG_DIR = logs

# Compile flags
VLOG_FLAGS = -sv +acc -work $(WORK_DIR)

# Simulation flags
VSIM_FLAGS = -c -work $(WORK_DIR)

# File lists
COMPILE_LIST = compile.f

# Unit test list
UNIT_TESTS = tb_alu_unit tb_reg_file tb_imm_gen tb_branch_unit \
             tb_jump_unit tb_load_store_unit tb_control_unit tb_program_counter \
             tb_instruction_mem tb_data_memory

# ==============================================================================
# Help
# ==============================================================================

help:
	@echo "=========================================="
	@echo "RV32I Pipeline CPU - Makefile"
	@echo "=========================================="
	@echo ""
	@echo "Main Commands:"
	@echo "  make compile          - Compile all RTL and testbench"
	@echo "  make run TB=<name>    - Run specific testbench"
	@echo "  make wave TB=<name>   - Run with waveform viewer (GUI)"
	@echo "  make unit             - Run all unit tests (10 tests)"
	@echo "  make pipeline         - Run pipeline integration test"
	@echo "  make verify           - Run full verification test"
	@echo "  make all              - Compile + run all tests"
	@echo "  make clean            - Clean generated files"
	@echo ""
	@echo "Examples:"
	@echo "  make run TB=tb_alu_unit           - Test ALU only"
	@echo "  make wave TB=tb_alu_unit          - View ALU waveform"
	@echo "  make run TB=tb_rv32i_pipeline     - Test pipeline"
	@echo "  make unit                         - Test all 10 units"
	@echo ""
	@echo "Unit Tests Available:"
	@echo "  tb_alu_unit, tb_reg_file, tb_imm_gen, tb_branch_unit"
	@echo "  tb_jump_unit, tb_load_store_unit, tb_control_unit, tb_program_counter"
	@echo "  tb_instruction_mem, tb_data_memory"
	@echo ""
	@echo "Integration Tests:"
	@echo "  tb_rv32i_pipeline, tb_full_verification"
	@echo ""
	@echo "=========================================="

# ==============================================================================
# Main Targets
# ==============================================================================

# Compile all RTL and testbench
compile:
	@echo "=========================================="
	@echo "Compiling RTL and Testbench..."
	@echo "=========================================="
	@if [ ! -d $(WORK_DIR) ]; then $(VLIB) $(WORK_DIR); fi
	@$(VLOG) $(VLOG_FLAGS) -f $(COMPILE_LIST)
	@echo ""
	@echo "✓ Compilation complete!"
	@echo "=========================================="

# Run specific testbench
run: compile
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

# Run with waveform viewer
wave: compile
	@if [ -z "$(TB)" ]; then \
		echo "Error: Please specify TB=<testbench_name>"; \
		echo "Example: make wave TB=tb_alu_unit"; \
		exit 1; \
	fi
	@echo "=========================================="
	@echo "Running with GUI: $(TB)"
	@echo "=========================================="
	@$(SIM) -gui $(WORK_DIR).$(TB) -do "add wave -r /*; run -all"

# Run all unit tests (clean output)
unit: compile
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
pipeline: compile
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
verify: compile
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
all: compile
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
# Utility Targets
# ==============================================================================

# Clean all generated files
clean:
	@echo "=========================================="
	@echo "Cleaning generated files..."
	@echo "=========================================="
	@rm -rf $(WORK_DIR)
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
