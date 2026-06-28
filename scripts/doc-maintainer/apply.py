#!/usr/bin/env python3
"""IPLAN-0025 doc-maintainer — apply step (§2.1 step 8).

Reads a validated plan JSON + applies the per-file edits via the chosen
LLM in apply-mode, producing .proposed files in --out-dir.

Inputs:
  --plan       Path to plan JSON produced by planner.py.
  --tier       'low_risk' or 'high_risk' — which set to apply.
  --gh-repo    <owner>/<repo>.
  --reviewer   LLM choice: 'claude' or 'codex'.
  --out-dir    Output directory for .proposed files.

Per IPLAN-0025 §2.1 step 8:
  - Each plan entry produces <out-dir>/<path>.proposed with the new
    file content.
  - Prompt requires the AI to REDACT secret-shaped strings (Risk 11)
    + forbids source code / governance config edits.
  - LLM unavailable → fail LOUD per D12 / Risk 12.

alpha.1 status: planner emits empty plans; apply.py is a no-op pass-through
in v1.4.0. Real apply-mode ships in v1.4.1.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def fail(msg: str) -> None:
    print(f"::error::apply: {msg}", file=sys.stderr)
    sys.exit(1)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--plan", required=True)
    ap.add_argument("--tier", required=True, choices=("low_risk", "high_risk"))
    ap.add_argument("--gh-repo", required=True)
    ap.add_argument("--reviewer", required=True, choices=("claude", "codex"))
    ap.add_argument("--out-dir", required=True)
    args = ap.parse_args()

    plan_path = Path(args.plan)
    if not plan_path.is_file():
        fail(f"plan not found: {args.plan}")
    try:
        plan = json.loads(plan_path.read_text())
    except json.JSONDecodeError as e:
        fail(f"plan invalid JSON: {e}")

    entries = plan.get(f"{args.tier}_set", [])
    if not entries:
        print(f"::notice::apply: no {args.tier} entries — nothing to apply.")
        return 0

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    # alpha.1: nothing to apply because planner emits empty plans.
    # When v1.4.1 ships the real planner, apply.py will iterate `entries`,
    # invoke `claude --apply-edit` per entry, write each result to
    # <out-dir>/<path>.proposed.
    print(
        f"::notice::apply: alpha.1 stub — would apply {len(entries)} {args.tier} entries"
        f" via {args.reviewer} in v1.4.1; no-op in v1.4.0."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
