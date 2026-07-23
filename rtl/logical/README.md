# Logical RTL

This directory contains the technology-independent, synthesizable CPU RTL.
`rv32i_top` and `rv32i_core` are structural integration boundaries: they may
declare interconnect and instantiate modules, but must not own behavioral
datapath or control logic. The five-stage implementation lives in
`pipeline/rv32i_pipeline.sv`; reusable behavior belongs to the appropriate
stage, hazard, bus or common module.

Verification sources live under `verification/`, and bare-metal integration
firmware lives under `firmware/`.
Module and signal naming follows [`../doc/coding_style.md`](../doc/coding_style.md).
