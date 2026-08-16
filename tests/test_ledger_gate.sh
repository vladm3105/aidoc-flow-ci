#!/usr/bin/env bash
# tests/test_ledger_gate.sh — unit tests for scripts/pre_push_check_ci.sh,
# the Claim-ledger reader added for #469.
#
# Everything runs in a FIXTURE repo, never against this repo's real plans/:
# the real gated set changes every time a plan is edited, so asserting on it
# would make this suite a measurement of the backlog rather than of the gate.
#
# The check_plan.py stub RECORDS ITS ARGV rather than only controlling its
# exit status. A stub that controls only the return value proves nothing about
# how the command was called — and two of the defects under test here (the
# missing --root, and the empty-string argument from `"${arr[@]:-}"`) are
# argument defects that a return-value-only stub cannot see.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

WRAPPER="$ROOT/scripts/pre_push_check_ci.sh"

# --- fixture builder -------------------------------------------------------
# $1 = fixture name; $2 = canon stub exit code; $3 = check_plan stub exit code
_mk() {
  local name="$1" canon_rc="$2" plan_rc="$3"
  local d="$TMP/$name"
  mkdir -p "$d/repo/scripts" "$d/repo/plans"
  cp "$WRAPPER" "$d/repo/scripts/pre_push_check_ci.sh"

  # Canon stub. The wrapper runs canon as a SUBPROCESS because the real canon
  # ends in `exit "$rc"`; if that ever regresses to `source`, this stub's exit
  # would terminate the wrapper and every assertion below would vanish rather
  # than fail — so the stub also prints a marker the tests assert on.
  cat > "$d/repo/scripts/pre_push_check.sh" <<CANON
#!/usr/bin/env bash
echo "CANON-STUB-RAN"
exit $canon_rc
CANON
  chmod +x "$d/repo/scripts/pre_push_check.sh"

  # check_plan.py stub: append argv (one <arg> per line) to a log, then exit.
  cat > "$d/check_plan.py" <<PY
#!/usr/bin/env python3
import sys
with open("$d/argv.log", "a") as fh:
    fh.write("CALL " + " ".join("<%s>" % a for a in sys.argv[1:]) + "\n")
plan = sys.argv[-1]
if $plan_rc:
    print("FAIL %s" % plan)
    print("  - ledger row 7: symbol 'sentinel-symbol' not found in some/file.sh")
    print("  warn %s: ledger row 9: line drifted; citation passes" % plan)
sys.exit($plan_rc)
PY
  printf '%s' "$d"
}

_plan() { # $1 = dir, $2 = filename, $3 = status line (empty = no Status line)
  { [ -n "$3" ] && printf '**Status:** %s\n\n' "$3"; printf '## Claim ledger\n\n| # | Claim |\n'; } \
    > "$1/repo/plans/$2"
}

_run() { # $1 = dir; rest = env assignments
  local d="$1"; shift
  ( cd "$d/repo" && env CHECK_PLAN="$d/check_plan.py" "$@" bash scripts/pre_push_check_ci.sh 2>&1 )
}

# ===========================================================================
echo "== gated / exempt classification =="
d="$(_mk classify 0 0)"
_plan "$d" "PLAN-900_shipped.md"    "SHIPPED — 2026-01-01 (ci/v1.0.0)"
_plan "$d" "PLAN-901_deferred.md"   "DEFERRED to the next cycle"
_plan "$d" "PLAN-902_inprogress.md" "In Progress — P1 done"
_plan "$d" "PLAN-903_ready.md"      "ready — 7-pass verified"
_plan "$d" "PLAN-904_nostatus.md"   ""
out="$(_run "$d")"
assert_contains "$out" "CANON-STUB-RAN"      "runs canon as a subprocess, not sourced"
assert_contains "$out" "gated:  3 plan(s)"   "3 gated (In Progress, ready, no-status)"
assert_contains "$out" "exempt: 2 plan(s)"   "2 exempt (SHIPPED, DEFERRED)"
assert_contains "$out" "PLAN-900_shipped.md" "the exempt set is PRINTED, not silent"
assert_contains "$out" "PLAN-901_deferred.md" "DEFERRED is exempt"

echo "== fail-closed: a plan with no Status line is GATED, never exempt =="
# This is the #469 defect class itself — an unparseable header that silently
# drops a plan from the gate is indistinguishable from having no gate.
assert_absent "$out" "PLAN-904_nostatus.md" "no-status plan is not listed as exempt"
assert_ok "grep -q '<$d/repo/plans/PLAN-904_nostatus.md>' '$d/argv.log'" \
  "no-status plan was actually PASSED to check_plan.py"
assert_fail "grep -q '<$d/repo/plans/PLAN-900_shipped.md>' '$d/argv.log'" \
  "SHIPPED plan was not passed to check_plan.py"

echo "== --root is passed, and no empty-string argument is ever passed =="
# `"${ROOT_ARGS[@]:-}"` expands an EMPTY array to one empty-string argument
# under `set -u`; check_plan.py would receive "" as a plan path. The argv log
# renders every argument as <arg>, so an empty one shows up as a literal <>.
assert_ok   "grep -q -- '<--root>' '$d/argv.log'" "--root is passed to check_plan.py"
assert_fail "grep -q '<>' '$d/argv.log'"          "no empty-string argument is passed"

# The assertion above is VACUOUS on its own: autodetection makes ROOT_ARGS
# non-empty for every directory except `/`, so the empty-array expansion it
# guards is never reached. Force the empty case and re-assert — otherwise the
# guard is tested only in the configuration where it cannot fire.
d="$(_mk noroot 0 0)"
_plan "$d" "PLAN-905_live.md" "In Progress"
out="$(_run "$d" LEDGER_EXTRA_ROOT=)"
assert_fail "grep -q -- '<--root>' '$d/argv.log'" "LEDGER_EXTRA_ROOT= drops the extra root"
assert_fail "grep -q '<>' '$d/argv.log'"          "empty ROOT_ARGS passes NO argument, not an empty one"
assert_ok   "grep -q '<$d/repo/plans/PLAN-905_live.md>' '$d/argv.log'" \
  "the plan is still the only argument when there is no extra root"

echo "== advisory by default: a failing ledger does NOT fail the push =="
d="$(_mk advisory 0 1)"
_plan "$d" "PLAN-910_live.md" "In Progress"
out="$(_run "$d")"; rc=$?
assert_eq "$rc" "0" "canon green + ledger red exits 0 (advisory)"
assert_contains "$out" "ADVISORY" "says it is advisory"
assert_contains "$out" "sentinel-symbol" "prints the failing ROW, not just a count"
assert_absent  "$out" "line drifted; citation passes" \
  "drift warnings are filtered out — they are the gate working, not a failure"

echo "== LEDGER_GATE_BLOCKING=1 makes the same failure blocking =="
d="$(_mk blocking 0 1)"
_plan "$d" "PLAN-911_live.md" "In Progress"
out="$(_run "$d" LEDGER_GATE_BLOCKING=1)"; rc=$?
assert_eq "$rc" "1" "blocking mode exits 1 on a failing ledger"
assert_contains "$out" "::error::" "blocking mode emits a CI error annotation"

echo "== a green ledger is green in both modes =="
d="$(_mk green 0 0)"
_plan "$d" "PLAN-912_live.md" "In Progress"
out="$(_run "$d" LEDGER_GATE_BLOCKING=1)"; rc=$?
assert_eq "$rc" "0" "blocking mode still exits 0 when every gated ledger passes"
assert_contains "$out" "✅ Claim ledgers verified" "reports the green explicitly"

echo "== canon's exit code is never masked by the ledger gate =="
# The wrapper's whole reason to exist is adding a check WITHOUT weakening the
# OPS-0069 audit-trail gate canon owns. A canon failure must survive a green
# ledger, in advisory and blocking mode alike.
d="$(_mk canonred 1 0)"
_plan "$d" "PLAN-913_live.md" "In Progress"
out="$(_run "$d")"; rc=$?
assert_eq "$rc" "1" "canon red + ledger green still exits 1"
assert_contains "$out" "✅ Claim ledgers verified" "ledger gate still ran after canon failed"

echo "== check_plan.py absent: skipped-with-notice, canon rc preserved =="
d="$(_mk missing 0 0)"
_plan "$d" "PLAN-914_live.md" "In Progress"
out="$( cd "$d/repo" && env CHECK_PLAN="$d/nonexistent.py" bash scripts/pre_push_check_ci.sh 2>&1 )"; rc=$?
assert_eq "$rc" "0" "missing check_plan.py does not fail the push"
assert_contains "$out" "skipped" "says it skipped"
assert_contains "$out" "nonexistent.py" "names the path it looked for"

d="$(_mk missing_canonred 1 0)"
_plan "$d" "PLAN-915_live.md" "In Progress"
out="$( cd "$d/repo" && env CHECK_PLAN="$d/nonexistent.py" bash scripts/pre_push_check_ci.sh 2>&1 )"; rc=$?
assert_eq "$rc" "1" "skipping the ledger gate does not mask a canon failure"

echo "== no ledger-bearing plans at all =="
d="$(_mk noplans 0 0)"
printf 'no ledger here\n' > "$d/repo/plans/PLAN-920_none.md"
out="$(_run "$d")"; rc=$?
assert_eq "$rc" "0" "a repo with no Claim ledgers exits 0"
assert_contains "$out" "nothing to verify" "says there was nothing to verify"
assert_fail "test -s '$d/argv.log'" "check_plan.py was not invoked at all"

echo "== ledger heading match is case-insensitive =="
d="$(_mk case 0 0)"
{ printf '**Status:** In Progress\n\n## CLAIM LEDGER\n'; } > "$d/repo/plans/PLAN-930_upper.md"
out="$(_run "$d")"
assert_contains "$out" "gated:  1 plan(s)" "'## CLAIM LEDGER' is matched case-insensitively"

echo "== --ledger-only skips canon, but still runs the ledger gate =="
# The git hook uses this flag because canon is wired as its own pre-push hook.
# If it ever stopped skipping canon, every push would run the canon checks
# twice; if it stopped running the ledger gate, the hook would be inert.
d="$(_mk ledgeronly 1 0)"
_plan "$d" "PLAN-940_live.md" "In Progress"
out="$( cd "$d/repo" && env CHECK_PLAN="$d/check_plan.py" bash scripts/pre_push_check_ci.sh --ledger-only 2>&1 )"; rc=$?
assert_absent  "$out" "CANON-STUB-RAN" "--ledger-only does not run canon"
assert_eq "$rc" "0" "--ledger-only ignores canon's rc (canon runs as its own hook)"
assert_contains "$out" "✅ Claim ledgers verified" "--ledger-only still runs the ledger gate"

echo "== an unrecognised argument fails loudly rather than being ignored =="
# Silently ignoring an unknown flag is how `--ledger-only` typo'd in the hook
# config would turn into a full canon re-run that nobody notices.
d="$(_mk badarg 0 0)"
_plan "$d" "PLAN-941_live.md" "In Progress"
out="$( cd "$d/repo" && env CHECK_PLAN="$d/check_plan.py" bash scripts/pre_push_check_ci.sh --typo 2>&1 )"; rc=$?
assert_eq "$rc" "2" "an unknown argument exits 2"
assert_contains "$out" "usage:" "an unknown argument prints usage"
assert_absent  "$out" "CANON-STUB-RAN" "an unknown argument runs nothing"

suite_summary "ledger-gate"
