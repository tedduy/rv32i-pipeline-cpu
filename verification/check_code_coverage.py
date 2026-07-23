#!/usr/bin/env python3
"""Gate individual Verilator coverage points without lossy LCOV conversion."""

from __future__ import annotations

import argparse
from collections import defaultdict
from dataclasses import dataclass
import json
from pathlib import Path
import sys


@dataclass(frozen=True)
class Point:
    kind: str
    count: int
    filename: str
    line: str
    column: str
    comment: str
    hierarchy: str
    state_value: str


def parse_metadata(encoded: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    for item in encoded.split("\x01"):
        if "\x02" in item:
            key, value = item.split("\x02", 1)
            fields[key] = value
    return fields


def read_points(path: Path) -> list[Point]:
    points: list[Point] = []
    for number, raw_line in enumerate(
        path.read_text(encoding="utf-8", errors="replace").splitlines(), 1
    ):
        if not raw_line.startswith("C '"):
            continue
        try:
            encoded, raw_count = raw_line[3:].rsplit("' ", 1)
            fields = parse_metadata(encoded)
            points.append(
                Point(
                    kind=fields.get("t", "unknown"),
                    count=int(raw_count),
                    filename=fields.get("f", "<unknown>"),
                    line=fields.get("l", "?"),
                    column=fields.get("n", "?"),
                    comment=fields.get("o", ""),
                    hierarchy=fields.get("h", ""),
                    state_value=fields.get("Ft", ""),
                )
            )
        except (ValueError, TypeError) as error:
            raise ValueError(f"{path}:{number}: malformed coverage record") from error
    if not points:
        raise ValueError(f"{path}: no Verilator coverage points found")
    return points


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("database", type=Path)
    parser.add_argument("--policy", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()

    policy = json.loads(args.policy.read_text(encoding="utf-8"))
    minimum_hits = int(policy.get("minimum_hits", 1))
    thresholds = policy["thresholds"]
    points = read_points(args.database)

    # Verilator emits the same source point once per elaborated instance.
    # Aggregate those records for the RTL source metric while retaining an
    # instance-level diagnostic view in the JSON report.
    source_counts: dict[tuple[str, ...], int] = defaultdict(int)
    source_examples: dict[tuple[str, ...], Point] = {}
    for point in points:
        semantic_comment = (
            point.state_value if point.kind == "fsm_state" else point.comment
        )
        key = (
            point.kind,
            point.filename,
            point.line,
            point.column,
            semantic_comment,
        )
        source_counts[key] += point.count
        source_examples.setdefault(key, point)

    totals: dict[str, int] = defaultdict(int)
    hits: dict[str, int] = defaultdict(int)
    misses: dict[str, list[Point]] = defaultdict(list)
    for key, count in source_counts.items():
        kind = key[0]
        totals[kind] += 1
        if count >= minimum_hits:
            hits[kind] += 1
        else:
            misses[kind].append(source_examples[key])

    instance_totals: dict[str, int] = defaultdict(int)
    instance_hits: dict[str, int] = defaultdict(int)
    for point in points:
        instance_totals[point.kind] += 1
        if point.count >= minimum_hits:
            instance_hits[point.kind] += 1

    result: dict[str, object] = {
        "minimum_hits": minimum_hits,
        "aggregation": "source point across elaborated instances",
        "metrics": {},
        "instance_metrics": {},
        "passed": True,
    }
    failed = False
    for kind, threshold in thresholds.items():
        total = totals.get(kind, 0)
        hit = hits.get(kind, 0)
        percent = 100.0 * hit / total if total else 0.0
        passed = total > 0 and percent >= float(threshold)
        failed |= not passed
        result["metrics"][kind] = {
            "hit": hit,
            "total": total,
            "percent": round(percent, 3),
            "threshold": float(threshold),
            "passed": passed,
        }
        status = "PASS" if passed else "FAIL"
        print(
            f"{kind:10s} {hit:6d}/{total:<6d} "
            f"{percent:7.2f}%  gate={float(threshold):6.2f}%  {status}"
        )

    for kind in sorted(instance_totals):
        total = instance_totals[kind]
        hit = instance_hits[kind]
        result["instance_metrics"][kind] = {
            "hit": hit,
            "total": total,
            "percent": round(100.0 * hit / total, 3),
        }

    result["passed"] = not failed
    result["uncovered"] = {
        kind: [
            {
                "file": point.filename,
                "line": point.line,
                "column": point.column,
                "comment": point.comment,
                "hierarchy": point.hierarchy,
            }
            for point in kind_misses[: int(policy.get("max_reported_misses", 100))]
        ]
        for kind, kind_misses in misses.items()
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")

    if failed:
        print(f"Code coverage gate: FAIL (details: {args.report})")
        return 1
    print(f"Code coverage gate: PASS (details: {args.report})")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as error:
        print(f"coverage error: {error}", file=sys.stderr)
        raise SystemExit(2)
