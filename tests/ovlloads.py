#!/usr/bin/env python3
"""Print each scenario's overlay load count (its overlay-loads checkpoint, STING Ctrl-Y) for the golden and candidate
builds of the last tests/regress.sh run, from obj/regress.json: the working-set measure for refactor phase 5."""
import json
import re
import sys
from pathlib import Path

report = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "obj" / "regress.json")
runs = json.loads(report.read_text())


def loads(build):
    for line in build.get("checkpoints", {}).get("overlay-loads", {}).get("text", []):
        m = re.search(r"overlay loads (\d+)", line, re.IGNORECASE)
        if m:
            return int(m.group(1))
    return None


for name, run in sorted(runs.items()):
    g, c = loads(run.get("golden", {})), loads(run.get("candidate", {}))
    if g is not None or c is not None:
        change = "" if g is None or c is None else f"  ({c - g:+d})"
        print(f"{name:12} golden {g}  candidate {c}{change}")
