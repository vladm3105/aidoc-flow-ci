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

suite_summary "version-sync"
