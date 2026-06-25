#!/usr/bin/env python3
"""docs-sync operation 1: CHANGELOG stub-entry.

When merged commit touches trigger_paths AND CHANGELOG wasn't touched,
write a proposed stub entry under section_header. Stub is intentionally
low-quality so contributors rewrite on next PR (currency, not polish).

Reads config from $CONFIG_PATH (default .github/docs-sync.json).
Reads merge SHA from $MERGE_SHA (workflow's github.sha).
Writes proposed update to .docs-sync-proposed/changelog_stub.proposed.
Exits 0 on success or skip; non-zero only on unexpected errors.
"""
from __future__ import annotations
import fnmatch
import json
import os
import re
import subprocess
import sys
from pathlib import Path


def main() -> int:
    config_path = os.environ.get("CONFIG_PATH", ".github/docs-sync.json")
    merge_sha = os.environ.get("MERGE_SHA")
    if not merge_sha:
        print("changelog_stub: MERGE_SHA env not set; skipping")
        return 0

    if not Path(config_path).exists():
        print(f"changelog_stub: {config_path} not found; skipping")
        return 0

    cfg = json.loads(Path(config_path).read_text())
    stub_cfg = cfg.get("changelog_stub", {})
    if not stub_cfg.get("enabled", True):
        print("changelog_stub: disabled in config; skipping")
        return 0

    trigger_paths = stub_cfg.get("trigger_paths", [".github/workflows/*.yml"])
    dest = stub_cfg.get("destination", "CHANGELOG.md")
    header = stub_cfg.get("section_header", "## [Unreleased]")

    changed = subprocess.run(
        ["git", "show", "--name-only", "--format=", merge_sha],
        capture_output=True, text=True, check=True,
    ).stdout.strip().split("\n")

    triggered = any(fnmatch.fnmatch(f, p) for f in changed for p in trigger_paths)
    if not triggered:
        print(f"changelog_stub: no trigger paths touched in {merge_sha[:8]}; skipping")
        return 0

    if dest in changed:
        print(f"changelog_stub: {dest} already touched in {merge_sha[:8]}; skipping")
        return 0

    subject = subprocess.run(
        ["git", "show", "-s", "--format=%s", merge_sha],
        capture_output=True, text=True, check=True,
    ).stdout.strip()
    pr_match = re.search(r"\(#(\d+)\)$", subject)
    pr_ref = f"PR #{pr_match.group(1)}" if pr_match else "recent merge"

    stub_block = f"""
### Changed — (auto-stub from {pr_ref}; please rewrite)

- `{subject}`
"""

    p = Path(dest)
    if not p.exists():
        print(f"changelog_stub: {dest} does not exist; skipping")
        return 0

    s = p.read_text()
    if header not in s:
        print(f"changelog_stub: section '{header}' not found in {dest}; skipping")
        return 0

    insert_at = s.index(header) + len(header)
    new_content = s[:insert_at] + stub_block + s[insert_at:]

    Path(".docs-sync-proposed").mkdir(exist_ok=True)
    Path(".docs-sync-proposed/changelog_stub.proposed").write_text(new_content)
    Path(".docs-sync-proposed/changelog_stub.target").write_text(dest)
    print(f"changelog_stub: proposed update to {dest}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
