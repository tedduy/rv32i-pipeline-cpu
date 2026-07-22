# ==============================================================================
# Wave configuration for tb_rv32i_pipeline
# Fixed signal list for consistent waveform display
# ==============================================================================

onerror {resume}
quietly WaveActivateNextPane {} 0

# Clock and Reset
add wave -noupdate -divider {Clock & Reset}
add wave -noupdate /tb_rv32i_pipeline/clk
add wave -noupdate /tb_rv32i_pipeline/rst

# Program Counter and Instruction
add wave -noupdate -divider {IF Stage}
add wave -noupdate -radix hexadecimal /tb_rv32i_pipeline/dut/o_debug_pc
add wave -noupdate -radix hexadecimal /tb_rv32i_pipeline/dut/o_debug_instruction

# Register File Data
add wave -noupdate -divider {ID Stage - Register File}
add wave -noupdate -radix hexadecimal /tb_rv32i_pipeline/dut/o_debug_rs1_data
add wave -noupdate -radix hexadecimal /tb_rv32i_pipeline/dut/o_debug_rs2_data

# ALU and Immediate
add wave -noupdate -divider {EX Stage}
add wave -noupdate -radix hexadecimal /tb_rv32i_pipeline/dut/o_debug_alu_result
add wave -noupdate -radix hexadecimal /tb_rv32i_pipeline/dut/o_debug_immediate

# Memory Stage
add wave -noupdate -divider {MEM Stage}
add wave -noupdate -radix hexadecimal /tb_rv32i_pipeline/dut/o_debug_mem_addr

# Write Back Stage
add wave -noupdate -divider {WB Stage}
add wave -noupdate -radix hexadecimal /tb_rv32i_pipeline/dut/o_debug_wb_data

# Control Signals
add wave -noupdate -divider {Control Signals}
add wave -noupdate /tb_rv32i_pipeline/dut/o_debug_rd_write
add wave -noupdate /tb_rv32i_pipeline/dut/o_debug_mem_write
add wave -noupdate /tb_rv32i_pipeline/dut/o_debug_mem_read
add wave -noupdate /tb_rv32i_pipeline/dut/o_debug_branch_taken
add wave -noupdate /tb_rv32i_pipeline/dut/o_debug_jal
add wave -noupdate /tb_rv32i_pipeline/dut/o_debug_jalr
add wave -noupdate /tb_rv32i_pipeline/dut/o_debug_stall
add wave -noupdate /tb_rv32i_pipeline/dut/o_debug_flush

# Configure wave window
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 300
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ns} {1000 ns}

# Run simulation
run -all
