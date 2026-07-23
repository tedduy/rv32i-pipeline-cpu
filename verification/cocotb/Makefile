SIM ?= verilator

REPO_ROOT := $(abspath ../..)
RTL_FILELIST := $(REPO_ROOT)/rtl/logical/filelist.f
RTL_SOURCES := $(addprefix $(REPO_ROOT)/,$(filter %.sv,$(shell grep -v '^+' $(RTL_FILELIST))))

TOPLEVEL_LANG := verilog
VERILOG_SOURCES := $(RTL_SOURCES)
COCOTB_TOPLEVEL ?= rv32i_core
COCOTB_TEST_MODULES ?= test_core
COCOTB_HDL_TIMEUNIT := 1ns
COCOTB_HDL_TIMEPRECISION := 1ps
RTL_COVERAGE ?= 0
COVERAGE_FILE ?= $(COCOTB_TOPLEVEL).dat
SIM_BUILD := $(REPO_ROOT)/build/cocotb/$(SIM)

ifeq ($(SIM),verilator)
COMPILE_ARGS += --timing --Wall
COMPILE_ARGS += -Wno-PINCONNECTEMPTY -Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM
ifeq ($(RTL_COVERAGE),1)
SIM_BUILD := $(REPO_ROOT)/build/cocotb/verilator-coverage-$(COCOTB_TOPLEVEL)
COMPILE_ARGS += --coverage
COCOTB_PLUSARGS += +verilator+coverage+file+$(REPO_ROOT)/build/coverage/$(COVERAGE_FILE)
endif
endif

COCOTB_RESULTS_FILE ?= $(SIM_BUILD)/results.xml

include $(shell cocotb-config --makefiles)/Makefile.sim
