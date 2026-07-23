#!/usr/bin/env bash
# tests/test_precommit_refresh.sh — regression cover for the FT-32 REFRESH
# DECISION: given canon's marker version and a consumer's, does install.sh
# re-merge, or no-op?
#
# WHY THIS EXISTS, SEPARATELY FROM test_precommit_merge.sh: that file drives the
# Python MERGE and asserts its output. It says nothing about whether the merge is
# ever REACHED. The whole of FT-32 is the reachability decision — before it, any
# marker at all meant no-op forever and an adopted consumer could never receive a
# canon change. A pre-push review mutated the comparison back to always-no-op
# (restoring the exact FT-32 freeze, fleet-wide) and the full suite stayed GREEN:
# nothing in tests/ referenced CANON_MARK_V, `preserve`, or `refresh`. This file
# is what goes red for that mutation.
#
# HOW IT STAYS HONEST: the decision block is EXTRACTED FROM install.sh between
# its `# >>> PRECOMMIT-MERGE >>>` markers and run for real. Only `fetch_template`
# is stubbed (to hand over a fixture fragment instead of hitting the network); the
# marker parse, the version compare and the merge are the shipped code.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
ROOT="$(cd "$HERE/.." && pwd)"
INSTALL="$ROOT/install/install.sh"
FRAGMENT="$ROOT/install/templates/pre-commit-hook-block.yaml"

# --- M2: the mechanism rests on canon carrying a PARSABLE version -------------
# If the fragment's `vN` is ever dropped, `marker_version` falls back to 1, every
# consumer compares >= and the global freeze silently returns — the exact bug
# FT-32 fixed, with no other symptom. Assert canon always ships one.
if grep -qE '^# CANON: aidoc-flow-ci pre_push_check v[0-9]+' "$FRAGMENT"; then
  _g "canon fragment carries a parsable versioned marker (vN)"
else
  _r "canon fragment lost its versioned marker — refresh silently disabled fleet-wide"
fi
# Canon must dogfood the version it ships (CLAUDE.md: canon-source self-adopts).
frag_v="$(grep -m1 -oE '^# CANON: aidoc-flow-ci pre_push_check v[0-9]+' "$FRAGMENT" | grep -oE '[0-9]+$')"
own_v="$(grep -m1 -oE '^# CANON: aidoc-flow-ci pre_push_check v[0-9]+' "$ROOT/.pre-commit-config.yaml" \
         | grep -oE '[0-9]+$' || echo 0)"
assert_eq "$own_v" "$frag_v" "canon's own .pre-commit-config.yaml is at the version it ships (Wave-0 dogfood)"

if ! python3 -c 'import yaml' 2>/dev/null && ! python3 -c 'import ruamel.yaml' 2>/dev/null; then
  if [ "${CI:-}" = "true" ]; then
    _r "no YAML library in CI — refresh assertions did not run (install python3-yaml)"
    suite_summary "precommit-refresh"; exit $?
  fi
  printf '  \033[33mskip\033[0m no YAML library — refresh decision tests skipped\n'
  suite_summary "precommit-refresh"; exit $?
fi

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# Extract the decision block verbatim from install.sh.
python3 - "$INSTALL" > "$TMP/block.sh" <<'PY'
import re, sys
src = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r'^# >>> PRECOMMIT-MERGE >>>.*?\n(.*?)\n# <<< PRECOMMIT-MERGE <<<',
              src, re.S | re.M)
sys.stdout.write(m.group(1) if m else "")
PY
assert_ok "[ -s '$TMP/block.sh' ]" "decision block extracted from install.sh"
assert_ok "grep -q 'CANON_MARK_V' '$TMP/block.sh'" "extracted block carries the version compare"

# Run the real block against a consumer fixture. `fetch_template` is the only
# stub: it hands over the fragment the caller chose, exactly as the network
# fetch would have.
decide() { # $1 = consumer config ('' = no file); $2 = fragment path → sets DECISION/OUT
  local dir="$TMP/run-$RANDOM$RANDOM"
  mkdir -p "$dir"
  [ -n "$1" ] && printf '%s\n' "$1" > "$dir/.pre-commit-config.yaml"
  {
    # Same options install.sh itself runs under (`set -euo pipefail`, :49). This
    # is fidelity, not decoration: under `set -e` a bare failing command in the
    # decision path aborts the bootstrap, so a version parse that returns
    # non-zero must stay inside an `if`/`||` guard. Running the block under
    # weaker options would hide exactly that class of bug.
    echo 'set -euo pipefail'
    echo "fetch_template() { cp '$2' \"\$2\"; }"
    # validate_fetched (FT-39) guards the fetched body's shape; it is defined
    # OUTSIDE the PRECOMMIT-MERGE markers, so stub it here the same way as
    # fetch_template. This test isolates the version-compare DECISION; the
    # validator's own teeth are in tests/test_install.sh Part 5.
    echo 'validate_fetched() { :; }'
    cat "$TMP/block.sh"
  } > "$dir/drive.sh"
  ( cd "$dir" && bash drive.sh ) >"$TMP/out" 2>"$TMP/err"
  # the decision is the leading verb of the summary line
  DECISION="$(grep -oE '^  (add|merge|refresh|preserve) ' "$TMP/out" | head -1 | tr -d ' ')"
  OUT="$dir/.pre-commit-config.yaml"
}

# A consumer config carrying an arbitrary marker version, otherwise well-formed.
consumer_at() { # $1 = marker line
  printf '%s\n%s' "$1" 'repos:
- repo: local
  hooks:
  - id: aidoc-flow-pre-push
    name: legacy pre-push
    entry: scripts/pre_push_check.sh
    language: script
    stages: [pre-push]'
}

echo "== the FT-32 case matrix =="

decide "" "$FRAGMENT"
assert_eq "$DECISION" "add" "no config at all → install canon fragment verbatim"

decide 'repos:
- repo: local
  hooks:
  - id: mine
    name: mine
    entry: x
    language: script' "$FRAGMENT"
assert_eq "$DECISION" "merge" "config with NO marker → first-adoption merge"

decide "$(consumer_at '# CANON: aidoc-flow-ci pre_push_check (idempotency marker per PLAN-002 §5.2)')" "$FRAGMENT"
assert_eq "$DECISION" "refresh" "UNVERSIONED legacy marker (=v1) < canon → refresh (THE FT-32 FIX)"

decide "$(consumer_at "# CANON: aidoc-flow-ci pre_push_check v${frag_v} (idempotency marker)")" "$FRAGMENT"
assert_eq "$DECISION" "preserve" "marker == canon → no-op (steady state)"

decide "$(consumer_at "# CANON: aidoc-flow-ci pre_push_check v$((frag_v + 1)) (from a newer canon)")" "$FRAGMENT"
assert_eq "$DECISION" "preserve" "marker NEWER than canon → no-op, never downgraded"

decide "$(consumer_at "# CANON: aidoc-flow-ci pre_push_check v$((frag_v + 8)) (two-digit)")" "$FRAGMENT"
assert_eq "$DECISION" "preserve" "two-digit version compares numerically, not lexically"

# --- convergence: a refresh must leave the file at canon's version ------------
# If the stamp were wrong (or hardcoded), every run would re-merge forever. This
# is the property that makes the refresh safe to run on a schedule.
echo ""
echo "== a refresh converges in one pass =="
decide "$(consumer_at '# CANON: aidoc-flow-ci pre_push_check (legacy)')" "$FRAGMENT"
assert_eq "$DECISION" "refresh" "first pass refreshes"
refreshed="$(cat "$OUT")"
decide "$refreshed" "$FRAGMENT"
assert_eq "$DECISION" "preserve" "second pass no-ops — the refresh stamped canon's vN"
n_mark="$(printf '%s\n' "$refreshed" | grep -c '^# CANON: aidoc-flow-ci pre_push_check' || true)"
assert_eq "$n_mark" "1" "exactly one marker line survives (no stale-marker accumulation)"

# --- the marker must not be read from unrelated prose ------------------------
# An anchored parse matters: a consumer comment merely MENTIONING an old version
# must not be mistaken for their marker and trigger a pointless re-merge.
echo ""
echo "== the version is read from the marker line, not from anywhere in the file =="
decide "$(printf '%s\n%s\n%s' \
  "# CANON: aidoc-flow-ci pre_push_check v${frag_v} (current)" \
  "# note: migrated from pre_push_check v1 tooling in 2024" \
  'repos:
- repo: local
  hooks:
  - id: aidoc-flow-pre-push
    name: pp
    entry: scripts/pre_push_check.sh
    language: script
    stages: [pre-push]')" "$FRAGMENT"
assert_eq "$DECISION" "preserve" "an unrelated 'v1' mention does not force a spurious refresh"
assert_ok "! grep -q 'integer expression expected' '$TMP/err'" "no shell integer-compare error leaks to the operator"

# --- a refresh is ADDITIVE: it must never clobber a consumer's wrapper --------
# Consumers point aidoc-flow-pre-push at scripts/pre_push_check_<repo>.sh
# (PLAN-002 §4.8). A refresh that overwrote that entry would silently disable
# their repo-specific checks on every adopted repo at once.
echo ""
echo "== a refresh preserves a consumer's wrapper entry =="
decide "$(printf '%s\n%s' '# CANON: aidoc-flow-ci pre_push_check (legacy)' 'repos:
- repo: local
  hooks:
  - id: aidoc-flow-pre-push
    name: ops wrapper
    entry: scripts/pre_push_check_ops.sh
    language: script
    stages: [pre-push]')" "$FRAGMENT"
assert_eq "$DECISION" "refresh" "wrapper consumer is refreshed"
assert_ok "grep -q 'pre_push_check_ops.sh' '$OUT'" "consumer's wrapper entry survives the refresh"
n_pp="$(grep -c 'id: aidoc-flow-pre-push' "$OUT")"
assert_eq "$n_pp" "1" "wrapper is not duplicated by canon's copy"

suite_summary "precommit-refresh"
