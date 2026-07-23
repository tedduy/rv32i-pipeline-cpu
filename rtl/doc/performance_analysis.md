# Performance measurement policy

The project does not publish workload-independent CPI, MIPS, Fmax, area or
power claims. Those values depend on the program, memory wait states, target
technology, constraints and tool version.

## Architectural expectations

- The in-order pipeline has IF, ID, EX, MEM and WB stages.
- A correctly predicted straight-line single-cycle instruction stream can
  approach one retired instruction per cycle after pipeline fill.
- Taken control transfers flush younger work.
- Load-use dependencies and native-memory backpressure can stall the pipeline.
- Iterative multiply and divide operations prioritize area over throughput and
  occupy EX for multiple cycles.
- Compressed instructions reduce code size but do not imply a fixed CPI.

## Required reporting method

Any performance result added to this repository must include:

1. Exact RTL commit.
2. Workload ELF or reproducible instruction generator.
3. Clock/reset and memory latency model.
4. Retired instruction and cycle counts from architectural interfaces.
5. Tool name, version, target device/library and constraint file.
6. Raw report location below `build/`.

Use `mcycle`, `minstret` or the commit interface for measurements. Debug PC
changes are not an instruction-retirement counter.

`make synth-yosys` is only a synthesizability sanity check. It does not provide
technology timing, area or power signoff.
