# Shared synthesis constraints for tdrv32_core and the AHB-Lite wrapper.
# The DC driver defines clock_period from SYNTH_CLOCK_PERIOD before sourcing
# this file, which keeps the constraint policy independent from the tool flow.

create_clock -name core_clk -period $clock_period [get_ports i_clk]
set core_clock [get_clocks core_clk]

set_clock_uncertainty -setup [expr {$clock_period * 0.05}] $core_clock
set_clock_uncertainty -hold 0.05 $core_clock
set_false_path -from [get_ports i_arst_n]

set data_inputs [remove_from_collection [all_inputs] [get_ports {i_clk i_arst_n}]]
if {[sizeof_collection $data_inputs] > 0} {
    set_input_delay [expr {$clock_period * 0.10}] -clock $core_clock $data_inputs
}

if {[sizeof_collection [all_outputs]] > 0} {
    set_output_delay [expr {$clock_period * 0.10}] -clock $core_clock [all_outputs]
    set_load 0.05 [all_outputs]
}

set_max_transition [expr {$clock_period * 0.10}] [current_design]
