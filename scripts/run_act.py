#!/usr/bin/env python3
"""Run one ELF or a directory of self-checking RISC-V ELFs with VCS."""

from __future__ import annotations

import argparse
import hashlib
import subprocess
import sys
from pathlib import Path

from elf_to_mem import ElfError, convert


PASS_MARKER = "RVCP-SUMMARY: TEST PASSED"


def discover(path: Path) -> list[Path]:
    if path.is_file():
        return [path]
    if path.is_dir():
        return sorted(path.rglob("*.elf"))
    return []


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="ELF or directory containing ELFs")
    parser.add_argument("--simv", type=Path, required=True, help="compiled tb_act VCS executable")
    parser.add_argument("--work-dir", type=Path, default=Path("build/act4"))
    parser.add_argument("--max-cycles", type=int, default=1_000_000)
    parser.add_argument("--memory-bytes", type=int, default=1024 * 1024)
    parser.add_argument("--suite-name", default="ACT4 regression")
    args = parser.parse_args()

    tests = discover(args.input)
    if not tests:
        parser.error(f"no .elf tests found at {args.input}")
    if not args.simv.is_file():
        parser.error(f"VCS executable not found: {args.simv}")

    args.work_dir.mkdir(parents=True, exist_ok=True)
    passed = 0
    failed: list[Path] = []

    for index, elf in enumerate(tests, start=1):
        identity = hashlib.sha1(str(elf.resolve()).encode()).hexdigest()[:10]
        stem = f"{elf.stem}-{identity}"
        memory_file = args.work_dir / f"{stem}.hex"
        log_file = args.work_dir / f"{stem}.log"
        print(f"[{index}/{len(tests)}] {elf}")
        try:
            convert(elf, memory_file, args.memory_bytes)
            result = subprocess.run(
                [
                    str(args.simv.resolve()),
                    f"+MEM_HEX={memory_file.resolve()}",
                    f"+TEST_NAME={elf.name}",
                    f"+MAX_CYCLES={args.max_cycles}",
                ],
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                check=False,
            )
            log_file.write_text(result.stdout, encoding="utf-8")
            if result.returncode == 0 and PASS_MARKER in result.stdout:
                passed += 1
                print("  PASS")
            else:
                failed.append(elf)
                print(f"  FAIL (log: {log_file})")
        except (OSError, ElfError) as error:
            failed.append(elf)
            log_file.write_text(f"{error}\n", encoding="utf-8")
            print(f"  ERROR: {error}")

    print(f"\n{args.suite_name}: {passed}/{len(tests)} passed")
    if failed:
        print("Failed tests:")
        for elf in failed:
            print(f"  {elf}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
