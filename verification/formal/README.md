# Formal verification

Formal verification is split by responsibility:

- `protocol/` proves native-bus, sleep and architectural-retirement safety.
- `riscv/` connects the core to RVFI and checks ISA semantics and architectural
  consistency with YosysHQ riscv-formal.

Both flows derive their production source list from
`rtl/logical/filelist.f`. The checked-in `.in` files contain only
flow-specific settings; rendered configs and proof work directories are
generated below `build/formal/`.

Run `make formal`, `make riscv-formal`, or the extended
`make riscv-formal-all` target from the repository root.
