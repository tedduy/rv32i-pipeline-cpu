# Verification

The open-source verification flow is layered so that each tool has one clear
responsibility:

- Verilator performs production RTL lint and runs the reusable cocotb tests.
- Icarus provides simulator-portability regression.
- Yosys checks that the production RTL remains synthesizable.
- ACT4 checks architectural RISC-V compliance.
- SymbiYosys proves bounded interface and retirement invariants.

The cocotb environment drives only the public native memory and interrupt
interfaces and checks architectural results through the commit interface.
Tests must not depend on pipeline hierarchy.

## Current cocotb test plan

| Test | Checks |
| --- | --- |
| `boot_and_retire` | Reset, basic retire trace, forwarding, load-use stall |
| `native_wait_state_protocol` | Stable valid/ready requests and exactly-once stores |
| `rv32i_datapath_control_flow_and_hazards` | Integer ALU, forwarding, load/store, taken branch, JAL and JALR flush |
| `rv32m_corner_cases` | MUL variants, signed/unsigned DIV/REM, divide-by-zero and signed overflow |
| `rv32c_mixed_width_fetch_and_forwarding` | Mixed 16/32-bit fetch across word boundaries and compressed dependencies |
| `constrained_random_architectural_scoreboard` | Seeded RV32I/RV32M/load-store streams against an independent commit/memory model |
| `machine_csr_ecall_and_mret` | CSR read/write semantics, synchronous trap precision and MRET resume |
| `machine_external_interrupt_is_precise` | Masking, precise interrupt entry, `mcause`/`mepc` and replay exactly once |
| `wfi_sleep_wake_and_interrupt_entry` | WFI retirement, sleep bus quiescence, wake-only and wake-plus-trap paths |
| `instruction_load_and_store_access_faults_are_precise` | Precise bus faults, trap metadata and suppression of architectural side effects |
| `synchronous_exception_matrix_and_fence_i` | Illegal, EBREAK, misaligned load/store traps and FENCE.I |
| `software_and_timer_interrupt_priority` | Software/timer interrupt causes and priority |
| `subword_memory_and_complete_branch_matrix` | All byte/halfword lanes and all six branch relations |

Coverage unit suites exhaust all 65,536 RV32C input parcels against an
independent architectural oracle (28 legal and 19 illegal/reserved functional
bins), and directly exercise load/store steering, branch decisions, CSR state,
fetch buffering, decode, multiplier and divider protocols.
Self-checking full-width suites also verify the configurable reset vector,
program counter, jump calculations and every pipeline-register payload/control
field.

The formal protocol harness proves bounded interface and retirement safety for
arbitrary instruction/data responses and reaches both retirement and data-bus
cover goals. Full ISA equivalence with `riscv-formal` remains a separate step:
the current commit interface does not yet expose all required RVFI fields.

## Commands

```sh
make verification-setup
source .tools/oss-cad-suite/environment
make lint
make cocotb-verilator
make cocotb-iverilog
make random-regression
make synth-yosys
make formal
make coverage
make ci
```

`CORE_RANDOM_SEED=0x... COCOTB_TEST_FILTER=constrained_random make
cocotb-verilator` reproduces a particular randomized stream. The default
`random-regression` target runs three reviewed seeds.

The setup target deliberately installs the pinned cocotb release with
`/usr/bin/python3`. OSS CAD Suite continues to provide Verilator, Icarus and
Yosys, but its bundled Python is not used. This keeps the flow compatible with
RHEL/AlmaLinux 9 and its glibc 2.34 runtime.

The Icarus cocotb target uses the small wrappers under
`scripts/icarus-cocotb/`. OSS CAD Suite's default `vvp` launcher forces its
bundled Python runtime, while cocotb must embed the host-compatible Python from
`.venv`.

Coverage output is written below `build/coverage/`. The gate has two distinct
parts:

- Functional coverage must be 100%: 101 architectural commit/bus/trap bins and
  47 exhaustive RV32C legal/illegal-class bins. Bins are sampled from observed
  DUT behavior, not merely from generated stimulus.
- Verilator code coverage is parsed directly from its raw database, preserving
  separate line, branch, expression, FSM-state and toggle points. Identical
  source points from multiple elaborated instances are aggregated for the RTL
  gate; the JSON retains a separate instance-level diagnostic view.

Current gates are 100% line, branch, expression and FSM-state coverage, plus
90% toggle coverage. See `build/coverage/code_coverage.json`,
`build/coverage/functional_coverage.json` and
`build/coverage/rv32c_functional_coverage.json` for machine-readable results;
annotated missed RTL points are under `build/coverage/annotated/`.
