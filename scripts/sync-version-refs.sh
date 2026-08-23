#!/usr/bin/env bash
# sync-version-refs.sh — propagate the single-source release tag (the repo-root
# VERSION file) into the INSTALL-COMMAND references in the docs of record.
#
# PLAN-004 BL-4 fix: README + install/README (and, as PLAN-004 PR-A2 extends
# this list, multi-project-guide + PLAYBOOK) carried hand-edited `ci/vX.Y.Z`
# pins that silently went stale across release cuts. This script makes VERSION
# the sole source and rewrites only the mechanical install references:
#
#   • raw.githubusercontent.com/vladm3105/aidoc-flow-ci/<TAG>/install/install.sh
#   • uses: vladm3105/aidoc-flow-ci/.github/workflows/<wf>.yml@<TAG>   (examples)
#   • CI_TAG=<TAG>
#
# It DELIBERATELY does NOT touch historical prose ("shipped in ci/v1.0.x"),
# CHANGELOG provenance, or troubleshooting war stories — those legitimately name
# old tags and must be preserved (PLAN-004 §3 history non-goal + §7 criterion 5).
#
# Usage:
#   scripts/sync-version-refs.sh                   # rewrite in place
#   scripts/sync-version-refs.sh --check           # dry-run; exit 1 if any file is stale
#   scripts/sync-version-refs.sh --check-published # exit 1 if the VERSION tag is
#                                                  # not published on origin (run AFTER
#                                                  # a release cut, NOT in pre-commit —
#                                                  # see the note below re: the bump deadlock)
#
# `--check` is wired as a pre-commit hook in this repo's .pre-commit-config.yaml,
# so docs cannot drift from VERSION without failing local + CI pre-commit.
# `--check-published` is a release-verification tool and is intentionally NOT
# wired into pre-commit/on-PR (that would deadlock the VERSION-bump commit).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="$REPO_ROOT/VERSION"

# Files whose install/pin references track VERSION.
#   • docs: raw-URL install commands + CI_TAG= examples
#   • template callers: the `uses: vladm3105/aidoc-flow-ci/…@ci/vX.Y.Z` pins
#     (PLAN-004 PR-A2 item 17 — one release tag across every caller template)
TARGETS=(
  "README.md"
  "install/README.md"
  "docs/multi-project-guide.md"
  "docs/PLAYBOOK_governance-canon-rollout.md"
  "docs/REVIEWER_APP_ONBOARDING.md"
  "docs/BRANCH_PROTECTION.md"
  # install.sh carries BOTH a `CI_TAG=ci/vX.Y.Z bash install.sh` usage EXAMPLE in
  # its header AND the authoritative `CI_TAG_FALLBACK=` line. Both shapes are
  # rewritten below. The fallback was previously hand-bumped per release and the
  # ci/v2.0.1 cut forgot it — so a CI_TAG-less `--repin` wrote ci/v2.0.0 onto
  # consumers already on v2.0.1, pinning the fleet BACKWARDS. A release step that
  # can be forgotten will be; it is mechanical now.
  "install/install.sh"
  # These carry the raw-URL / uses:@tag / CI_TAG= shapes the sed program rewrites
  # but were outside TARGETS — they matched VERSION only by coincidence and would
  # drift silently at the next bump (the exact class PLAN-004 BL-4 built this for).
  "docs/overrides.md"
  "docs/architecture.md"
  "docs/security.md"
  "docs/MIGRATION_v2.0.0.md"
  # CI-0024 applies to every version-named migration guide, so this one joins
  # TARGETS the moment it exists rather than "matching VERSION by coincidence"
  # until the next bump. Its three version-bearing commands — the repin, the
  # template-fetch URL and the ROLLBACK — are all marker-guarded, because in a
  # document named for a tag that tag is the SUBJECT, not a pin to keep current.
  "docs/MIGRATION_v3.0.0.md"
  # Same rule, same reason — joins TARGETS the moment it exists. Its two
  # version-bearing commands (the v4 repin and the v3 ROLLBACK) are both
  # marker-guarded: the rollback target in particular must stay ci/v3.0.0
  # forever, and an unguarded rewrite would silently point it at the release
  # being rolled back FROM.
  "docs/MIGRATION_v4.0.0.md"
  "docs/UPDATE_GUIDE.md"
  "docs/AI_CI_DEPLOYMENT.md"
  # Pins the $schema URL at a tag; safe_to_replace:false so --update never repairs
  # a consumer's stale copy either.
  "install/templates/config.json.template"
)
# Every shipped caller template pins aidoc-flow-ci reusables — keep them all at
# the current release tag so a fresh consumer install gets a coherent pin set.
for _t in "$REPO_ROOT"/install/templates/workflows/*.yml; do
  [ -e "$_t" ] && TARGETS+=("${_t#"$REPO_ROOT"/}")
done
# This repo self-adopts its own canon (Wave 0) — its .github/workflows/*.yml
# callers pin aidoc-flow-ci reusables too, and MUST track VERSION so the
# canon-home dogfoods the current release (they previously drifted to v1.0.1–
# v1.6.0 because they were outside this list). Only the `uses:…@ci/vX.Y.Z` shape
# is rewritten (sed program below), so non-pin content is untouched.
for _t in "$REPO_ROOT"/.github/workflows/*.yml; do
  [ -e "$_t" ] && TARGETS+=("${_t#"$REPO_ROOT"/}")
done

CHECK_ONLY=0
CHECK_PUBLISHED=0
case "${1:-}" in
  '') : ;;   # no arg → rewrite in place (default)
  --check) CHECK_ONLY=1 ;;
  --check-published) CHECK_PUBLISHED=1 ;;
  *) echo "sync-version-refs: unknown option '$1' (use --check | --check-published)" >&2; exit 2 ;;
esac

if [ ! -f "$VERSION_FILE" ]; then
  echo "sync-version-refs: VERSION file not found at $VERSION_FILE" >&2
  exit 2
fi
TAG="$(tr -d '[:space:]' < "$VERSION_FILE")"
# CI-0033 §27: bash regex test, no pipeline status to invert.
if [[ ! "$TAG" =~ ^ci/v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "sync-version-refs: VERSION content '$TAG' is not a valid ci/vX.Y.Z tag" >&2
  exit 2
fi

# --check-published (PLAN-005 PR-C / D4, preventive): assert the VERSION tag
# exists ON THE REMOTE. Consumers resolve `@ci/vX.Y.Z` from GitHub, so a
# local-only (unpushed) tag still breaks a fresh install — hence `git ls-remote`,
# NOT `git rev-parse` (which would pass on a local tag). This is a SEPARATE mode,
# deliberately NOT wired into pre-commit or on-PR CI: the release flow bumps
# VERSION to a tag that is cut FROM the bump commit, so a hard on-PR check would
# deadlock every release. Run it AFTER cutting+pushing the tag (release
# verification), or on a schedule to catch a forgotten tag-cut. Uses $TAG (the
# validated VERSION content) — the B3 break itself (ci/v1.7.0/v1.7.1) is already
# resolved; this guards future cuts.
if [ "$CHECK_PUBLISHED" -eq 1 ]; then
  if git ls-remote --exit-code --tags origin "$TAG" >/dev/null 2>&1; then
    echo "sync-version-refs: OK — VERSION tag $TAG is published on origin"
    exit 0
  fi
  echo "sync-version-refs: FAIL — VERSION=$TAG is NOT a published tag on origin (or origin is unreachable)." >&2
  echo "  If the tag is genuinely unpublished: a shipped template pin / install URL references an" >&2
  echo "  unresolvable ref — cut+push it (git tag -a $TAG -m … && git push origin $TAG) or revert VERSION." >&2
  echo "  If this was a transient network/origin error, re-run." >&2
  exit 1
fi

# The four install-reference shapes, each anchored so only install pins are
# touched (never bare historical mentions of a tag). These patterns distinguish
# install-reference SHAPE (raw-URL / uses:@tag / CI_TAG=), NOT
# current-vs-historical. Bare prose like "supersedes docs-sync.yml at
# ci/v2.0.0" has none of these shapes and is left untouched.
#
# CI-0024. The header above used to say this was "safe only because the target
# docs contain no ILLUSTRATIVE old-tag install commands", and told the reader to
# "mark that line to exclude it" if one were ever added. That caveat was ACCURATE
# when written (a0fc68c, 2026-07-09): TARGETS was README.md + install/README.md,
# and docs/MIGRATION_v2.0.0.md did not yet exist. It was a correct, prospective
# warning — though it anticipated the wrong direction: it expected an example to
# be added to a target, and what happened was a file ALREADY containing two being
# added to TARGETS.
#
# The trigger fired on 2026-07-17, when 1a027da (#175) added
# docs/MIGRATION_v2.0.0.md to TARGETS. That doc carries two illustrative
# `CI_TAG=` commands that must NOT track VERSION: its §5 "repin to @ci/v2.0.0"
# step and, far worse, its Rollback section, whose command exists to pin a
# consumer BACK to ci/v1.x. It read `ci/v1.9.5` through 5992b9b and became
# `ci/v2.0.1` in 1a027da, tracking the release tag at every cut since — so the
# published rollback instruction re-pinned FORWARD, the exact opposite of its
# stated intent.
#
# The lesson is NOT "the comment was wrong". It is that a prospective caveat
# naming a future trigger has no way to stop the commit that trips it months
# later, because that commit's author never reads this file. The remedy the
# caveat prescribed was never IMPLEMENTED, only described — so there was nothing
# for #175 to fail against. A named trigger condition must be enforced
# mechanically or it is decoration — so tests/test_version_sync.sh now PINS the
# EXPLICIT TARGETS array below: adding a file to it fails the suite and tells you
# to check the new target for illustrative install commands first. NB the two
# GLOB arms further down are not pinned — a new caller template joins TARGETS
# silently. That is acceptable only because a caller's pin SHOULD track VERSION;
# do not read the guard as covering them.
#
# For a file that is ALREADY a target, per REPO_STANDARDS §22.2:
#   - an illustrative command on an OLD tag IS caught by --check (it reads as a
#     stale reference); the failure message names the marker remedy alongside the
#     rewriter, because advising the rewriter alone falsifies the command.
#   - an illustrative command written at the CURRENT tag is genuinely unguarded —
#     textually identical to a live reference, so only the markers below help.
#
# The mechanism the old comment promised now exists. Wrap any span whose install
# references are ILLUSTRATIVE or HISTORICAL:
#
#   <!-- sync-version-refs:ignore-start -->
#   ```bash
#   CI_TAG=ci/v1.9.5 bash install.sh <owner/repo> --repin
#   ```
#   <!-- sync-version-refs:ignore-end -->
#
# Markers are inert in rendered Markdown and are matched literally, so the same
# pair works in shell/YAML targets behind a `#` comment. Both --check and the
# rewrite honour them, and unbalanced markers are a hard error (see below) —
# an unterminated ignore-start would otherwise silently freeze the rest of a
# file, turning this guard into the very drift it exists to prevent.
IGNORE_START='sync-version-refs:ignore-start'
IGNORE_END='sync-version-refs:ignore-end'

# Fail LOUD on malformed markers rather than degrading to a partial rewrite.
# Checks pairing AND ordering: a stray `ignore-end` before any start, a nested
# start, or a start with no end each abort. `grep -c` counts LINES, so two
# markers on one line would miscount — hence the awk state machine, which also
# gives the exact line number in the message.
validate_ignore_markers() {
  awk -v s="$IGNORE_START" -v e="$IGNORE_END" -v f="$1" '
    index($0, s) && index($0, e) { printf "%s:%d: both ignore-start and ignore-end on one line\n", f, FNR; bad=1; next }
    index($0, s) { if (open) { printf "%s:%d: nested sync-version-refs:ignore-start (previous opened at line %d)\n", f, FNR, openln; bad=1 } ; open=1; openln=FNR; next }
    index($0, e) { if (!open) { printf "%s:%d: sync-version-refs:ignore-end with no matching ignore-start\n", f, FNR; bad=1 } ; open=0; next }
    END { if (open) { printf "%s:%d: unterminated sync-version-refs:ignore-start\n", f, openln; bad=1 } ; exit (bad ? 1 : 0) }
  ' "$1"
}

# The substitutions are applied ONLY to lines outside an ignore span. Each rule
# carries its OWN negated address range (`/start/,/end/!s#…#`) rather than
# sharing one `{ … }` block: a bare `}` line — measured, not theorised —
# truncated the function-extraction awk
# in tests/test_version_sync.sh, which stops at the first line that is exactly
# `}`. Per-rule addresses keep the shipped code drivable by the tests that guard
# it. Deliberately not an awk rewrite: awk's gsub cannot express the \1
# backreferences these patterns depend on.
sed_program() {
  cat <<SED
/${IGNORE_START}/,/${IGNORE_END}/!s#(raw\.githubusercontent\.com/vladm3105/aidoc-flow-ci/)ci/v[0-9]+\.[0-9]+\.[0-9]+#\1${TAG}#g
/${IGNORE_START}/,/${IGNORE_END}/!s#(vladm3105/aidoc-flow-ci/[^@[:space:]]*@)ci/v[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.]+)?#\1${TAG}#g
/${IGNORE_START}/,/${IGNORE_END}/!s#(^|[^A-Za-z0-9_])(CI_TAG=)ci/v[0-9]+\.[0-9]+\.[0-9]+#\1\2${TAG}#g
/${IGNORE_START}/,/${IGNORE_END}/!s#(CI_TAG_FALLBACK=")ci/v[0-9]+\.[0-9]+\.[0-9]+#\1${TAG}#g
SED
}

stale=0
for f in "${TARGETS[@]}"; do
  path="$REPO_ROOT/$f"
  [ -f "$path" ] || { echo "sync-version-refs: target missing: $f" >&2; exit 2; }
  # Validate BEFORE substituting, and in --check mode too: a malformed marker
  # must never silently widen or narrow what gets rewritten.
  if ! marker_err="$(validate_ignore_markers "$path")"; then
    echo "sync-version-refs: malformed ignore markers:" >&2
    printf '  %s\n' "$marker_err" >&2
    exit 2
  fi
  updated="$(sed -E -f <(sed_program) "$path")"
  if [ "$updated" != "$(cat "$path")" ]; then
    if [ "$CHECK_ONLY" -eq 1 ]; then
      echo "sync-version-refs: STALE install reference in $f (VERSION=$TAG)" >&2
      stale=1
    else
      printf '%s\n' "$updated" > "$path"
      echo "sync-version-refs: updated $f -> $TAG"
    fi
  fi
done

if [ "$CHECK_ONLY" -eq 1 ] && [ "$stale" -eq 1 ]; then
  # Two different faults reach this message and they have OPPOSITE remedies.
  # Offering only the rewriter is how CI-0024 stayed invisible: an illustrative
  # or historical command pinned to an old tag DOES trip this check, and the
  # operator was then told to run the very rewriter that falsifies it. Naming
  # both remedies is what turns this from a misdirecting guard into a real one.
  echo "sync-version-refs: two possible causes — pick the right remedy:" >&2
  echo "  1. A genuinely stale CURRENT install reference:" >&2
  echo "       run 'scripts/sync-version-refs.sh'" >&2
  echo "  2. An ILLUSTRATIVE or HISTORICAL command that must NOT track VERSION" >&2
  echo "     (a rollback to an old tag, a past migration's repin step):" >&2
  echo "       do NOT run the rewriter — it will falsify the command. Wrap it in" >&2
  echo "       <!-- ${IGNORE_START} --> / <!-- ${IGNORE_END} -->" >&2
  exit 1
fi
echo "sync-version-refs: all install references match VERSION=$TAG"
