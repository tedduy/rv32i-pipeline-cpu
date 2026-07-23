# Bare-metal smoke firmware

This firmware is an integration check, not an RTL unit test. It validates
startup, stack/BSS initialization, machine traps, counters, the M extension,
`FENCE.I` and the simulation UART/status devices.

Use `make firmware-build` to build only, or `make firmware-run` to execute the
ELF through the native memory interfaces with Cocotb + Verilator. Generated
ELF, map and disassembly files are written below `build/firmware/smoke/`;
simulator artifacts stay below `build/cocotb/verilator-firmware/`.

Install the pinned project-local compiler once with
`make riscv-toolchain-setup`. It lives under `.tools/riscv-toolchain/` and is
independent from the optional ACT4 environment.
