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
  # $4 selects the OUTPUT SHAPE, independently of the exit status, because the
  # two together are what the wrapper has to disentangle: rc=0 also means
  # "declined to look", and rc!=0 with unparseable output means the gate broke
  # rather than the ledger being stale.
  local shape="${4:-rows}"
  cat > "$d/check_plan.py" <<PY
#!/usr/bin/env python3
import sys
with open("$d/argv.log", "a") as fh:
    fh.write("CALL " + " ".join("<%s>" % a for a in sys.argv[1:]) + "\n")
plan = sys.argv[-1]
shape = "$shape"
if shape == "skipped":
    print("ok   %s (not a gated plan; skipped)" % plan)
elif shape == "crash":
    print("Traceback (most recent call last):", file=sys.stderr)
    print('  File "check_plan.py", line 1, in <module>', file=sys.stderr)
    print("RuntimeError: boom", file=sys.stderr)
elif shape == "unparseable":
    print("check_plan.py: error: unrecognized arguments: --root")
elif $plan_rc:
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
# The gated roster is printed too, so absence from the WHOLE output no longer
# proves absence from the exempt list. Scope to the exempt section.
exempt_block="$(printf '%s\n' "$out" | sed -n '/exempt:/,/^$/p')"
assert_absent "$exempt_block" "PLAN-904_nostatus.md" "no-status plan is not listed as exempt"
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

echo "== no PLAN files at all: nothing to verify (the only benign zero) =="
d="$(_mk noplans 0 0)"
out="$(_run "$d")"; rc=$?
assert_eq "$rc" "0" "a repo with no PLAN files exits 0"
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

echo "== PLAN-028 B3: the wrapper FORWARDS --promote and skips the ledger gate =="
# The wrapper rejected every argument but --ledger-only, so canon's promotion
# mode was unreachable through it — and this file is the reference design every
# consumer wrapper is copied from. Forwarding alone was not enough: the parser
# had to learn the flag, or the usage error fired before canon ever ran.
d="$(_mk promote 0 0)"
_plan "$d" "PLAN-942_live.md" "In Progress"
# Make the stub echo its own argv so forwarding is observed, not assumed.
cat > "$d/repo/scripts/pre_push_check.sh" <<'CANON'
#!/usr/bin/env bash
echo "CANON-STUB-RAN args:$*"
exit 0
CANON
chmod +x "$d/repo/scripts/pre_push_check.sh"
out="$( cd "$d/repo" && env CHECK_PLAN="$d/check_plan.py" bash scripts/pre_push_check_ci.sh --promote staging 2>&1 )"; rc=$?
assert_eq "$rc" "0" "--promote exits with canon's rc"
assert_contains "$out" "CANON-STUB-RAN args:--promote staging" "--promote is forwarded to canon verbatim"
assert_contains "$out" "claim-ledger gate is skipped" "--promote skips the ledger gate, and says so"
assert_absent  "$out" "Claim ledgers verified" "--promote does not run the ledger gate over an empty range"

# The wrapper must not swallow canon's refusal — a promotion canon rejects has
# to fail the wrapper too, or the gate is decorative.
d="$(_mk promotefail 1 0)"
_plan "$d" "PLAN-943_live.md" "In Progress"
out="$( cd "$d/repo" && env CHECK_PLAN="$d/check_plan.py" bash scripts/pre_push_check_ci.sh --promote staging 2>&1 )"; rc=$?
assert_eq "$rc" "1" "a promotion canon REFUSES fails the wrapper too"

# Argument handling stays exhaustive now that the parser is a loop.
d="$(_mk promotearg 0 0)"
_plan "$d" "PLAN-944_live.md" "In Progress"
out="$( cd "$d/repo" && env CHECK_PLAN="$d/check_plan.py" bash scripts/pre_push_check_ci.sh --promote 2>&1 )"; rc=$?
assert_eq "$rc" "2" "--promote with no target exits 2"
out="$( cd "$d/repo" && env CHECK_PLAN="$d/check_plan.py" bash scripts/pre_push_check_ci.sh --promote staging --typo 2>&1 )"; rc=$?
assert_eq "$rc" "2" "a trailing unknown argument after --promote still exits 2"
assert_absent "$out" "CANON-STUB-RAN" "a rejected argument list runs nothing"
out="$( cd "$d/repo" && env CHECK_PLAN="$d/check_plan.py" bash scripts/pre_push_check_ci.sh --ledger-only --promote staging 2>&1 )"; rc=$?
assert_eq "$rc" "2" "--ledger-only and --promote together are refused rather than silently ordered"

echo "== the wrapper is executable (pre-commit language: script needs it) =="
# This repo has already shipped a non-executable hook script once; the mode bit
# reported success while every clone's hook failed to exec. The fixture copies
# with `cp` and invokes via `bash`, so no other assertion here can see it.
assert_ok "[ -x '$WRAPPER' ]" "scripts/pre_push_check_ci.sh has the executable bit"
assert_ok "[ \"\$(cd '$ROOT' && git ls-files -s scripts/pre_push_check_ci.sh | cut -d' ' -f1)\" = '100755' ]" \
  "the executable bit is recorded in the index, not just on disk"

echo "== a skip must respect the mode it is skipping =="
# These exits used to be unconditional, so LEDGER_GATE_BLOCKING=1 did not
# block: CHECK_PLAN=/nonexistent disabled the gate and exited 0. That is an
# env-var escape hatch of exactly the kind OPS-0069 removed from canon.
d="$(_mk blockskip 0 0)"
_plan "$d" "PLAN-950_live.md" "In Progress"
out="$( cd "$d/repo" && env CHECK_PLAN="$d/nope.py" LEDGER_GATE_BLOCKING=1 bash scripts/pre_push_check_ci.sh --ledger-only 2>&1 )"; rc=$?
assert_eq "$rc" "1" "blocking mode FAILS when check_plan.py is missing"
assert_contains "$out" "::error::" "blocking mode annotates the unavailable gate"
out="$( cd "$d/repo" && env CHECK_PLAN="$d/nope.py" bash scripts/pre_push_check_ci.sh --ledger-only 2>&1 )"; rc=$?
assert_eq "$rc" "0" "advisory mode still skips quietly when it is missing"

echo "== LEDGER_GATE_BLOCKING accepts spellings, and rejects nonsense =="
# An enforcement switch that silently no-ops on `true` is the
# check-standards-drift `--tier` shape: a gate reporting success having
# checked nothing.
for v in true yes on TRUE; do
  out="$( cd "$d/repo" && env CHECK_PLAN="$d/nope.py" LEDGER_GATE_BLOCKING="$v" bash scripts/pre_push_check_ci.sh --ledger-only 2>&1 )"; rc=$?
  assert_eq "$rc" "1" "LEDGER_GATE_BLOCKING=$v enforces"
done
for v in false no off 0; do
  out="$( cd "$d/repo" && env CHECK_PLAN="$d/nope.py" LEDGER_GATE_BLOCKING="$v" bash scripts/pre_push_check_ci.sh --ledger-only 2>&1 )"; rc=$?
  assert_eq "$rc" "0" "LEDGER_GATE_BLOCKING=$v stays advisory"
done
out="$( cd "$d/repo" && env CHECK_PLAN="$d/check_plan.py" LEDGER_GATE_BLOCKING=maybe bash scripts/pre_push_check_ci.sh --ledger-only 2>&1 )"; rc=$?
assert_eq "$rc" "2" "an unrecognised LEDGER_GATE_BLOCKING value is rejected, not ignored"
assert_contains "$out" "not understood" "and says so"

echo "== rc=0 meaning 'declined to look' is NOT reported as verified =="
# check_plan.py returns 0 both for "this plan passes" and for "(not a gated
# plan; skipped)". Reading the second as the first is how a one-character
# heading edit escaped the gate under a green tick.
d="$(_mk skipped 0 0 skipped)"
_plan "$d" "PLAN-951_live.md" "In Progress"
out="$(_run "$d")"; rc=$?
assert_absent  "$out" "✅ Claim ledgers verified" "a skipped plan is not reported as verified"
assert_contains "$out" "SKIPPED by check_plan.py" "the selector disagreement is named"
assert_eq "$rc" "1" "a selector disagreement is a malfunction, not advisory"

echo "== a crashing checker is a MALFUNCTION, never a stale ledger =="
# Advisory covers "your ledger is stale". It must not cover "the gate broke",
# or the count is printed with nothing to act on.
d="$(_mk crash 0 1 crash)"
_plan "$d" "PLAN-952_live.md" "In Progress"
out="$(_run "$d")"; rc=$?
assert_contains "$out" "MALFUNCTIONED" "a crash is reported as a malfunction"
assert_contains "$out" "RuntimeError: boom" "the raw output is shown, not swallowed"
assert_absent  "$out" "hard-failing ledger rows" "a crash is not miscounted as failing rows"
assert_eq "$rc" "1" "a malfunction is non-zero even in advisory mode"

d="$(_mk usageerr 0 2 unparseable)"
_plan "$d" "PLAN-953_live.md" "In Progress"
out="$(_run "$d")"; rc=$?
assert_contains "$out" "unrecognized arguments" "a usage error surfaces its own message"
assert_eq "$rc" "1" "a usage error is non-zero even in advisory mode"

echo "== the green line names the checker that produced it =="
# Any executable satisfies this gate; an empty file yields a clean pass. The
# assertion must therefore carry its own provenance.
d="$(_mk provenance 0 0)"
_plan "$d" "PLAN-954_live.md" "In Progress"
out="$(_run "$d")"
assert_contains "$out" "$d/check_plan.py" "the green names the check_plan.py it used"

echo "== both rosters are printed, not just the exempt one =="
d="$(_mk rosters 0 0)"
_plan "$d" "PLAN-955_live.md"    "In Progress"
_plan "$d" "PLAN-956_shipped.md" "SHIPPED — 2026-01-01"
out="$(_run "$d")"
assert_contains "$out" "PLAN-955_live.md"    "the GATED roster is printed by name"
assert_contains "$out" "PLAN-956_shipped.md" "the exempt roster is printed by name"

echo "== a plan carrying neither heading is counted, not silently dropped =="
d="$(_mk unselected 0 0)"
_plan "$d" "PLAN-957_live.md" "In Progress"
printf '**Status:** In Progress\n\n## Claims ledger\n' > "$d/repo/plans/PLAN-958_typo.md"
out="$(_run "$d")"
assert_contains "$out" "carry NEITHER heading" "the unselected plan is reported"
assert_absent  "$out" "PLAN-958_typo.md" "and it is genuinely not in either roster"

echo "== a suffixed heading drops out of selection rather than faking a pass =="
d="$(_mk suffix 0 0)"
_plan "$d" "PLAN-959_live.md" "In Progress"
printf '**Status:** In Progress\n\n## Claim ledger (cited)\n' > "$d/repo/plans/PLAN-960_suffix.md"
out="$(_run "$d")"
assert_fail "grep -q '<$d/repo/plans/PLAN-960_suffix.md>' '$d/argv.log'" \
  "the suffixed-heading plan is not passed to check_plan.py"
assert_contains "$out" "carry NEITHER heading" "and its absence is reported, not silent"

echo "== a '## Review log' plan is selected, mirroring check_plan.py's gating =="
# check_plan.py gates on EITHER section. Selecting on the ledger alone let a
# plan that lost its ledger heading vanish from this gate while remaining
# gated there — the same silent drop, on the section axis.
d="$(_mk reviewlog 0 0)"
printf '**Status:** In Progress\n\n## Review log\n' > "$d/repo/plans/PLAN-961_reviewonly.md"
out="$(_run "$d")"
assert_contains "$out" "gated:  1 plan(s)" "a Review-log-only plan is gated"
assert_ok "grep -q '<$d/repo/plans/PLAN-961_reviewonly.md>' '$d/argv.log'" \
  "and is actually passed to check_plan.py"

echo "== zero selected out of N plans is a FLOOR, not 'nothing to verify' =="
# The gate collapsing 23 → 0 and calling it success is the failure mode this
# whole change exists to prevent.
d="$(_mk floor 0 0)"
printf 'no headings here\n' > "$d/repo/plans/PLAN-962_none.md"
printf 'nor here\n'         > "$d/repo/plans/PLAN-963_none.md"
out="$(_run "$d")"; rc=$?
assert_eq "$rc" "1" "plans present but none selected is an error"
assert_contains "$out" "selector or the convention has moved" "and it names the likely cause"

echo "== an unrecognised SECOND argument fails too =="
d="$(_mk badarg2 0 0)"
_plan "$d" "PLAN-964_live.md" "In Progress"
out="$( cd "$d/repo" && env CHECK_PLAN="$d/check_plan.py" bash scripts/pre_push_check_ci.sh --ledger-only --typo 2>&1 )"; rc=$?
assert_eq "$rc" "2" "arguments past \$1 are rejected, not ignored"
assert_absent "$out" "CANON-STUB-RAN" "and nothing runs"

echo "== a status that merely BEGINS with a finished word stays gated =="
d="$(_mk prefix 0 0)"
_plan "$d" "PLAN-965_a.md" "COMPLETEness of the ledger is unknown"
_plan "$d" "PLAN-966_b.md" "SUPERSEDED-BY-NOTHING"
_plan "$d" "PLAN-967_c.md" "COMPLETE — 2026-01-01"
out="$(_run "$d")"
assert_contains "$out" "gated:  2 plan(s)" "prefix-only matches (COMPLETEness, SUPERSEDED-BY-NOTHING) stay gated"
assert_contains "$out" "exempt: 1 plan(s)" "a real finished marker is still exempt"

suite_summary "ledger-gate"
