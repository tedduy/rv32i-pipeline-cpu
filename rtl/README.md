# RTL workspace

The RTL workspace contains production design and design-specific policy:

- `logical/`: technology-independent SystemVerilog design sources.
- `sdc/`: timing constraints.
- `lint/`: lint rules and waivers.
- `doc/`: design policy and maintained reports.

Testbench, formal and compliance sources live under `verification/`; firmware
lives under `firmware/`. Generated files belong below the repository-level
`build/` directory, except for the explicitly requested lint log under
`rtl/lint/reports/`.
