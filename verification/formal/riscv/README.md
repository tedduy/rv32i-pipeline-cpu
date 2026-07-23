# RVFI and riscv-formal

The core exposes one in-order RVFI channel when compiled with
`RISCV_FORMAL`. The production RTL does not contain the RVFI shadow registers.

The flow pins the official YosysHQ `riscv-formal` repository and stores the
checkout under the ignored `.tools/` directory:

```sh
make riscv-formal-setup
make riscv-formal
```

The default target runs a bounded representative RV32I/RV32C gate plus register
and PC consistency checks. Use `make riscv-formal-all` to generate every
RV32IMC instruction check locally; M-extension jobs use a deeper bound because
the multiplier and divider are iterative.

The memory abstraction returns an unconstrained value with zero wait states.
`RISCV_FORMAL_ALIGNED_MEM` is enabled because the native data bus transfers
aligned 32-bit words with per-byte masks.
