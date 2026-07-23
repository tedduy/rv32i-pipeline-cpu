# Logical RTL

This directory contains the technology-independent, synthesizable CPU RTL.
`tdrv32_top` and `tdrv32_core` are structural integration boundaries: they may
declare interconnect and instantiate modules, but must not own behavioral
datapath or control logic. The five-stage implementation lives in
`pipeline/tdrv32_pipeline.sv`; reusable behavior belongs to the appropriate
stage, hazard, bus or common module.

Verification sources live under `verification/`, and bare-metal integration
firmware lives under `firmware/`.
Module and signal naming follows [`../doc/coding_style.md`](../doc/coding_style.md).
