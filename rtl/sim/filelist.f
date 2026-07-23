+incdir+rtl/logical/common
+incdir+rtl/logical/stages/fetch
+incdir+rtl/logical/stages/decode
+incdir+rtl/logical/stages/execute
+incdir+rtl/logical/stages/memory
+incdir+rtl/logical/stages/system
+incdir+rtl/logical/pipeline
+incdir+rtl/logical/hazard
+incdir+rtl/logical/bus
+incdir+rtl/sim/unit
+incdir+rtl/sim/integration
+incdir+rtl/sim/compliance

rtl/logical/common/adder_n_bit.sv
rtl/logical/common/mux2to1.sv
rtl/logical/common/mux3to1.sv
rtl/logical/common/mux4to1.sv

rtl/logical/stages/fetch/program_counter.sv
rtl/logical/stages/fetch/instruction_memory.sv

rtl/logical/stages/decode/control_unit.sv
rtl/logical/stages/decode/immediate_generator.sv
rtl/logical/stages/decode/register_file.sv
rtl/logical/stages/decode/rv32c_decompressor.sv

rtl/logical/stages/fetch/rv32c_fetch_buffer.sv

rtl/logical/stages/execute/alu_unit.sv
rtl/logical/stages/execute/iterative_multiplier.sv
rtl/logical/stages/execute/branch_unit.sv
rtl/logical/stages/execute/jump_unit.sv

rtl/logical/stages/memory/load_store_unit.sv
rtl/logical/stages/memory/data_memory.sv

rtl/logical/stages/system/csr_file.sv

rtl/logical/pipeline/if_id_register.sv
rtl/logical/pipeline/id_ex_register.sv
rtl/logical/pipeline/ex_mem_register.sv
rtl/logical/pipeline/mem_wb_register.sv

rtl/logical/hazard/forwarding_unit.sv
rtl/logical/hazard/hazard_detection_unit.sv

rtl/logical/bus/native_to_ahb_lite.sv
rtl/logical/rv32i_core.sv
rtl/logical/rv32i_top.sv

rtl/sim/integration/tb_full_verification.sv
rtl/sim/integration/tb_rv32i_pipeline.sv
rtl/sim/integration/tb_load_use_hazard.sv
rtl/sim/integration/tb_memory_wait_states.sv
rtl/sim/integration/tb_reset_vector.sv
rtl/sim/integration/tb_commit_interface.sv
rtl/sim/integration/tb_machine_csr_trap.sv
rtl/sim/integration/tb_machine_external_interrupt.sv
rtl/sim/integration/tb_machine_exceptions.sv
rtl/sim/integration/tb_machine_identification_csrs.sv
rtl/sim/integration/tb_bus_access_faults.sv
rtl/sim/integration/tb_ahb_lite_interface.sv
rtl/sim/integration/tb_wfi_sleep.sv
rtl/sim/integration/tb_fence_i.sv
rtl/sim/integration/tb_zicntr.sv
rtl/sim/integration/tb_zmmul.sv
rtl/sim/compliance/tb_act.sv

rtl/sim/unit/tb_alu_unit.sv
rtl/sim/unit/tb_multicycle_multiplier.sv
rtl/sim/unit/tb_register_file.sv
rtl/sim/unit/tb_immediate_generator.sv
rtl/sim/unit/tb_branch_unit.sv
rtl/sim/unit/tb_jump_unit.sv
rtl/sim/unit/tb_load_store_unit.sv
rtl/sim/unit/tb_control_unit.sv
rtl/sim/unit/tb_program_counter.sv
rtl/sim/unit/tb_instruction_memory.sv
rtl/sim/unit/tb_data_memory.sv
rtl/sim/unit/tb_native_to_ahb_lite.sv
rtl/sim/unit/tb_rv32c_decompressor.sv
rtl/sim/unit/tb_rv32c_fetch_buffer.sv
