#!/usr/bin/env bash
# aidoc-flow-ci repo-specific pre-push wrapper (#469).
#
# This is the `scripts/pre_push_check_<repo>.sh` wrapper that canon's own
# `.pre-commit-config.yaml` comment and `scripts/pre_push_check.sh` header
# have described since PLAN-002 §4.8 but which this repo never had. Its
# absence is the defect #469 records: `check_plan.py` is a correct gate with
# no reader, so 23 Claim ledgers went unverified and PLAN-023's ledger
# contradicted the code it cited for weeks without anything noticing.
#
# SCOPE
#   1. canon `scripts/pre_push_check.sh`, verbatim, as a subprocess
#      (canon ends in `exit "$rc"`, so it cannot be sourced) — BLOCKING
#   2. Claim-ledger verification of the GATED plan set (below) — ADVISORY
#
# WHY THE LEDGER CHECK IS ADVISORY BY DEFAULT
#   Measured at the time of writing: 79 hard-failing rows across 11 gated
#   plans. Wiring that blocking on day one reds every plan-touching push,
#   which is how a gate gets bypassed and then ignored. It reports; it does
#   not block. Flip it with LEDGER_GATE_BLOCKING=1 once the gated set is
#   repaired — the reporting path and the blocking path are the same code,
#   so the flip is a one-variable change and not a rewrite.
#
# WHY THIS IS A LOCAL HOOK AND NOT A CI JOB
#   `check_plan.py` ships with the verified-planning Claude skill in
#   ~/.claude/skills/, NOT in this repo. The ephemeral single-use CI
#   runners are fresh containers with no ~/.claude, so a `plans-gate` job
#   cannot invoke it without vendoring the script first. Vendoring is a
#   separate decision with its own drift surface; until it is taken, the
#   pre-push wrapper is the only reader that can exist.
#
# `set -uo pipefail` (NOT -e) — preserves canon's rc-accumulator pattern:
# per-check failures must be non-fatal so every check runs on every push.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"

# --ledger-only skips section 1. The git hook uses it because canon's
# pre_push_check.sh is ALREADY wired as its own pre-push hook in this repo
# (the established repo-specific-extra pattern here — see `sync-version-refs`
# in .pre-commit-config.yaml — rather than repointing the canon fragment,
# which would drift canon's own config from the template it ships).
# Run the script with no arguments to get canon + ledger in one pass by hand.
LEDGER_ONLY=0
case "${1:-}" in
  --ledger-only) LEDGER_ONLY=1 ;;
  "")            ;;
  *) echo "usage: $(basename "$0") [--ledger-only]" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# 1. Canon pre-push checks (blocking)
# ---------------------------------------------------------------------------
# Subprocess, not `source`: canon terminates with `exit "$rc"`, which would
# take this wrapper's own process with it and silently skip everything below.
rc=0
if [ "$LEDGER_ONLY" -eq 0 ]; then
  bash "$HERE/pre_push_check.sh"
  rc=$?
fi

# ---------------------------------------------------------------------------
# 2. Claim-ledger gate (advisory unless LEDGER_GATE_BLOCKING=1)
# ---------------------------------------------------------------------------
echo
echo "════════════════════════════════════════════════════════════════════"
echo "── Claim-ledger gate (#469) ──"

CHECK_PLAN="${CHECK_PLAN:-$HOME/.claude/skills/verified-planning/check_plan.py}"

if [ ! -f "$CHECK_PLAN" ]; then
  # Canon's skipped-with-notice pattern. Deliberately NOT an error: the
  # script belongs to a Claude skill that is not guaranteed present on any
  # given machine, and failing here would block pushes from environments
  # that never had the gate to begin with.
  echo "ℹ️  Claim-ledger gate skipped — check_plan.py not found at:"
  echo "      $CHECK_PLAN"
  echo "    Set CHECK_PLAN=/path/to/check_plan.py to point it elsewhere."
  exit "$rc"
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "ℹ️  Claim-ledger gate skipped — python3 not resolvable."
  exit "$rc"
fi

# Cross-repo citations (`operations/CLAUDE.md`, `framework/CHANGELOG.md`, …)
# resolve against the WORKSPACE root, not this repo's. Without this, 23 rows
# fail as `path does not exist` purely because of how the gate was invoked —
# an invocation artifact, not a plan defect. Passed only when the parent
# directory actually exists and is not the repo itself (a standalone clone
# outside the umbrella simply gets no extra root).
#
# LEDGER_EXTRA_ROOT overrides the autodetection when SET, including when set
# to the empty string, which disables the extra root entirely. It exists
# because autodetection alone is untestable: the parent of any real directory
# except `/` exists, so the no-extra-root branch would never be reachable and
# its guard below would be asserted but never exercised.
ROOT_ARGS=()
if [ "${LEDGER_EXTRA_ROOT+set}" = "set" ]; then
  WORKSPACE_ROOT="$LEDGER_EXTRA_ROOT"
else
  WORKSPACE_ROOT="$(cd "$REPO_ROOT/.." 2>/dev/null && pwd)"
fi
if [ -n "${WORKSPACE_ROOT:-}" ] && [ "$WORKSPACE_ROOT" != "$REPO_ROOT" ] && [ -d "$WORKSPACE_ROOT" ]; then
  ROOT_ARGS=(--root "$WORKSPACE_ROOT")
fi

# GATED SET = every ledger-bearing plan whose Status line does NOT declare it
# finished. FAIL CLOSED: a plan with no Status line at all is GATED, not
# exempt — five plans in this repo have no Status line, and treating an
# unparseable header as "finished" would silently drop them from the gate,
# which is the exact failure #469 is about.
#
# KNOWN WEAKNESS, recorded rather than hidden: the exemption marker lives in
# the same file the gate checks, so a plan can escape by declaring itself
# SHIPPED. That is why the exempt set is PRINTED on every run — the
# exemption is visible, not silent. Tightening it needs a marker the plan
# cannot write about itself, which is a separate decision.
FINISHED_RE='^\**(SHIPPED|COMPLETE|COMPLETED|IMPLEMENTED|DEFERRED|SUPERSEDED)'

# Bash's own `=~`, NOT `printf … | grep -qiE`. The piped form is the CI-0033
# construct §27 bans repo-wide: a pipeline whose exit status is a DECISION can
# be inverted by SIGPIPE when `grep -q` exits early, and the classification
# would flip a gated plan to exempt with no symptom. `=~` decides on the value,
# so there is no pipeline and no status to invert. `nocasematch` is scoped to
# the loop and restored after it.
shopt -s nocasematch
gated=()
exempt=()
while IFS= read -r plan; do
  [ -n "$plan" ] || continue
  status="$(grep -m1 -E '^\*\*Status:\*\*|^Status:' "$plan" 2>/dev/null \
            | sed -E 's/^\*\*Status:\*\* *//; s/^Status: *//')"
  if [[ "$status" =~ $FINISHED_RE ]]; then
    exempt+=("$plan")
  else
    gated+=("$plan")
  fi
done < <(grep -li '^## Claim ledger' "$REPO_ROOT"/plans/*.md 2>/dev/null | sort)
shopt -u nocasematch

if [ "${#gated[@]}" -eq 0 ] && [ "${#exempt[@]}" -eq 0 ]; then
  echo "ℹ️  No ledger-bearing plans found under plans/ — nothing to verify."
  exit "$rc"
fi

echo "   gated:  ${#gated[@]} plan(s)"
echo "   exempt: ${#exempt[@]} plan(s) (finished marker):"
for p in "${exempt[@]:-}"; do
  [ -n "$p" ] && echo "             $(basename "$p")"
done
echo

# Report ROWS, never a count. A count tells you HOW MANY rows fail, never
# WHICH — and the two are not interchangeable: a plan edit that breaks one
# row while another is repaired nets zero, so an unchanged count reads as
# "nothing happened" while the ledger silently churned underneath it.
failing_plans=0
for plan in "${gated[@]:-}"; do
  [ -n "$plan" ] || continue
  # `${a[@]+"${a[@]}"}`, NOT `"${a[@]:-}"` — the latter expands an EMPTY array
  # to one empty-string argument under `set -u`, which check_plan.py then
  # receives as a plan path. The gate would report a bogus failure for "".
  out="$(python3 "$CHECK_PLAN" ${ROOT_ARGS[@]+"${ROOT_ARGS[@]}"} "$plan" 2>&1)"
  plan_rc=$?
  if [ "$plan_rc" -ne 0 ]; then
    failing_plans=$((failing_plans + 1))
    printf '  ❌ %s\n' "$(basename "$plan")"
    # Hard failures only. `warn … line drifted; citation passes` is the gate
    # working as designed — the symbol match absorbed the drift — and
    # `--fix` re-points those. Printing them here would bury the real rows.
    printf '%s\n' "$out" | grep -E '^\s+- ' | sed 's/^ */      /'
  fi
done

if [ "$failing_plans" -eq 0 ]; then
  echo "  ✅ Claim ledgers verified for all ${#gated[@]} gated plan(s)."
else
  echo
  echo "  ${failing_plans} of ${#gated[@]} gated plan(s) have hard-failing ledger rows."
  echo "  Re-derive:  bash scripts/pre_push_check_ci.sh"
  echo "  Re-pin drifted line numbers LAST, after code freeze:"
  echo "    python3 \"\$CHECK_PLAN\" --fix plans/<plan>.md"
  if [ "${LEDGER_GATE_BLOCKING:-0}" = "1" ]; then
    echo "::error::Claim-ledger gate is BLOCKING (LEDGER_GATE_BLOCKING=1) — fix before pushing."
    rc=1
  else
    echo "  ADVISORY — not blocking this push (#469). Set LEDGER_GATE_BLOCKING=1 to enforce."
  fi
fi

echo "════════════════════════════════════════════════════════════════════"
exit "$rc"
