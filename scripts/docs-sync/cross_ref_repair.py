#!/usr/bin/env python3
"""docs-sync operation 3: cross-ref dead-link repair (alpha.1 stub).

Per IPLAN-0018 §3.1 op 3: parses lychee --offline output; if dead-link
target was renamed in the merged PR (git -M50% threshold), auto-rewrites
the link. If target was deleted, opens an issue (not auto-fix).

alpha.1 stub: skipped entirely. Full implementation in alpha.2 depends on:
  - Lychee JSON output shape verification (per IPLAN-0018 §6 TO VERIFY)
  - Git-rename detection threshold tuning on a real corpus

Reads config from $CONFIG_PATH (default .github/docs-sync.json).
Exits 0 on success or skip; exits 1 if the config exists but is not parseable,
so a broken config surfaces as a named error rather than a silent no-op.
"""
from __future__ import annotations
import json
import os
import sys
from pathlib import Path


def main() -> int:
    config_path = os.environ.get("CONFIG_PATH", ".github/docs-sync.json")
    if not Path(config_path).exists():
        print(f"cross_ref_repair: {config_path} not found; skipping")
        return 0

    try:
        cfg = json.loads(Path(config_path).read_text())
    except (json.JSONDecodeError, UnicodeDecodeError, OSError) as exc:
        # Fail closed and LOUD rather than on a bare traceback — see the note in
        # version_sync.py, which shares this shape.
        print(
            f"::error::cross_ref_repair: {config_path} is not valid JSON ({exc}); "
            "refusing to guess at a repair config"
        )
        return 1
    cr_cfg = cfg.get("cross_ref_repair", {}) if isinstance(cfg, dict) else None
    if not isinstance(cfg, dict) or not isinstance(cr_cfg, dict):
        # Same shape-guard as version_sync.py: valid JSON with a non-object top
        # level or section must fail closed, not AttributeError.
        print(
            f"::error::cross_ref_repair: {config_path} must contain a JSON object "
            'with an object "cross_ref_repair" section; '
            "refusing to guess at a repair config"
        )
        return 1
    if not cr_cfg.get("enabled", False):
        print("cross_ref_repair: disabled in config; skipping")
        return 0

    print("cross_ref_repair: alpha.1 stub — full implementation in alpha.2")
    print(
        "  (depends on lychee JSON output shape verification + git-rename "
        "threshold tuning per IPLAN-0018 §5 Q3 + §6 TO VERIFY)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
