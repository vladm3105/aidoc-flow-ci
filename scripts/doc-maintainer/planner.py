#!/usr/bin/env python3
"""IPLAN-0025 doc-maintainer — planner step (§2.1 steps 4-7).

Inputs:
  --merge-sha    The merge commit SHA whose diff drives the plan.
  --gh-repo      <owner>/<repo>.
  --config       Path to .github/doc-maintainer.json.
  --conventions  Path to .github/doc-maintainer-conventions.md.
  --reviewer     LLM choice: 'claude' or 'codex'.
  --out-plan     Path to write the validated plan JSON.

Output JSON shape:
  {
    "merge_sha": "<sha>",
    "pr_number": 123 or null,
    "low_risk_set": [
      {"path": "CHANGELOG.md", "instruction": "...", "rationale": "..."}
    ],
    "high_risk_set": [
      {"path": "ops/DECISIONS.md", "instruction": "...", "rationale": "..."}
    ],
    "validation": {"allowlist_violations": [], "rejected": []}
  }

Hard errors → exit 1 (workflow fails LOUD per D12 / Risk 12):
  - LLM unavailable after 3× retry with backoff.
  - Plan contains entries outside outer allowed_paths (rejects ENTIRE plan).
  - Invalid config schema (missing required fields).

Soft errors → exit 0 with empty plan:
  - No merge PR found.
  - No changed files in merge.

alpha.1 status (per IPLAN-0025 §3 P3 dry-run pilot):
  Real LLM invocation is stubbed; planner returns an EMPTY plan with a
  notice. v1.4.1 ships the actual LLM invocation; v1.4.0's purpose is
  to wire the workflow infrastructure end-to-end in dry-run so we can
  observe that the trigger fires reliably (addressing IPLAN-0018's
  "didn't fire" reliability gap empirically before LLM cost kicks in).
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path


def fail(msg: str) -> None:
    print(f"::error::planner: {msg}", file=sys.stderr)
    sys.exit(1)


def gh_api(path: str) -> dict | list:
    """Wrapper for `gh api <path>` returning parsed JSON."""
    try:
        out = subprocess.run(
            ["gh", "api", path],
            check=True,
            capture_output=True,
            text=True,
        )
        return json.loads(out.stdout)
    except subprocess.CalledProcessError as e:
        fail(f"gh api {path} failed: {e.stderr.strip()[:200]}")
    except json.JSONDecodeError as e:
        fail(f"gh api {path} returned non-JSON: {e}")
    return {}


def resolve_pr_number(gh_repo: str, merge_sha: str) -> int | None:
    """Find the PR number whose merge produced this SHA."""
    pulls = gh_api(f"repos/{gh_repo}/commits/{merge_sha}/pulls")
    if isinstance(pulls, list) and pulls:
        return int(pulls[0]["number"])
    return None


def changed_files(gh_repo: str, merge_sha: str) -> list[str]:
    """List files changed in the merge commit."""
    commit = gh_api(f"repos/{gh_repo}/commits/{merge_sha}")
    files = commit.get("files", []) if isinstance(commit, dict) else []
    return [f["filename"] for f in files]


def load_config(path: str) -> dict:
    p = Path(path)
    if not p.is_file():
        fail(f"config not found: {path}")
    try:
        cfg = json.loads(p.read_text())
    except json.JSONDecodeError as e:
        fail(f"config invalid JSON: {e}")
        return {}
    # Required keys per IPLAN-0025 §2.2.
    for key in ("dry_run", "allowed_paths", "auto_merge"):
        if key not in cfg:
            fail(f"config missing required key: {key}")
    auto_merge = cfg.get("auto_merge", {})
    if not isinstance(auto_merge, dict):
        fail("config.auto_merge must be an object")
    for key in ("low_risk_paths", "high_risk_paths"):
        if key not in auto_merge:
            fail(f"config.auto_merge missing required key: {key}")
    return cfg


def load_conventions(path: str) -> str:
    """Read the consumer's conventions doc; missing file is OK (empty string)."""
    p = Path(path)
    if not p.is_file():
        return ""
    return p.read_text()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--merge-sha", required=True)
    ap.add_argument("--gh-repo", required=True)
    ap.add_argument("--config", required=True)
    ap.add_argument("--conventions", required=True)
    ap.add_argument("--reviewer", required=True, choices=("claude", "codex"))
    ap.add_argument("--out-plan", required=True)
    args = ap.parse_args()

    cfg = load_config(args.config)
    conventions = load_conventions(args.conventions)

    pr_number = resolve_pr_number(args.gh_repo, args.merge_sha)
    files = changed_files(args.gh_repo, args.merge_sha)

    if not files:
        print(f"::notice::planner: no changed files in merge {args.merge_sha}; empty plan.")

    # alpha.1 stub: emit empty plan + notice.
    # The actual LLM invocation (claude/codex CLI call with a structured
    # prompt) ships in v1.4.1 per the IPLAN-0025 §3 alpha-stub note.
    # Wiring this end-to-end NOW lets the IPLAN-0018-style reliability
    # observation start accumulating ahead of LLM cost.
    print(
        "::notice::planner: alpha.1 stub — emitting empty plan."
        " LLM invocation ships in v1.4.1 per IPLAN-0025 §3."
        f" Reviewer would be: {args.reviewer}; conventions doc bytes: {len(conventions)};"
        f" candidate files in merge: {len(files)}; PR: {pr_number}."
    )

    plan = {
        "merge_sha": args.merge_sha,
        "pr_number": pr_number,
        "low_risk_set": [],
        "high_risk_set": [],
        "validation": {
            "allowlist_violations": [],
            "rejected": [],
            "alpha_stub": True,
        },
    }

    out = Path(args.out_plan)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(plan, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
