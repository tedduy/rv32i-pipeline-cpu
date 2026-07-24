#!/usr/bin/env python3
"""Reject repository drift between ownership boundaries and tool manifests."""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
RTL_FILELIST = ROOT / "rtl/logical/filelist.f"


def fail(message: str) -> None:
    raise SystemExit(f"Consistency error: {message}")


def rtl_sources() -> list[Path]:
    sources: list[Path] = []
    for raw_line in RTL_FILELIST.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith(("+", "#")):
            continue
        source = ROOT / line
        if source.suffix != ".sv":
            fail(f"unsupported production manifest entry: {line}")
        if not source.is_file():
            fail(f"missing production source: {line}")
        sources.append(source.resolve())
    if len(sources) != len(set(sources)):
        fail("duplicate source in rtl/logical/filelist.f")
    return sources


def check_structural_boundaries() -> None:
    forbidden = re.compile(
        r"^\s*(assign\b|always(?:_comb|_ff|_latch)?\b|"
        r"function\b|task\b|generate\b)"
    )
    for relative in ("rtl/logical/tdrv32_core.sv", "rtl/logical/tdrv32_top.sv"):
        path = ROOT / relative
        for number, line in enumerate(
            path.read_text(encoding="utf-8").splitlines(), start=1
        ):
            if forbidden.match(line):
                fail(f"{relative}:{number} owns behavior instead of hierarchy")


def check_fpga_manifest(production: list[Path]) -> None:
    qsf = ROOT / "fpga/de2_115/tdrv32_top.qsf"
    qsf_sources: set[Path] = set()
    pattern = re.compile(r"SYSTEMVERILOG_FILE\s+(\S+)")
    for line in qsf.read_text(encoding="utf-8").splitlines():
        match = pattern.search(line)
        if match:
            source = (qsf.parent / match.group(1)).resolve()
            if not source.is_file():
                fail(f"Quartus source does not exist: {match.group(1)}")
            if source.is_relative_to(ROOT / "rtl/logical"):
                qsf_sources.add(source)

    production_set = set(production)
    missing = sorted(path.relative_to(ROOT) for path in production_set - qsf_sources)
    extra = sorted(path.relative_to(ROOT) for path in qsf_sources - production_set)
    if missing or extra:
        fail(f"Quartus RTL manifest drift: missing={missing}, extra={extra}")


def check_formal_templates() -> None:
    templates = {
        ROOT / "verification/formal/protocol/tdrv32_core_protocol.sby.in":
            "@RTL_BASENAMES@",
        ROOT / "verification/formal/ahb/native_to_ahb_lite_protocol.sby.in":
            "@RTL_BASENAMES@",
        ROOT / "verification/formal/ahb/tdrv32_top_ahb_protocol.sby.in":
            "@RTL_BASENAMES@",
        ROOT / "verification/formal/riscv/checks.cfg.in":
            "@RTL_RISCV_FILES@",
    }
    for path, marker in templates.items():
        text = path.read_text(encoding="utf-8")
        if text.count(marker) != 1:
            fail(f"{path.relative_to(ROOT)} must contain exactly one {marker}")


def check_removed_legacy_paths() -> None:
    forbidden = (
        "rtl/sim",
        "rtl/cdc",
        "rtl/rdc",
        "rtl/syn/dc",
        "verification/riscv-formal",
        "asic/sky130/netlist/rv32i_top.v",
    )
    for relative in forbidden:
        path = ROOT / relative
        if path.is_file() or (path.is_dir() and any(item.is_file() for item in path.rglob("*"))):
            fail(f"legacy path still exists: {relative}")


def check_portable_paths() -> None:
    ignored_parts = {".git", ".tools", ".venv", "build", "__pycache__"}
    checked_suffixes = {
        ".cfg", ".f", ".json", ".md", ".mk", ".py", ".qsf", ".sh",
        ".sv", ".tcl", ".vlt", ".yaml", ".yml",
    }
    absolute_user_path = re.compile(r"(?<![A-Za-z0-9])/(?:home|Users)/")

    for path in ROOT.rglob("*"):
        if (
            not path.is_file()
            or any(part in ignored_parts for part in path.relative_to(ROOT).parts)
            or path.suffix not in checked_suffixes
        ):
            continue
        for number, line in enumerate(
            path.read_text(encoding="utf-8", errors="ignore").splitlines(), start=1
        ):
            if absolute_user_path.search(line):
                fail(
                    f"{path.relative_to(ROOT)}:{number} contains a "
                    "machine-specific absolute path"
                )


def main() -> int:
    production = rtl_sources()
    check_structural_boundaries()
    check_fpga_manifest(production)
    check_formal_templates()
    check_removed_legacy_paths()
    check_portable_paths()
    print(
        "Consistency: PASS "
        f"({len(production)} production RTL sources, structural top/core, "
        "portable paths)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
