#!/usr/bin/env bash
# aidoc-flow-ci sync/check-drift.sh — compare a consumer's
# .github/workflows/*.yml against the canonical templates at the
# pinned ci/vX.Y.Z tag. WARNING-ONLY, NEVER BLOCKS (mirrors
# aidoc-flow-operations check-docs-updated.sh pattern; per
# IPLAN-0017 §3.1b).
#
# Usage:
#   bash check-drift.sh  # in the consumer repo root
#
# No --strict mode: the locked rule (operations CLAUDE.md "Unified
# CI — drift detection") says drift is warning-only and never blocks.
# Drift is reported as ::warning::; contributor decides whether to
# bring back to canonical, intentionally keep, or upstream.

set -uo pipefail

# Any aidoc-flow-ci pin present at all? (cheap guard before per-file work.)
if ! grep -hoE '@ci/v[0-9]+\.[0-9]+\.[0-9]+' .github/workflows/*.yml >/dev/null 2>&1; then
  echo "drift-check: no aidoc-flow-ci uses: pin found in .github/workflows/; nothing to check"
  exit 0
fi

# Detect visibility from the consumer's GH metadata.
PRIVATE=$(gh repo view --json isPrivate --jq '.isPrivate' 2>/dev/null) || { echo "drift-check: gh repo view failed; skipping (warning-only contract preserved)"; exit 0; }
VISIBILITY="public"
[ "$PRIVATE" = "true" ] && VISIBILITY="private"

DRIFT=0
for wf in ai-review composition; do
  local_file=".github/workflows/${wf}.yml"
  [ -f "$local_file" ] || continue
  # PLAN-004 PR-A2 fix: compare each caller against the tag IT is pinned to,
  # NOT the highest tag across all files. A consumer mid-bump — e.g.
  # ai-review@ci/v1.6.0 alongside composition@ci/v1.7.0 — must not have the
  # not-yet-bumped caller false-flagged against the newer caller's canon.
  # (Whole-repo settings drift, where a single canon tag IS the right frame,
  # is check-standards-drift.sh's job; this script is per-caller.)
  pin=$(grep -oE 'vladm3105/aidoc-flow-ci/[^@[:space:]]*@ci/v[0-9]+\.[0-9]+\.[0-9]+' "$local_file" \
        | grep -oE 'ci/v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  if [ -z "$pin" ]; then
    echo "drift-check: $local_file has no aidoc-flow-ci pin — skipping"
    continue
  fi
  echo "drift-check: $local_file pinned to $pin"
  template_url="https://raw.githubusercontent.com/vladm3105/aidoc-flow-ci/${pin}/install/templates/workflows/${wf}-${VISIBILITY}.yml"
  canonical=$(mktemp)
  if ! curl -fsSL -o "$canonical" "$template_url"; then
    echo "::warning::drift-check: failed to fetch canonical $template_url — skipping"
    rm -f "$canonical"
    continue
  fi
  if ! diff -q "$local_file" "$canonical" >/dev/null 2>&1; then
    DRIFT=$((DRIFT + 1))
    echo "::warning::drift-check: $local_file diverges from canonical $template_url"
    diff -u "$canonical" "$local_file" | head -20 || true
  fi
  rm -f "$canonical"
done

if [ "$DRIFT" -eq 0 ]; then
  echo "drift-check: no drift"
else
  echo ""
  echo "drift-check: $DRIFT file(s) drifted. Resolution options:"
  echo "  - bring back to canonical: remove the local file + re-run install/install.sh (or await install.sh --update, PLAN-004 PR-E)"
  echo "  - intentional divergence: add a comment in the file explaining why"
  echo "  - upstream the change: open PR on vladm3105/aidoc-flow-ci with the diff"
fi

# Always exit 0 — warning-only per the locked rule (IPLAN-0017 §3.1b).
exit 0
