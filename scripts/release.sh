#!/usr/bin/env bash
# scripts/release.sh — cut a ci/vX.Y.Z release, enforcing the
# prep → merge → dry-run → tag ordering that was tribal knowledge (PLAN-018
# FT-21). The ci/v2.9.0 cut hit three failure modes this guards against:
#
#   (1) the tag was cut BEFORE the prep PR merged, so it pointed at a tree whose
#       VERSION + consumer pins were still the OLD version. `tag` refuses unless
#       VERSION on main already equals the version being cut.
#   (2) the prep PR's own checks go red because its bumped self-pins reference a
#       tag that cannot exist yet (chicken-and-egg, inherent to self-pinning
#       canon). This is EXPECTED — the known one-red-run path (FT-21 option a).
#       `prep` says so and distinguishes the expected red from a real one.
#   (3) those startup_failure runs are NOT retryable (`gh run rerun` refuses
#       them); the next push after the tag exists re-triggers them green.
#
# The 🔴 FT-30 cold-start dry-run sits BETWEEN prep-merge and tag and is
# founder-executed (it writes to a throwaway repo). `tag` therefore requires an
# explicit --dry-run-verified flag so the tag cannot be cut without that gate.
#
# SUBCOMMANDS
#   release.sh prep <ci/vX.Y.Z>
#       On a clean main: create the prep branch, write VERSION (with a trailing
#       newline — a newline-less VERSION fails self-pre-commit's end-of-file-fixer,
#       FT-36), run sync-version-refs.sh, promote the CHANGELOG. You review, open
#       the PR, and merge it (expected-red per (2)).
#
#   release.sh tag <ci/vX.Y.Z> --dry-run-verified
#       After the prep is MERGED to main AND the founder ran the FT-30 cold-start
#       dry-run: verify VERSION==version on main, cut the annotated tag on HEAD,
#       push it, and `gh release create --latest` from the CHANGELOG section.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
cd "$ROOT"

die() { echo "release: $*" >&2; exit 1; }
note() { printf '\033[1m%s\033[0m\n' "$*"; }

VER_RE='^ci/v[0-9]+\.[0-9]+\.[0-9]+$'

require_version_arg() {
  [ -n "${1:-}" ] || die "usage: release.sh $2 <ci/vX.Y.Z> ${3:-}"
  printf '%s' "$1" | grep -qE "$VER_RE" || die "version must match ci/vX.Y.Z (got '$1')"
}

current_version() { tr -d '[:space:]' < VERSION; }

# --- prep ------------------------------------------------------------------
prep() {
  local version="$1"
  require_version_arg "$version" prep
  git rev-parse --verify -q "refs/tags/$version" >/dev/null && die "tag $version already exists — nothing to prep"
  [ "$version" = "$(current_version)" ] && die "VERSION already reads $version — prep already done?"
  [ -z "$(git status --porcelain)" ] || die "working tree not clean — commit or stash first"
  local branch="release/${version//\//-}-prep"
  git rev-parse --verify -q "$branch" >/dev/null && die "branch $branch already exists"

  note "==> prep $version"
  git checkout -q -b "$branch"

  # VERSION — trailing newline is load-bearing (FT-36: self-pre-commit's
  # end-of-file-fixer fails a newline-less VERSION).
  printf '%s\n' "$version" > VERSION
  echo "  VERSION -> $version"

  # propagate the tag into CI_TAG_FALLBACK + every install/self-caller pin
  bash "$HERE/sync-version-refs.sh" >/dev/null
  echo "  sync-version-refs: pins + CI_TAG_FALLBACK -> $version"

  # promote CHANGELOG: the current ## Unreleased block becomes this release;
  # a fresh empty ## Unreleased is left on top.
  local date; date="$(TZ=America/New_York date +%Y-%m-%d)"
  python3 - "$version" "$date" <<'PY'
import sys
version, date = sys.argv[1], sys.argv[2]
p = "CHANGELOG.md"
s = open(p, encoding="utf-8").read()
anchor = "## Unreleased\n"
if anchor not in s:
    sys.exit("CHANGELOG.md has no '## Unreleased' section to promote")
if ("## %s " % version) in s:
    sys.exit("CHANGELOG.md already has a '## %s' section" % version)
s = s.replace(anchor, "## Unreleased\n\n## %s — %s\n" % (version, date), 1)
open(p, "w", encoding="utf-8").write(s)
PY
  echo "  CHANGELOG: ## Unreleased -> ## $version — $date (fresh Unreleased left)"

  note "==> suite (the ONLY expected failure is version-sync's latest-tag assertion — FT-21)"
  local out rc=0
  out="$(bash tests/run.sh 2>&1)" || rc=$?
  local clean; clean="$(printf '%s\n' "$out" | sed 's/\x1b\[[0-9;]*m//g')"
  if [ "$rc" -eq 0 ]; then
    echo "  suite: fully green (unusual mid-prep, but fine)"
  else
    # EXPECTED red = the suite failed for EXACTLY the version-sync latest-tag
    # assertion and nothing else. Confirm this POSITIVELY, and rule out a
    # crash-style failure that prints no `_r FAIL` line — a `set -e` abort, a
    # missing binary, an early `exit 1` — which an "any-other-FAIL-line" subtraction
    # would silently pass as the benign chicken-and-egg (the misclassification
    # that would prime the operator to merge past a real breakage). Crashes are
    # caught by counting started test groups (`━━ header`) vs finished ones
    # (each prints a `<name>: N passed, M failed` summary): a group that dies
    # mid-file never prints its summary.
    local has_expected other_fails headers summaries
    has_expected="$(printf '%s\n' "$clean" | grep -c 'FAIL .*latest published tag' || true)"
    other_fails="$(printf '%s\n' "$clean" | grep -E '^[[:space:]]+FAIL ' | grep -vc 'latest published tag' || true)"
    headers="$(printf '%s\n' "$clean" | grep -c '^━━ ' || true)"
    summaries="$(printf '%s\n' "$clean" | grep -cE ': [0-9]+ passed, [0-9]+ failed' || true)"
    if [ "$has_expected" -ge 1 ] && [ "$other_fails" -eq 0 ] && [ "$headers" -eq "$summaries" ]; then
      echo "  suite: RED as EXPECTED — only version-sync's 'latest published tag' assertion"
      echo "         fails (the tag does not exist yet). It goes green when you cut the tag."
    else
      echo "  suite: UNEXPECTED red — this is NOT the FT-21 chicken-and-egg:" >&2
      [ "$has_expected" -ge 1 ] || echo "    · the version-sync latest-tag assertion did NOT fire — something else broke the suite" >&2
      if [ "$other_fails" -gt 0 ]; then
        printf '%s\n' "$clean" | grep -E '^[[:space:]]+FAIL ' | grep -v 'latest published tag' | sed 's/^/    /' >&2
      fi
      [ "$headers" -eq "$summaries" ] || echo "    · a test group crashed without a summary ($headers started, $summaries finished — a set-e abort or missing tool)" >&2
      echo "  Recover: git checkout main && git branch -D $branch && git checkout -- ." >&2
      die "suite has UNEXPECTED failures — fix before opening the prep PR"
    fi
  fi

  cat <<EOF

$(note "Next (yours):")
  1. Review the diff:            git -C $ROOT diff main
  2. Commit (OPS-0069 phrase), push, open the prep PR. Its \`suite\` +
     self-caller checks will be RED — that is the FT-21 chicken-and-egg (self-pins
     reference $version, which does not exist yet). Merge anyway (main is
     unprotected; use --admin).
  3. 🔴 Founder runs the FT-30 cold-start dry-run (docs/RELEASE_CHECKLIST.md),
     exporting CI_TAG=<the prep-merge SHA>.
  4. After it passes and the prep is on main:
       bash scripts/release.sh tag $version --dry-run-verified
EOF
}

# --- tag -------------------------------------------------------------------
tag() {
  local version="$1"; shift || true
  require_version_arg "$version" tag "--dry-run-verified"
  local verified=0
  for a in "$@"; do [ "$a" = "--dry-run-verified" ] && verified=1; done
  [ "$verified" -eq 1 ] || die "refusing to tag without --dry-run-verified (the 🔴 FT-30 cold-start dry-run gates the cut — see docs/RELEASE_CHECKLIST.md)"

  local branch; branch="$(git rev-parse --abbrev-ref HEAD)"
  [ "$branch" = "main" ] || die "must be on main to tag (on '$branch') — the prep PR must be MERGED first"
  git fetch -q origin main
  [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || die "local main is not up to date with origin/main — pull first"
  git rev-parse --verify -q "refs/tags/$version" >/dev/null && die "tag $version already exists"

  # The core FT-21 guard: the tree being tagged must ALREADY carry this version.
  [ "$(current_version)" = "$version" ] || die "VERSION on main reads '$(current_version)', not '$version' — the prep PR is not merged yet (cutting now = the v2.9.0 mistake: a tag pointing at the OLD version)"
  local fb; fb="$(grep -oE 'CI_TAG_FALLBACK="ci/v[0-9]+\.[0-9]+\.[0-9]+"' install/install.sh | head -1 | sed -E 's/.*"(ci\/v[^"]+)"/\1/')"
  [ "$fb" = "$version" ] || die "CI_TAG_FALLBACK is '$fb', not '$version' — sync-version-refs did not run in prep"

  # release notes = the CHANGELOG section for this version.
  local notes; notes="$(awk -v v="$version" '
    $0 ~ "^## " v " " {p=1; print; next}
    p && /^## ci\/v/ {exit}
    p {print}
  ' CHANGELOG.md)"
  [ -n "$notes" ] || die "no '## $version' section found in CHANGELOG.md"

  note "==> tagging $version on $(git rev-parse --short HEAD)"
  git tag -a "$version" -m "$version" HEAD
  git push origin "$version"
  echo "  pushed tag $version"

  printf '%s\n' "$notes" | gh release create "$version" --title "$version" --notes-file - --latest
  echo "  gh release created (marked Latest)"

  cat <<EOF

$(note "Done. Post-release (yours):")
  - The prep PR's self-caller checks that were startup_failure are NOT retryable;
    the next push to main (e.g. a HANDOFF update) re-triggers them green.
  - Smoke: CI_TAG=$version bash install/install.sh <owner/repo> --repin on a
    consumer, and check-pin-currency.sh --fleet (docs/RELEASE_CHECKLIST.md).
EOF
}

case "${1:-}" in
  prep) shift; prep "${1:-}" ;;
  tag)  shift; tag "$@" ;;
  *) die "usage: release.sh {prep <ci/vX.Y.Z> | tag <ci/vX.Y.Z> --dry-run-verified}" ;;
esac
