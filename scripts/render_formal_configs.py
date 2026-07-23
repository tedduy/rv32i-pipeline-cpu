#!/usr/bin/env python3
"""Render formal-tool configs from the production RTL manifest."""

from __future__ import annotations

import argparse
from pathlib import Path


def rtl_sources(filelist: Path) -> list[str]:
    sources: list[str] = []
    for raw_line in filelist.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("+") or line.startswith("#"):
            continue
        if not line.endswith(".sv"):
            raise ValueError(f"unsupported file-list entry: {line}")
        if not Path(line).is_file():
            raise FileNotFoundError(f"RTL source does not exist: {line}")
        sources.append(line)

    basenames = [Path(source).name for source in sources]
    duplicates = sorted(
        name for name in set(basenames) if basenames.count(name) > 1
    )
    if duplicates:
        raise ValueError(
            "SymbiYosys requires unique source basenames: "
            + ", ".join(duplicates)
        )
    return sources


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--filelist", type=Path, required=True)
    parser.add_argument("--template", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--format", choices=("protocol", "riscv"), required=True)
    args = parser.parse_args()

    sources = rtl_sources(args.filelist)
    rendered = args.template.read_text(encoding="utf-8")

    if args.format == "protocol":
        basename_lines = "\n".join(
            f"    {Path(source).name} \\" for source in sources
        )
        rendered = rendered.replace("@RTL_BASENAMES@", basename_lines)
        rendered = rendered.replace("@RTL_FILES@", "\n".join(sources))
    else:
        riscv_lines = "\n".join(
            f"@basedir@/../../{source}" for source in sources
        )
        rendered = rendered.replace("@RTL_RISCV_FILES@", riscv_lines)

    if "@RTL_" in rendered:
        raise ValueError(f"unexpanded RTL marker in {args.template}")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(rendered, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
