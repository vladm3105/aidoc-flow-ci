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
# founder-executed (it writes to a throwaway repo). `tag` gates on it
# CONDITIONALLY: it demands --dry-run-verified only when the release actually
# changes the installer BOOTSTRAP WRITE PATH — install.sh, check-precommit-hooks.sh,
# the manifest, labels.json, the pre-commit fragment, and every template the
# manifest ships INCLUDING its visibility_variants (see `coldstart_surface` for the
# exact scope and what is deliberately excluded). When that path is byte-identical
# to the last released one the gate auto-waives with an audit line, because a
# dry-run of unchanged code proves nothing. It fails CLOSED: no previous tag, an
# unreadable manifest, or a manifest whose shape yields no templates, and the flag
# is required exactly as before.
#
# SUBCOMMANDS
#   release.sh prep <ci/vX.Y.Z>
#       On a clean main: create the prep branch, write VERSION (with a trailing
#       newline — a newline-less VERSION fails self-pre-commit's end-of-file-fixer,
#       FT-36), run sync-version-refs.sh, promote the CHANGELOG. You review, open
#       the PR, and merge it (expected-red per (2)).
#
#   release.sh tag <ci/vX.Y.Z> [--dry-run-verified]
#       After the prep is MERGED to main: verify VERSION==version on main, cut the
#       annotated tag on HEAD, push it, and `gh release create --latest` from the
#       CHANGELOG section. --dry-run-verified is REQUIRED when the cold-start path
#       changed (the script says so and lists the files), and always accepted.
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

# Only exact ci/vX.Y.Z releases. `sort -V` ranks `ci/v2.13.0-rc.1` ABOVE
# `ci/v2.13.0`, so an unfiltered glob would let a pre-release (or a stray tag like
# ci/v0.0.1-ruletest) become `prev` and mis-scope the diff.
# `grep` exits 1 when nothing matches; under `set -e` that would abort the caller's
# `prev="$(previous_tag)"` assignment instead of yielding the empty string the
# no-previous-tag branch is written to handle. Hence the `|| true`.
previous_tag() { git tag --list 'ci/v[0-9]*' | { grep -E "$VER_RE" || true; } | sort -V | tail -1; }

# --- FT-30 cold-start surface ----------------------------------------------
# The dry-run gate exists to catch a broken INSTALLER cold start (a bootstrap
# template deleted at ci/v2.2.0 shipped broken for nine releases). It is only
# meaningful when the release actually changes that path, so the gate is
# CONDITIONAL rather than ceremonial — see `coldstart_gate` below.
#
# SCOPE: the installer's BOOTSTRAP WRITE PATH — install.sh plus every template it
# fetches and writes into the consumer. That is the path whose breakage ABORTS a
# cold start (`fetch_template ... || exit 1`) and the failure F1 actually was.
# The surface is DERIVED from the manifest (both `template` and every
# `visibility_variants` value), so a newly-shipped template is covered with no edit
# here.
#
# Deliberately OUT of scope, and why:
#   - install/README.md — docs.
#   - deploy-ci-wizard.sh, apply-standards.sh — separate entry points a cold start
#     never executes.
#   - the standards-VERIFY assets reached transitively via `verify_standards`
#     (sync/check-standards-drift.sh and what it fetches: branch-protection-*.json,
#     repo-settings.json, actions-permissions.json, check-pin-currency.sh).
#     install.sh captures that step's rc instead of exiting, so it is ADVISORY —
#     a fault there degrades the report, it does not abort the install. If a
#     release changes those, pass --dry-run-verified deliberately; the gate will
#     not force you.
coldstart_surface() {
  # The manifest half must FAIL LOUD, not degrade. Swallowing a manifest read
  # error — or accepting a manifest whose shape changed so it yields nothing —
  # would silently shrink the surface to the explicit list, so a release that
  # changed a shipped template would auto-waive the gate: the exact class of miss
  # FT-30 exists to prevent. An EMPTY result is therefore an error, not a waive.
  #
  # NB `local mf rc=0` is declared on its own line and the assignment made on the
  # NEXT line deliberately. `local mf="$(...)" || rc=$?` would mask the command
  # substitution's exit status behind `local`'s own (always 0) and silently
  # fail OPEN. Do not collapse these two lines.
  local mf rc=0
  mf="$(python3 - <<'PY' 2>/dev/null
import json, re, sys
m = json.load(open("install/templates/manifest.json"))      # raises -> rc!=0
files = m.get("files")
if not isinstance(files, list) or not files:
    sys.exit(1)                                             # schema drift -> fail closed
out = set()
for f in files:
    t = f.get("template")
    if t:
        out.add(t)
    # install.sh cold-start fetches the -private/-public variants directly
    # (e.g. workflows/composition-private.yml); they live ONLY here, so a
    # template-only walk is blind to them — and private repos are most of the fleet.
    for v in (f.get("visibility_variants") or {}).values():
        if v:
            out.add(v)
if not out:
    sys.exit(1)
for t in sorted(out):
    # pathspecs are word-split by the caller, so whitespace/glob would silently
    # drop a path from the diff. Refuse rather than under-report.
    if re.search(r"[\s*?\[\]]", t):
        sys.exit(1)
    print("install/templates/" + t)
PY
)" || rc=$?
  [ "$rc" -eq 0 ] && [ -n "$mf" ] || return 1
  # Explicit half: what install.sh fetches/executes that the manifest does not
  # name. NB `install/templates/pre_push_check.sh` is manifest-covered; canon's
  # own `scripts/pre_push_check.sh` is a separate local copy the installer never
  # fetches, so it is deliberately NOT here.
  printf '%s\n' \
    install/install.sh \
    install/check-precommit-hooks.sh \
    install/templates/manifest.json \
    install/templates/labels.json \
    install/templates/pre-commit-hook-block.yaml
  printf '%s\n' "$mf"
}

# --- prep ------------------------------------------------------------------
prep() {
  local version="${1:-}"
  require_version_arg "$version" prep
  git rev-parse --verify -q "refs/tags/$version" >/dev/null && die "tag $version already exists — nothing to prep"
  [ "$version" = "$(current_version)" ] && die "VERSION already reads $version — prep already done?"
  [ -z "$(git status --porcelain)" ] || die "working tree not clean — commit or stash first"
  local branch="release/${version//\//-}-prep"
  git rev-parse --verify -q "$branch" >/dev/null && die "branch $branch already exists"
  # FT-48: prep must start from an up-to-date main — the SAME guard `tag` carries.
  # A prep from a stale or off-main tree promotes an INCOMPLETE `## Unreleased`
  # CHANGELOG into the release, and `tag`'s VERSION-match guard cannot catch that
  # (VERSION would still match). Placed AFTER the tag/VERSION checks so a prep of
  # the current version is still rejected with its specific reason.
  local cur_branch; cur_branch="$(git rev-parse --abbrev-ref HEAD)"
  [ "$cur_branch" = "main" ] || die "must be on main to prep (on '$cur_branch') — prep starts from an up-to-date main"
  git fetch -q origin main
  [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || die "local main is not up to date with origin/main — pull first"

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
  local version="${1:-}"; shift || true
  require_version_arg "$version" tag "[--dry-run-verified]"
  local verified=0
  for a in "$@"; do [ "$a" = "--dry-run-verified" ] && verified=1; done

  # --- FT-30 gate, CONDITIONAL (see coldstart_surface) ---------------------
  # Required only when this release changes the installer cold-start path.
  # Fails CLOSED: if the previous tag or the surface cannot be determined, the
  # flag is required exactly as before.
  local prev; prev="$(previous_tag)"
  if [ "$verified" -eq 1 ]; then
    echo "  FT-30 cold-start gate: --dry-run-verified supplied — accepted."
  elif [ -z "$prev" ]; then
    die "refusing to tag without --dry-run-verified: no previous ci/v* tag found, so the cold-start surface cannot be diffed (first release, or unfetched tags — run 'git fetch --tags'). See docs/RELEASE_CHECKLIST.md"
  else
    local surface changed
    if ! surface="$(coldstart_surface)"; then
      die "refusing to tag without --dry-run-verified: could not compute the cold-start surface — install/templates/manifest.json is unreadable, or its shape yields no templates. See docs/RELEASE_CHECKLIST.md"
    fi
    # shellcheck disable=SC2086  # deliberate word-split: many pathspecs
    changed="$(git diff --name-only "$prev..HEAD" -- $surface 2>/dev/null)"
    if [ -n "$changed" ]; then
      echo "release: this release CHANGES the installer cold-start path since $prev:" >&2
      printf '%s\n' "$changed" | sed 's/^/    /' >&2
      die "refusing to tag without --dry-run-verified — run the 🔴 FT-30 cold-start dry-run (docs/RELEASE_CHECKLIST.md), then re-run with --dry-run-verified"
    fi
    note "==> FT-30 cold-start gate AUTO-WAIVED"
    echo "  No file on the installer bootstrap write path changed in $prev..HEAD,"
    echo "  so the cold start is byte-identical to the one verified for $prev."
    echo "  Scope: install.sh, check-precommit-hooks.sh, the manifest, labels.json,"
    echo "  the pre-commit fragment, and every template the manifest ships"
    echo "  (including visibility_variants) — $(printf '%s\n' "$surface" | wc -l) paths."
    echo "  The advisory standards-verify assets are OUT of scope by design."
    echo "  Pass --dry-run-verified to run the dry-run anyway."
  fi

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
  *) die "usage: release.sh {prep <ci/vX.Y.Z> | tag <ci/vX.Y.Z> [--dry-run-verified]}" ;;
esac
