# Technology-mapped synthesis flow for Synopsys Design Compiler.
# Required environment variables are supplied by the Makefile target.

proc require_env {name} {
    if {![info exists ::env($name)] || $::env($name) eq ""} {
        error "Missing required environment variable: $name"
    }
    return $::env($name)
}

set project_root [file normalize [file join [file dirname [info script]] ../../..]]
set top          [require_env SYNTH_TOP]
set target_db    [file normalize [require_env SYNTH_LIBRARY]]
set output_dir   [file normalize [require_env SYNTH_OUTPUT_DIR]]
set clock_period [expr {double([require_env SYNTH_CLOCK_PERIOD])}]

# A constraint or synthesis command error must fail the batch run rather than
# leave apparently valid but incompletely constrained reports behind.
set_app_var sh_continue_on_error false

if {![file exists $target_db]} {
    error "Synthesis target library does not exist: $target_db"
}

file mkdir $output_dir
file mkdir [file join $output_dir work]
file mkdir [file join $output_dir reports]
file mkdir [file join $output_dir netlist]

set_app_var search_path [list [file dirname $target_db] \
                                  [file join $project_root rtl logical]]
set_app_var target_library [list $target_db]
set_app_var synthetic_library [list dw_foundation.sldb]
set_app_var link_library [concat "*" $target_library $synthetic_library]

define_design_lib WORK -path [file join $output_dir work]

set logical_root [file join $project_root rtl logical]
set rtl_files {}
foreach pattern [list *.sv */*.sv */*/*.sv] {
    foreach source [glob -nocomplain -directory $logical_root $pattern] {
        lappend rtl_files $source
    }
}
set rtl_files [lsort -unique $rtl_files]
if {[llength $rtl_files] == 0} {
    error "No SystemVerilog RTL files found below $logical_root"
}

puts "SYNTH-INFO: top=$top"
puts "SYNTH-INFO: library=$target_db"
puts "SYNTH-INFO: clock_period=$clock_period ns"
puts "SYNTH-INFO: multiplier=iterative-radix2"
puts "SYNTH-INFO: divider=restoring-radix2"
puts "SYNTH-INFO: rtl_files=[llength $rtl_files]"

analyze -format sverilog $rtl_files
elaborate $top
link
uniquify

redirect -file [file join $output_dir reports check_design_precompile.rpt] {
    check_design
}

set constraint_file [file join $project_root rtl sdc rv32i_core.sdc]
if {![file exists $constraint_file]} {
    error "Synthesis constraint file does not exist: $constraint_file"
}
source $constraint_file
set_fix_multiple_port_nets -all -buffer_constants

compile_ultra -no_autoungroup

# Give design-rule repair a second mapped optimization pass.  At the slow
# corner the first timing-driven pass can leave small max-transition misses on
# high-fanout mux and multiplier nodes even though setup/hold already close.
compile_ultra -incremental -no_autoungroup

# Every iterative multiply/divide step is registered and must meet a normal
# one-cycle constraint. Resolve the mapped registers only for dedicated timing
# reports; no multicycle timing exception is valid for either implementation.
set mapped_mul_launch_pins [get_pins -hierarchical -quiet \
    -filter "full_name =~ *ex_mdu/u_multiplier/*_q_reg*/Q"]
set mapped_mul_capture_pins [get_pins -hierarchical -quiet \
    -filter "full_name =~ *ex_mdu/u_multiplier/*_q_reg*/D"]
set mapped_mul_capture_pins [add_to_collection $mapped_mul_capture_pins \
    [get_pins -hierarchical -quiet \
        -filter "full_name =~ *ex_mem_reg/o_alu_result_reg*/D"]]

set mapped_div_launch_pins [get_pins -hierarchical -quiet \
    -filter "full_name =~ *ex_mdu/u_divider/*_q_reg*/Q"]
set mapped_div_capture_pins [get_pins -hierarchical -quiet \
    -filter "full_name =~ *ex_mdu/u_divider/*_q_reg*/D"]
set mapped_div_capture_pins [add_to_collection $mapped_div_capture_pins \
    [get_pins -hierarchical -quiet \
        -filter "full_name =~ *ex_mem_reg/o_alu_result_reg*/D"]]

if {[sizeof_collection $mapped_mul_launch_pins] == 0 ||
    [sizeof_collection $mapped_mul_capture_pins] == 0} {
    error "Could not resolve mapped multiplier timing-report pins"
}
if {[sizeof_collection $mapped_div_launch_pins] == 0 ||
    [sizeof_collection $mapped_div_capture_pins] == 0} {
    error "Could not resolve mapped divider timing-report pins"
}

redirect -file [file join $output_dir reports check_design.rpt] {
    check_design
}
redirect -file [file join $output_dir reports area.rpt] {
    report_area -hierarchy
}
redirect -file [file join $output_dir reports qor.rpt] {
    report_qor
}
redirect -file [file join $output_dir reports resources.rpt] {
    report_resources -hierarchy
}
redirect -file [file join $output_dir reports timing.rpt] {
    report_timing -delay_type max -max_paths 20 -nworst 2 -path full \
        -input_pins -nets -transition_time -capacitance
}
redirect -file [file join $output_dir reports timing_reg2reg.rpt] {
    report_timing -delay_type max \
        -from [all_registers -clock_pins] \
        -to [all_registers -data_pins] \
        -max_paths 20 -nworst 2 -path full -input_pins -nets \
        -transition_time -capacitance
}
redirect -file [file join $output_dir reports timing_multiplier.rpt] {
    report_timing -delay_type max \
        -from $mapped_mul_launch_pins -to $mapped_mul_capture_pins \
        -max_paths 4 -nworst 1 -path full -input_pins -nets \
        -transition_time -capacitance
}
redirect -file [file join $output_dir reports timing_divider.rpt] {
    report_timing -delay_type max \
        -from $mapped_div_launch_pins -to $mapped_div_capture_pins \
        -max_paths 4 -nworst 1 -path full -input_pins -nets \
        -transition_time -capacitance
}
redirect -file [file join $output_dir reports timing_hold.rpt] {
    report_timing -delay_type min -max_paths 20 -nworst 2 -path full \
        -input_pins -nets -transition_time -capacitance
}
redirect -file [file join $output_dir reports constraints.rpt] {
    report_constraint -all_violators
}
redirect -file [file join $output_dir reports clocks.rpt] {
    report_clock
}

change_names -rules verilog -hierarchy
write -format ddc -hierarchy -output [file join $output_dir netlist ${top}.ddc]
write -format verilog -hierarchy -output [file join $output_dir netlist ${top}.v]
write_sdc [file join $output_dir netlist ${top}.sdc]

puts "SYNTH-SUMMARY: reports=[file join $output_dir reports]"
puts "SYNTH-SUMMARY: netlist=[file join $output_dir netlist ${top}.v]"
exit
