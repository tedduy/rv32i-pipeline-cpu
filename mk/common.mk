# Shared project paths and tool overrides.

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
