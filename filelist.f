+incdir+rtl/common
+incdir+rtl/stages/fetch
+incdir+rtl/stages/decode
+incdir+rtl/stages/execute
+incdir+rtl/stages/memory
+incdir+rtl/stages/system
+incdir+rtl/pipeline
+incdir+rtl/hazard
+incdir+tb/unit
+incdir+tb/integration
+incdir+tb/compliance

rtl/common/adder_n_bit.sv
rtl/common/mux2to1.sv
rtl/common/mux3to1.sv
rtl/common/mux4to1.sv

rtl/stages/fetch/program_counter.sv
rtl/stages/fetch/instruction_memory.sv

rtl/stages/decode/control_unit.sv
rtl/stages/decode/immediate_generator.sv
rtl/stages/decode/register_file.sv

rtl/stages/execute/alu_unit.sv
rtl/stages/execute/branch_unit.sv
rtl/stages/execute/jump_unit.sv

rtl/stages/memory/load_store_unit.sv
rtl/stages/memory/data_memory.sv

rtl/stages/system/csr_file.sv

rtl/pipeline/if_id_register.sv
rtl/pipeline/id_ex_register.sv
rtl/pipeline/ex_mem_register.sv
rtl/pipeline/mem_wb_register.sv

rtl/hazard/forwarding_unit.sv
rtl/hazard/hazard_detection_unit.sv

rtl/rv32i_top.sv

tb/integration/tb_full_verification.sv
tb/integration/tb_rv32i_pipeline.sv
tb/integration/tb_load_use_hazard.sv
tb/integration/tb_memory_wait_states.sv
tb/integration/tb_reset_vector.sv
tb/integration/tb_commit_interface.sv
tb/integration/tb_machine_csr_trap.sv
tb/integration/tb_machine_external_interrupt.sv
tb/integration/tb_machine_exceptions.sv
tb/integration/tb_machine_identification_csrs.sv
tb/compliance/tb_act.sv

tb/unit/tb_alu_unit.sv
tb/unit/tb_register_file.sv
tb/unit/tb_immediate_generator.sv
tb/unit/tb_branch_unit.sv
tb/unit/tb_jump_unit.sv
tb/unit/tb_load_store_unit.sv
tb/unit/tb_control_unit.sv
tb/unit/tb_program_counter.sv
tb/unit/tb_instruction_memory.sv
tb/unit/tb_data_memory.sv
