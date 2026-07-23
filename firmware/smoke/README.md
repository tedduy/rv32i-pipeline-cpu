# Bare-metal smoke firmware

This firmware is an integration check, not an RTL unit test. It validates
startup, stack/BSS initialization, machine traps, counters, the M extension,
`FENCE.I` and the simulation UART/status devices.

Use `make firmware-build` or `make firmware-run`. Generated ELF, map and
disassembly files are written below `build/firmware/smoke/`.
