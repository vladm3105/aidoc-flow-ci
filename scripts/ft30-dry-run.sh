#!/usr/bin/env bash
# scripts/ft30-dry-run.sh — run (or preflight) the 🔴 FT-30 cold-start dry-run
# that gates `release.sh tag`.
#
# WHY THIS EXISTS: the gate is founder-executed because it WRITES to another repo
# (clones it and creates ~21 labels), and its pass criteria lived only as prose in
# docs/RELEASE_CHECKLIST.md — so "did it pass?" was a judgement call made by eye
# over ~60 lines of installer output. This script asserts each criterion against
# the markers install.sh actually prints, and fails loudly naming which one.
#
# It does NOT create or delete the throwaway repo. Creating it is a deliberate
# human act; deleting it is destructive and irreversible. Teardown is printed as
# a command for you to run, never executed.
#
# USAGE
#   scripts/ft30-dry-run.sh --check
#       Preflight only. No writes anywhere. Answers: is the gate even owed for
#       the next tag, is CI_TAG resolvable and PUSHED, is gh authenticated, does
#       the target exist. Run this first — it catches the mistakes that waste the
#       real run.
#
#   scripts/ft30-dry-run.sh --target owner/throwaway-repo
#       The real thing. Runs install.sh against the target and asserts the FT-30
#       criteria.
#
# THE ONE THING THAT MATTERS MOST: CI_TAG must name the commit that is ABOUT to
# be tagged (main HEAD), not the previous release. Resolved automatically here,
# because getting it wrong validates the PREVIOUS release's installer and the run
# looks green while proving nothing. That is the single most common way this gate
# is wasted.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
cd "$ROOT" || exit 1

RED=$'\033[31m'; GRN=$'\033[32m'; YEL=$'\033[33m'; BLD=$'\033[1m'; RST=$'\033[0m'
ok()   { printf '  %sok%s   %s\n'   "$GRN" "$RST" "$*"; }
bad()  { printf '  %sFAIL%s %s\n'   "$RED" "$RST" "$*"; FAILED=$((FAILED+1)); }
warn() { printf '  %swarn%s %s\n'   "$YEL" "$RST" "$*"; }
note() { printf '%s%s%s\n' "$BLD" "$*" "$RST"; }
FAILED=0

MODE=run; TARGET=""
while [ $# -gt 0 ]; do
  case "$1" in
    --check)  MODE=check; shift ;;
    --target) TARGET="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,32p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# ---------------------------------------------------------------- preflight ---
note "==> preflight"

command -v gh >/dev/null || { bad "gh not on PATH"; exit 1; }
gh auth status >/dev/null 2>&1 && ok "gh authenticated" || bad "gh not authenticated — run 'gh auth login'"

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
[ "$BRANCH" = "main" ] && ok "on main" \
  || warn "on '$BRANCH', not main — CI_TAG resolves from HEAD, so this may not be the tree you intend to tag"

CI_TAG_RESOLVED="$(git rev-parse HEAD)"
ok "CI_TAG resolves to $CI_TAG_RESOLVED"

# raw.githubusercontent can only serve a commit that exists on the remote. A
# local-only HEAD produces 404s on every template fetch — a failure that looks
# like a broken installer rather than an unpushed commit.
if git branch -r --contains "$CI_TAG_RESOLVED" 2>/dev/null | grep -q .; then
  ok "HEAD is pushed (reachable from a remote branch)"
else
  bad "HEAD is NOT pushed — raw.githubusercontent cannot serve it; every template fetch would 404"
fi

# Is the gate even owed? Reuse release.sh's own definition rather than a copy of
# it, so this cannot drift from the thing that actually refuses.
PREV_TAG="$(git tag -l 'ci/v*' | grep -E '^ci/v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1)"
if [ -n "$PREV_TAG" ]; then
  CHANGED="$(git diff --name-only "$PREV_TAG..HEAD" -- install/ 2>/dev/null | grep -E '^install/(install\.sh|check-precommit-hooks\.sh|templates/)' || true)"
  if [ -n "$CHANGED" ]; then
    ok "FT-30 gate is OWED (bootstrap path changed since $PREV_TAG):"
    printf '%s\n' "$CHANGED" | sed 's/^/         /'
  else
    warn "no bootstrap-path change since $PREV_TAG — 'release.sh tag' should AUTO-WAIVE."
    warn "Running this anyway is harmless but proves nothing; a dry-run of unchanged code is noise."
  fi
else
  warn "no previous ci/vX.Y.Z tag — the gate fails CLOSED and the flag is required"
fi

if [ -n "$TARGET" ]; then
  if gh repo view "$TARGET" --json name >/dev/null 2>&1; then
    ok "target $TARGET exists"
    # install.sh CLONES the target; it will not create it.
    case "$TARGET" in
      */aidoc-flow-*|*/iplan*|*/engramory|*/interlog|*/llm-router|*/web-site)
        bad "$TARGET looks like a REAL workspace repo. This creates ~21 labels on it. Use a throwaway." ;;
      *) ok "target does not look like a workspace repo" ;;
    esac
  else
    bad "target $TARGET not found — create it first; install.sh clones, it does not create"
  fi
elif [ "$MODE" = run ]; then
  bad "--target owner/repo is required for a real run"
fi

if [ "$MODE" = check ]; then
  echo
  if [ "$FAILED" -eq 0 ]; then
    note "preflight clean. Real run:"
    echo "  bash scripts/ft30-dry-run.sh --target <owner>/<throwaway-repo>"
    exit 0
  fi
  note "preflight found $FAILED problem(s) — fix before the real run."
  exit 1
fi

[ "$FAILED" -eq 0 ] || { echo; note "preflight failed — refusing to write to $TARGET."; exit 1; }

# ------------------------------------------------------------------ the run ---
echo
note "==> FT-30 cold-start dry-run against $TARGET"
echo "    CI_TAG=$CI_TAG_RESOLVED"
echo "    This CREATES ~21 labels on $TARGET. Ctrl-C within 5s to abort."
sleep 5

LOG="$(mktemp -t ft30-XXXXXX.log)"
export CI_TAG="$CI_TAG_RESOLVED"
URL="https://raw.githubusercontent.com/vladm3105/aidoc-flow-ci/${CI_TAG}/install/install.sh"

echo "    fetching installer from the tree under test: $URL"
if ! curl -fsSL "$URL" -o "$LOG.installer"; then
  bad "could not fetch install.sh at $CI_TAG — is HEAD pushed?"
  exit 1
fi
ok "installer fetched from $CI_TAG (not from your working tree)"

set +e
bash "$LOG.installer" "$TARGET" 2>&1 | tee "$LOG"
RC=${PIPESTATUS[0]}
# deliberately NOT re-enabling `set -e`: failures below are counted in $FAILED so
# every criterion is reported, not just the first one that trips.

# --------------------------------------------------------------- assertions ---
echo
note "==> FT-30 criteria"
has() { grep -qF -- "$1" "$LOG"; }

[ "$RC" -eq 0 ] && ok "installer exited 0" || bad "installer exited $RC"

has "==> creating canonical labels on" \
  && ok "reached label creation" || bad "never reached 'creating canonical labels' — bootstrap aborted earlier"

has "==> done. Next steps (founder)" \
  && ok "final next-steps block printed" || bad "no final next-steps block — the run did not complete"

# FT-57 is the newest bootstrap-path change; if NEITHER backup line appears the
# mandatory-backup hook did not run at all, and this gate has failed even if
# everything else looks green.
if has "==> backed up" || has "==> backup: no pre-existing CI/governance surfaces"; then
  ok "FT-57 pre-write backup ran"
else
  bad "NEITHER backup line printed — the mandatory backup hook did not run (FT-57)"
fi

has "Pre-write backup of everything that already existed (FT-57):" \
  && ok "next-steps names the backup directory" || bad "next-steps does not name the backup directory"
has "Restore one file:" \
  && ok "next-steps gives the restore command" || bad "next-steps has no restore command"

has "review job pins the self-hosted pool even on public repos" \
  && ok "runner-pool probe printed" || bad "runner-pool probe missing (PLAN-018 F4)"
has "LITELLM_BASE_URL + LITELLM_REVIEW_API_KEY" \
  && ok "LiteLLM secrets note printed" || bad "LiteLLM note missing"

grep -qE '^\s+FAIL ' "$LOG" && { bad "installer emitted FAIL line(s):"; grep -E '^\s+FAIL ' "$LOG" | sed 's/^/         /'; } \
  || ok "no FAIL lines"
grep -q '==> ABORT:' "$LOG" && { bad "installer ABORTed:"; grep '==> ABORT:' "$LOG" | sed 's/^/         /'; } \
  || ok "no ABORT"
grep -q '404' "$LOG" && { bad "404(s) in output — a template is missing at this ref:"; grep -n '404' "$LOG" | head -5 | sed 's/^/         /'; } \
  || ok "no 404s"

# ------------------------------------------------------------------ verdict ---
echo
if [ "$FAILED" -eq 0 ]; then
  note "${GRN}FT-30 DRY-RUN PASSED${RST}${BLD} — log: $LOG"
  echo
  echo "  Tear down the throwaway (NOT done automatically):"
  echo "    gh repo delete $TARGET --yes"
  echo
  echo "  Then cut the tag:"
  echo "    bash scripts/release.sh tag <ci/vX.Y.Z> --dry-run-verified"
  exit 0
fi
note "${RED}FT-30 DRY-RUN FAILED${RST}${BLD} — $FAILED criterion/criteria. Log: $LOG"
echo "  Do NOT pass --dry-run-verified. Fix the cause and re-run."
exit 1
