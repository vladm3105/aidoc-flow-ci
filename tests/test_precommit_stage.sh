#!/usr/bin/env bash
# tests/test_precommit_stage.sh — the zero-hook detector (PLAN-018 FT-31),
# install/check-precommit-hooks.sh.
#
# WHY THIS EXISTS: the detector is the general form of F3 — it catches a
# .pre-commit-config.yaml that would pass the required `pre-commit` check while
# selecting ZERO hooks (all hooks pre-push-staged, nothing at the pre-commit
# stage the reusable runs). It runs operator-side (install.sh + wizard +
# release checklist), so a regression in the detector itself is silent unless
# something drives it. This does.
#
# It also pins the two properties that make the detector correct and safe:
#   - the canon fragment it ships passes (so a real cold start is never vacuous);
#   - it agrees with the reusable's ACTUAL default-stage behaviour, extracted
#     from the workflow rather than restated.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
ROOT="$(cd "$HERE/.." && pwd)"
DET="$ROOT/install/check-precommit-hooks.sh"

assert_ok "[ -x '$DET' ]" "detector is executable"

if ! python3 -c 'import yaml' 2>/dev/null; then
  # In CI a missing YAML lib is a broken gate, not an environment quirk (tests.yml
  # installs python3-yaml). Locally, skip-with-notice per suite convention.
  if [ "${CI:-}" = "true" ]; then
    _r "no PyYAML in CI — detector assertions did not run (install python3-yaml)"
    suite_summary "precommit-stage"; exit $?
  fi
  printf '  \033[33mskip\033[0m PyYAML not installed — detector tests skipped\n'
  suite_summary "precommit-stage"; exit $?
fi

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
run() { bash "$DET" "$1" >/dev/null 2>&1; echo $?; }

# ---------------------------------------------------------------------------
# exit codes: 0 = has a stage-matching hook, 1 = zero, 2 = cannot determine
# ---------------------------------------------------------------------------
echo "== detector exit codes on representative configs =="

# The canon fragment canon actually ships — a cold start must never be vacuous.
assert_eq "$(run "$ROOT/install/templates/pre-commit-hook-block.yaml")" "0" \
  "canon fragment: has pre-commit-stage hooks (exit 0)"

# Vacuous — the exact F3 shape: only pre-push hooks.
cat > "$TMP/vac.yaml" <<'EOF'
repos:
- repo: local
  hooks:
  - id: only-pre-push
    name: only pre-push
    entry: 'true'
    language: system
    stages: [pre-push]
EOF
assert_eq "$(run "$TMP/vac.yaml")" "1" "pre-push-only config: ZERO stage hooks (exit 1)"

# A hook with NO stages key runs at every stage → counts.
cat > "$TMP/nostage.yaml" <<'EOF'
repos:
- repo: local
  hooks:
  - id: unstaged
    name: unstaged
    entry: 'true'
    language: system
EOF
assert_eq "$(run "$TMP/nostage.yaml")" "0" "hook with no stages: key counts (exit 0)"

# Legacy `commit` stage name is accepted alongside `pre-commit`.
cat > "$TMP/legacy.yaml" <<'EOF'
repos:
- repo: local
  hooks:
  - id: legacy
    name: legacy
    entry: 'true'
    language: system
    stages: [commit]
EOF
assert_eq "$(run "$TMP/legacy.yaml")" "0" "legacy 'commit' stage counts (exit 0)"

# A stageless hook inherits top-level default_stages. default_stages: [pre-push]
# makes a stageless hook genuinely vacuous (verified against pre-commit itself);
# an earlier counter missed this and false-passed it (exit 0). Must be exit 1.
cat > "$TMP/ds-vac.yaml" <<'EOF'
default_stages: [pre-push]
repos:
- repo: local
  hooks:
  - {id: s, name: s, entry: 'true', language: system}
EOF
assert_eq "$(run "$TMP/ds-vac.yaml")" "1" "default_stages:[pre-push] + stageless hook: vacuous (exit 1)"

cat > "$TMP/ds-ok.yaml" <<'EOF'
default_stages: [pre-commit]
repos:
- repo: local
  hooks:
  - {id: s, name: s, entry: 'true', language: system}
EOF
assert_eq "$(run "$TMP/ds-ok.yaml")" "0" "default_stages:[pre-commit] + stageless hook: real (exit 0)"

# An explicit per-hook stages: overrides default_stages.
cat > "$TMP/ds-override.yaml" <<'EOF'
default_stages: [pre-push]
repos:
- repo: local
  hooks:
  - {id: s, name: s, entry: 'true', language: system, stages: [pre-commit]}
EOF
assert_eq "$(run "$TMP/ds-override.yaml")" "0" "explicit stages override default_stages (exit 0)"

# Missing file / unparseable → cannot determine (exit 2), never a false 0/1.
assert_eq "$(run "$TMP/does-not-exist.yaml")" "2" "missing file: cannot determine (exit 2)"
printf 'repos: : : not yaml\n' > "$TMP/bad.yaml"
assert_eq "$(run "$TMP/bad.yaml")" "2" "unparseable YAML: cannot determine (exit 2)"
printf -- '- a\n- b\n' > "$TMP/list.yaml"
assert_eq "$(run "$TMP/list.yaml")" "2" "top-level list (not a mapping): cannot determine (exit 2)"

# ---------------------------------------------------------------------------
# The detector's stage assumption must match what the reusable actually does.
# Extracted from the workflow, not restated — if the empty-run-stage branch ever
# starts passing --hook-stage, the detector's premise changed and this says so.
# ---------------------------------------------------------------------------
echo ""
echo "== detector matches the reusable's default-stage behaviour =="
PCWF="$ROOT/.github/workflows/pre-commit.yml"
if grep -qE '^\s*pre-commit run --all-files --show-diff-on-failure$' "$PCWF"; then
  _g "reusable's default branch runs bare (selects the pre-commit stage) — detector premise holds"
else
  _r "reusable's default branch no longer runs bare — detector premise changed"
fi

suite_summary "precommit-stage"
