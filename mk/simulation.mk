# Cocotb functional regression on Verilator and Icarus.

COCOTB_DIR := verification/cocotb
ICARUS_WRAPPERS := $(CURDIR)/scripts/icarus-cocotb
RANDOM_SEEDS ?= 0x5eed1234 0x1badb002 0xdeadbeef
DETERMINISTIC_TEST_FILTER ?= '^(?!.*constrained_random_architectural_scoreboard).+'
DETERMINISTIC_SUITES := \
	tdrv32_core:test_core:core \
	native_to_ahb_lite:test_native_to_ahb_lite:native-to-ahb-lite \
	core_sleep_gate:test_core_sleep_gate:core-sleep-gate \
	tdrv32_top:test_top:top

.PHONY: verification-setup check-cocotb cocotb-verilator cocotb-iverilog \
	random-regression

verification-setup:
	@$(SYSTEM_PYTHON) -m venv "$(VENV)"
	@"$(VENV_BIN)/python" -m pip install --upgrade pip
	@"$(VENV_BIN)/python" -m pip install -r verification/requirements.txt

check-cocotb:
	@test -x "$(VENV_BIN)/cocotb-config" || { \
		echo "Missing Cocotb environment. Run: make verification-setup"; \
		exit 1; \
	}

cocotb-verilator: check-cocotb
	@set -e; \
	for suite in $(DETERMINISTIC_SUITES); do \
		IFS=: read -r top tests stem <<< "$$suite"; \
		PATH="$(VENV_BIN):$$PATH" $(MAKE) --no-print-directory \
			-C "$(COCOTB_DIR)" SIM=verilator \
			COCOTB_TOPLEVEL="$$top" COCOTB_TEST_MODULES="$$tests" \
			SIM_BUILD="$(CURDIR)/build/cocotb/verilator-$$stem" \
			COCOTB_TEST_FILTER="$(DETERMINISTIC_TEST_FILTER)"; \
	done

cocotb-iverilog: check-cocotb
	@set -e; \
	for suite in $(DETERMINISTIC_SUITES); do \
		IFS=: read -r top tests stem <<< "$$suite"; \
		PATH="$(VENV_BIN):$$PATH" $(MAKE) --no-print-directory \
			-C "$(COCOTB_DIR)" SIM=icarus \
			ICARUS_BIN_DIR="$(ICARUS_WRAPPERS)" \
			COCOTB_TOPLEVEL="$$top" COCOTB_TEST_MODULES="$$tests" \
			SIM_BUILD="$(CURDIR)/build/cocotb/icarus-$$stem" \
			COCOTB_TEST_FILTER="$(DETERMINISTIC_TEST_FILTER)"; \
	done

random-regression: check-cocotb
	@set -e; \
	for seed in $(RANDOM_SEEDS); do \
		echo "Constrained-random seed $$seed"; \
		PATH="$(VENV_BIN):$$PATH" CORE_RANDOM_SEED="$$seed" \
			COCOTB_TEST_FILTER=constrained_random_architectural_scoreboard \
			$(MAKE) --no-print-directory -C "$(COCOTB_DIR)" SIM=verilator; \
	done
