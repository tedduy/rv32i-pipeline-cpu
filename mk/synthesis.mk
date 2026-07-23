# Open-source synthesizability sanity check.

SYNTH_TOP ?= tdrv32_core
YOSYS_DIR := build/synth/yosys/$(SYNTH_TOP)

.PHONY: synth-yosys

synth-yosys:
	@$(call require_tool,$(YOSYS))
	@mkdir -p "$(YOSYS_DIR)"
	@$(YOSYS) -q -l "$(YOSYS_DIR)/yosys.log" -p \
		'read_verilog -sv $(RTL_SOURCES); hierarchy -check -top $(SYNTH_TOP); proc; opt; check -assert; synth -top $(SYNTH_TOP); check -assert; stat'
