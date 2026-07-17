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
#
# COVERAGE (was: a hardcoded `for wf in ai-review composition`, so drift in a
# consumer's labeler / links / pre-commit / secret-scan / codeql /
# doc-maintainer / auto-merge-ai-prs / markdown-lint / docs-sync caller was
# structurally invisible to the tool whose job is finding drift). The loop is
# now driven by the consumer's OWN pinned callers and resolved through
# install/templates/manifest.json, so a newly-manifested canon workflow is
# covered without editing this script.
#
# Coverage is exactly the manifest's workflow surface — whatever
# install/templates/manifest.json enumerates under .github/workflows/ at the
# caller's pin. It is NOT "every canon workflow": a template that exists under
# install/templates/workflows/ but has no manifest entry cannot be resolved
# here. Do not restate this as full coverage without re-measuring against
# manifest.json.
#
# SCOPE — what this script does NOT cover, and why:
#   - Non-workflow canon surfaces (.markdownlint.json, .lychee.toml,
#     CODEOWNERS, CLAUDE.md, scripts/pre_push_check.sh, …). They carry no
#     `@ci/vX.Y.Z` pin, so this script — which frames every comparison on
#     the pin the file itself declares — has no tag to resolve them at.
#     `install/apply-standards.sh --check` compares those.
#   - Manifest surfaces ABSENT locally. Most are `auto_install: false`
#     (optional adoption), so absence is a legitimate consumer choice,
#     not drift.
#   - Templates with `substitute` placeholders (per-consumer values such
#     as CODEOWNER_HANDLE). A raw template-vs-local diff would report the
#     substitution itself as drift. No workflow template declares any
#     today; the guard below keeps that true if one ever does.
#   - Callers pinned below `ci/v1.7.0`. manifest.json first shipped at
#     v1.7.0 (verified across all tags), so it cannot be fetched at an
#     older pin. Such a caller is reported as skipped, never as clean.
#
# REPORTING CONTRACT: drift is warning-only and never blocks (the locked
# IPLAN-0017 §3.1b rule). That licence covers DRIFT — it does not license this
# script's OWN failures being quiet. Every path that leaves a caller
# uncompared must emit a `::warning::` and increment SKIPPED, and the terminal
# verdict must never read "no drift" when anything went unexamined. A tool that
# reports a pass over files it never opened is the same defect class as a
# secret-scan that greens while scanning nothing.

set -uo pipefail

# bash 4+ required for `declare -A` (the per-pin manifest cache). Without this
# guard, bash 3.2 (macOS system bash) prints a non-fatal `declare: -A: invalid
# option` under `set -uo pipefail` (no -e), then arithmetic-evaluates every
# MANIFEST_CACHE[$pin] subscript to 0 — collapsing all pins into one slot, so a
# consumer mid-bump silently gets the WRONG tag's manifest. That is exactly the
# per-caller pin frame this script exists to preserve. check-standards-drift.sh
# guards the same way; this one did not.
if (( BASH_VERSINFO[0] < 4 )); then
  echo "::warning::drift-check: bash 4+ required (found ${BASH_VERSION:-unknown}) — install a newer bash (macOS: brew install bash). Skipping; drift is UNKNOWN, not absent."
  exit 0
fi

if [ ! -d .github/workflows ]; then
  echo "drift-check: no .github/workflows/ directory here — is this a consumer repo root? nothing to check"
  exit 0
fi

# Any aidoc-flow-ci REFERENCE at all? Deliberately matches `@<anything>`, not
# `@ci/vX.Y.Z`: a caller pinned to a branch or a bare SHA is still a canon
# caller, and it is one with a drifted pin — precisely what this tool should
# report. The old guard matched only semver, so a repo whose callers were ALL
# branch-pinned reported "nothing to check" and exited clean.
if ! grep -hoE 'vladm3105/aidoc-flow-ci/[^@[:space:]]+@[^[:space:]"'"'"']+' .github/workflows/*.yml >/dev/null 2>&1; then
  echo "drift-check: no aidoc-flow-ci uses: reference found in .github/workflows/; nothing to check"
  exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "::warning::drift-check: python3 not found — cannot parse manifest.json, so NO caller was compared. Drift is unknown, not absent."
  exit 0
fi

# Detect visibility from the consumer's GH metadata.
# ::warning:: not a bare echo: this failure no-ops the ENTIRE tool. The
# warning-only contract governs drift findings, not the tool silently declining
# to run behind a green check.
PRIVATE=$(gh repo view --json isPrivate --jq '.isPrivate' 2>/dev/null) || { echo "::warning::drift-check: gh repo view failed — cannot resolve visibility variants, so NO caller was compared. Drift is unknown, not absent."; exit 0; }
VISIBILITY="public"
[ "$PRIVATE" = "true" ] && VISIBILITY="private"
echo "drift-check: visibility=$VISIBILITY"

RAW_BASE="https://raw.githubusercontent.com/vladm3105/aidoc-flow-ci"

# Manifest cache, keyed by pin — a consumer mid-bump legitimately has
# callers on different tags, and each must resolve against the manifest of
# ITS OWN tag (a template may be renamed or gain a variant between tags).
declare -A MANIFEST_CACHE=()

# fetch_manifest <pin> — sets the global FETCHED_MANIFEST to the cached path.
# Returns non-zero on fetch failure. Deliberately communicates via a global
# rather than stdout: `x=$(fetch_manifest …)` would run it in a SUBSHELL, so
# the cache write would be discarded (re-fetching once per caller) and the
# temp files would leak past the cleanup loop.
FETCHED_MANIFEST=""
fetch_manifest () {
  local pin="$1"
  if [ -n "${MANIFEST_CACHE[$pin]:-}" ]; then
    FETCHED_MANIFEST="${MANIFEST_CACHE[$pin]}"
    return 0
  fi
  local f
  f=$(mktemp)
  if ! curl -fsSL -o "$f" "${RAW_BASE}/${pin}/install/templates/manifest.json"; then
    rm -f "$f"
    FETCHED_MANIFEST=""
    return 1
  fi
  MANIFEST_CACHE[$pin]="$f"
  FETCHED_MANIFEST="$f"
}

# resolve_template <manifest> <consumer_path> <visibility>
#   stdout: "<template>\t<substitute_count>" on a clean resolve.
#   exit 0 = resolved; 3 = no manifest entry for this path; 4 = entry exists but
#   no template resolves for this visibility; 2 = manifest unparseable.
# The three failure modes are given DISTINCT codes because they point at
# different repos: 3 is a canon/consumer naming mismatch, 4 is a canon manifest
# defect, 2 is a corrupt fetch. Collapsing them (as an empty-string return does)
# sends the operator to the wrong place.
resolve_template () {
  python3 - "$1" "$2" "$3" <<'PYEOF'
import sys, json
manifest, want, vis = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    m = json.load(open(manifest, encoding="utf-8"))
except Exception:
    sys.exit(2)
for f in m.get("files", []):
    if f.get("path") == want:
        tmpl = f.get("visibility_variants", {}).get(vis, f.get("template"))
        if not tmpl:
            sys.exit(4)
        print("\t".join([tmpl, str(len(f.get("substitute", []) or []))]))
        sys.exit(0)
sys.exit(3)
PYEOF
}

DRIFT=0
CHECKED=0
SKIPPED=0
CANON_CALLERS=0
shopt -s nullglob
for local_file in .github/workflows/*.yml; do
  # Is this a canon caller at all? Match the ref as `@<anything>` so a
  # branch/SHA-pinned caller is still recognised (and reported below), rather
  # than being silently classified as consumer-owned.
  ref=$(grep -oE 'vladm3105/aidoc-flow-ci/[^@[:space:]]+@[^[:space:]"'"'"']+' "$local_file" \
        | head -1 | sed 's/.*@//')
  # No aidoc-flow-ci reference => consumer-owned workflow, genuinely out of
  # frame. This is the common case for repo-local workflows, so it stays silent.
  [ -n "$ref" ] || continue
  CANON_CALLERS=$((CANON_CALLERS + 1))

  # PLAN-004 PR-A2 fix: compare each caller against the tag IT is pinned to,
  # NOT the highest tag across all files. A consumer mid-bump — e.g.
  # ai-review@ci/v1.6.0 alongside composition@ci/v1.7.0 — must not have the
  # not-yet-bumped caller false-flagged against the newer caller's canon.
  # (Whole-repo settings drift, where a single canon tag IS the right frame,
  # is check-standards-drift.sh's job; this script is per-caller.)
  pin=$(printf '%s' "$ref" | grep -oE '^ci/v[0-9]+\.[0-9]+\.[0-9]+$' || true)
  if [ -z "$pin" ]; then
    # A canon caller pinned to a branch or a bare SHA. Not comparable (there is
    # no canon TAG to diff against), and itself a finding: canon's contract is
    # `@ci/vX.Y.Z`. Reported, never silent.
    SKIPPED=$((SKIPPED + 1))
    echo "::warning::drift-check: $local_file references aidoc-flow-ci at '@${ref}', which is not a ci/vX.Y.Z tag — not compared. Canon callers must pin a release tag; a branch/SHA pin drifts silently and cannot be drift-checked."
    continue
  fi

  if ! fetch_manifest "$pin"; then
    SKIPPED=$((SKIPPED + 1))
    echo "::warning::drift-check: could not fetch manifest.json at $pin — $local_file NOT compared (drift unknown). manifest.json first shipped at ci/v1.7.0; an older pin cannot be resolved by this tool."
    continue
  fi
  manifest="$FETCHED_MANIFEST"

  entry=$(resolve_template "$manifest" "$local_file" "$VISIBILITY")
  case $? in
    0) : ;;
    3) SKIPPED=$((SKIPPED + 1))
       echo "::warning::drift-check: $local_file pins $pin but canon's manifest at that tag has no entry for this path — NOT compared. Either the caller was renamed locally (canon keys on the filename), or canon ships the template without manifesting it."
       continue ;;
    4) SKIPPED=$((SKIPPED + 1))
       echo "::warning::drift-check: $local_file is manifested at $pin but no template resolves for visibility=$VISIBILITY — NOT compared. This is a canon manifest defect, not a consumer issue."
       continue ;;
    *) SKIPPED=$((SKIPPED + 1))
       echo "::warning::drift-check: could not parse manifest.json at $pin — $local_file NOT compared (drift unknown)."
       continue ;;
  esac
  IFS=$'\t' read -r template subs <<< "$entry"
  if [ "${subs:-0}" != "0" ]; then
    SKIPPED=$((SKIPPED + 1))
    echo "::warning::drift-check: $local_file uses template $template, which declares per-consumer substitutions — NOT compared (a raw diff would false-flag the substituted values)."
    continue
  fi

  echo "drift-check: $local_file pinned to $pin (template: $template)"
  template_url="${RAW_BASE}/${pin}/install/templates/${template}"
  canonical=$(mktemp)
  if ! curl -fsSL -o "$canonical" "$template_url"; then
    SKIPPED=$((SKIPPED + 1))
    echo "::warning::drift-check: failed to fetch canonical $template_url — $local_file NOT compared (drift unknown)."
    rm -f "$canonical"
    continue
  fi
  CHECKED=$((CHECKED + 1))
  if ! diff -q "$local_file" "$canonical" >/dev/null 2>&1; then
    DRIFT=$((DRIFT + 1))
    echo "::warning::drift-check: $local_file diverges from canonical $template_url"
    diff -u "$canonical" "$local_file" | head -20 || true
  fi
  rm -f "$canonical"
done

if [ "${#MANIFEST_CACHE[@]}" -gt 0 ]; then
  for f in "${MANIFEST_CACHE[@]}"; do rm -f "$f"; done
fi

# The verdict must carry its own denominator. "no drift" over 0 compared files
# is byte-identical to "no drift" over a healthy repo, and in the Actions UI it
# is a green check with a collapsed log — the warnings scroll ABOVE the line
# that contradicts them. Report what was NOT examined as prominently as what was.
echo "drift-check: compared $CHECKED of $CANON_CALLERS canon caller(s); $SKIPPED skipped"
if [ "$SKIPPED" -gt 0 ]; then
  echo "::warning::drift-check: $SKIPPED canon caller(s) were NOT compared (see warnings above) — their drift is UNKNOWN, not absent."
fi
if [ "$DRIFT" -eq 0 ] && [ "$SKIPPED" -eq 0 ]; then
  echo "drift-check: no drift"
elif [ "$DRIFT" -eq 0 ]; then
  echo "drift-check: no drift among the $CHECKED caller(s) compared"
else
  echo ""
  echo "drift-check: $DRIFT file(s) drifted. Resolution options:"
  echo "  - bring back to canonical: remove the local file + re-run install/install.sh (or await install.sh --update, PLAN-004 PR-E)"
  echo "  - intentional divergence: add a comment in the file explaining why"
  echo "  - upstream the change: open PR on vladm3105/aidoc-flow-ci with the diff"
fi

# Always exit 0 — warning-only per the locked rule (IPLAN-0017 §3.1b).
exit 0
