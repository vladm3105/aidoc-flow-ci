#!/usr/bin/env bash
# tests/test_version_sync.sh — release-pointer drift guard.
#
# WHY THIS EXISTS: `install.sh` resolves the tag it installs/re-pins as
#   CI_TAG env > VERSION file > CI_TAG_FALLBACK
# so if VERSION or the fallback names anything other than the latest PUBLISHED
# tag, a `--repin` without an explicit CI_TAG silently writes the WRONG tag onto
# a consumer. Measured 2026-07-17: VERSION and CI_TAG_FALLBACK both said
# ci/v2.0.0 while ci/v2.0.1 was the live fleet target — so every documented
# `--repin` invocation would have pinned consumers BACKWARDS onto the three
# ai-review blockers v2.0.1 exists to fix, on the one armed live consumer.
# Nothing caught it: sync-version-refs.sh --check only proves the refs agree
# with VERSION, not that VERSION is right. It reported green.
#
# The fallback was documented as "hand-bumped per release". A release step that
# can be forgotten will be. This test is the guard; sync-version-refs.sh now
# rewrites the fallback mechanically.
#
# CONTRACT: VERSION == CI_TAG_FALLBACK == the latest published ci/v* tag.
#
# RELEASE ORDER (this test encodes it): bump VERSION -> run sync-version-refs.sh
# -> commit -> THEN `git tag`. Between the bump and the tag this test fails,
# which is correct and intentional: during that window VERSION names a tag that
# does not exist yet, and an install/repin in that window would 404. Cut the tag
# to make it pass. Do NOT "fix" a red here by reverting the bump.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
cd "$ROOT" || exit 1

echo "== version pointers (VERSION / CI_TAG_FALLBACK / latest tag) =="

VERSION_VAL="$(tr -d '[:space:]' < VERSION 2>/dev/null || echo '')"
FALLBACK_VAL="$(grep -oE 'CI_TAG_FALLBACK="ci/v[0-9]+\.[0-9]+\.[0-9]+"' install/install.sh \
  | head -1 | sed -E 's/.*"(ci\/v[0-9]+\.[0-9]+\.[0-9]+)"/\1/')"

if [ -z "$VERSION_VAL" ]; then
  _r "VERSION file is empty or unreadable"
elif [ -z "$FALLBACK_VAL" ]; then
  _r "could not parse CI_TAG_FALLBACK from install/install.sh"
else
  if [ "$VERSION_VAL" = "$FALLBACK_VAL" ]; then
    _g "VERSION ($VERSION_VAL) == CI_TAG_FALLBACK"
  else
    _r "VERSION ($VERSION_VAL) != CI_TAG_FALLBACK ($FALLBACK_VAL) — a CI_TAG-less install/repin would use the fallback and write the wrong tag. Run: bash scripts/sync-version-refs.sh"
  fi

  # Latest published tag. Sort with -V so ci/v2.0.10 > ci/v2.0.9. Skip the
  # comparison (do not fail) when tags are unavailable — a shallow CI clone or a
  # fresh fork has none, and a guard that fails on "cannot check" would be noise
  # rather than signal. The pointers-agree assertion above still runs.
  LATEST_TAG="$(git tag --list 'ci/v[0-9]*' 2>/dev/null | sort -V | tail -1)"
  if [ -z "$LATEST_TAG" ]; then
    echo "  ---  no ci/v* tags reachable (shallow clone?) — skipping latest-tag comparison"
  elif [ "$VERSION_VAL" = "$LATEST_TAG" ]; then
    _g "VERSION ($VERSION_VAL) == latest published tag"
  else
    _r "VERSION ($VERSION_VAL) != latest published tag ($LATEST_TAG) — install/repin would target a tag that is not the current release. If you are mid-release-cut, cut the tag; otherwise bump VERSION + run scripts/sync-version-refs.sh"
  fi
fi

echo ""
echo "== deploy-ci-wizard.sh resolves VERSION with NO literal fallback (PLAN-018 F7) =="

# The wizard once ended its CI_TAG resolution with `|| echo 'ci/v1.9.5'`. Under
# `set -euo pipefail` a missing/unreadable VERSION makes that fallback FIRE, so
# the wizard scaffolded callers pinned 14 releases back — green and silent.
# test above guards install.sh's fallback; NOTHING guarded the wizard's. These
# assertions do, by EXECUTING the shipped script against a VERSION that is
# missing/empty/good — never by re-reading its source.
WIZ="$ROOT/install/deploy-ci-wizard.sh"

# 1. No stale literal tag survives in the resolution line. A bare `grep` for any
#    ci/v* in the whole file would false-match doc examples, so scope to the
#    CI_TAG assignment region: the wizard must not carry a hardcoded pin there.
if grep -nE "CI_TAG=.*ci/v[0-9]+\.[0-9]+" "$WIZ" >/dev/null 2>&1; then
  _r "deploy-ci-wizard.sh carries a literal ci/v* tag in its CI_TAG resolution — a stale fallback can reappear"
else
  _g "deploy-ci-wizard.sh CI_TAG resolution carries no literal tag"
fi

# 2. Execute the resolution in isolation, exactly as shipped, against three
#    VERSION states. Extract the CI_TAG line + its guard block so the test runs
#    the REAL code, not a paraphrase.
wiz_probe() { # $1 = what to put at <sandbox>/VERSION ('' => remove the file)
  local sandbox; sandbox="$(mktemp -d)"
  mkdir -p "$sandbox/install"
  # the shipped resolution block: the CI_TAG= line through the closing `}`
  awk '/^CI_TAG="\$\(tr -d/{p=1} p{print} /^}$/{if(p)exit}' "$WIZ" > "$sandbox/install/probe_body.sh"
  {
    echo 'set -euo pipefail'
    echo 'HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"'
    cat "$sandbox/install/probe_body.sh"
    echo 'printf "OK:%s\n" "$CI_TAG"'
  } > "$sandbox/install/probe.sh"
  if [ -n "$1" ]; then printf '%s' "$1" > "$sandbox/VERSION"; else rm -f "$sandbox/VERSION"; fi
  local out rc
  out="$(bash "$sandbox/install/probe.sh" 2>/dev/null)"; rc=$?
  rm -rf "$sandbox"
  printf '%s\n' "rc=$rc out=$out"
}

# Guard extraction didn't silently produce an empty body (which would make every
# case "pass" for the wrong reason).
_probe_body_lines="$(awk '/^CI_TAG="\$\(tr -d/{p=1} p{print} /^}$/{if(p)exit}' "$WIZ" | wc -l | tr -d ' ')"
assert_ok "[ '${_probe_body_lines:-0}' -ge 3 ]" "wizard CI_TAG resolution block extracted ($_probe_body_lines lines)"

good_res="$(wiz_probe 'ci/v9.9.9')"
assert_contains "$good_res" "rc=0" "good VERSION resolves (rc=0)"
assert_contains "$good_res" "OK:ci/v9.9.9" "good VERSION yields its exact tag"

miss_res="$(wiz_probe '')"
assert_contains "$miss_res" "rc=2" "missing VERSION exits 2 (fails loud, no literal fallback)"
assert_absent "$miss_res" "OK:" "missing VERSION scaffolds NO tag"

empty_res="$(wiz_probe '   ')"
assert_contains "$empty_res" "rc=2" "whitespace-only VERSION exits 2 (no unresolvable @ pin)"

suite_summary "version-sync"
