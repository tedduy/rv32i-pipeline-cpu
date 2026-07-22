# RTL coding and naming style

The project uses these naming rules for new and refactored SystemVerilog:

- Files, modules, types, functions and signals use `lower_snake_case`.
- A synthesizable module normally has the same name as its source file.
- Input, output and bidirectional ports use `i_`, `o_` and `io_` prefixes.
- Active-low signals end in `_n`; clocks and resets are named `i_clk` and
  `i_arst_n` at module boundaries.
- Pipeline-local signals use `if_`, `id_`, `ex_`, `mem_` or `wb_` prefixes.
- Module instances use `u_`; generate blocks use `g_`.
- Parameters, local parameters, opcodes and enum literals use
  `UPPER_SNAKE_CASE`.
- Sequential state may use `_q`; explicitly calculated next state may use
  `_d`.
- Testbench top modules use `tb_`; the instance under test is normally `dut`.

The stable integration modules are:

- `rv32i_core`: native instruction/data valid-ready interfaces.
- `rv32i_top`: separate instruction and data AHB-Lite masters.

Debug outputs belong to the native core and use the `o_debug_` namespace.
Generated ASIC netlists retain the port names from the RTL revision that
created them and must be regenerated after an RTL interface rename.
