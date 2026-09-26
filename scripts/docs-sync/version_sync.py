#!/usr/bin/env python3
"""docs-sync operation 2: version-string propagation (alpha.1 stub).

Ports framework's scripts/sync-version-refs.sh pattern but reads per-consumer
regex map from .github/docs-sync.json.

alpha.1 stub: detection only — logs what WOULD be propagated. Full propagation
+ regex-map design lands in alpha.2 after operations pilot validates the
detection logic.

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
        print(f"version_sync: {config_path} not found; skipping")
        return 0

    try:
        cfg = json.loads(Path(config_path).read_text())
    except (json.JSONDecodeError, UnicodeDecodeError, OSError) as exc:
        # Fail closed and LOUD. Without this the step dies on a bare traceback,
        # and a typo in a documentation-sync config reads as a Python bug rather
        # than as "your config is broken". Note the workflow's own `cfg` step
        # parses this file with `jq` under `set -euo pipefail` and fails first,
        # so this path is defence-in-depth for direct/local runs.
        print(
            f"::error::version_sync: {config_path} is not valid JSON ({exc}); "
            "refusing to guess at a propagation config"
        )
        return 1
    vs_cfg = cfg.get("version_sync", {}) if isinstance(cfg, dict) else None
    if not isinstance(cfg, dict) or not isinstance(vs_cfg, dict):
        # Valid JSON, wrong shape (a list, or a non-object section): .get would
        # die on AttributeError, i.e. the same bare traceback the parse guard
        # above exists to prevent. A config whose SHAPE is wrong is as broken
        # as one whose syntax is.
        print(
            f"::error::version_sync: {config_path} must contain a JSON object "
            'with an object "version_sync" section; '
            "refusing to guess at a propagation config"
        )
        return 1
    if not vs_cfg.get("enabled", True):
        print("version_sync: disabled in config; skipping")
        return 0

    sources = vs_cfg.get("sources", [])
    if not sources:
        print("version_sync: no sources configured; skipping")
        return 0

    for src in sources:
        if not isinstance(src, dict) or "version_file" not in src or "targets" not in src:
            print(
                f"::error::version_sync: {config_path} has a malformed source "
                f"entry ({src!r}); each entry needs version_file and targets"
            )
            return 1
        vf = Path(src["version_file"])
        if not vf.exists():
            print(f"version_sync: {vf} not found; skipping")
            continue
        version = vf.read_text().strip()
        print(f"version_sync: would propagate version={version} into {src['targets']}")

    print("version_sync: alpha.1 stub — full propagation in alpha.2")
    return 0


if __name__ == "__main__":
    sys.exit(main())
