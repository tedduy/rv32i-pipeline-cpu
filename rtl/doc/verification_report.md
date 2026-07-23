# Verification status

The maintained verification flow targets the public `rv32i_core` interfaces and
uses only open-source tools in CI.

## Acceptance gate

`make ci` is the required RTL gate:

1. Verilator lint of the public AHB-Lite wrapper.
2. Deterministic and constrained-random Cocotb regression on Verilator.
3. Simulator-portability regression on Icarus Verilog.
4. Verilator code and functional coverage.
5. Yosys synthesizability check.
6. SymbiYosys native-bus and retirement protocol properties.
7. Representative YosysHQ riscv-formal RV32I/RV32C and consistency checks.

The code-coverage policy requires 100% line, branch, expression and FSM-state
coverage, plus at least 90% toggle coverage. Architectural and RV32C functional
bins must both reach 100%. Generated measurements and annotated misses are
written below `build/coverage/`.

## Independent verification layers

| Layer | Scope |
| --- | --- |
| Cocotb | End-to-end behavior through native bus, interrupt and commit ports |
| Functional coverage | Observed architectural, bus, trap and RV32C classes |
| Protocol formal | Request stability, bus legality, retirement safety and reachability |
| riscv-formal | RVFI instruction semantics and architectural consistency |
| ACT4 | Official architectural compatibility programs |
| Firmware smoke | Bare-metal startup, traps, counters, M extension and UART |

ACT4 and firmware are optional local release checks because they require a
RISC-V GCC/Sail environment not installed by the default CI job. Their source
and harnesses live in `verification/compliance/` and `firmware/smoke/`.

No fixed test count or synthesis result is recorded here. The executable gate
and machine-readable output below `build/` are authoritative, preventing this
document from becoming stale as tests are added.
