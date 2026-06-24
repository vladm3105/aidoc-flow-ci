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

# The pinned tag the consumer is using — read from the first workflow
# file's `uses:` line.
PIN=$(grep -hoE '@ci/v[0-9]+\.[0-9]+\.[0-9]+' .github/workflows/*.yml 2>/dev/null | sort -u | head -1)
if [ -z "$PIN" ]; then
  echo "drift-check: no aidoc-flow-ci uses: pin found in .github/workflows/; nothing to check"
  exit 0
fi
TAG="${PIN#@}"
echo "drift-check: consumer pinned to $TAG"

# Detect visibility from the consumer's GH metadata.
PRIVATE=$(gh repo view --json isPrivate --jq '.isPrivate' 2>/dev/null) || { echo "drift-check: gh repo view failed; skipping (warning-only contract preserved)"; exit 0; }
VISIBILITY="public"
[ "$PRIVATE" = "true" ] && VISIBILITY="private"

DRIFT=0
for wf in ai-review composition; do
  local_file=".github/workflows/${wf}.yml"
  [ -f "$local_file" ] || continue
  template_url="https://raw.githubusercontent.com/vladm3105/aidoc-flow-ci/${TAG}/install/templates/workflows/${wf}-${VISIBILITY}.yml"
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
  echo "drift-check: no drift vs $TAG"
else
  echo ""
  echo "drift-check: $DRIFT file(s) drifted from $TAG. Resolution options:"
  echo "  - bring back to canonical: re-run install/install.sh (TODO ci/v1.0.1: add --force)"
  echo "  - intentional divergence: add a comment in the file explaining why"
  echo "  - upstream the change: open PR on vladm3105/aidoc-flow-ci with the diff"
fi

# Always exit 0 — warning-only per the locked rule (IPLAN-0017 §3.1b).
exit 0
