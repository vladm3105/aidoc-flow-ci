#!/usr/bin/env bash
# tests/test_precommit_merge.sh — regression cover for install.sh's
# .pre-commit-config.yaml MERGE, the step that delivers canon's own hooks into a
# consumer that already has a config.
#
# WHY THIS EXISTS: PLAN-018 PR-B changed the merge's de-dup rule from whole-entry
# structural equality to repo-URL keying, so canon could ship a third-party entry
# (pre-commit-hooks) without duplicating it for an adopter already using that repo
# at a different rev. That change was correct for URLs and WRONG for `local`:
# `local` is a PSEUDO-repo, not an identity — pre-commit permits any number of
# them, and 4 of 8 workspace siblings already carry one. Keying on it treated the
# consumer's own local block as a collision and never installed
# `aidoc-flow-pre-push`, silently dropping the OPS-0069 audit-trail check. And
# because the merge still writes the `# CANON:` marker, every later install.sh run
# no-ops — so the hook was unrecoverable by any canon path (cf. FT-32).
#
# The full suite passed with that defect in place. Nothing asserted the merge's
# OUTPUT, only the fragment's content. This file asserts the output.
#
# HOW IT STAYS HONEST: the merge program is EXTRACTED FROM install.sh and run,
# never re-implemented here. A test carrying its own copy of the merge logic
# passes happily while the installer rots.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
ROOT="$(cd "$HERE/.." && pwd)"
INSTALL="$ROOT/install/install.sh"
FRAGMENT="$ROOT/install/templates/pre-commit-hook-block.yaml"

if ! python3 -c 'import yaml' 2>/dev/null && ! python3 -c 'import ruamel.yaml' 2>/dev/null; then
  # In CI a missing YAML library is a BROKEN GATE, not an environment quirk: this
  # whole suite would report `0 passed, 0 failed` and exit 0 while asserting
  # nothing. tests.yml installs python3-yaml explicitly for that reason. Locally,
  # skip-with-notice matches the suite's convention for optional tooling.
  if [ "${CI:-}" = "true" ]; then
    _r "no YAML library in CI — merge assertions did not run (install python3-yaml)"
    suite_summary "precommit-merge"
    exit $?
  fi
  printf '  \033[33mskip\033[0m no YAML library (PyYAML or ruamel.yaml) — merge tests skipped\n'
  suite_summary "precommit-merge"
  exit $?
fi
LIB=pyyaml; python3 -c 'import ruamel.yaml' 2>/dev/null && LIB=ruamel

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# Extract the merge program from install.sh's heredoc.
# Anchored on the MERGE invocation, not on `<<'PYEOF'` alone — install.sh has
# several PYEOF heredocs and the first one is substitute_placeholders. An
# unanchored match silently extracted the wrong program; the PSEUDO_REPOS guard
# below is what caught it, and is why that assertion exists.
python3 - "$INSTALL" > "$TMP/merge.py" <<'PY'
import re, sys
src = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r'python3 - "\$PRECOMMIT_TMP" "\$MERGE_TMP" "\$yaml_lib" <<\'PYEOF\'[^\n]*\n(.*?)\nPYEOF',
              src, re.S)
sys.stdout.write(m.group(1) if m else "")
PY
assert_ok "[ -s '$TMP/merge.py' ]" "merge program extracted from install.sh"
assert_ok "grep -q 'PSEUDO_REPOS' '$TMP/merge.py'" "merge program carries the pseudo-repo rule"

# Run the merge against a consumer fixture. Runs in its own dir because the
# program reads './.pre-commit-config.yaml' by relative path, as install.sh does
# after cd-ing into the cloned consumer.
merge() { # $1 = consumer config content; sets $OUT/$ERR/$RC
  local dir="$TMP/run-$RANDOM$RANDOM"
  mkdir -p "$dir"
  printf '%s\n' "$1" > "$dir/.pre-commit-config.yaml"
  ( cd "$dir" && python3 "$TMP/merge.py" "$FRAGMENT" "$dir/out.yaml" "$LIB" ) \
    >"$TMP/stdout" 2>"$TMP/stderr"
  RC=$?
  OUT="$dir/out.yaml"; ERR="$(cat "$TMP/stderr")"
}

has_hook() { grep -qF "$2" "$1"; }

# --- the defect this file was written for -----------------------------------
echo "== canon's own hooks survive a consumer that already has 'repo: local' =="
merge 'repos:
- repo: local
  hooks:
  - id: my-own-check
    name: my own check
    entry: scripts/mine.sh
    language: script'
assert_eq "$RC" "0" "merge succeeds against a consumer local block"
if has_hook "$OUT" "aidoc-flow-pre-push"; then
  _g "canon's aidoc-flow-pre-push (OPS-0069 audit-trail) IS installed"
else
  _r "canon's aidoc-flow-pre-push was DROPPED — OPS-0069 check silently lost"
fi
if has_hook "$OUT" "my-own-check"; then _g "consumer's own local hook preserved"
else _r "consumer's own local hook preserved"; fi
if has_hook "$OUT" "check-yaml"; then _g "canon's commit-stage hooks installed"
else _r "canon's commit-stage hooks installed"; fi

# Two local blocks are legal pre-commit (verified: validate-config rc=0, both
# hooks run), so appending canon's is correct rather than merely tolerable.
n_local="$(grep -c '^- repo: local' "$OUT")"
assert_ok "[ '${n_local:-0}' -ge 1 ]" "local blocks present after merge (found $n_local)"

# --- the case URL-keying was introduced for ---------------------------------
echo ""
echo "== a consumer on a different rev of a canon third-party repo keeps theirs =="
merge 'repos:
- repo: https://github.com/pre-commit/pre-commit-hooks
  rev: v4.6.0
  hooks:
  - id: check-yaml'
assert_eq "$RC" "0" "merge succeeds against a rev collision"
assert_ok "grep -q 'rev: v4.6.0' '$OUT'" "consumer's rev is kept, not overwritten"
n_dup="$(grep -c 'repo: https://github.com/pre-commit/pre-commit-hooks' "$OUT")"
assert_eq "$n_dup" "1" "no duplicate entry for the same repo URL"
assert_contains "$ERR" "WARN" "collision is reported to the operator"
assert_contains "$ERR" "end-of-file-fixer" "WARN names the canon hook ids they lack"
if has_hook "$OUT" "aidoc-flow-pre-push"; then
  _g "aidoc-flow-pre-push still installed despite the URL collision"
else
  _r "aidoc-flow-pre-push dropped by a URL collision on an unrelated repo"
fi
assert_ok "grep -q '^COLLISIONS=' '$TMP/stdout'" "collision is machine-reported for the summary line"

# --- idempotency -------------------------------------------------------------
echo ""
echo "== merging is idempotent =="
merge 'repos:
- repo: https://github.com/psf/black
  rev: 24.1.0
  hooks:
  - id: black'
first="$(cat "$OUT")"
merge "$first"
assert_eq "$RC" "0" "second merge succeeds"
n2="$(grep -c 'aidoc-flow-pre-push' "$OUT")"
assert_eq "$n2" "1" "re-merging does not duplicate the canon hook"

# --- malformed / hostile consumer input --------------------------------------
# The merge must FAIL CLOSED with an actionable message, never a traceback and
# never a partial write. install.sh removes the temp file and exits before `mv`,
# so the consumer's real file is untouched either way — this asserts the message
# shape, which is what makes the failure diagnosable.
echo ""
echo "== malformed consumer configs fail closed with an actionable message =="
for fixture in 'repos:' 'repos: hello' '- just
- a
- list'; do
  merge "$fixture"
  label="$(printf '%s' "$fixture" | head -1)"
  if [ "$RC" -ne 0 ]; then _g "non-zero rc on malformed input ($label)"
  else _r "non-zero rc on malformed input ($label)"; fi
  if printf '%s' "$ERR" | grep -q 'Traceback'; then
    _r "no raw traceback on malformed input ($label)"
  else
    _g "no raw traceback on malformed input ($label)"
  fi
  if printf '%s' "$ERR" | grep -qE '  FAIL '; then _g "actionable FAIL message ($label)"
  else _r "actionable FAIL message ($label)"; fi
done

# --- terminal-escape neutralisation ------------------------------------------
# Consumer-controlled values are echoed to the operator's terminal. YAML
# double-quoted scalars process escapes, so \e[2K\r could erase and rewrite the
# line the operator reads — directly relevant because a collision WARN is what
# tells them canon's block was only partly applied.
echo ""
echo "== consumer-controlled values cannot inject terminal escapes =="
merge 'repos:
- repo: https://github.com/pre-commit/pre-commit-hooks
  rev: "v1.0.0\e[2K\rSPOOFED"
  hooks:
  - id: check-yaml'
# The WARN must be emitted at all — an else-branch that passes when no WARN
# appeared would go green if collision reporting were removed entirely.
if printf '%s' "$ERR" | grep -q 'SPOOFED'; then
  _g "collision WARN emitted for the hostile-rev fixture"
  # Present is fine; it must be INERT (escaped), not an active control sequence.
  # `grep -q $'\033'` rather than grep -P: BSD grep has no -P.
  if printf '%s' "$ERR" | grep -q "$(printf '\033')"; then
    _r "raw ESC sequence reached the operator's terminal"
  else
    _g "escape rendered inert (repr-quoted), not executed"
  fi
else
  _r "collision WARN emitted for the hostile-rev fixture"
fi

suite_summary "precommit-merge"
