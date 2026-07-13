#!/usr/bin/env bash
# aidoc-flow-ci install.sh — bootstrap a consumer repo with default
# callers, canonical labels, self-review canon (scripts/pre_push_check.sh
# + .pre-commit-config.yaml merge), and .github/ai-review/config.json.
# Idempotent; safe to re-run; preserves existing files (local override
# always wins); .pre-commit-config.yaml merges canon block via CANON
# marker per PLAN-002 §5.2 (M5 fix).
#
# Templates are fetched via raw GitHub URLs (the pinned CI_TAG) — works in
# both process-substitution mode (`bash <(curl …)`) AND local-clone mode.
# Earlier BASH_SOURCE-based design failed under process-sub because
# BASH_SOURCE points at /dev/fd/N there (caught on aidoc-flow-operations
# PR #108 review).
#
# Usage:
#   Bootstrap (one-shot; new files added, existing preserved):
#   bash install.sh <owner/repo> [--visibility public|private]
#                                 [--codeowner <handle>]
#                                 [--canon-operations-url <url>]
#                                 [--canon-ci-url <url>]
#   Update (re-fetch canon for a repo that already adopted; PLAN-004 PR-E):
#   bash install.sh <owner/repo> --update [--non-interactive]
#                                 [--codeowner <handle>] [--canon-*-url <url>]
#   Re-pin (version-only tag bump; preserves all customization — use this for a
#   re-pin, NEVER --update which re-applies the template body; FT-9):
#   CI_TAG=ci/v2.0.0 bash install.sh <owner/repo> --repin
#   CI_TAG=ci/v2.0.0 bash install.sh <owner/repo> --visibility private
#
# De-branding flags (PLAN-004 D2) let an external org adopt the canon
# without vladm3105/aidoc-flow-operations hardcoded. Placeholders in the
# templates (${CODEOWNER_HANDLE} in config.json; ${CANON_OPERATIONS_URL} /
# ${CANON_CI_URL} in CLAUDE.md) are substituted at fetch time. Every flag
# DEFAULTS to the aidoc-flow values, so omitting all three produces
# byte-identical output to the pre-D2 templates.
#   --codeowner <handle>          trust/CODEOWNERS handle (leading @ optional;
#                                   default vladm3105)
#   --canon-operations-url <url>  path/URL to the operations canon repo
#                                   (default ../operations)
#   --canon-ci-url <url>          path/URL to this CI canon repo
#                                   (default ../aidoc-flow-ci)
#
# Requires: gh (authenticated for write on the target repo) + curl + git +
# python3 (placeholder substitution + existing label/pre-commit steps).

set -euo pipefail

TARGET_REPO="${1:?usage: $0 <owner/repo> [--visibility public|private]}"
shift
VISIBILITY="private"
# De-branding defaults — chosen so omitting the flags yields byte-identical
# output to the pre-D2 templates (the aidoc-flow workspace's own values).
CODEOWNER_HANDLE="vladm3105"
CANON_OPERATIONS_URL="../operations"
CANON_CI_URL="../aidoc-flow-ci"
# PLAN-004 PR-E: --update re-fetches the canon surfaces (from manifest.json) for
# a consumer that already adopted, diffs each vs local, and replaces on request.
# --non-interactive auto-replaces only `safe_to_replace` files (workflows,
# dependabot) and keeps everything else. Default (bootstrap) is unchanged.
MODE_UPDATE=0
MODE_REPIN=0
NONINTERACTIVE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --visibility) VISIBILITY="$2"; shift 2 ;;
    --update) MODE_UPDATE=1; shift ;;
    # --repin: version-only pin bump. Rewrites the @ci/vX.Y.Z on every
    # `uses: …/aidoc-flow-ci/…` line to the target CI_TAG and touches NOTHING
    # else — runner_labels, permissions, triggers, and any consumer
    # customization are preserved. This is the CORRECT re-pin operation;
    # `--update` (which re-applies the template body) must never be used for a
    # re-pin (FT-9: it clobbers customized callers → runner-self brick).
    --repin) MODE_REPIN=1; shift ;;
    --non-interactive) NONINTERACTIVE=1; shift ;;
    # Strip a leading @ so `--codeowner @org` and `--codeowner org` are
    # equivalent; the templates re-add @ only where CODEOWNERS syntax needs it.
    --codeowner) : "${2:?--codeowner requires a value}"; CODEOWNER_HANDLE="${2#@}"; shift 2 ;;
    --canon-operations-url) CANON_OPERATIONS_URL="${2:?--canon-operations-url requires a value}"; shift 2 ;;
    --canon-ci-url) CANON_CI_URL="${2:?--canon-ci-url requires a value}"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done
case "$VISIBILITY" in public|private) ;; *) echo "--visibility must be public|private" >&2; exit 1 ;; esac
if [ "$MODE_UPDATE" = 1 ] && [ "$MODE_REPIN" = 1 ]; then
  echo "--update and --repin are mutually exclusive (--repin = version-only pin bump; --update = re-apply template body)" >&2; exit 1
fi
# Validate the de-branding values BEFORE substitution. --codeowner lands in
# config.json's trust.ai_review — a SECURITY allowlist — inside a JSON string,
# so restrict it to the GitHub handle grammar (letters, digits, . _ / -). A
# value with JSON-breaking chars (" ] } , or whitespace) could otherwise
# corrupt the JSON or smuggle an extra trust entry, and the post-substitution
# assertion only catches SURVIVING placeholders, not injected content.
case "$CODEOWNER_HANDLE" in
  "" | *[!A-Za-z0-9._/-]* )
    echo "--codeowner: '$CODEOWNER_HANDLE' is not a valid handle (allowed: letters, digits, and . _ / -)" >&2
    exit 1 ;;
esac
# --canon-*-url land in CLAUDE.md (AI-agent governance instructions). Reject
# newlines / control chars so a value cannot break out of the markdown link
# line and inject governance text (defense-in-depth).
for _canon_url in "$CANON_OPERATIONS_URL" "$CANON_CI_URL"; do
  case "$_canon_url" in
    *[[:cntrl:]]* )
      echo "--canon-*-url: values must not contain newlines or control characters" >&2
      exit 1 ;;
  esac
done

# Resolve the pinned CI tag. Precedence (PLAN-004 §4.4): CI_TAG env >
# VERSION file (repo-local only) > hardcoded fallback. The fallback is
# bumped on every release cut so consumers who don't set CI_TAG get a
# frozen tag (not the moving `main`).
#
# VERSION is read ONLY from the script's own directory when running from a
# checkout. In process-substitution mode (`bash <(curl …)`) $0/BASH_SOURCE
# point at /dev/fd/N (see the header note), so no local VERSION is reachable
# and the hardcoded fallback is authoritative — that is expected and correct.
# The startup log below names the winning source so a stale CI_TAG env var in
# a consumer's CI caller silently overriding VERSION is diagnosable.
CI_TAG_FALLBACK="ci/v2.0.0"
if [ -n "${CI_TAG:-}" ]; then
  CI_TAG_SOURCE="CI_TAG env"
else
  _self="${BASH_SOURCE[0]:-$0}"
  _script_dir=""
  case "$_self" in
    /dev/fd/*|/proc/*|pipe:*|"") : ;;   # process-sub: no local VERSION to read
    *) _script_dir="$(cd "$(dirname "$_self")" 2>/dev/null && pwd || true)" ;;
  esac
  if [ -n "$_script_dir" ] && [ -f "$_script_dir/../VERSION" ] \
     && _v="$(tr -d '[:space:]' < "$_script_dir/../VERSION")" \
     && printf '%s' "$_v" | grep -qE '^ci/v[0-9]+\.[0-9]+\.[0-9]+$'; then
    CI_TAG="$_v"
    CI_TAG_SOURCE="VERSION file"
  else
    # Distinguish a malformed VERSION from an absent one so an operator who
    # expects VERSION to win learns from the log that it was rejected.
    if [ -n "$_script_dir" ] && [ -f "$_script_dir/../VERSION" ]; then
      echo "==> WARN: $_script_dir/../VERSION present but not a valid ci/vX.Y.Z tag — using fallback" >&2
    fi
    CI_TAG="$CI_TAG_FALLBACK"
    CI_TAG_SOURCE="hardcoded fallback"
  fi
fi
TEMPLATE_BASE="https://raw.githubusercontent.com/vladm3105/aidoc-flow-ci/${CI_TAG}/install/templates"

echo "==> using CI_TAG=$CI_TAG (source: $CI_TAG_SOURCE)"
if [ "$MODE_REPIN" = 1 ]; then
  echo "==> re-pinning $TARGET_REPO callers to @ $CI_TAG (version-only; topology preserved)"
elif [ "$MODE_UPDATE" = 1 ]; then
  echo "==> updating $TARGET_REPO against canon @ $CI_TAG (non-interactive=$NONINTERACTIVE)"
else
  echo "==> bootstrapping $TARGET_REPO (visibility=$VISIBILITY, tag=$CI_TAG)"
fi

# Clone the consumer to a stable user-visible location (NOT a temp dir
# with auto-cleanup trap) — the user needs to inspect + commit after this
# script exits.
WORK_DIR="${WORK_DIR:-$PWD/aidoc-flow-ci-bootstrap-$$}"
gh repo clone "$TARGET_REPO" "$WORK_DIR/consumer" -- --depth 1
cd "$WORK_DIR/consumer"

# Bootstrap creates the canon dirs; --update only touches files the consumer
# already has, so it must NOT litter empty dirs into the clone.
[ "$MODE_UPDATE" = 1 ] || [ "$MODE_REPIN" = 1 ] || mkdir -p .github/workflows .github/ai-review

fetch_template() {
  # $1 = source path under install/templates/; $2 = destination path
  local src="$1" dst="$2"
  if ! curl -fsSL "${TEMPLATE_BASE}/${src}" -o "${dst}"; then
    echo "  FAIL  failed to fetch ${TEMPLATE_BASE}/${src}" >&2
    return 1
  fi
}

substitute_placeholders() {
  # $1 = file to substitute in place. Replaces the canonical de-branding
  # placeholders with the resolved values. Substitution is LITERAL (not
  # regex) and the values are passed as argv to python3 — never interpolated
  # into shell or code — so a hostile handle/URL cannot inject (same
  # discipline as PLAN-004 C2's env-var indirection). A post-substitution
  # assertion fails closed if any DECLARED placeholder survives (a typo in
  # the template or a missed replacement), so a half-branded file can never
  # be committed. It greps ONLY the three declared names — NOT a blanket
  # ${...} scan — so unrelated shell-style ${VAR} text a consumer may
  # legitimately carry elsewhere does not trip it (per PLAN-004 Pass-4).
  local file="$1"
  python3 - "$file" "$CODEOWNER_HANDLE" "$CANON_OPERATIONS_URL" "$CANON_CI_URL" <<'PYEOF'
import sys
path, handle, ops_url, ci_url = sys.argv[1:5]
text = open(path, encoding="utf-8").read()
text = text.replace("${CODEOWNER_HANDLE}", handle)
text = text.replace("${CANON_OPERATIONS_URL}", ops_url)
text = text.replace("${CANON_CI_URL}", ci_url)
open(path, "w", encoding="utf-8").write(text)
PYEOF
  if grep -nE '\$\{(CODEOWNER_HANDLE|CANON_OPERATIONS_URL|CANON_CI_URL)\}' "$file" >&2; then
    echo "  FAIL  unresolved canon placeholder(s) remain in ${file} (substitution bug — refusing to leave a half-branded file)" >&2
    exit 1
  fi
}

update_mode() {
  # PLAN-004 PR-E. Walk install/templates/manifest.json; for every canon
  # surface the consumer ALREADY has, re-fetch the template at $CI_TAG,
  # substitute the de-branding placeholders, and diff vs local. On drift:
  # interactive → prompt [k]eep/[r]eplace/[d]iff-only; --non-interactive →
  # replace ONLY `safe_to_replace` files (workflows, dependabot), keep the
  # rest (governance/policy: config.json, CODEOWNERS, CLAUDE.md, pre_push).
  # Files the consumer does NOT have are skipped (bootstrap adds new files;
  # --update never introduces surfaces the consumer didn't opt into).
  # NOTE: labels.json (GitHub-API surface) + .pre-commit-config.yaml (canon
  # block is MERGED, not replaced) are intentionally out of this file-diff
  # walk — re-run `install.sh` (bootstrap) to refresh those.
  local vis
  # Resolve variant from the repo's ACTUAL visibility (a stale --visibility
  # would fetch the wrong caller variant). The repo was already cloned above,
  # so a `gh repo view` failure here is anomalous — treat it as FATAL rather
  # than guessing, since guessing wrong could auto-replace (e.g.) a public
  # caller with the private variant under --non-interactive.
  local detected
  if ! detected=$(gh repo view "$TARGET_REPO" --json isPrivate --jq '.isPrivate' 2>/dev/null); then
    echo "  FAIL  gh repo view failed for $TARGET_REPO — cannot resolve visibility for variant selection (refusing to guess)" >&2
    return 1
  fi
  case "$detected" in
    true)  vis="private" ;;
    false) vis="public" ;;
    *)     echo "  FAIL  unexpected isPrivate='$detected' from gh — refusing to guess visibility" >&2; return 1 ;;
  esac
  echo "==> update: resolving templates for visibility=$vis"

  local manifest
  manifest=$(mktemp)
  fetch_template "manifest.json" "$manifest" || { rm -f "$manifest"; return 1; }

  # Emit "path<TAB>resolved_template<TAB>safe(0|1)" per file (variant resolved
  # in python3, which is already a hard dependency).
  local entries
  entries=$(python3 - "$manifest" "$vis" <<'PYEOF'
import sys, json
manifest, vis = sys.argv[1], sys.argv[2]
m = json.load(open(manifest, encoding="utf-8"))
for f in m["files"]:
    tmpl = f.get("visibility_variants", {}).get(vis, f["template"])
    safe = "1" if f.get("safe_to_replace") else "0"
    print("\t".join([f["path"], tmpl, safe]))
PYEOF
) || { echo "  FAIL  could not parse manifest.json" >&2; rm -f "$manifest"; return 1; }
  rm -f "$manifest"

  local replaced=0 kept=0 unchanged=0 absent=0
  # Read all entries into an array FIRST so the loop body's stdin stays free
  # for the interactive prompt (reading from stdin inside `while <<<` would
  # consume the entry list).
  local -a lines=()
  mapfile -t lines <<< "$entries"
  local line cpath ctmpl csafe fetched action dir tmp2
  for line in "${lines[@]}"; do
    [ -z "$line" ] && continue
    IFS=$'\t' read -r cpath ctmpl csafe <<< "$line"
    if [ ! -f "$cpath" ]; then
      absent=$((absent + 1)); continue
    fi
    fetched=$(mktemp)
    if ! curl -fsSL "${TEMPLATE_BASE}/${ctmpl}" -o "$fetched"; then
      echo "  WARN  failed to fetch ${ctmpl} — skipping $cpath" >&2
      rm -f "$fetched"; continue
    fi
    # Substitute uniformly: a template with no declared placeholders is a
    # no-op (and still passes the fail-closed assertion). This makes the
    # diff show what would ACTUALLY land (post-substitution content).
    substitute_placeholders "$fetched"
    if diff -q "$cpath" "$fetched" >/dev/null 2>&1; then
      unchanged=$((unchanged + 1)); rm -f "$fetched"; continue
    fi
    echo ""
    echo "  DRIFT  $cpath  (safe_to_replace=$csafe)"
    # Label the canon side with the template name (not the mktemp path) so the
    # printed diff / audit log names which canon file the drift is against.
    diff -u --label "$cpath" --label "canon:$ctmpl" "$cpath" "$fetched" 2>/dev/null | sed 's/^/    /' | head -60 || true
    if [ "$NONINTERACTIVE" = 1 ] || [ ! -t 0 ]; then
      [ "$NONINTERACTIVE" != 1 ] && echo "  (no TTY — treating as --non-interactive)"
      if [ "$csafe" = 1 ]; then action="r"; else action="k"; fi
    else
      printf "  [k]eep local / [r]eplace with canon / [d]iff-only (keep)? "
      read -r action || action="k"
    fi
    case "$action" in
      r|R)
        # Atomic replace: stage a tmp beside the target (same filesystem) then
        # rename, so a mid-write interrupt never leaves a truncated file.
        dir=$(dirname "$cpath")
        tmp2=$(mktemp "${dir}/.canon.XXXXXX") || { echo "  FAIL  mktemp in $dir" >&2; rm -f "$fetched"; return 1; }
        if cp "$fetched" "$tmp2" && mv "$tmp2" "$cpath"; then
          replaced=$((replaced + 1)); echo "  replaced  $cpath"
        else
          rm -f "$tmp2"; echo "  FAIL  could not replace $cpath" >&2; rm -f "$fetched"; return 1
        fi
        ;;
      *)
        kept=$((kept + 1))
        [ "$csafe" = 0 ] && [ "$NONINTERACTIVE" = 1 ] \
          && echo "  kept      $cpath (not safe-to-replace — review the diff above + update by hand if wanted)" \
          || echo "  kept      $cpath"
        ;;
    esac
    rm -f "$fetched"
  done

  echo ""
  echo "==> update summary: replaced=$replaced  kept=$kept  unchanged=$unchanged  absent/not-adopted=$absent"
  if [ "$replaced" -gt 0 ]; then
    echo "    Inspect + commit: cd $WORK_DIR/consumer && git diff"
  fi
  return 0
}

repin_mode() {
  # Version-only re-pin: rewrite the @ci/vX.Y.Z on every
  # `uses: …/aidoc-flow-ci/…` line in .github/workflows/*.yml to $CI_TAG.
  # Preserves runner_labels, permissions, triggers, and every consumer
  # customization — the ONLY change is the pinned tag. Idempotent.
  local target="$CI_TAG" changed=0 f
  [ -d .github/workflows ] || { echo "  no .github/workflows/ — nothing to re-pin" >&2; return 0; }
  # Match both .yml and .yaml (GitHub Actions honors either); [ -f ] handles the
  # literal-glob no-match case so a repo with only one extension is fine.
  for f in .github/workflows/*.yml .github/workflows/*.yaml; do
    [ -f "$f" ] || continue
    grep -qE '^\s*uses:.*vladm3105/aidoc-flow-ci/' "$f" || continue
    # rewrite only the pin on aidoc-flow-ci uses: lines; leave @main and
    # comments untouched. Report old→new per file.
    local before; before="$(grep -E '^\s*uses:.*aidoc-flow-ci/.*@(ci/v[0-9.]+|[0-9a-f]{40})' "$f" | grep -oE '@ci/v[0-9.]+|@[0-9a-f]{7}' | sort -u | tr '\n' ' ')"
    # (1) tag-pinned callers: @ci/vX.Y.Z -> @$target
    sed -i -E "s#(^[[:space:]]*uses:[[:space:]]*vladm3105/aidoc-flow-ci/[^@]+)@ci/v[0-9.]+#\1@${target}#" "$f"
    # (2) SHA-pinned callers: @<40hex> (optionally trailed by "# ci/vX") -> @$target.
    #     '|' delimiter because the pattern contains '#'. Converts a SHA pin to a
    #     tag pin so --repin covers the whole fleet (audit-trail was historically
    #     SHA-pinned; without this it was silently skipped).
    sed -i -E "s|(^[[:space:]]*uses:[[:space:]]*vladm3105/aidoc-flow-ci/[^@]+)@[0-9a-f]{40}([[:space:]]*# ci/v[0-9.]+.*)?$|\1@${target}|" "$f"
    if ! git diff --quiet -- "$f" 2>/dev/null; then
      echo "  repinned  $f  (${before:-?} -> @${target})"
      changed=$((changed+1))
    fi
  done
  echo "==> re-pin summary: $changed file(s) bumped to @${target}"
  return 0
}

if [ "$MODE_REPIN" = 1 ]; then
  if repin_mode; then repin_rc=0; else repin_rc=$?; fi
  echo ""
  echo "==> re-pin done (rc=$repin_rc). Working copy: $WORK_DIR/consumer"
  echo "    Review the diff, then commit + push (version-only; topology preserved)."
  exit "$repin_rc"
fi

if [ "$MODE_UPDATE" = 1 ]; then
  # Call in an `if` so a `return 1` from update_mode doesn't trip `set -e`
  # before we can report + exit with its status. NOTE: running a function in a
  # condition disables `set -e` for its ENTIRE body — every failure path inside
  # update_mode carries its own explicit `return 1` guard for that reason.
  if update_mode; then update_rc=0; else update_rc=$?; fi
  echo ""
  echo "==> update done (rc=$update_rc). Working copy: $WORK_DIR/consumer"
  exit "$update_rc"
fi

# Drop the default consumer-side callers. Preserve existing files.
for wf in ai-review composition; do
  if [ -f ".github/workflows/${wf}.yml" ]; then
    echo "  preserve  .github/workflows/${wf}.yml (already exists — local override)"
  else
    fetch_template "workflows/${wf}-${VISIBILITY}.yml" ".github/workflows/${wf}.yml" || exit 1
    echo "  add       .github/workflows/${wf}.yml"
  fi
done

if [ -f ".github/ai-review/config.json" ]; then
  echo "  preserve  .github/ai-review/config.json (already exists)"
else
  fetch_template "config.json.template" ".github/ai-review/config.json" || exit 1
  substitute_placeholders ".github/ai-review/config.json"
  echo "  add       .github/ai-review/config.json (codeowner=${CODEOWNER_HANDLE})"
fi

# --- PLAN-004 FT-7: CODEOWNERS canon (de-branded via --codeowner) ---
# Ships for every tier (governance + umbrella gate on it via branch
# protection `require_code_owner_reviews`; product + ops-private tiers ship
# it but do NOT gate — see the template header). The drift check
# (`apply-standards.sh`) compares CODEOWNERS with owner handles NORMALIZED,
# so a consumer's own handle here is not read as drift against the canon.
if [ -f ".github/CODEOWNERS" ]; then
  echo "  preserve  .github/CODEOWNERS (already exists — inspect for canon parity via apply-standards.sh --check)"
else
  fetch_template "CODEOWNERS.template" ".github/CODEOWNERS" || exit 1
  substitute_placeholders ".github/CODEOWNERS"
  echo "  add       .github/CODEOWNERS (codeowner=${CODEOWNER_HANDLE})"
fi

# --- PLAN-003 PR-V2: CLAUDE.md canon template bootstrap ---
# If consumer has no CLAUDE.md, install the canon template with all
# placeholders present (consumer MUST fill placeholders before commit).
# If consumer has a CLAUDE.md, verify presence of the 5 required
# sections (per PLAN-003 §4.3) + the Per-repo governance table anchor
# (per §4.5). Print a merge suggestion; do NOT auto-modify existing
# CLAUDE.md — too risky given the file's session-level importance.
if [ -f "CLAUDE.md" ]; then
  echo "  preserve  CLAUDE.md (already exists)"
  # Verify canonical section presence per §4.3 + §4.5. All 5 required
  # anchors: H1 title + 4 H2 sections.
  MISSING_SECTIONS=()
  grep -qE "^# CLAUDE\.md" CLAUDE.md || MISSING_SECTIONS+=("# CLAUDE.md — <REPO_FRIENDLY_NAME>")
  grep -qE "^## What this (repo|project) is" CLAUDE.md || MISSING_SECTIONS+=("## What this repo is")
  grep -qE "^## Per-repo governance(\s+[—-].*)?\s*$" CLAUDE.md || MISSING_SECTIONS+=("## Per-repo governance (with optional em-dash tail)")
  grep -qE "^## GitHub operations" CLAUDE.md || MISSING_SECTIONS+=("## GitHub operations")
  grep -qE "^## Workspace standards" CLAUDE.md || MISSING_SECTIONS+=("## Workspace standards (aidoc-flow canon — read the canonical rules directly)")
  if [ "${#MISSING_SECTIONS[@]}" -gt 0 ]; then
    echo "  WARN      CLAUDE.md is missing the following canonical sections (per PLAN-003 §4.3):"
    for section in "${MISSING_SECTIONS[@]}"; do
      echo "              - $section"
    done
    echo "            fetch template + merge manually:"
    echo "              curl -fsSL ${TEMPLATE_BASE}/CLAUDE.md.template"
    echo "            do NOT auto-overwrite — existing CLAUDE.md has session-level"
    echo "            content that must be preserved. See PLAN-003 §5.4c for the"
    echo "            per-repo rewrite scope + Wave rollout guidance."
  fi
else
  fetch_template "CLAUDE.md.template" "CLAUDE.md" || exit 1
  substitute_placeholders "CLAUDE.md"
  echo "  add       CLAUDE.md (template with placeholders — FILL BEFORE COMMIT: <REPO_FRIENDLY_NAME>, <REPO_PURPOSE_ONE_LINER>, table cells, etc.)"
fi

# --- PLAN-002 PR-U2: self-review canon (pre_push_check.sh + pre-commit wiring) ---

# scripts/pre_push_check.sh — exact-match canon. Preserve if already
# present (consumer may have added local edits pre-canon-adoption).
# L2 fold: script-branded error if `scripts` exists as a file.
if [ -e scripts ] && [ ! -d scripts ]; then
  echo "  FAIL: 'scripts' exists in the consumer repo but is not a directory — cannot install canon script" >&2
  exit 1
fi
mkdir -p scripts
if [ -f "scripts/pre_push_check.sh" ]; then
  echo "  preserve  scripts/pre_push_check.sh (already exists — inspect for canon parity via apply-standards.sh --check)"
  # L3 fold: advise on executable bit.
  if [ ! -x scripts/pre_push_check.sh ]; then
    echo "  WARN      existing scripts/pre_push_check.sh is not executable — 'chmod +x scripts/pre_push_check.sh' recommended (pre-commit's language: script needs it)"
  fi
else
  fetch_template "pre_push_check.sh" "scripts/pre_push_check.sh" || exit 1
  chmod +x scripts/pre_push_check.sh
  echo "  add       scripts/pre_push_check.sh"
fi

# .pre-commit-config.yaml — merge canon hook block idempotently.
# Idempotency key: canonical marker `# CANON: aidoc-flow-ci pre_push_check`.
# If present → no-op. If absent → merge (append hook block; upgrade
# default_install_hook_types root key from [pre-commit] → [pre-commit,
# pre-push] if consumer had only [pre-commit]).
PRECOMMIT_TMP=$(mktemp)
fetch_template "pre-commit-hook-block.yaml" "$PRECOMMIT_TMP" || { rm -f "$PRECOMMIT_TMP"; exit 1; }
if [ ! -f ".pre-commit-config.yaml" ]; then
  # Consumer has no pre-commit config — install canon fragment verbatim.
  # (Canon fragment carries the marker at line 1 → subsequent re-runs no-op.)
  cp "$PRECOMMIT_TMP" .pre-commit-config.yaml
  echo "  add       .pre-commit-config.yaml (from canon fragment)"
elif grep -qF "# CANON: aidoc-flow-ci pre_push_check" .pre-commit-config.yaml; then
  echo "  preserve  .pre-commit-config.yaml (canon marker present — no-op)"
else
  # M2 fold: fail-fast on missing YAML library BEFORE entering merge, so
  # the operator gets an actionable message instead of a generic FAIL.
  # M1 fold: prefer ruamel.yaml (round-trip preserves consumer comments);
  # fall back to PyYAML with explicit WARN about comment stripping.
  yaml_lib=""
  if python3 -c 'import ruamel.yaml' 2>/dev/null; then
    yaml_lib="ruamel"
  elif python3 -c 'import yaml' 2>/dev/null; then
    yaml_lib="pyyaml"
    echo "  WARN      ruamel.yaml unavailable — falling back to PyYAML which STRIPS consumer comments from .pre-commit-config.yaml. Install ruamel.yaml (pip install ruamel.yaml) to preserve comments." >&2
  else
    echo "  FAIL: neither ruamel.yaml nor PyYAML available — 'pip install ruamel.yaml' (preferred) or 'pip install pyyaml' and re-run install.sh" >&2
    rm -f "$PRECOMMIT_TMP"
    exit 1
  fi

  # M3 fold: put tempfile on the target filesystem so `mv` is atomic
  # rename(2), not cross-fs copy+unlink (which would leave a truncated
  # .pre-commit-config.yaml on SIGINT mid-mv).
  MERGE_TMP=$(mktemp ./.pre-commit-config.yaml.tmp.XXXXXX)
  if python3 - "$PRECOMMIT_TMP" "$MERGE_TMP" "$yaml_lib" <<'PYEOF' ; then
import sys

canon_path, out_path, yaml_lib = sys.argv[1], sys.argv[2], sys.argv[3]

if yaml_lib == "ruamel":
    from ruamel.yaml import YAML
    ry = YAML(typ='rt')
    ry.preserve_quotes = True
    load = lambda p: ry.load(open(p))
    dump = lambda obj, f: ry.dump(obj, f)
else:
    import yaml
    load = lambda p: yaml.safe_load(open(p))
    dump = lambda obj, f: yaml.safe_dump(obj, f, default_flow_style=False, sort_keys=False)

try:
    consumer = load('.pre-commit-config.yaml') or {}
except Exception as e:
    print(f"  FAIL  .pre-commit-config.yaml parse error: {e}", file=sys.stderr)
    sys.exit(1)
try:
    canon = load(canon_path) or {}
except Exception as e:
    print(f"  FAIL  canon fragment parse error: {e}", file=sys.stderr)
    sys.exit(1)

# Root-key upgrade: default_install_hook_types must include pre-push.
# L1 fold: preserve consumer intent — if scalar (invalid but real), coerce
# to a single-element list rather than resetting to canonical default.
consumer_hooks = consumer.get('default_install_hook_types', ['pre-commit'])
if isinstance(consumer_hooks, str):
    consumer_hooks = [consumer_hooks]
elif not isinstance(consumer_hooks, list):
    consumer_hooks = ['pre-commit']
canon_hooks = canon.get('default_install_hook_types', ['pre-commit', 'pre-push'])
for h in canon_hooks:
    if h not in consumer_hooks:
        consumer_hooks.append(h)
consumer['default_install_hook_types'] = consumer_hooks

# Append canon repos-block entries (which are hooks). Preserve existing.
consumer_repos = consumer.setdefault('repos', [])
for canon_repo in canon.get('repos', []):
    # De-dup by structural equality. Canon uses `repo: local` + a
    # single hook id `aidoc-flow-pre-push` — check for exact match.
    if canon_repo not in consumer_repos:
        consumer_repos.append(canon_repo)

with open(out_path, 'w') as f:
    # Preserve the canon marker line at top so future re-runs no-op.
    f.write("# CANON: aidoc-flow-ci pre_push_check (idempotency marker per PLAN-002 §5.2)\n")
    dump(consumer, f)
PYEOF
    mv "$MERGE_TMP" .pre-commit-config.yaml
    echo "  merge     .pre-commit-config.yaml (canon block appended; default_install_hook_types upgraded if needed; ${yaml_lib}-backed)"
  else
    rm -f "$MERGE_TMP" "$PRECOMMIT_TMP"
    echo "  FAIL      .pre-commit-config.yaml merge failed — inspect manually" >&2
    exit 1
  fi
fi
rm -f "$PRECOMMIT_TMP"

# Canonical labels — idempotent + fail-loud. Prefetch existing labels so
# we don't conflate "already exists" with real failures (auth / permission
# / network / invalid repo).
echo "==> creating canonical labels on $TARGET_REPO"
LABELS_TMP=$(mktemp)
fetch_template "labels.json" "$LABELS_TMP" || exit 1
EXISTING_TMP=$(mktemp)
if ! gh label list --json name,color,description -R "$TARGET_REPO" > "$EXISTING_TMP" 2>/dev/null; then
  echo "  FAIL  failed to list existing labels on $TARGET_REPO (auth/permission/network?). Cannot safely idempotent-create." >&2
  rm -f "$LABELS_TMP" "$EXISTING_TMP"
  exit 1
fi
python3 -c "
import json, subprocess, sys
desired = json.load(open('$LABELS_TMP'))
existing_by_name = {l['name']: l for l in json.load(open('$EXISTING_TMP'))}
failures = 0
for d in desired:
    name = d['name']
    if name in existing_by_name:
        cur = existing_by_name[name]
        if cur.get('color') == d['color'] and cur.get('description') == d['description']:
            print(f'  exists   label {name}')
        else:
            print(f'  WARN     label {name} exists with different color/description (color: {cur.get(\"color\")} vs {d[\"color\"]}; not overwriting)')
        continue
    try:
        subprocess.run(['gh', 'label', 'create', name, '--color', d['color'], '--description', d['description'], '-R', '$TARGET_REPO'], check=True, capture_output=True)
        print(f'  add      label {name}')
    except subprocess.CalledProcessError as e:
        stderr = (e.stderr or b'').decode('utf-8', errors='replace').strip()
        print(f'  FAIL     gh label create {name} failed (exit {e.returncode}): {stderr}', file=sys.stderr)
        failures += 1
sys.exit(1 if failures > 0 else 0)
"
LABEL_RC=$?
rm -f "$LABELS_TMP" "$EXISTING_TMP"
if [ "$LABEL_RC" -ne 0 ]; then
  echo "==> ABORT: $LABEL_RC label-creation failure(s); the consumer may be missing canonical labels. Fix the failures and re-run."
  exit "$LABEL_RC"
fi

echo ""
echo "==> done. Next steps (founder):"
echo "    1. Inspect bootstrapped files: cd $WORK_DIR/consumer && git diff"
echo "    2. Commit + push + open PR on the consumer"
echo "    3. Add reviewer App secrets (APP_REVIEWER_1_ID + APP_REVIEWER_1_KEY) to the consumer"
echo "    4. After CI green, set vars.APP_REVIEWER_1_BOT_ID + branch protection per IPLAN-0016 §2a-v3"
echo "    5. (Cleanup, your choice) rm -rf $WORK_DIR"
