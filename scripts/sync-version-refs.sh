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
#   scripts/sync-version-refs.sh          # rewrite in place
#   scripts/sync-version-refs.sh --check  # dry-run; exit 1 if any file is stale
#
# Wired as a pre-commit hook in this repo's .pre-commit-config.yaml (--check),
# so docs cannot drift from VERSION without failing local + CI pre-commit.

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
)
# Every shipped caller template pins aidoc-flow-ci reusables — keep them all at
# the current release tag so a fresh consumer install gets a coherent pin set.
for _t in "$REPO_ROOT"/install/templates/workflows/*.yml; do
  [ -e "$_t" ] && TARGETS+=("${_t#"$REPO_ROOT"/}")
done

CHECK_ONLY=0
[ "${1:-}" = "--check" ] && CHECK_ONLY=1

if [ ! -f "$VERSION_FILE" ]; then
  echo "sync-version-refs: VERSION file not found at $VERSION_FILE" >&2
  exit 2
fi
TAG="$(tr -d '[:space:]' < "$VERSION_FILE")"
if ! printf '%s' "$TAG" | grep -qE '^ci/v[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "sync-version-refs: VERSION content '$TAG' is not a valid ci/vX.Y.Z tag" >&2
  exit 2
fi

# The three install-reference contexts, each anchored so only install pins are
# touched (never bare historical mentions of a tag). NOTE (code-review LOW):
# these patterns distinguish install-reference SHAPE (raw-URL / uses:@tag /
# CI_TAG=), not current-vs-historical. That is safe only because the target
# docs contain no ILLUSTRATIVE old-tag install commands — bare prose like
# "supersedes docs-sync.yml at ci/v2.0.0" has none of these shapes and is left
# untouched. If a historical `uses:…@ci/vX.Y.Z` EXAMPLE is ever added to a
# target, mark that line to exclude it (or narrow the pattern) rather than let
# it be silently rewritten.
sed_program() {
  cat <<SED
s#(raw\.githubusercontent\.com/vladm3105/aidoc-flow-ci/)ci/v[0-9]+\.[0-9]+\.[0-9]+#\1${TAG}#g
s#(vladm3105/aidoc-flow-ci/[^@[:space:]]*@)ci/v[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.]+)?#\1${TAG}#g
s#(^|[^A-Za-z0-9_])(CI_TAG=)ci/v[0-9]+\.[0-9]+\.[0-9]+#\1\2${TAG}#g
SED
}

stale=0
for f in "${TARGETS[@]}"; do
  path="$REPO_ROOT/$f"
  [ -f "$path" ] || { echo "sync-version-refs: target missing: $f" >&2; exit 2; }
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
  echo "sync-version-refs: run 'scripts/sync-version-refs.sh' to fix." >&2
  exit 1
fi
echo "sync-version-refs: all install references match VERSION=$TAG"
