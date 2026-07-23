# TDRV32

[![CI](https://github.com/tedduy/TDRV32/actions/workflows/ci.yml/badge.svg)](https://github.com/tedduy/TDRV32/actions/workflows/ci.yml)

A 32-bit RISC-V CPU written in SystemVerilog with a five-stage pipeline:

```text
IF → ID → EX → MEM → WB
```

## Features

- RV32IMC with Zicsr, Zifencei, and Zicntr.
- Data forwarding and load-use hazard detection.
- Pipeline flushing for branches and jumps.
- Iterative multiplier and divider.
- Machine-mode CSRs, exceptions, interrupts, `MRET`, and `WFI`.
- Separate instruction and data native buses with `valid`, `ready`, and fault signaling.
- Dual AHB-Lite master interfaces through `rv32i_top`.
- Commit interface and RVFI support for formal verification.
- Cocotb, constrained-random, coverage, formal, and ACT4 verification flows.
- Bare-metal firmware and a DE2-115 FPGA wrapper.

## Quick Start

Requirements: Git, Docker, and GNU Make.

```bash
git clone https://github.com/tedduy/TDRV32.git
cd TDRV32
make mount
```

`make mount` pulls the CI image and opens a shell at `/workspace`. All tools
required for RTL verification are included in the container.

```bash
make doctor
make lint
make test
make formal
make riscv-formal
```

To work without Docker:

```bash
make setup
make doctor
make test
```

## Common Commands

```bash
make help                # List all targets
make lint                # Run Verilator lint
make test                # Run Cocotb with Verilator and Icarus
make random-regression   # Run constrained-random tests
make coverage            # Measure code and functional coverage
make formal              # Prove protocol properties
make riscv-formal        # Run RVFI ISA checks
make synth-yosys         # Run a synthesis sanity check
make firmware-run        # Run the bare-metal smoke test
make ci                  # Run the complete local quality gate
```

## OpenLane

Enter the OpenLane 2 environment:

```bash
make mount-openlane
```

The repository is mounted at `/workspace`. PDK data is persisted in the
`tdrv32-openlane-pdk` Docker volume.

## Repository Layout

```text
rtl/logical/              Synthesizable RTL
verification/cocotb/     Cocotb testbench
verification/formal/     Protocol and riscv-formal checks
verification/compliance/ ACT4 configuration
firmware/smoke/          Bare-metal firmware
fpga/de2_115/            DE2-115 Quartus project
mk/                      Make targets
scripts/                 Tool setup and utilities
```

Recommended starting points:

1. [`rv32i_core.sv`](rtl/logical/rv32i_core.sv)
2. [`rv32i_pipeline.sv`](rtl/logical/pipeline/rv32i_pipeline.sv)
3. [`test_core.py`](verification/cocotb/test_core.py)

See [`verification/README.md`](verification/README.md) for the verification
plan and coverage policy.

## Upstream Projects

This project uses and builds upon the following open-source projects:

- [RISC-V ISA Manual](https://github.com/riscv/riscv-isa-manual)
- [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build)
- [Verilator](https://github.com/verilator/verilator)
- [Icarus Verilog](https://github.com/steveicarus/iverilog)
- [Yosys](https://github.com/YosysHQ/yosys)
- [SymbiYosys](https://github.com/YosysHQ/sby)
- [Boolector](https://github.com/Boolector/boolector)
- [Cocotb](https://github.com/cocotb/cocotb)
- [riscv-formal](https://github.com/YosysHQ/riscv-formal)
- [RISC-V Architectural Tests](https://github.com/riscv-non-isa/riscv-arch-test)
- [OpenLane 2](https://github.com/efabless/openlane2)

## License

TDRV32 is licensed under the [Apache License 2.0](LICENSE).
