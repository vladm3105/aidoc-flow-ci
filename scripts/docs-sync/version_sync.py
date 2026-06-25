#!/usr/bin/env python3
"""docs-sync operation 2: version-string propagation (alpha.1 stub).

Ports framework's scripts/sync-version-refs.sh pattern but reads per-consumer
regex map from .github/docs-sync.json.

alpha.1 stub: detection only — logs what WOULD be propagated. Full propagation
+ regex-map design lands in alpha.2 after operations pilot validates the
detection logic.

Reads config from $CONFIG_PATH (default .github/docs-sync.json).
Exits 0 on success or skip.
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

    cfg = json.loads(Path(config_path).read_text())
    vs_cfg = cfg.get("version_sync", {})
    if not vs_cfg.get("enabled", True):
        print("version_sync: disabled in config; skipping")
        return 0

    sources = vs_cfg.get("sources", [])
    if not sources:
        print("version_sync: no sources configured; skipping")
        return 0

    for src in sources:
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
