# Cocotb functional regression on Verilator and Icarus.

COCOTB_DIR := verification/cocotb
ICARUS_WRAPPERS := $(CURDIR)/scripts/icarus-cocotb
RANDOM_SEEDS ?= 0x5eed1234 0x1badb002 0xdeadbeef
DETERMINISTIC_TEST_FILTER ?= '^(?!.*constrained_random_architectural_scoreboard).+'

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
	@PATH="$(VENV_BIN):$$PATH" $(MAKE) --no-print-directory \
		-C "$(COCOTB_DIR)" SIM=verilator \
		COCOTB_TEST_FILTER="$(DETERMINISTIC_TEST_FILTER)"

cocotb-iverilog: check-cocotb
	@PATH="$(VENV_BIN):$$PATH" $(MAKE) --no-print-directory \
		-C "$(COCOTB_DIR)" SIM=icarus ICARUS_BIN_DIR="$(ICARUS_WRAPPERS)" \
		COCOTB_TEST_FILTER="$(DETERMINISTIC_TEST_FILTER)"

random-regression: check-cocotb
	@set -e; \
	for seed in $(RANDOM_SEEDS); do \
		echo "Constrained-random seed $$seed"; \
		PATH="$(VENV_BIN):$$PATH" CORE_RANDOM_SEED="$$seed" \
			COCOTB_TEST_FILTER=constrained_random_architectural_scoreboard \
			$(MAKE) --no-print-directory -C "$(COCOTB_DIR)" SIM=verilator; \
	done
