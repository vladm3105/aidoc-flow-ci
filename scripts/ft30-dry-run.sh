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
# CI-0033 §27: capture, then test the capture. `git branch` is a multi-write
# writer, the class where `| grep -q` inverts far below the pipe buffer.
_branches="$(git branch -r --contains "$CI_TAG_RESOLVED" 2>/dev/null || true)"
if [ -n "$_branches" ]; then   # exactly `grep -q .`: any character at all
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
# PIN THE WORKING COPY so the FILE SET can be inspected after the run. install.sh
# defaults WORK_DIR to `$PWD/aidoc-flow-ci-bootstrap-$$`, whose pid we cannot
# predict from here — and without the tree, every criterion below has to be a
# grep over the installer's own log (see #358).
WORK_DIR="$(mktemp -d -t ft30-work-XXXXXX)"
export WORK_DIR
CONSUMER="$WORK_DIR/consumer"
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
has "LLM_URL + LLM_API_KEY" \
  && ok "LiteLLM secrets note printed" || bad "LiteLLM note missing"

grep -qE '^\s+FAIL ' "$LOG" && { bad "installer emitted FAIL line(s):"; grep -E '^\s+FAIL ' "$LOG" | sed 's/^/         /'; } \
  || ok "no FAIL lines"
grep -q '==> ABORT:' "$LOG" && { bad "installer ABORTed:"; grep '==> ABORT:' "$LOG" | sed 's/^/         /'; } \
  || ok "no ABORT"
grep -q '404' "$LOG" && { bad "404(s) in output — a template is missing at this ref:"; grep -n '404' "$LOG" | head -5 | sed 's/^/         /'; } \
  || ok "no 404s"

# ---------------------------------------------- what actually landed (#358) ---
#
# EVERY CRITERION ABOVE IS A GREP OVER THE INSTALLER'S OWN LOG. That asserts the
# bootstrap COMPLETED; it says nothing about WHAT IT INSTALLED. A stanza that
# silently never runs — a deleted `if` block, an `auto_install` flag flipped, a
# guard that fires when it should not — prints every marker string these look
# for, exits 0, and passes the whole gate having installed the wrong file set.
# That is #358, and it is the exact class FT-30 exists to catch: the F1 defect
# was a cold start that shipped without `ai-review.yml` for nine releases.
#
# So: compare the tree on disk against the manifest AT THE REF UNDER TEST — not
# against the working tree, for the same reason the installer is fetched from
# the ref rather than sourced locally.
note "==> installed file set (the part a log grep cannot see)"

if [ ! -d "$CONSUMER/.github/workflows" ]; then
  bad "no .github/workflows/ in the working copy ($CONSUMER) — nothing to verify"
else
  _mf="$(mktemp)"
  if ! curl -fsSL "https://raw.githubusercontent.com/vladm3105/aidoc-flow-ci/${CI_TAG}/install/templates/manifest.json" -o "$_mf"; then
    bad "could not fetch manifest.json at $CI_TAG — cannot verify the file set"
  else
    # Visibility decides which variant SHOULD have landed. Resolve it the way
    # install.sh does — from the live repo — and refuse to guess.
    _vis=""
    case "$(gh repo view "$TARGET" --json isPrivate --jq '.isPrivate' 2>/dev/null)" in
      true)  _vis=private ;;
      false) _vis=public ;;
    esac
    if [ -z "$_vis" ]; then
      bad "could not resolve $TARGET visibility — cannot verify which variant should have installed"
    else
      ok "target visibility: $_vis"
      # Expected = every auto_install:true workflow entry. This is the SAME
      # invariant tests/test_install.sh asserts offline against the bootstrap
      # block; here it is asserted against a real cold start.
      _expected="$(python3 - "$_mf" <<'PYEXP'
import sys, json
m = json.load(open(sys.argv[1], encoding="utf-8"))
for f in m.get("files") or []:
    p = f.get("path") or ""
    if p.startswith(".github/workflows/") and f.get("auto_install"):
        print(p)
PYEXP
)"
      if [ -z "$_expected" ]; then
        bad "manifest at $CI_TAG declares NO auto_install workflow callers — a cold start would arm contexts with no producer"
      else
        _missing=""
        while IFS= read -r _w; do
          [ -n "$_w" ] || continue
          if [ -s "$CONSUMER/$_w" ]; then
            ok "installed: $_w"
          else
            _missing="$_missing $_w"
          fi
        done <<< "$_expected"
        if [ -n "$_missing" ]; then
          bad "manifest declares auto_install but these did NOT land:$_missing"
        fi

        # THE VARIANT, not just the presence. A private consumer handed the
        # public caller pins ubuntu-latest and every job QUEUES FOREVER
        # (OPS-0049/D1) — a file that exists and is wrong, which a presence
        # check cannot see. Only meaningful for callers carrying a literal
        # `runs-on:`; the v2 reusable callers express the pool as an input.
        while IFS= read -r _w; do
          [ -s "$CONSUMER/$_w" ] || continue
          _rl="$(grep -E '^[[:space:]]*runs-on:' "$CONSUMER/$_w" || true)"
          [ -n "$_rl" ] || continue
          # ALL FOUR QUADRANTS. The first draft had three and fell through
          # silently on public+self-hosted — which is the one that was actually
          # live: bootstrap defaulted VISIBILITY to `private` and never
          # auto-detected, so a public cold start installed the self-hosted
          # variant. A check missing the case that is happening is the failure
          # mode this whole block was added to fix, one level up.
          case "$_vis:$_rl" in
            private:*ubuntu-latest*)
              bad "$_w is on ubuntu-latest but $TARGET is PRIVATE — jobs will queue forever (OPS-0049/D1)" ;;
            public:*self-hosted*)
              bad "$_w is SELF-HOSTED but $TARGET is PUBLIC — a fork-code-executing job on the shared pool (D7). NEVER ship this." ;;
            private:*self-hosted*) ok "$_w: self-hosted, correct for a private target" ;;
            public:*ubuntu-latest*) ok "$_w: ubuntu-latest, correct for a public target" ;;
            *) bad "$_w: could not classify runner line against visibility=$_vis — $_rl" ;;
          esac
        done <<< "$_expected"
      fi
    fi
  fi
  rm -f "$_mf"

  # A caller that landed EMPTY passes `-f` and every log grep. FT-39 exists
  # because a 200-with-HTML-body was written over a gate.
  while IFS= read -r -d '' _f; do
    [ -s "$_f" ] || bad "installed but EMPTY: ${_f#"$CONSUMER"/}"
  done < <(find "$CONSUMER/.github/workflows" -type f -print0 2>/dev/null)
fi

echo "    working copy kept for inspection: $CONSUMER"

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
