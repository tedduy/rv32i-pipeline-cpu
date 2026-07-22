# RTL workspace

The RTL workspace separates synthesizable logic from verification and tool
collateral:

- `logical/`: technology-independent SystemVerilog design sources.
- `sim/`: unit, integration, compliance and gate-level testbenches.
- `syn/`: synthesis drivers.
- `sdc/`: timing constraints.
- `lint/`: lint rules and waivers.
- `cdc/`: clock-domain crossing collateral.
- `rdc/`: reset-domain crossing collateral.
- `doc/`: design and verification documentation.

Generated files belong below the repository-level `build/` directory.
