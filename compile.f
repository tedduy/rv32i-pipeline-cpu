+incdir+rtl/common
+incdir+rtl/core/stages
+incdir+rtl/core/pipeline
+incdir+rtl/core/hazard
+incdir+rtl/top
+incdir+tb/unit_test
rtl/common/adder_N_bit.sv
rtl/common/mux2to1.sv
rtl/common/mux3to1.sv
rtl/common/mux4to1.sv
rtl/core/stages/ALU_Unit.sv
rtl/core/stages/Branch_Unit.sv
rtl/core/stages/Control_Unit.sv
rtl/core/stages/Data_Memory.sv
rtl/core/stages/Immediate_Generation.sv
rtl/core/stages/Instruction_Mem.sv
rtl/core/stages/Jump_Unit.sv
rtl/core/stages/Load_Store_Unit.sv
rtl/core/stages/Program_Counter.sv
rtl/core/stages/Reg_File.sv
rtl/core/pipeline/IF_ID_Register.sv
rtl/core/pipeline/ID_EX_Register.sv
rtl/core/pipeline/EX_MEM_Register.sv
rtl/core/pipeline/MEM_WB_Register.sv
rtl/core/hazard/Forwarding_Unit.sv
rtl/core/hazard/Hazard_Detection_Unit.sv
rtl/top/rv32i_top.sv
tb/tb_full_verification.sv
tb/tb_rv32i_pipeline.sv
tb/unit_test/tb_alu_unit.sv
tb/unit_test/tb_reg_file.sv
tb/unit_test/tb_imm_gen.sv
tb/unit_test/tb_branch_unit.sv
tb/unit_test/tb_jump_unit.sv
tb/unit_test/tb_load_store_unit.sv
tb/unit_test/tb_control_unit.sv
tb/unit_test/tb_program_counter.sv
tb/unit_test/tb_instruction_mem.sv
tb/unit_test/tb_data_memory.sv
# ==============================================================================
# Gate-Level Simulation Files
# For OpenLane Run 3 (Best Configuration) + Sky130 PDK
# ==============================================================================

# Note: These files are used by 'make gl' targets only
# Sky130 PDK Libraries and Gate-Level Netlist paths are defined in Makefile

# Gate-Level Testbench
tb/tb_rv32i_gl.sv
