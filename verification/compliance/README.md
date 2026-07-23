# Architectural compliance

This directory owns the optional RISC-V Architectural Compatibility Test
(ACT4) flow:

- `act4/` contains the architectural profile, Sail settings, linker script and
  reviewed upstream patches.
- `tb_act.sv` is the ELF execution harness around the public native-bus core.

ACT4 is independent from Cocotb and riscv-formal: it executes official
self-checking architectural programs. Use `make act-tools-check`,
`make act-generate` and `make act-regression`.
