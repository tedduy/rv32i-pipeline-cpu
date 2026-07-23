SHELL := /bin/bash
.DEFAULT_GOAL := help

# Keep this file as the public entry point. Implementation lives in mk/ so each
# verification flow can evolve independently without turning this into a script.
include mk/common.mk
include mk/doctor.mk
include mk/verification.mk
include mk/compliance.mk
include mk/firmware.mk

.PHONY: help all ci test clean

help:
	@echo "RV32IMC open-source development flow"
	@echo
	@echo "Quick start"
	@echo "  make verification-setup  Create .venv and install Cocotb"
	@echo "  make doctor              Check required local tools"
	@echo "  make test                Run Cocotb on Verilator and Icarus"
	@echo "  make ci                  Run the complete RTL quality gate"
	@echo
	@echo "RTL quality"
	@echo "  make lint                Verilator lint"
	@echo "  make random-regression   Constrained-random test seeds"
	@echo "  make coverage            Gate code metrics + 100% functional bins"
	@echo "  make formal              SymbiYosys protocol proofs"
	@echo "  make synth-yosys         Yosys synthesis sanity check"
	@echo
	@echo "RISC-V compliance"
	@echo "  make act-generate        Generate the configured ACT4 tests"
	@echo "  make act-regression      Run all generated ACT4 tests"
	@echo "  make act-run ELF=<path>  Run one ACT4 ELF"
	@echo "  make act-<suite>         Run zca, zc-exceptions, zicsr,"
	@echo "                           zifencei, zicntr, m or sm-exceptions"
	@echo
	@echo "Firmware"
	@echo "  make firmware-build      Build the bare-metal smoke test"
	@echo "  make firmware-run        Build and simulate the smoke test"
	@echo
	@echo "Maintenance"
	@echo "  make clean               Remove generated build artifacts"

test: cocotb-verilator cocotb-iverilog

ci: lint test random-regression coverage synth-yosys formal
all: ci

clean:
	@rm -rf build
	@rm -rf rtl/lint/reports
	@rm -rf verification/formal/rv32i_core_protocol_bmc
	@rm -rf verification/formal/rv32i_core_protocol_cover
