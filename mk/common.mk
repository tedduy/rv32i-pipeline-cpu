# Shared project paths and tool overrides.

TOOLS_DIR ?= $(CURDIR)/.tools
OSS_CAD_SUITE_ROOT ?= $(TOOLS_DIR)/oss-cad-suite
RISCV_TOOLCHAIN_DIR ?= $(TOOLS_DIR)/riscv-toolchain

# Prefer a project-local installation automatically. Individual tool variables
# and PATH can still be overridden for a system installation.
ifneq ($(wildcard $(OSS_CAD_SUITE_ROOT)/bin/verilator),)
export PATH := $(OSS_CAD_SUITE_ROOT)/bin:$(PATH)
export VERILATOR_ROOT := $(OSS_CAD_SUITE_ROOT)/share/verilator
export GHDL_PREFIX := $(OSS_CAD_SUITE_ROOT)/lib/ghdl
endif

RTL_FILELIST := rtl/logical/filelist.f
RTL_SOURCES := $(filter %.sv,$(shell grep -v '^+' $(RTL_FILELIST)))

IVERILOG ?= iverilog
VERILATOR ?= verilator
YOSYS ?= yosys
SBY ?= sby
SYSTEM_PYTHON ?= /usr/bin/python3

VENV ?= $(CURDIR)/.venv
VENV_BIN := $(VENV)/bin

define require_tool
command -v "$(1)" >/dev/null 2>&1 || { \
	echo "Missing tool: $(1)"; \
	exit 1; \
}
endef
