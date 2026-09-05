#!/usr/bin/env python3
"""Diff dreamchecker's raw output against a committed baseline of
already-known diagnostics, so a run only fails for diagnostics YOU
introduced - not the ones already present on a clean checkout (147 at
last count, including a preexisting sleep-safety error in
code/modules/wiremod/core/component.dm that makes dreamchecker's own exit
code nonzero unconditionally, regardless of what you changed).

Usage:
    dreamchecker 2>&1 | tools/bootstrap/python modular_zzmeta/tools/dreamchecker_diff.py
    dreamchecker 2>&1 | tools/bootstrap/python modular_zzmeta/tools/dreamchecker_diff.py --update-baseline

Exit code 0 if there are no new diagnostics vs the baseline (or
--update-baseline was passed), 1 otherwise. Also importable: dm_debug_server.py
(the Claude-only MCP tool) uses the same parse/load/save functions so both
paths agree on what counts as "new".
"""
import argparse
import os
import re
import sys

BASELINE_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "dreamchecker_baseline.txt")
_ANSI_RE = re.compile(r'(\x9B|\x1B\[)[0-?]*[ -\/]*[@-~]')


def parse_diagnostics(output: str) -> list[str]:
    """Split raw dreamchecker stdout into diagnostic blocks and normalize
    each to one line, covering both shapes dreamchecker emits: a
    'filename, line N, column N:' location line followed by 'error:'/
    'warning: message', and a bare 'error: message' block (proc-level
    sleep-safety errors) followed by '- file:line:col: ...' context lines.
    Section headers like 'Parsing tgstation.dme...' match neither and are
    dropped.
    """
    clean = _ANSI_RE.sub('', output)
    diagnostics = []
    for block in re.split(r'\n\s*\n', clean):
        block = block.strip()
        if not block:
            continue
        first_line = block.splitlines()[0]
        if re.match(r'^(error|warning):', first_line) or re.search(r', line \d+, column \d+:$', first_line):
            diagnostics.append(" | ".join(line.strip() for line in block.splitlines() if line.strip()))
    return diagnostics


def load_baseline() -> set[str] | None:
    if not os.path.exists(BASELINE_PATH):
        return None
    with open(BASELINE_PATH) as f:
        return {line.rstrip("\n") for line in f if line.strip()}


def save_baseline(diagnostics: list[str]) -> None:
    with open(BASELINE_PATH, "w") as f:
        for d in sorted(diagnostics):
            f.write(d + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument(
        "--update-baseline", action="store_true",
        help="Adopt this run's diagnostics as the new baseline instead of diffing against it.",
    )
    args = parser.parse_args()

    output = sys.stdin.read()
    print(output)

    if "Parsing tgstation.dme" not in output:
        print("dreamchecker did not appear to run (no 'Parsing tgstation.dme...' banner found).", file=sys.stderr)
        return 1

    diagnostics = parse_diagnostics(output)

    if args.update_baseline:
        save_baseline(diagnostics)
        print(f"Baseline updated: {len(diagnostics)} diagnostic(s) adopted at {BASELINE_PATH}")
        return 0

    baseline = load_baseline()
    if baseline is None:
        print(f"No baseline found at {BASELINE_PATH} - run with --update-baseline on a clean tree to create one.", file=sys.stderr)
        return 1

    new = sorted(d for d in diagnostics if d not in baseline)
    fixed = sorted(d for d in baseline if d not in diagnostics)

    if new:
        print(f"\n{len(new)} NEW diagnostic(s) not in baseline:")
        for d in new:
            print(f"  - {d}")
    if fixed:
        print(f"\n{len(fixed)} baseline diagnostic(s) no longer present (run --update-baseline to adopt):")
        for d in fixed:
            print(f"  - {d}")
    if not new and not fixed:
        print(f"\nNo new diagnostics vs baseline ({len(baseline)} known, all still present).")

    return 1 if new else 0


if __name__ == "__main__":
    sys.exit(main())
