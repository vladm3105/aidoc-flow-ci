#!/usr/bin/env bash
# check-precommit-hooks.sh — the zero-hook detector (PLAN-018 FT-31).
#
# WHY THIS EXISTS: the `pre-commit` reusable runs `pre-commit run --all-files`
# with NO `--hook-stage` when its `run-stage` input is empty (the default), which
# selects the `pre-commit` stage. A config whose hooks are all `stages:
# [pre-push]` matches ZERO hooks, prints nothing, and exits 0 — a green REQUIRED
# check that inspected nothing (PLAN-018 F3). F3 fixed the shipped fragment; this
# is the general DETECTOR for the vacuous-config class. It resolves stages the
# way pre-commit does (per-hook `stages`, else top-level `default_stages`, else
# every stage), so both the explicit `stages: [pre-push]` and the
# `default_stages: [pre-push]` + stageless shapes are caught.
#
# WHERE IT RUNS — operator-side ONLY: install.sh (post-merge), the deploy wizard,
# and the release checklist. NOT on the `pre-commit` reusable's gating path. A
# detector on the gating path would flip any consumer running `run-stage: manual`
# with no `manual` hooks from pass to fail on re-pin — turning a consumer's green
# required check red, which CI-0013 does not authorize. Operator-side, it catches
# the vacuous case at install/release time with no consumer-facing gate change.
#
# EXIT CODES:
#   0  at least one hook runs at the pre-commit (default) stage — the check is real
#   1  ZERO stage-matching hooks — the required check would inspect nothing
#   2  cannot determine (file missing, or no YAML library) — never reports clean
set -uo pipefail

CONFIG="${1:-.pre-commit-config.yaml}"

if [ ! -f "$CONFIG" ]; then
  echo "check-precommit-hooks: $CONFIG not found — cannot verify the required lint check has hooks" >&2
  exit 2
fi

# Count hooks that run at the DEFAULT `pre-commit` stage — i.e. what bare
# `pre-commit run --all-files` (no --hook-stage) selects. Stage resolution
# follows pre-commit's own rules:
#   - a hook with explicit `stages:` uses those;
#   - a hook with NO `stages:` inherits the top-level `default_stages`;
#   - if `default_stages` is also unset, the hook runs at EVERY stage.
# `commit` is the legacy name for `pre-commit`. Getting `default_stages` wrong is
# a real false-pass: `default_stages: [pre-push]` + a stageless hook is genuinely
# vacuous (verified against pre-commit itself), and an earlier version of this
# counter missed it. Emits the count, or SKIP when no YAML library is importable.
count="$(python3 - "$CONFIG" <<'PY'
import sys
try:
    import yaml
except ImportError:
    print("SKIP"); raise SystemExit(0)
try:
    doc = yaml.safe_load(open(sys.argv[1], encoding="utf-8")) or {}
except Exception as e:
    print("ERR:%s" % e); raise SystemExit(0)
if not isinstance(doc, dict):
    print("ERR:not a mapping"); raise SystemExit(0)

def as_list(v):
    if v is None:
        return None
    return [v] if isinstance(v, str) else list(v)

default_stages = as_list(doc.get("default_stages"))  # None => every stage

def runs_at_pre_commit(stages):
    # stages is the hook's EFFECTIVE stage list (None => runs at every stage).
    if stages is None:
        return True
    return "pre-commit" in stages or "commit" in stages

n = 0
for repo in doc.get("repos") or []:
    if not isinstance(repo, dict):
        continue
    for hook in repo.get("hooks") or []:
        if not isinstance(hook, dict):
            continue
        stages = as_list(hook.get("stages"))
        if stages is None:              # no per-hook stages => inherit default_stages
            stages = default_stages     # may still be None => every stage
        if runs_at_pre_commit(stages):
            n += 1
print(n)
PY
)"

case "$count" in
  SKIP)
    echo "check-precommit-hooks: PyYAML unavailable — cannot verify $CONFIG (install python3-yaml)" >&2
    exit 2 ;;
  ERR:*)
    echo "check-precommit-hooks: cannot parse $CONFIG (${count#ERR:})" >&2
    exit 2 ;;
  ''|*[!0-9]*)
    echo "check-precommit-hooks: unexpected counter output '$count' for $CONFIG" >&2
    exit 2 ;;
esac

if [ "$count" -gt 0 ]; then
  echo "check-precommit-hooks: OK — $count hook(s) run at the pre-commit stage in $CONFIG"
  exit 0
fi

# Zero. This is the F3 shape: the pre-commit reusable would run, match nothing,
# and exit 0 — a required check that inspects nothing.
cat >&2 <<EOF
check-precommit-hooks: ZERO hooks run at the pre-commit stage in $CONFIG.

  The 'pre-commit' reusable runs 'pre-commit run --all-files' with no
  --hook-stage (its default), which selects the pre-commit stage. With no hook
  at that stage the job matches nothing and exits 0 — a green REQUIRED check
  that inspected nothing. A config whose only hooks are 'stages: [pre-push]' is
  exactly this case.

  Fix: ensure at least one commit-stage hook (the canon fragment ships
  check-yaml / end-of-file-fixer / trailing-whitespace). See docs/REPO_STANDARDS.md
  section 14.1a.
EOF
exit 1
