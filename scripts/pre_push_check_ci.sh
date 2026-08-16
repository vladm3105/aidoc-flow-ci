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
#   Measured at the time of writing: of 15 gated plans, 14 fail — 79 hard
#   FAILING ledger rows across 11 of them, plus 6 review-log defects in the
#   other 3. (The unit is failing rows, not ledger size; the ledgers
#   themselves are far larger.) Wiring that blocking on day one reds every
#   plan-touching push, which is how a gate gets bypassed and then ignored.
#   It reports; it does not block. Flip it with LEDGER_GATE_BLOCKING=1 once
#   the gated set is repaired — every skip path honours the flag, so the flip
#   really is one variable. It did not used to be: the skips exited 0
#   unconditionally, leaving an env-var escape hatch.
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
# `$#` as well as `$1`: checking only `$1` accepted `--ledger-only --typo`,
# silently ignoring the tail. The suite asserted "an unrecognised argument
# fails loudly", so the test's claim was broader than the code's guarantee.
if [ "$#" -gt 1 ]; then
  echo "usage: $(basename "$0") [--ledger-only]" >&2; exit 2
fi
case "${1:-}" in
  --ledger-only) LEDGER_ONLY=1 ;;
  "")            ;;
  *) echo "usage: $(basename "$0") [--ledger-only]" >&2; exit 2 ;;
esac

# An enforcement switch that silently no-ops on a plausible spelling is the
# `check-standards-drift.sh --tier` shape: a gate that checked nothing and
# reported success. `LEDGER_GATE_BLOCKING=true` used to leave the gate
# advisory with no warning, so accept the usual spellings and REJECT anything
# else rather than defaulting it to off.
case "${LEDGER_GATE_BLOCKING:-0}" in
  1|true|yes|on|TRUE|YES|ON)    BLOCKING=1 ;;
  0|""|false|no|off|FALSE|NO|OFF) BLOCKING=0 ;;
  *) echo "::error::LEDGER_GATE_BLOCKING='${LEDGER_GATE_BLOCKING}' not understood (use 1/0, true/false, yes/no, on/off)." >&2
     exit 2 ;;
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

# `${HOME:-}`, not `$HOME` — under `set -u` an unset HOME (env -i, some cron
# contexts) would abort the wrapper here with `HOME: unbound variable`, AFTER
# canon had already printed its success banner. The `-f` test below then
# produces the intended skip instead.
CHECK_PLAN="${CHECK_PLAN:-${HOME:-}/.claude/skills/verified-planning/check_plan.py}"

# A skip must respect the mode it is skipping. Every one of these paths used
# to `exit "$rc"` UNCONDITIONALLY, so `LEDGER_GATE_BLOCKING=1` did not block:
# `CHECK_PLAN=/nonexistent git push` disabled the gate and exited 0. That is
# an env-var escape hatch — the exact property canon's header says OPS-0069
# deliberately removed — and it made this script's own claim that enforcing is
# "a one-variable change" false. Verified before and after.
ledger_skip() { # $1 = reason
  if [ "$BLOCKING" -eq 1 ]; then
    echo "::error::Claim-ledger gate is BLOCKING but cannot run — $1"
    exit 1
  fi
  echo "ℹ️  Claim-ledger gate skipped — $1"
  exit "$rc"
}

if [ ! -f "$CHECK_PLAN" ]; then
  # Canon's skipped-with-notice pattern in advisory mode. Deliberately NOT an
  # error there: the script belongs to a Claude skill that is not guaranteed
  # present on any given machine, and failing would block pushes from
  # environments that never had the gate to begin with. In BLOCKING mode the
  # same absence is a hard failure — you asked for enforcement.
  ledger_skip "check_plan.py not found at: $CHECK_PLAN
    Set CHECK_PLAN=/path/to/check_plan.py to point it elsewhere."
fi

if ! command -v python3 >/dev/null 2>&1; then
  ledger_skip "python3 not resolvable."
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
FINISHED_RE='^\**(SHIPPED|COMPLETE|COMPLETED|IMPLEMENTED|DEFERRED|SUPERSEDED|ABANDONED)([[:space:]]|$)'

# Bash's own `=~`, NOT `printf … | grep -qiE`. The piped form is the CI-0033
# construct §27 bans repo-wide: a pipeline whose exit status is a DECISION can
# be inverted by SIGPIPE when `grep -q` exits early, and the classification
# would flip a gated plan to exempt with no symptom. `=~` decides on the value,
# so there is no pipeline and no status to invert. `nocasematch` is scoped to
# the loop and RESTORED to its prior value — `shopt -u` would force it off
# regardless of how the caller had it set.
_prev_nocasematch="$(shopt -p nocasematch)"
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
# The selector MIRRORS check_plan.py's own gating rather than approximating
# it: that tool gates a plan carrying either `## Claim ledger` OR
# `## Review log` (check_plan.py:224). Selecting on the ledger alone let a plan
# that lost its ledger heading vanish from this gate while check_plan.py still
# considered it gated. ANCHORED to the whole heading, too — a prefix match
# selected `## Claim ledger (cited)`, which check_plan.py then declined to
# gate, so the wrapper reported as verified a plan the checker never read.
done < <(grep -liE '^## (Claim ledger|Review log)[[:space:]]*$' "$REPO_ROOT"/plans/*.md 2>/dev/null | sort)
eval "$_prev_nocasematch"

# A plan carrying NEITHER heading appears in no list, so its absence would be
# invisible — the failure mode this gate exists to catch, on the section axis
# instead of the Status axis. Count it and say so.
# Scoped to `PLAN-*.md`, not every file under plans/. The directory also holds
# rollout logs, an assessment and a TODO queue, none of which ever carries a
# ledger — counting those made the warning permanently on, and a warning that
# is always on is one nobody reads. Among PLAN files a missing ledger is a
# real gap.
total_plans=0
for _p in "$REPO_ROOT"/plans/PLAN-*.md; do [ -f "$_p" ] && total_plans=$((total_plans + 1)); done
unselected=$(( total_plans - ${#gated[@]} - ${#exempt[@]} ))
[ "$unselected" -lt 0 ] && unselected=0

if [ "${#gated[@]}" -eq 0 ] && [ "${#exempt[@]}" -eq 0 ]; then
  # A FLOOR, not a no-op. Zero selected out of zero plans is fine; zero
  # selected out of N plans means the selector broke or the heading convention
  # moved, and reporting that as "nothing to verify" would be the gate
  # collapsing 23 → 0 and calling it success.
  if [ "$total_plans" -gt 0 ]; then
    echo "::error::${total_plans} plan(s) under plans/ but NONE carries a '## Claim ledger'"
    echo "::error::or '## Review log' heading — the selector or the convention has moved."
    exit 1
  fi
  echo "ℹ️  No plans under plans/ — nothing to verify."
  exit "$rc"
fi

# BOTH rosters are printed, not just the exempt one. A count is what you read
# when a plan silently drops out of the gate; a roster is what you read when
# you want to know whether the plan you just edited was actually checked.
echo "   gated:  ${#gated[@]} plan(s)"
for p in "${gated[@]:-}"; do
  [ -n "$p" ] && echo "             $(basename "$p")"
done
echo "   exempt: ${#exempt[@]} plan(s) (finished marker):"
for p in "${exempt[@]:-}"; do
  [ -n "$p" ] && echo "             $(basename "$p")"
done
if [ "$unselected" -gt 0 ]; then
  echo "   ⚠️  ${unselected} plan(s) carry NEITHER heading and were checked by nothing."
fi
echo

# Report ROWS, never a count. A count tells you HOW MANY rows fail, never
# WHICH — and the two are not interchangeable: a plan edit that breaks one
# row while another is repaired nets zero, so an unchanged count reads as
# "nothing happened" while the ledger silently churned underneath it.
# Strip C0 control characters before printing. Every string below is drawn
# from repo content — plan filenames, and ledger cells that check_plan.py
# interpolates verbatim into its error text — so a crafted plan could emit
# ESC/CR sequences that rewrite this script's own output. That matters more
# than usual here: the exempt list printed above IS the disclosed mitigation
# for self-exemption, and forged output would defeat exactly that.
_safe() { LC_ALL=C tr -d '\000-\010\013\014\016-\037\177'; }

failing_plans=0
malfunction=0
for plan in "${gated[@]:-}"; do
  [ -n "$plan" ] || continue
  # `${a[@]+"${a[@]}"}`, NOT `"${a[@]:-}"` — the latter expands an EMPTY array
  # to one empty-string argument under `set -u`, which check_plan.py then
  # receives as a plan path. The gate would report a bogus failure for "".
  out="$(python3 "$CHECK_PLAN" ${ROOT_ARGS[@]+"${ROOT_ARGS[@]}"} "$plan" 2>&1)"
  plan_rc=$?

  # rc=0 is NOT proof of verification. check_plan.py also returns 0 for
  # `(not a gated plan; skipped)` — i.e. "I declined to look at this" — and
  # reading that as a pass is how a one-character heading edit escaped the
  # gate under a green tick. The selector is anchored above so this should now
  # be unreachable; it is checked anyway, because the two selectors living in
  # different codebases is precisely the drift that produced the defect.
  if [ "$plan_rc" -eq 0 ]; then
    case "$out" in
      *"not a gated plan; skipped"*)
        malfunction=$((malfunction + 1))
        printf '  ⚠️  %s — SELECTED by this gate but SKIPPED by check_plan.py\n' \
          "$(basename "$plan" | _safe)"
        printf '      The two selectors disagree; this plan was verified by nothing.\n'
        ;;
    esac
    continue
  fi

  # Hard failures only. `warn … line drifted; citation passes` is the gate
  # working as designed — the symbol match absorbed the drift — and `--fix`
  # re-points those. Printing them here would bury the real rows.
  # `[[:space:]]`, not `\s`: the latter is a GNU extension, undefined in POSIX
  # ERE, so it silently matches nothing on BSD/macOS grep.
  rows="$(printf '%s\n' "$out" | _safe | grep -E '^[[:space:]]+- ')"

  if [ -z "$rows" ]; then
    # Non-zero status with no parseable rows is a GATE MALFUNCTION, not a
    # stale ledger: an interpreter crash, a usage error, or an output-format
    # change in check_plan.py (a file this repo does not own). Advisory mode
    # covers "your ledger is stale"; it must never cover "the gate broke", or
    # the count is reported with nothing to act on — the exact artifact the
    # comment above forbids.
    malfunction=$((malfunction + 1))
    printf '  ⚠️  %s — check_plan.py failed with no parseable rows:\n' \
      "$(basename "$plan" | _safe)"
    printf '%s\n' "$out" | _safe | head -5 | sed 's/^/      /'
    continue
  fi

  failing_plans=$((failing_plans + 1))
  printf '  ❌ %s\n' "$(basename "$plan" | _safe)"
  printf '%s\n' "$rows" | sed 's/^ */      /'
done

if [ "$malfunction" -gt 0 ]; then
  # A gate malfunction is never advisory. Advisory covers "your ledger is
  # stale"; it must not cover "the gate could not tell you anything".
  echo
  echo "::error::Claim-ledger gate MALFUNCTIONED on ${malfunction} plan(s) — see above."
  echo "  This is not a stale ledger: check_plan.py could not be run or its"
  echo "  output could not be parsed. Advisory mode does not cover this."
  rc=1
elif [ "$failing_plans" -eq 0 ]; then
  echo "  ✅ Claim ledgers verified for all ${#gated[@]} gated plan(s), using:"
  echo "       $CHECK_PLAN"
else
  echo
  echo "  ${failing_plans} of ${#gated[@]} gated plan(s) have hard-failing ledger rows."
  echo "  Re-derive:  bash scripts/pre_push_check_ci.sh --ledger-only"
  echo "  Re-pin drifted line numbers LAST, after code freeze:"
  echo "    python3 \"\$CHECK_PLAN\" --fix plans/<plan>.md"
  if [ "$BLOCKING" -eq 1 ]; then
    echo "::error::Claim-ledger gate is BLOCKING (LEDGER_GATE_BLOCKING=1) — fix before pushing."
    rc=1
  else
    echo "  ADVISORY — not blocking this push (#469). Set LEDGER_GATE_BLOCKING=1 to enforce."
  fi
fi

echo "════════════════════════════════════════════════════════════════════"
exit "$rc"
