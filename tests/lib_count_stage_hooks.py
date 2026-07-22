#!/usr/bin/env python3
"""Count hooks in a pre-commit config that run at the DEFAULT (`pre-commit`) stage.

Support file for tests/test_install.sh Part 4 (PLAN-018 F3). Lives as its own
file rather than a heredoc inside the test so the YAML parsing is readable and
shellcheck/quoting cannot mangle it.

Prints an integer, or `SKIP` when PyYAML is unavailable (the test suite's
existing convention for optional tooling — see tests/test_lint.sh).

A hook with no `stages:` key runs at every stage in pre-commit, so it counts.
`commit` is accepted alongside `pre-commit` because pre-commit renamed the
stage; older consumer configs may still use the legacy name.
"""
import sys

try:
    import yaml
except ImportError:
    print("SKIP")
    raise SystemExit(0)

doc = yaml.safe_load(open(sys.argv[1], encoding="utf-8")) or {}

count = 0
for repo in doc.get("repos") or []:
    if not isinstance(repo, dict):
        continue
    for hook in repo.get("hooks") or []:
        if not isinstance(hook, dict):
            continue
        stages = hook.get("stages")
        if stages is None or "pre-commit" in stages or "commit" in stages:
            count += 1

print(count)
