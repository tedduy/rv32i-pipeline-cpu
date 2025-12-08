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

# Cycle Counter
add wave -noupdate -divider {CPU Status}
add wave -noupdate -radix unsigned /tb_rv32i_pipeline/dut/cycle_counter

# Program Counter and Instruction
add wave -noupdate -divider {IF Stage}
add wave -noupdate -radix hexadecimal /tb_rv32i_pipeline/dut/W_PC_out
add wave -noupdate -radix hexadecimal /tb_rv32i_pipeline/dut/instruction

# Register File Data
add wave -noupdate -divider {ID Stage - Register File}
add wave -noupdate -radix hexadecimal /tb_rv32i_pipeline/dut/W_RD1
add wave -noupdate -radix hexadecimal /tb_rv32i_pipeline/dut/W_RD2

# ALU and Immediate
add wave -noupdate -divider {EX Stage}
add wave -noupdate -radix hexadecimal /tb_rv32i_pipeline/dut/W_ALUout
add wave -noupdate -radix hexadecimal /tb_rv32i_pipeline/dut/W_immediate

# Memory Stage
add wave -noupdate -divider {MEM Stage}
add wave -noupdate -radix hexadecimal /tb_rv32i_pipeline/dut/W_mem_addr

# Write Back Stage
add wave -noupdate -divider {WB Stage}
add wave -noupdate -radix hexadecimal /tb_rv32i_pipeline/dut/W_WB_data

# Control Signals
add wave -noupdate -divider {Control Signals}
add wave -noupdate /tb_rv32i_pipeline/dut/W_reg_write
add wave -noupdate /tb_rv32i_pipeline/dut/W_mem_write
add wave -noupdate /tb_rv32i_pipeline/dut/W_mem_read
add wave -noupdate /tb_rv32i_pipeline/dut/W_branch_taken
add wave -noupdate /tb_rv32i_pipeline/dut/W_jal
add wave -noupdate /tb_rv32i_pipeline/dut/W_jalr
add wave -noupdate /tb_rv32i_pipeline/dut/W_stall
add wave -noupdate /tb_rv32i_pipeline/dut/W_flush

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
