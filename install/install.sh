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
#   CI_TAG=ci/v3.0.0 bash install.sh <owner/repo> --repin
#   CI_TAG=ci/v3.0.0 bash install.sh <owner/repo> --visibility private
#   Add a surface the consumer does NOT have (the only route for an
#   `auto_install: false` file — bootstrap installs only the auto_install set and
#   --update never introduces a new surface, which is how the v3 callers shipped
#   uninstallable; #429). Repeatable. Never overwrites, arms nothing:
#   bash install.sh <owner/repo> --add-surface .github/workflows/quick-gates.yml \
#                                --add-surface .github/workflows/scanners.yml
#   Verify server-side standards (no install; exits non-zero on genuine drift —
#   PLAN-015 B2; needs an admin-scoped gh token to check branch protection):
#   bash install.sh <owner/repo> --verify-standards --tier <governance|product|ops|umbrella|bootstrap>
#   (a bootstrap also runs this verify at the end and reports honestly if --tier is given)
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

# FT-50: install.sh itself uses `mapfile` (bash 4+), so bash >= 4 is UNCONDITIONAL
# to run it — not just for the pre-push hook. macOS ships bash 3.2. Guard up front
# with an actionable message (mirrors install/apply-standards.sh's guard) instead
# of a cryptic `mapfile: command not found` deep in --update.
if (( BASH_VERSINFO[0] < 4 )); then
  echo "install.sh requires bash >= 4 (uses mapfile); this is bash ${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}. macOS ships bash 3.2 — 'brew install bash', then run with that bash (e.g. /opt/homebrew/bin/bash install.sh ...)." >&2
  exit 1
fi

# HARD DEPENDENCIES, CHECKED BEFORE ANYTHING MUTATES. The header states
# "Requires: gh … + curl + git + python3" and, until this block, checked only
# `gh` — and that only at :1531, more than a thousand lines after the clone and
# the pre-write backup. A host without `python3` therefore cloned the target,
# wrote the backup, and then died inside `substitute_placeholders` with a bare
# `python3: command not found`: recoverable from the backup, but with nothing
# naming the missing dependency. Every other script in this repo
# (apply-standards.sh, set-llm-secrets.sh) preflights; the installer — the one
# entry point a NEW adopter runs first, on a machine canon has never seen — did
# not. Placed above argument parsing so it costs no network call (the placement
# rule the --visibility bug taught: validation must never require the network).
_missing_deps=""
for _dep in gh curl git python3; do
  command -v "$_dep" >/dev/null 2>&1 || _missing_deps="$_missing_deps $_dep"
done
if [ -n "$_missing_deps" ]; then
  echo "install.sh requires:$_missing_deps — not found on PATH." >&2
  echo "  gh      GitHub CLI, authenticated for write on the target repo (gh auth login)" >&2
  echo "  curl    fetches every template from raw.githubusercontent.com" >&2
  echo "  git     clones the target and commits the installed surfaces" >&2
  echo "  python3 renders manifest-driven placeholder substitution" >&2
  echo "Refusing to start: this script clones and writes to a real repo, so a" >&2
  echo "mid-run failure leaves a partially-installed tree behind." >&2
  exit 1
fi

TARGET_REPO="${1:?usage: $0 <owner/repo> [--visibility public|private]}"
shift
# DEFAULTS TO PRIVATE ONLY AS A FALLBACK, AND IS AUTO-DETECTED BELOW. Leaving
# this as the effective value is how a PUBLIC repo got the private variants: the
# bootstrap block reads $VISIBILITY, `update_mode` and `add_surface_mode` resolve
# from the LIVE repo, and only bootstrap trusted the flag. A public cold start
# run without `--visibility public` therefore installed
# `quick-gates-private.yml` — self-hosted — on a repo whose `quick-gates` job
# executes the PR's own files. That is the D7 / fork-code-on-self-hosted
# violation `CLAUDE.md` says NEVER to make.
VISIBILITY="private"
VISIBILITY_EXPLICIT=0
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
# PLAN-015 B2 Task 3: `--verify-standards` runs the server-side drift check
# (no install) and exits non-zero on genuine drift/absent standards; `--tier`
# names the tier to compare against (also used to verify at the end of a
# bootstrap instead of printing a silent "apply branch protection" reminder).
MODE_VERIFY=0
TIER=""
ADD_SURFACES=()
while [ $# -gt 0 ]; do
  case "$1" in
    --visibility) VISIBILITY="$2"; VISIBILITY_EXPLICIT=1; shift 2 ;;
    --update) MODE_UPDATE=1; shift ;;
    # --repin: version-only pin bump. Rewrites the @ci/vX.Y.Z on every
    # `uses: …/aidoc-flow-ci/…` line to the target CI_TAG and touches NOTHING
    # else — runner_labels, permissions, triggers, and any consumer
    # customization are preserved. This is the CORRECT re-pin operation;
    # `--update` (which re-applies the template body) must never be used for a
    # re-pin (FT-9: it clobbers customized callers → runner-self brick).
    --repin) MODE_REPIN=1; shift ;;
    --verify-standards) MODE_VERIFY=1; shift ;;
    # --add-surface: install a manifested surface the consumer does NOT have.
    # The only path for an `auto_install: false` file — bootstrap installs only
    # the auto_install set, and --update never introduces a new surface, so v3's
    # callers had no install path at all (#429). Repeatable. Adds only; never
    # overwrites, never arms a required context.
    --add-surface) ADD_SURFACES+=("${2:?--add-surface requires a path}"); shift 2 ;;
    --tier) TIER="${2:?--tier requires a value}"; shift 2 ;;
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
if [ "$MODE_VERIFY" = 1 ] && { [ "$MODE_UPDATE" = 1 ] || [ "$MODE_REPIN" = 1 ]; }; then
  echo "--verify-standards is standalone (no install) — not combinable with --update/--repin" >&2; exit 1
fi
# --add-surface is its own mode: it ADDS files the consumer lacks, while
# --update re-applies bodies of files they have and --repin rewrites tag strings
# in place. Combining them would make "what did this run do to my tree?"
# unanswerable, which is the question FT-9 was lost on.
if [ "${#ADD_SURFACES[@]}" -gt 0 ] && { [ "$MODE_UPDATE" = 1 ] || [ "$MODE_REPIN" = 1 ] || [ "$MODE_VERIFY" = 1 ]; }; then
  echo "--add-surface is standalone — not combinable with --update/--repin/--verify-standards" >&2; exit 1
fi
# --tier is meaningless here: this mode exits before any tier-driven step, and
# accepting a flag it silently ignores is how an operator concludes branch
# protection was applied. Reject rather than ignore.
if [ "${#ADD_SURFACES[@]}" -gt 0 ] && [ -n "$TIER" ]; then
  echo "--tier has no effect with --add-surface (this mode arms nothing); drop it" >&2; exit 1
fi
if [ -n "$TIER" ]; then
  case "$TIER" in governance|product|ops|umbrella|bootstrap) ;; *) echo "--tier must be one of: governance|product|ops|umbrella|bootstrap" >&2; exit 1 ;; esac
fi

# --- visibility, resolved from the LIVE repo -------------------------------
#
# PLACED AFTER EVERY PURE-ARGUMENT VALIDATION, DELIBERATELY. An earlier draft put
# this immediately after the `--visibility` value check, which made a
# bad-arguments error depend on the network: `--add-surface X --update` aborted
# with "could not read visibility" instead of "not combinable", because the
# `gh` call ran first. Caught by the existing mutual-exclusion tests.
# **Argument validation must never require a network call.**
# RESOLVE VISIBILITY FROM THE LIVE REPO unless the operator stated it. The same
# rule `update_mode` and `add_surface_mode` already follow, applied to the one
# mode that did not — and bootstrap is the mode where getting it wrong is worst,
# because it is the only one that writes a caller the consumer never had.
#
# An explicit `--visibility` still wins: it is the documented escape for a repo
# about to be flipped, and overriding a deliberate flag would be its own defect.
# Detection failure REFUSES rather than falling back to the `private` default —
# "could not determine" must never resolve to a value that installs
# fork-code-executing jobs onto a self-hosted pool.
if [ "$VISIBILITY_EXPLICIT" = 0 ] && [ "${MODE_VERIFY:-0}" = 0 ]; then
  if _detected_vis=$(gh repo view "$TARGET_REPO" --json isPrivate --jq '.isPrivate' 2>/dev/null); then
    case "$_detected_vis" in
      true)  VISIBILITY="private" ;;
      false) VISIBILITY="public" ;;
      *) echo "==> ABORT: unexpected isPrivate='$_detected_vis' from gh for $TARGET_REPO — refusing to guess visibility." >&2
         echo "           Pass --visibility public|private explicitly." >&2; exit 1 ;;
    esac
    echo "==> visibility auto-detected from $TARGET_REPO: $VISIBILITY"
  else
    echo "==> ABORT: could not read $TARGET_REPO visibility via gh — refusing to guess." >&2
    echo "           A wrong guess installs self-hosted callers onto a public repo (D7)." >&2
    echo "           Fix gh auth, or pass --visibility public|private explicitly." >&2
    exit 1
  fi
fi

if [ "$MODE_VERIFY" = 1 ] && [ -z "$TIER" ]; then
  echo "--verify-standards requires --tier <governance|product|ops|umbrella|bootstrap>" >&2; exit 1
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
# kept at the current release by `scripts/sync-version-refs.sh` (it is NOT
# hand-bumped — it was, and the ci/v2.0.1 cut forgot it, leaving every
# CI_TAG-less `--repin` writing ci/v2.0.0 onto consumers already on v2.0.1,
# i.e. silently pinning the fleet BACKWARDS onto known-fixed bugs).
# `tests/test_version_sync.sh` asserts VERSION == CI_TAG_FALLBACK == the
# latest published ci/v* tag, so the drift cannot recur silently.
#
# VERSION is read ONLY from the script's own directory when running from a
# checkout. In process-substitution mode (`bash <(curl …)`) $0/BASH_SOURCE
# point at /dev/fd/N (see the header note), so no local VERSION is reachable
# and the hardcoded fallback is authoritative — that is expected and correct.
# The startup log below names the winning source so a stale CI_TAG env var in
# a consumer's CI caller silently overriding VERSION is diagnosable.
CI_TAG_FALLBACK="ci/v3.0.0"
if [ -n "${CI_TAG:-}" ]; then
  CI_TAG_SOURCE="CI_TAG env"
else
  _self="${BASH_SOURCE[0]:-$0}"
  _script_dir=""
  case "$_self" in
    /dev/fd/*|/proc/*|pipe:*|"") : ;;   # process-sub: no local VERSION to read
    *) _script_dir="$(cd "$(dirname "$_self")" 2>/dev/null && pwd || true)" ;;
  esac
  # CI-0033 §27: a bash regex test, not a pipeline whose status is the decision.
  # This is the spelling release.sh:54 and sync-version-refs.sh:96 already use;
  # install.sh was the last holdout. The writer here is a `printf` builtin, so
  # no inversion was reachable at this payload size — but §27 states that "the
  # payload is small" is not a justification, and this file is the one every
  # consumer curls, so it decides which tag a cold-start install pins.
  if [ -n "$_script_dir" ] && [ -f "$_script_dir/../VERSION" ] \
     && _v="$(tr -d '[:space:]' < "$_script_dir/../VERSION")" \
     && [[ "$_v" =~ ^ci/v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
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

# PLAN-015 B2 Task 3 — honestly verify server-side standards instead of a silent
# "apply branch protection" reminder. Fetches check-standards-drift.sh from
# canon@CI_TAG and runs it against $repo, classifying the outcome:
#   0 = clean;  1 = genuine drift / absent branch protection;
#   2 = could not verify — the check bailed (gh unauthenticated / jq missing) OR
#       a control was uncheckable (e.g. the token lacks admin scope to read
#       branch protection; administration:read is not grantable to a workflow
#       GITHUB_TOKEN, so a local run needs an authenticated admin-scoped gh);
#   3 = skipped (no --tier, or the script could not be fetched).
# "Installed" must never read as "standards on." Emits the check's own output
# indented; the caller maps the rc to a status line.
verify_standards() {
  local tier="$1" repo="$2"
  if [ -z "$tier" ]; then
    echo "     (skipped — pass --tier <governance|product|ops|umbrella|bootstrap> to verify server-side standards)"
    return 3
  fi
  local script; script="$(mktemp)"
  if ! curl -fsSL "https://raw.githubusercontent.com/vladm3105/aidoc-flow-ci/${CI_TAG}/sync/check-standards-drift.sh" -o "$script" 2>/dev/null; then
    echo "     (skipped — could not fetch check-standards-drift.sh@${CI_TAG})"
    rm -f "$script"; return 3
  fi
  local out
  # Warning mode (no --strict): the script prints ::warning:: lines and a final
  # machine-parseable summary "<N> drift, <M> fetch/scope error(s), <P> pin
  # error(s)". Classify from that SUMMARY, not from individual warning strings —
  # those vary per control and are easy to miss (contexts drift carries spaces,
  # a missing label reads "canon label missing:", and an unauthenticated gh /
  # missing jq bails early emitting NEITHER a drift line nor the summary).
  out="$(bash "$script" --tier "$tier" --repo "$repo" --ci-tag "$CI_TAG" 2>&1 || true)"
  rm -f "$script"
  printf '%s\n' "$out" | sed 's/^/     /'
  local summary n_drift n_fetch
  summary="$(printf '%s\n' "$out" | grep -oE '[0-9]+ drift, [0-9]+ fetch/scope error\(s\), [0-9]+ pin error\(s\)' | tail -1)"
  if [ -z "$summary" ]; then
    # No summary ⇒ the check bailed before running (gh/jq missing or gh
    # unauthenticated) ⇒ verification did NOT happen. Never report clean.
    return 2
  fi
  n_drift="$(printf '%s' "$summary" | grep -oE '^[0-9]+')"
  n_fetch="$(printf '%s' "$summary" | grep -oE '[0-9]+ fetch' | grep -oE '^[0-9]+')"
  # PLAN-018 F2 — name the "required context has no producing workflow" class
  # rather than folding it into generic drift. That class does not present as a
  # failing check; it presents as a check that never reports, so a PR sits on
  # "Expected — Waiting for status to be reported" indefinitely and the operator
  # has no reason to connect it to a contexts line in a drift report.
  # REPORT-STRING ONLY — no new check. --verify-standards is standalone (no
  # clone), so it cannot enumerate the consumer's installed workflows to know
  # which contexts actually have producers; the automated form of that diff is
  # the wizard validator (FT-18).
  # Fires on TIER, not on a contexts delta. Gating it on the drift line was
  # anti-correlated with the defect it describes: the canonical "required
  # context has no producer" repo has contexts that MATCH canon exactly (that is
  # what `apply-standards --apply` writes from the tier template), so no
  # contexts line is emitted and the note never appeared in precisely the case
  # F2 exists to fix — while firing on unrelated deltas that had no missing
  # producer. Reading branch protection also needs an admin-scoped token, so the
  # common operator path emits no contexts line at all.
  # Umbrella is excluded because it deliberately has no required checks.
  if [ "$tier" != "umbrella" ]; then
    echo "     NOTE  every required context on tier '$tier' must be EMITTED by an"
    echo "           installed caller in .github/workflows/. A required check with"
    echo "           no producing workflow does not fail — it never reports, so PRs"
    echo "           block on 'Expected — Waiting for status to be reported'"
    echo "           indefinitely. This report compares SETTINGS, not producers;"
    echo "           the producer diff is the wizard validator (FT-18)."
  fi
  # Drift (branch protection / settings / actions-perms / labels) takes
  # precedence over an uncheckable control (drift is the actionable signal).
  if [ "${n_drift:-0}" -gt 0 ]; then return 1; fi
  if [ "${n_fetch:-0}" -gt 0 ]; then return 2; fi
  return 0
}

echo "==> using CI_TAG=$CI_TAG (source: $CI_TAG_SOURCE)"
if [ "$MODE_VERIFY" = 1 ]; then
  echo "==> verifying server-side standards for $TARGET_REPO (tier=$TIER, canon @ $CI_TAG)"
elif [ "$MODE_REPIN" = 1 ]; then
  echo "==> re-pinning $TARGET_REPO callers to @ $CI_TAG (version-only; topology preserved)"
elif [ "$MODE_UPDATE" = 1 ]; then
  echo "==> updating $TARGET_REPO against canon @ $CI_TAG (non-interactive=$NONINTERACTIVE)"
elif [ "${#ADD_SURFACES[@]}" -gt 0 ]; then
  # DELIBERATELY DOES NOT PRINT $VISIBILITY. This mode resolves the variant from
  # the repo's LIVE visibility and ignores the flag, so echoing the flag here
  # printed a contradiction four lines above the real value — on a public repo
  # invoked with `--visibility private`, "visibility=private" followed by
  # "resolving templates for visibility=public". In the one mode whose headline
  # safety claim is that you cannot pick wrong, and given OPS-0049/D1 is itself a
  # visibility-confusion incident, that is worth not saying at all.
  echo "==> adding surface(s) to $TARGET_REPO from canon @ $CI_TAG (variant resolved from LIVE visibility)"
else
  echo "==> bootstrapping $TARGET_REPO (visibility=$VISIBILITY$([ "$VISIBILITY_EXPLICIT" = 1 ] && printf ' [explicit]' || printf ' [detected]'), tag=$CI_TAG)"
fi

# --verify-standards is standalone (no clone/install): the check reads server
# settings via `gh api --repo` and compares against canon@CI_TAG.
if [ "$MODE_VERIFY" = 1 ]; then
  if verify_standards "$TIER" "$TARGET_REPO"; then vrc=0; else vrc=$?; fi
  echo ""
  case "$vrc" in
    0) echo "==> ✅ server-side standards verified clean (tier=$TIER)." ;;
    1) echo "==> ⚠️  server-side standards NOT applied — drift or missing branch protection (above). Arm per docs/BRANCH_PROTECTION.md + the fleet arming runbook." ;;
    2) echo "==> ⚠️  could not verify — gh unauthenticated/missing tool, or the token lacks admin scope to read branch protection. Re-run with an authenticated admin-scoped gh, or arm per docs/BRANCH_PROTECTION.md." ;;
    *) echo "==> verify skipped (see note above)." ;;
  esac
  exit "$vrc"
fi

# Clone the consumer to a stable user-visible location (NOT a temp dir
# with auto-cleanup trap) — the user needs to inspect + commit after this
# script exits.
WORK_DIR="${WORK_DIR:-$PWD/aidoc-flow-ci-bootstrap-$$}"
gh repo clone "$TARGET_REPO" "$WORK_DIR/consumer" -- --depth 1
cd "$WORK_DIR/consumer"

# >>> MANDATORY-BACKUP >>>  (extracted verbatim by tests/test_install.sh — keep
# these markers; the test drives THIS code rather than a copy of it.)
# FT-57: snapshot every pre-existing governance/CI surface BEFORE the first
# write. Three separate code paths mutate files in this clone — fetch_template's
# `curl -o`, the --update replace's `cp`+`mv`, and --repin's `sed -i` — so a
# per-writer hook would have to be remembered by whoever adds the fourth. One
# snapshot here cannot be bypassed by a later write path.
#
# UNCONDITIONAL by design: not gated on mode, --non-interactive, a TTY, or
# whether the run intends to replace anything. A consumer may carry an
# established, customized flow, and "we only meant to add files" is exactly the
# assumption under which the FT-9 --update clobber happened.
#
# Scope: all of .github/ (so the consumer's OWN workflows are captured too —
# this script never writes them, but a backup that only covers what we intend to
# touch is worthless when the bug is touching something we did not intend), plus
# the root-level configs the manifest can target. Deliberately NOT derived from
# manifest.json: a backup that drifts with the manifest would silently stop
# covering a surface the manifest dropped.
#
# Sited in WORK_DIR rather than beside the script: install.sh is documented as
# runnable piped (`bash <(curl …) --update`), where $0 is not a real path.
# WORK_DIR is deliberately never auto-cleaned, so the backup outlives the run.
BACKUP_DIR="$WORK_DIR/backup"
backup_existing_surfaces() {
  local n=0 p d list rc=0
  local -a files=()
  mkdir -p "$BACKUP_DIR" || return 1

  # NUL-delimited enumeration. A word-split `for p in $(find …)` list is wrong
  # twice over, and both were live defects here before this was fixed:
  #   "bug report.md"  -> split into two nonexistent paths; cp fails; the whole
  #                       installer becomes unusable on that repo, in every mode.
  #   "notes[1].md"    -> glob-expanded onto a SIBLING file; the bracket file is
  #                       never backed up, the sibling is copied twice, the count
  #                       reports success. Fail-OPEN, which is the one outcome a
  #                       mandatory backup must never produce.
  # Do not reintroduce an unquoted command substitution here.
  #
  # `find -L` so a symlinked .github (or a symlinked caller inside it) is
  # followed rather than silently yielding nothing — that was a clean bypass of a
  # MANDATORY backup. `! -type d` is the right predicate under -L: it keeps
  # regular files, symlinks-to-files (followed) and broken symlinks, while
  # excluding directories AND the symlinked-directory root itself (which `cp -p`
  # cannot copy). A resolvable symlink is captured by CONTENT, which is what a
  # restore wants; a BROKEN one has no content to capture and is copied as the
  # LINK instead (see the cp branch below) — `cp -p` dereferences, so a bare
  # `cp -p` on a dangling link fails and, being fail-closed, aborted the whole
  # installer in EVERY mode on any consumer that had one. (CI-0023.)
  list="$(mktemp)" || return 1
  if [ -d .github ]; then
    # find's own status is checked: a partial traversal (unreadable subdir) still
    # prints what it could read and exits non-zero. Swallowing that would report
    # a successful backup that is quietly missing files.
    # stderr is kept, not discarded: the two causes need different remedies and
    # the message alone cannot tell them apart. An unreadable subdirectory is a
    # permissions problem; a symlink LOOP (`ln -s a b; ln -s b a`) makes `find -L`
    # exit non-zero having enumerated nothing, and the old text blamed
    # permissions for it — sending the operator to `chmod` for a cycle no chmod
    # can fix. A loop is a genuine FAULT and still aborts (unlike a dangling
    # link, which is a shape and is handled below): `find -L` cannot traverse it,
    # so we cannot prove the snapshot is complete, and a mandatory backup that
    # cannot prove completeness must not proceed. (CI-0023.)
    # LC_ALL=C is load-bearing, not hygiene: the branch below keys on find's
    # ELOOP strerror text, which is TRANSLATED under a non-English locale. Without
    # it the grep misses, control falls to the permissions branch, and the run
    # reprints the exact misdiagnosis this block exists to remove — on an operator
    # whose locale we never see in CI, so no test would catch it.
    local find_err; find_err="$(mktemp)" || { rm -f "$list"; return 1; }
    if ! LC_ALL=C find -L .github ! -type d -print0 > "$list" 2>"$find_err"; then
      echo "  FAIL  could not enumerate .github — refusing to write" >&2
      if grep -qi 'too many levels of symbolic links' "$find_err"; then
        echo "        cause: a symlink LOOP under .github/ — find cannot traverse it." >&2
        echo "        Break the cycle, then re-run. (chmod will not help.)" >&2
      else
        echo "        cause: likely an unreadable subdirectory — check permissions." >&2
      fi
      sed 's/^/        /' "$find_err" >&2
      rm -f "$list" "$find_err"
      return 1
    fi
    rm -f "$find_err"
    while IFS= read -r -d '' p; do files+=("$p"); done < "$list"
  fi
  rm -f "$list"

  # Non-.github surfaces install.sh can write. Kept as an explicit list rather
  # than derived from manifest.json: a manifest-derived scope would silently
  # stop covering a surface the manifest drops. tests/test_install.sh
  # cross-checks this list AGAINST the manifest, so a manifest ADDITION outside
  # .github/ fails the suite instead of going unbacked.
  # `-e` alone is WRONG here: it dereferences, so a DANGLING symlink at one of
  # these paths tests false and is skipped — silently. The path still exists as
  # a link, install.sh can still overwrite it, and the run reports success with
  # that surface absent from the snapshot. That is fail-OPEN, the one outcome a
  # mandatory backup must never produce, and it is the same broken-symlink blind
  # spot as the `cp -p` defect below — this list simply lost it one step earlier,
  # at enumeration rather than at copy. `|| [ -L … ]` admits the link, and the
  # copy loop's fault-vs-shape branch then handles it. (CI-0023.)
  local r
  for r in .markdownlint.json .lychee.toml .yamllint.yaml .yamllint.yml \
           .pre-commit-config.yaml .gitignore .gitattributes CLAUDE.md \
           scripts/pre_push_check.sh; do
    { [ -e "$r" ] || [ -L "$r" ]; } && files+=("$r")
  done

  for p in ${files[0]+"${files[@]}"}; do
    d="$(dirname "$p")"
    mkdir -p "$BACKUP_DIR/$d" || rc=1
    # A dangling symlink is enumerated by `find -L … ! -type d` (the stat fails,
    # so find yields the link itself) but has no content for `cp -p` to
    # dereference. Copy the LINK verbatim instead (`-Pp`: no-dereference AND
    # preserve, since bare `-P` would not carry the link's own timestamps) — that
    # is the only faithful backup of it, and it keeps the mandatory snapshot
    # fail-CLOSED for real errors rather than aborting on a broken link the
    # consumer merely happens to carry. Do NOT collapse this to a plain `cp -P`
    # for every path: a resolvable symlink must still be captured by content.
    #
    # RESIDUAL, stated rather than papered over: `-e` reports false for EACCES as
    # well as ENOENT, so a resolvable link whose target sits behind an
    # unsearchable directory is classified here as dangling and backed up as a
    # link rather than by content. It is not silently lost, and the case needs
    # the installer to be run by someone who cannot traverse the consumer's own
    # tree — but it is a real gap, not a handled case.
    #
    # Reachable only via the ROOT-LIST arm. On the `.github/` arm `find -L`
    # stats the link first, gets EACCES, and the run hard-aborts above — so that
    # arm never reaches this branch and is stricter than this comment implies.
    # (CI-0023.)
    if [ -L "$p" ] && [ ! -e "$p" ]; then
      cp -Pp "$p" "$BACKUP_DIR/$p" || rc=1
    else
      cp -p "$p" "$BACKUP_DIR/$p" || rc=1
    fi
    [ "$rc" -eq 0 ] || { echo "  FAIL  could not back up $p — refusing to write" >&2; return 1; }
    n=$((n + 1))
  done

  if [ "$n" -eq 0 ]; then
    echo "==> backup: no pre-existing CI/governance surfaces (fresh repo)"
  else
    echo "==> backed up $n pre-existing file(s) -> $BACKUP_DIR"
  fi
}
# Fail CLOSED: if the snapshot cannot be taken, do not write.
backup_existing_surfaces || { echo "install: refusing to modify $TARGET_REPO without a backup" >&2; exit 1; }
# <<< MANDATORY-BACKUP <<<

# Bootstrap creates the canon dirs; --update only touches files the consumer
# already has, so it must NOT litter empty dirs into the clone.
[ "$MODE_UPDATE" = 1 ] || [ "$MODE_REPIN" = 1 ] || mkdir -p .github/workflows .github/ai-review

# >>> FETCH-VALIDATE >>>  (extracted verbatim by tests/test_install.sh — keep
# these markers; the test drives THIS code rather than a copy of it.)
# FT-39: `curl -f` rejects a 4xx/5xx, but a proxy, CDN, or captive portal can
# answer a request with a 200 whose body is EMPTY or an HTML error page. Writing
# that over a canon gate template silently 0-bytes a required check; for the
# pre-commit fragment it makes marker_version() read 1 and freezes every legacy
# consumer's FT-32 refresh (fails open). Every fetched body is validated once,
# here, before it is trusted. An optional 3rd arg names an extended-regex the
# body MUST match (used for the versioned pre-commit marker).
validate_fetched() { # $1 = fetched file  $2 = source name (for messages)  [$3 = required ERE]
  local _f="$1" _src="$2" _need="${3:-}"
  if [ ! -s "$_f" ]; then
    echo "  FAIL  fetched ${_src} is empty (a 0-byte 200 body) — refusing (FT-39)" >&2
    return 1
  fi
  # An HTML error page served 200 (a proxy/CDN/captive-portal splash) opens with
  # an HTML-document tag (`<!DOCTYPE html>`, `<html …>`). Match THAT — not a bare
  # `<`: a canon markdown template can legitimately open with an HTML comment
  # (`pull_request_template.md` starts `<!--`), so a bare-`<` reject would false-
  # fire on it. Inspect only a bounded prefix (whitespace/NUL stripped, lowered)
  # so a pathological large 200 body is never slurped whole into memory.
  local _head
  _head="$(head -c 512 "$_f" 2>/dev/null | tr -d '[:space:]\000' | tr '[:upper:]' '[:lower:]')" || true
  case "$_head" in
    '<!doctype'*|'<html'*|'<head'*|'<body'*|'<title'*)
      echo "  FAIL  fetched ${_src} opens with an HTML-document tag (an error page served 200?) — refusing (FT-39)" >&2
      return 1 ;;
  esac
  if [ -n "$_need" ] && ! grep -qE "$_need" "$_f"; then
    echo "  FAIL  fetched ${_src} is missing its required marker — refusing (FT-39; an empty/wrong body here silently freezes legacy-consumer refresh, FT-32)" >&2
    return 1
  fi
}
# <<< FETCH-VALIDATE <<<

fetch_template() {
  # $1 = source path under install/templates/; $2 = destination path
  local src="$1" dst="$2"
  if ! curl -fsSL "${TEMPLATE_BASE}/${src}" -o "${dst}"; then
    echo "  FAIL  failed to fetch ${TEMPLATE_BASE}/${src}" >&2
    return 1
  fi
  # FT-39: reject an empty/HTML 200 body before it is written over a gate.
  validate_fetched "$dst" "$src" || return 1
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
    # FT-39: an empty/HTML 200 body must never diff-and-replace a good local
    # file (a safe_to_replace surface under --non-interactive would be
    # overwritten with the error page). validate_fetched logs the reason; skip.
    validate_fetched "$fetched" "$ctmpl" || { rm -f "$fetched"; continue; }
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
    if [ "$NONINTERACTIVE" = 1 ]; then
      # Explicit opt-in to the destructive auto-replace of safe_to_replace files.
      if [ "$csafe" = 1 ]; then action="r"; else action="k"; fi
    elif [ ! -t 0 ]; then
      # FT-39: a missing TTY is NOT consent to replace. Inferring
      # --non-interactive from `[ ! -t 0 ]` meant a piped run (`bash <(curl …)
      # --update`) silently overwrote every customized safe_to_replace caller
      # with the canon body. With no TTY and no explicit --non-interactive we
      # cannot prompt, so default to KEEP and tell the operator how to opt in.
      echo "  (no TTY and no --non-interactive — keeping local; re-run with --non-interactive to auto-replace safe_to_replace surfaces)"
      action="k"
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
    # FT-50: `-i.bak … && rm` is portable in-place (adopter machines run this) —
    # bare GNU `sed -i` errors on BSD/macOS sed, which requires a backup suffix.
    # (1) tag-pinned callers: @ci/vX.Y.Z -> @$target. `rm` is a SEPARATE statement,
    #     not `&& rm` — so a sed failure still aborts under `set -e` (loud), and the
    #     backup is cleaned unconditionally.
    sed -i.bak -E "s#(^[[:space:]]*uses:[[:space:]]*vladm3105/aidoc-flow-ci/[^@]+)@ci/v[0-9.]+#\1@${target}#" "$f"
    rm -f "$f.bak"
    # (2) SHA-pinned callers: @<40hex> (optionally trailed by "# ci/vX") -> @$target.
    #     '|' delimiter because the pattern contains '#'. Converts a SHA pin to a
    #     tag pin so --repin covers the whole fleet (audit-trail was historically
    #     SHA-pinned; without this it was silently skipped).
    sed -i.bak -E "s|(^[[:space:]]*uses:[[:space:]]*vladm3105/aidoc-flow-ci/[^@]+)@[0-9a-f]{40}([[:space:]]*# ci/v[0-9.]+.*)?$|\1@${target}|" "$f"
    rm -f "$f.bak"
    if ! git diff --quiet -- "$f" 2>/dev/null; then
      echo "  repinned  $f  (${before:-?} -> @${target})"
      changed=$((changed+1))
    fi
  done
  echo "==> re-pin summary: $changed file(s) bumped to @${target}"
  return 0
}

# --- add-surface -------------------------------------------------------------
#
# THE MISSING THIRD MODE. Bootstrap installs only the `auto_install: true`
# callers; `--update` explicitly never introduces a surface the consumer does
# not already have. So an `auto_install: false` surface — every v3 caller — had
# NO install path at all: not bootstrap, not update, not repin. A release nobody
# can install is not released (aidoc-flow-ci#429).
#
# Why not just flip `auto_install` to true: bootstrap runs on repos that still
# carry the six v2 callers, so auto-installing v3 would give them BOTH — double
# the jobs, two sets of contexts, and the add-new/observe/remove-old sequence
# in docs/MIGRATION_v3.0.0.md silently skipped. Adoption has to be a deliberate
# act, which is what this mode is.
#
# It is GENERAL, not v3-specific: any manifested surface the consumer lacks.
# That matters because the same gap will exist for the next opt-in surface.
add_surface_mode() {
  local vis detected
  # Resolve from the LIVE repo, never from --visibility, and refuse to guess —
  # same rule as update_mode. Picking the wrong variant is how a private repo
  # ends up on ubuntu-latest and queues forever (OPS-0049, D1).
  if ! detected=$(gh repo view "$TARGET_REPO" --json isPrivate --jq '.isPrivate' 2>/dev/null); then
    echo "  FAIL  gh repo view failed for $TARGET_REPO — cannot resolve visibility (refusing to guess)" >&2
    return 1
  fi
  case "$detected" in
    true)  vis="private" ;;
    false) vis="public" ;;
    *)     echo "  FAIL  unexpected isPrivate='$detected' — refusing to guess visibility" >&2; return 1 ;;
  esac
  echo "==> add-surface: resolving templates for visibility=$vis"

  local manifest; manifest=$(mktemp)
  fetch_template "manifest.json" "$manifest" || { rm -f "$manifest"; return 1; }

  local rc=0 added=0 want
  for want in "${ADD_SURFACES[@]}"; do
    local row tmpl replaces exec_bit
    # `path<TAB>resolved_template<TAB>space-separated replaces`. Unknown path
    # yields nothing, which is an ERROR below, not a silent skip.
    row=$(python3 - "$manifest" "$vis" "$want" <<'PYADD'
import sys, json
manifest, vis, want = sys.argv[1], sys.argv[2], sys.argv[3]
m = json.load(open(manifest, encoding="utf-8"))
for f in m["files"]:
    if f["path"] == want:
        tmpl = f.get("visibility_variants", {}).get(vis, f["template"])
        # `replaces` is NEWLINE-joined into one field and split with mapfile by
        # the caller: an unquoted `for r in $replaces` word-splits AND
        # pathname-expands, so a future entry containing a glob metacharacter
        # would match against the consumer's tree.
        # CO-REPLACERS. `links.yml` carries TWO jobs and is replaced JOINTLY —
        # `quick-gates` takes its internal/offline half, `links-external` takes
        # the external half. Modelling that as two independent `replaces` edges
        # made the warning say "do not delete before the new context is green",
        # which reads as "safe to delete after" — and deleting `links.yml` with
        # only `quick-gates` installed silently loses external link checking,
        # with no check reporting anything because nothing produces it.
        # Emit, per replaced path, every surface that claims it.
        co = []
        for r in f.get("replaces") or []:
            claimers = sorted(g["path"] for g in m["files"] if r in (g.get("replaces") or []))
            co.append("%s|%s" % (r, ",".join(claimers)))
        print("\t".join([f["path"], tmpl, "\\n".join(co),
                         "1" if f.get("executable") else "0"]))
        break
PYADD
) || { echo "  FAIL  could not parse manifest.json" >&2; rm -f "$manifest"; return 1; }

    if [ -z "$row" ]; then
      echo "  FAIL  '$want' is not a manifested surface — check the path against install/templates/manifest.json" >&2
      rc=1; continue
    fi
    tmpl=$(printf '%s' "$row" | cut -f2)
    replaces=$(printf '%s' "$row" | cut -f3)
    exec_bit=$(printf '%s' "$row" | cut -f4)

    # NEVER overwrite. Replacing an existing caller is `--update`'s job and its
    # own hazard (FT-9 clobbered customized callers into a runner-self brick).
    # This mode only ever ADDS.
    # `-e` OR `-L`, not `-f`. `[ -f ]` is false for a DIRECTORY at the target, so
    # the run proceeded, `mv` deposited the temp file INSIDE it, and the mode
    # reported "1 file(s) added" having installed nothing — a fail-open in the
    # mode whose whole contract is that you know what it did. `-L` catches a
    # dangling symlink, which `-e` alone does not.
    if [ -e "$WORK_DIR/consumer/$want" ] || [ -L "$WORK_DIR/consumer/$want" ]; then
      echo "  skip      $want (already present — use --update to refresh it, never this)"
      continue
    fi

    # THE DUPLICATE-RUN WARNING. Adding v3 while the v2 callers it replaces are
    # still installed runs both: doubled jobs on a serial self-hosted pool, and
    # two sets of contexts where the migration sequence assumes you add the new
    # one deliberately. Warn, do not refuse — the migration guide's step 3 tells
    # you to run both briefly and observe green before removing the old ones.
    local still="" r
    local -a repl_arr=()
    [ -z "$replaces" ] || mapfile -t repl_arr < <(printf '%b\n' "$replaces")
    local joint=""
    for r in "${repl_arr[@]}"; do
      [ -n "$r" ] || continue
      local rpath="${r%%|*}" claimers="${r#*|}"
      [ -e "$WORK_DIR/consumer/$rpath" ] || continue
      still="$still $rpath"
      # More than one claimer means this old caller is replaced JOINTLY; naming
      # only the one being installed would licence a deletion that drops a check.
      case "$claimers" in
        *,*) joint="$joint
            $rpath is replaced JOINTLY by: ${claimers//,/, } — ALL of them must be
            installed and green before you delete it, or you silently lose whatever
            the missing one covers." ;;
      esac
    done
    if [ -n "$still" ]; then
      echo "  WARN      $want replaces surfaces still installed:$still"
      echo "            Both will run until you remove them. That is EXPECTED during"
      echo "            step 3 of docs/MIGRATION_v3.0.0.md (observe green, then remove)."
      echo "            Do NOT delete them before the new context is green."
      [ -z "$joint" ] || printf '%s\n' "$joint"
    fi

    # RAW curl + validate_fetched, NOT fetch_template — the same shape
    # update_mode uses at :594, and for the same reason: `fetch_template`'s first
    # argument must stay a LITERAL in this file. tests/test_install.sh scrapes
    # every call site and cross-checks the bootstrap set against the manifest, so
    # a variable there disarms that cover for every caller, not just this one.
    # (Caught by that guard on the first draft of this mode.)
    local fetched
    fetched=$(mktemp)
    if ! curl -fsSL "${TEMPLATE_BASE}/${tmpl}" -o "$fetched"; then
      echo "  FAIL  could not fetch ${tmpl} for $want" >&2
      rm -f "$fetched"; rc=1; continue
    fi
    # FT-39: an empty or HTML-200 body must never be written over a gate.
    validate_fetched "$fetched" "$tmpl" || { rm -f "$fetched"; rc=1; continue; }
    substitute_placeholders "$fetched"
    mkdir -p "$(dirname "$WORK_DIR/consumer/$want")"
    if ! mv "$fetched" "$WORK_DIR/consumer/$want"; then
      echo "  FAIL  could not write $want" >&2
      rm -f "$fetched"; rc=1; continue
    fi
    # MODE BIT FROM THE MANIFEST, not from mktemp. `mktemp` creates 0600 and `mv`
    # preserves it, so every added file landed non-readable — and for
    # `scripts/pre_push_check.sh` that is not cosmetic: bootstrap `chmod +x`es it
    # (:988) because pre-commit's `language: script` hook cannot exec it
    # otherwise. Adding it through this mode committed it at 100644 and every
    # clone's canon hook failed, while the mode reported success.
    if [ "$exec_bit" = "1" ]; then chmod 755 "$WORK_DIR/consumer/$want"
    else chmod 644 "$WORK_DIR/consumer/$want"; fi
    echo "  add       $want (from $tmpl)$([ "$exec_bit" = "1" ] && printf ' [executable]')"
    added=$((added + 1))

    # DEPENDENCY: a caller with a LITERAL self-hosted `runs-on:` needs
    # `.github/actionlint.yaml`, or the consumer's own gate rejects it.
    #
    # This is the v2→v3 shape change. Under v2 a private caller passed its labels
    # as a JSON STRING input and the reusable did the `fromJSON`, so actionlint
    # only ever saw an expression and had nothing to validate. v3 callers carry
    # `runs-on: ["self-hosted","ci","ephemeral"]` literally, and actionlint's
    # runner-label rule REJECTS labels it does not know — so `pre_push_check.sh`
    # check 3 fails on every push, in the consumer, with nothing naming the
    # missing config. The manifest entry for that file already said "NEW IN v3 and
    # load-bearing … manifest entry + install.sh fetch" while carrying
    # `auto_install: false`, i.e. it declared a requirement it did not deliver.
    #
    # Pulled as a DEPENDENCY rather than by flipping `auto_install`, deliberately:
    # bootstrap runs on repos that carry the v2 callers and must not gain v3
    # surfaces silently (see this mode's header). The config is inert where it is
    # unused, so arriving alongside the caller that needs it is the narrow fix.
    case "$(grep -E '^[[:space:]]*runs-on:' "$WORK_DIR/consumer/$want" 2>/dev/null || true)" in
      *self-hosted*) ;;
      *) continue ;;
    esac
    if [ -e "$WORK_DIR/consumer/.github/actionlint.yaml" ]; then
      echo "  dep       .github/actionlint.yaml already present (needed by $want)"
      continue
    fi
    local alcfg; alcfg=$(mktemp)
    if ! curl -fsSL "${TEMPLATE_BASE}/actionlint.yaml" -o "$alcfg"; then
      echo "  WARN      could not fetch actionlint.yaml — $want carries a literal self-hosted runs-on:," >&2
      echo "            so the consumer's pre_push_check.sh check 3 will reject it until that config lands." >&2
      rm -f "$alcfg"; continue
    fi
    if ! validate_fetched "$alcfg" "actionlint.yaml"; then rm -f "$alcfg"; continue; fi
    mkdir -p "$WORK_DIR/consumer/.github"
    if mv "$alcfg" "$WORK_DIR/consumer/.github/actionlint.yaml"; then
      chmod 644 "$WORK_DIR/consumer/.github/actionlint.yaml"
      echo "  dep       .github/actionlint.yaml (declares the labels $want selects)"
    else
      echo "  WARN      could not write .github/actionlint.yaml" >&2
      rm -f "$alcfg"
    fi
  done
  rm -f "$manifest"

  echo ""
  echo "==> add-surface summary: $added file(s) added"
  # THIS MODE ARMS NOTHING. Branch protection and rulesets are untouched on
  # purpose: arming a required context before its producer has been observed
  # green is the one step of the migration with no --admin-free exit.
  echo "    Branch protection and rulesets were NOT touched. Next:"
  echo "      1. commit + push, open a PR, and confirm the new job(s) run and pass"
  echo "      2. only then add the context(s) to protection AND rulesets"
  echo "      3. remove the old contexts, then delete the old caller files"
  echo "    Full sequence: docs/MIGRATION_v3.0.0.md"
  return "$rc"
}

if [ "${#ADD_SURFACES[@]}" -gt 0 ]; then
  if add_surface_mode; then add_rc=0; else add_rc=$?; fi
  echo ""
  echo "==> add-surface done (rc=$add_rc). Working copy: $WORK_DIR/consumer"
  exit "$add_rc"
fi

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
#
# PLAN-018 F1: each template is named EXPLICITLY, never derived from
# "${wf}-${VISIBILITY}.yml". Canon ships three distinct naming shapes, not one
# convention, so any derivation is wrong for at least one workflow:
#
#   ai-review    public: workflows/ai-review.yml            private: same
#                (PLAN-013 unified it into one protected template — no variants)
#   composition  public: workflows/composition-public.yml   private: …-private.yml
#   pre-commit   public: workflows/pre-commit.yml           private: …-private.yml
#                (asymmetric — the PUBLIC variant is the bare name)
#
# The old derivation asked for workflows/ai-review-private.yml, deleted at
# ci/v2.2.0: a 404 that killed every cold-start install before config.json,
# CODEOWNERS, CLAUDE.md, pre_push_check.sh, the pre-commit merge, and the labels.
#
# LOAD-BEARING — do not refactor into a TEMPLATES[$wf] lookup or any other form
# that makes fetch_template's first argument a variable. tests/test_install.sh
# extracts the block between the markers below, evaluates it under both
# visibilities with fetch_template stubbed, and cross-checks it against
# manifest.json in BOTH directions: each resolved template must match the
# visibility_variants resolution for its consumer path, and the installed caller
# SET must equal the auto_install:true workflow entries. So adding a caller here
# and flipping its auto_install are one change, and deleting a stanza fails
# rather than silently shipping a cold start without that workflow.
# It also asserts every fetch_template first argument in this file is a literal
# and that no `.github/workflows/` install sits outside the markers — a variable
# argument or a stray call site silently disarms that cover.

# >>> BOOTSTRAP-CALLERS >>>  (extracted verbatim by tests/test_install.sh)
# ai-review — single protected template, identical for both visibilities.
if [ -f ".github/workflows/ai-review.yml" ]; then
  echo "  preserve  .github/workflows/ai-review.yml (already exists — local override)"
else
  fetch_template "workflows/ai-review.yml" ".github/workflows/ai-review.yml" || exit 1
  echo "  add       .github/workflows/ai-review.yml"
fi

# composition — per-visibility variants, both explicitly suffixed.
if [ -f ".github/workflows/composition.yml" ]; then
  echo "  preserve  .github/workflows/composition.yml (already exists — local override)"
elif [ "$VISIBILITY" = "private" ]; then
  fetch_template "workflows/composition-private.yml" ".github/workflows/composition.yml" || exit 1
  echo "  add       .github/workflows/composition.yml (private)"
else
  fetch_template "workflows/composition-public.yml" ".github/workflows/composition.yml" || exit 1
  echo "  add       .github/workflows/composition.yml (public)"
fi

# pre-commit — THE BOOTSTRAP TIER'S REQUIRED-CONTEXT PRODUCER. ASYMMETRIC: the
# PUBLIC variant is the bare name (§16.9).
#
# PLAN-018 F2: installed UNCONDITIONALLY, not gated on --tier. `call / Lint /
# format / security hooks` — emitted by this caller — is a required status check
# on every tier that has required checks at all, and is the bootstrap tier's ONLY
# required context. Without a producer, arming protection pins every PR on
# "Expected — Waiting for status to be reported" forever. TIER defaults to "" and
# the README's documented one-liner passes none, so a tier-gated fix would leave
# the primary documented path undefined. On the umbrella tier (no required checks
# at all) the installed caller is simply advisory — additive, not harmful.
#
# WHY THIS IS STILL pre-commit UNDER v3, AND WHAT MOVES IT (aidoc-flow-ci#481).
# v3 folds three checks into `quick-gates`, so the producer is MEANT to become
# `quick-gates.yml` — but that is two edits, not one: the flag here, and PLAN-026
# §C0 substituting the `quick-gates` context into the four tier templates.
# #441 landed the flag alone. `apply-standards.sh` PUTs the tier file as one whole
# payload, so between the two a cold start installed `quick-gates.yml` while the
# templates still required THIS caller's context — a new repo bricked on arrival,
# with no `--admin` escape on consumer tiers. That is #481, and reverting the flag
# is what closes it.
#
# §C0 CANNOT SIMPLY LAND INSTEAD. Measured 2026-08-16: every consumer that has
# required contexts at all carries `pre-commit.yml` and NONE has
# `quick-gates.yml` — and a re-bootstrap will never give them one, because
# `quick-gates.yml` is `auto_install: false` and this block installs only the
# three callers hardcoded here. (It is NOT a `replaces`-driven skip. Nothing on
# any bootstrap path reads `replaces`; its only reader is the duplicate-run WARN
# in `add_surface_mode`, which installs anyway.) So substituting the templates
# first arms a context the whole fleet lacks a producer for — the same brick from
# the other side. The order is C1–C5 (put quick-gates on the fleet), then §C0 and
# this flag together, as ONE change. Until then quick-gates is adopted
# deliberately: `--add-surface .github/workflows/quick-gates.yml`, per
# docs/MIGRATION_v3.0.0.md.
#
# `tests/test_required_contexts.sh` §5 reds the suite if the bootstrap tier ever
# again requires a context a cold start omits. It cannot see the fleet-ordering
# constraint above — canon cannot read consumer repos — so a green suite is not
# clearance to land §C0.
if [ -f ".github/workflows/pre-commit.yml" ]; then
  echo "  preserve  .github/workflows/pre-commit.yml (already exists — local override)"
elif [ "$VISIBILITY" = "private" ]; then
  fetch_template "workflows/pre-commit-private.yml" ".github/workflows/pre-commit.yml" || exit 1
  echo "  add       .github/workflows/pre-commit.yml (private)"
else
  fetch_template "workflows/pre-commit.yml" ".github/workflows/pre-commit.yml" || exit 1
  echo "  add       .github/workflows/pre-commit.yml (public)"
fi
# <<< BOOTSTRAP-CALLERS <<<

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

# .yamllint.yaml — companion config for the pre-push hook's yamllint check
# (PLAN-015 M4). Without it a consumer that has yamllint installed gets the
# 80-char default, which floods SDD prose YAML with hundreds of line-length
# errors. Preserve if the consumer already tuned one (either extension).
if [ -f ".yamllint.yaml" ] || [ -f ".yamllint.yml" ]; then
  echo "  preserve  .yamllint.yaml (already exists — consumer-tuned)"
else
  fetch_template ".yamllint.yaml" ".yamllint.yaml" || exit 1
  echo "  add       .yamllint.yaml"
fi

# L2 (PLAN-015): the pre-push hook's actionlint + shellcheck checks degrade to
# skipped-with-notice when the tools are absent — 2 of 5 checks silently inert.
# Flag missing tools at install time (non-fatal) so the founder can install them;
# platform instructions are in docs/local-pre-push.md.
_missing_tools=""
command -v shellcheck >/dev/null 2>&1 || _missing_tools="$_missing_tools shellcheck"
command -v actionlint >/dev/null 2>&1 || _missing_tools="$_missing_tools actionlint"
if [ -n "$_missing_tools" ]; then
  echo "  NOTE      pre-push tools not found:${_missing_tools} — those checks will SKIP locally until installed (see docs/local-pre-push.md §5 Prerequisites). CI still enforces them."
fi

# .pre-commit-config.yaml — merge canon hook block idempotently.
# Idempotency key: canonical marker `# CANON: aidoc-flow-ci pre_push_check vN`.
#
# PLAN-018 FT-32 — the marker is VERSIONED so this file is refreshable. Before,
# any marker at all meant no-op forever: bootstrap skipped, `--update` excludes
# this file from the manifest walk, and `--apply` writes no content files — so an
# adopted consumer could NEVER receive a canon change to the fragment, and
# manifest.json's "re-run install.sh to refresh those" was FALSE for it. Now:
#   no marker            → merge (first adoption)
#   marker vN  <  canon  → RE-MERGE (the refresh path; additive + de-duped, so
#                          consumer entries are never clobbered) and stamp vCANON
#   marker vN  >= canon  → no-op preserve (steady state)
# An unversioned legacy marker counts as v1.
# >>> PRECOMMIT-MERGE >>>  (extracted verbatim by tests/test_precommit_refresh.sh
# — keep these markers; the test drives THIS code rather than a copy of it.)
PRECOMMIT_TMP=$(mktemp)
fetch_template "pre-commit-hook-block.yaml" "$PRECOMMIT_TMP" || { rm -f "$PRECOMMIT_TMP"; exit 1; }
CANON_MARK_RE='# CANON: aidoc-flow-ci pre_push_check'
# FT-39: the fragment's entire refresh logic hinges on a versioned marker.
# fetch_template already rejected an empty/HTML body, but a truncated or pre-v2
# fragment would pass that and then make marker_version() read 1 → every legacy
# consumer's refresh silently freezes (FT-32 fails open). Assert the versioned
# marker is present before the file is trusted for the version compare.
validate_fetched "$PRECOMMIT_TMP" "pre-commit-hook-block.yaml" "^${CANON_MARK_RE} v[0-9]+" \
  || { rm -f "$PRECOMMIT_TMP"; exit 1; }
# Marker-version parse, anchored at BOTH ends. Line-start, so an unrelated
# consumer comment that merely mentions `pre_push_check v1` is not read as THEIR
# marker (that would trigger a spurious re-merge on an already-current repo);
# digits-at-end, so a line carrying two versioned mentions cannot produce a
# multi-line capture (`[` would then print `integer expression expected` to the
# operator and mis-compare). Unversioned or absent ⇒ 1.
marker_version() { # $1 = file → prints N
  local _v
  _v="$(grep -m1 -oE "^${CANON_MARK_RE} v[0-9]+" "$1" 2>/dev/null | grep -oE '[0-9]+$' || true)"
  printf '%s' "${_v:-1}"
}
CANON_MARK_LINE="$(grep -m1 -E "^${CANON_MARK_RE}" "$PRECOMMIT_TMP" || echo "$CANON_MARK_RE")"
CANON_MARK_V="$(marker_version "$PRECOMMIT_TMP")"
if [ ! -f ".pre-commit-config.yaml" ]; then
  # Consumer has no pre-commit config — install canon fragment verbatim.
  # (Canon fragment carries the versioned marker at line 1 → re-runs no-op.)
  cp "$PRECOMMIT_TMP" .pre-commit-config.yaml
  echo "  add       .pre-commit-config.yaml (from canon fragment, marker v${CANON_MARK_V})"
elif grep -qE "^${CANON_MARK_RE}" .pre-commit-config.yaml \
     && { _cmv="$(marker_version .pre-commit-config.yaml)"; [ "$_cmv" -ge "$CANON_MARK_V" ]; }; then
  echo "  preserve  .pre-commit-config.yaml (canon marker v${_cmv} >= canon v${CANON_MARK_V} — no-op)"
else
  if grep -qE "^${CANON_MARK_RE}" .pre-commit-config.yaml 2>/dev/null; then
    echo "  refresh   .pre-commit-config.yaml (canon marker v${_cmv:-1} < canon v${CANON_MARK_V} — re-merging the canon block; FT-32)"
  fi
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
  MERGE_OUT=$(mktemp)
  if python3 - "$PRECOMMIT_TMP" "$MERGE_TMP" "$yaml_lib" "$CANON_MARK_LINE" <<'PYEOF' > "$MERGE_OUT" ; then
import sys

canon_path, out_path, yaml_lib = sys.argv[1], sys.argv[2], sys.argv[3]
canon_marker = sys.argv[4] if len(sys.argv) > 4 else "# CANON: aidoc-flow-ci pre_push_check"

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

# A pre-commit config must be a MAPPING. A top-level list (or scalar) otherwise
# reached `consumer.get(...)` below and died with a raw AttributeError before any
# of the structural guards further down could report it.
if not isinstance(consumer, dict):
    print(f"  FAIL  .pre-commit-config.yaml must be a YAML mapping, got "
          f"{type(consumer).__name__} — inspect the file", file=sys.stderr)
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
#
# De-dup by repo URL, NOT whole-entry structural equality (PLAN-018 F3). Canon
# now ships a third-party entry (pre-commit-hooks) as well as `repo: local`, and
# an adopter who already uses that repo at a DIFFERENT rev is structurally
# unequal — so the old rule appended a second `repos:` entry for the same repo.
# NOTE: pre-commit does NOT reject that (verified on 4.5.1: duplicate URLs at
# different revs, and duplicate hook ids, all give validate-config rc=0 and run).
# The de-dup is for coherence, not validity — two entries for one repo at
# different revs is confusing and runs the hook twice. On a URL collision the consumer's
# entry (and their rev) is kept and the collision is REPORTED, listing the canon
# hook ids they may be missing. Silently merging hook lists would overwrite a
# deliberate consumer rev; silently skipping would hide that a canon-required
# hook never arrived.
#
# `local` and `meta` are PSEUDO-repos, not identities. pre-commit permits any
# number of them (verified: two `- repo: local` blocks give
# `validate-config` rc=0 and both hooks run), and most consumers already have
# one or more. Keying de-dup on them would treat the consumer's own local block
# as a collision and never install canon's `aidoc-flow-pre-push` hook — silently
# dropping the OPS-0069 audit-trail check. So they are exempt from URL keying and
# de-dup by HOOK ID instead: a consumer missing `aidoc-flow-pre-push` still
# receives it, one that already carries it gets no duplicate. (Before FT-32 that
# drop was permanent — the marker made every later run a no-op. A version bump
# now re-merges, but only ADDITIVELY: an existing hook id is left as-is, which is
# what preserves a consumer's `pre_push_check_<repo>.sh` wrapper entry.)
PSEUDO_REPOS = ('local', 'meta')
consumer_repos = consumer.setdefault('repos', [])
collisions = []
skipped_hooks = []  # FT-44: canon local hooks the consumer has by id but with a changed body
try:
    if not isinstance(consumer_repos, list):
        raise TypeError(f"'repos' must be a list, got {type(consumer_repos).__name__}")
    existing_by_url = {}
    for r in consumer_repos:
        if isinstance(r, dict) and isinstance(r.get('repo'), str):
            existing_by_url.setdefault(r['repo'], r)
    for canon_repo in canon.get('repos', []):
        url = canon_repo.get('repo') if isinstance(canon_repo, dict) else None
        if not isinstance(url, str):
            continue
        if url in PSEUDO_REPOS:
            # Append only the canon hooks whose `id` the consumer does not already
            # have. Structural equality alone (the B2 form) is right for a FIRST
            # adoption but DUPLICATES the hook on an FT-32 refresh: a legacy or
            # locally-customized `aidoc-flow-pre-push` is structurally unequal to
            # canon's, so canon's copy got appended alongside it. Filtering by id
            # keeps B2's guarantee (a consumer missing the hook still gets it)
            # without duplicating one they already carry.
            # Map the consumer's local hook id -> its dict (local hooks live in
            # pseudo-repo entries), so we can tell "missing" from "present but
            # changed". setdefault keeps the FIRST occurrence, matching how
            # pre-commit resolves a duplicated id.
            consumer_hooks_by_id = {}
            for r in consumer_repos:
                if isinstance(r, dict) and r.get('repo') in PSEUDO_REPOS:
                    for h in (r.get('hooks') or []):
                        if isinstance(h, dict) and h.get('id'):
                            consumer_hooks_by_id.setdefault(h['id'], h)
            have_ids = set(consumer_hooks_by_id)
            missing_hooks = [h for h in (canon_repo.get('hooks') or [])
                             if isinstance(h, dict) and h.get('id') not in have_ids]
            if missing_hooks:
                blk = dict(canon_repo); blk['hooks'] = missing_hooks
                consumer_repos.append(blk)
            # FT-44: a canon local hook whose id the consumer HAS but whose body
            # DIFFERS is intentionally NOT clobbered (the refresh is additions-only,
            # preserving a customized wrapper), but it must be REPORTED — else the
            # summary prints a clean "canon block appended" and the operator never
            # learns canon shipped a changed hook their config still overrides.
            # Most-likely future case: a bumped `aidoc-flow-pre-push`.
            for h in (canon_repo.get('hooks') or []):
                if not (isinstance(h, dict) and h.get('id') in have_ids):
                    continue
                # Use `not (a == b)`, NOT `a != b`: ruamel's CommentedMap (the
                # preferred backend) overrides `__eq__` order-INsensitively but
                # inherits an order-SENSITIVE `__ne__` from OrderedDict, so `!=`
                # would falsely flag a key-reordered but content-identical hook as
                # changed — a spurious WARN on healthy configs.
                if not (h == consumer_hooks_by_id.get(h.get('id'))):
                    skipped_hooks.append(
                        f"  WARN  .pre-commit-config.yaml keeps your {h.get('id')!r} hook "
                        f"(in {url!r}) — canon ships a MODIFIED version; your copy is preserved "
                        f"(additions-only), so canon's change stays UNAPPLIED until merged by hand.")
            continue
        if url not in existing_by_url:
            consumer_repos.append(canon_repo)
            existing_by_url[url] = canon_repo
            continue
        if canon_repo == existing_by_url[url]:
            continue  # already exactly canon — nothing to say
        have = {h.get('id') for h in (existing_by_url[url].get('hooks') or []) if isinstance(h, dict)}
        want = {h.get('id') for h in (canon_repo.get('hooks') or []) if isinstance(h, dict)}
        missing = sorted(i for i in (want - have) if i)
        detail = f"missing canon hook id(s): {', '.join(missing)}" if missing else "hook ids all present"
        # !r on every consumer-controlled value: YAML double-quoted scalars
        # process escapes, so a config carrying \e[2K\r could rewrite the line
        # the operator reads. repr() renders those inert.
        collisions.append(
            f"  WARN  .pre-commit-config.yaml already declares {url!r} "
            f"(kept your entry, rev={existing_by_url[url].get('rev', 'n/a')!r}; canon ships "
            f"rev={canon_repo.get('rev', 'n/a')!r}) — {detail}")
except Exception as e:
    # Same actionable shape as the load() failures above, not a raw traceback.
    print(f"  FAIL  .pre-commit-config.yaml structure error: {e}", file=sys.stderr)
    sys.exit(1)

for line in collisions:
    print(line, file=sys.stderr)
for line in skipped_hooks:
    print(line, file=sys.stderr)
# Machine-readable for the shell, so the summary line cannot claim a clean
# append when a collision suppressed part of the canon block, or when a canon
# local hook was kept-but-changed (FT-44).
if collisions:
    print(f"COLLISIONS={len(collisions)}")
if skipped_hooks:
    print(f"SKIPPED_HOOKS={len(skipped_hooks)}")

# Dump to a buffer first so the consumer's OWN copy of the marker can be dropped.
# ruamel round-trips the leading comment, so without this a refreshed config
# accumulates one stale `# CANON:` line per refresh (v1, then v1+v2, ...). The
# shell reads the version with `grep -m1`, so behaviour stayed correct, but the
# litter is permanent and misreads as "adopted twice".
import io
_buf = io.StringIO()
dump(consumer, _buf)
_body = "".join(l for l in _buf.getvalue().splitlines(keepends=True)
                if not l.startswith("# CANON: aidoc-flow-ci pre_push_check"))

with open(out_path, 'w') as f:
    # Stamp CANON'S marker line (passed in as argv[4]) — not a hardcoded string.
    # On a refresh this REPLACES the consumer's stale vN with canon's, which is
    # what makes the next run a no-op instead of re-merging forever (FT-32).
    f.write(canon_marker.rstrip("\n") + "\n")
    f.write(_body)
PYEOF
    mv "$MERGE_TMP" .pre-commit-config.yaml
    # Honest summary: a URL collision means part of the canon block was NOT
    # appended (the consumer's entry was kept). Saying "canon block appended"
    # in that case reports success for work that did not happen — and the WARN
    # explaining it goes to stderr, which an operator reading stdout may miss.
    if grep -qE '^(COLLISIONS|SKIPPED_HOOKS)=' "$MERGE_OUT"; then
      # `|| true`: under `set -euo pipefail` a non-matching grep would fail the
      # pipeline (only ONE of the two signals may be present) and abort before the
      # summary prints. Empty → the ${:-0} fallbacks below render it 0.
      _ncol="$(grep -oE '^COLLISIONS=[0-9]+' "$MERGE_OUT" | cut -d= -f2 || true)"
      _nskip="$(grep -oE '^SKIPPED_HOOKS=[0-9]+' "$MERGE_OUT" | cut -d= -f2 || true)"
      echo "  merge     .pre-commit-config.yaml (PARTIAL — ${_ncol:-0} repo collision(s), ${_nskip:-0} modified-hook skip(s); your entries kept, see WARN above; default_install_hook_types upgraded if needed; ${yaml_lib}-backed)"
      # The marker is stamped even on a PARTIAL merge — it has to be, or every
      # later run would re-merge, re-WARN and never converge. The cost is that
      # the file then LOOKS current while the collided canon lines are still
      # missing, so say so here: this is the operator's only notice, and the
      # residual is exactly what the rollout worklist is for (CI-0013).
      echo "            NOTE  marker stamped v${CANON_MARK_V} — install.sh will NOT revisit this file. The canon lines named in the WARN(s) above stay UNAPPLIED until merged by hand."
      echo "                  The refresh delivers ADDITIONS only (new repo entries; new hook ids in canon's 'local' block). A rev bump, or a new hook id inside a repo you already declare, is REPORTED — never applied."
    else
      echo "  merge     .pre-commit-config.yaml (canon block appended; default_install_hook_types upgraded if needed; ${yaml_lib}-backed)"
    fi
    rm -f "$MERGE_OUT"
  else
    rm -f "$MERGE_TMP" "$PRECOMMIT_TMP" "$MERGE_OUT"
    echo "  FAIL      .pre-commit-config.yaml merge failed — inspect manually" >&2
    exit 1
  fi
fi
rm -f "$PRECOMMIT_TMP"
# <<< PRECOMMIT-MERGE <<<

# PLAN-018 FT-31 — the zero-hook detector. Verify the .pre-commit-config.yaml we
# just produced actually selects a hook at the stage the `pre-commit` reusable
# runs; a config with only pre-push hooks yields a green REQUIRED check that
# inspects nothing (F3). Advisory, not fatal: the config is installed and the
# rest of the bootstrap is unaffected, so a vacuous result is surfaced as a
# prominent warning rather than aborting — the operator needs to see it, but it
# does not undo a working install.
#
# The detector is FETCHED (like a template), not assumed local: under the
# documented `bash <(curl …)` one-liner install.sh has no sibling file on disk.
# Fetching keeps ONE source of the check that the wizard + release checklist also
# run. A fetch failure just skips the advisory — it must never fail a working
# install over a belt-and-suspenders check.
if [ -f ".pre-commit-config.yaml" ]; then
  _DETECTOR_TMP=$(mktemp)
  if curl -fsSL "${TEMPLATE_BASE%/templates}/check-precommit-hooks.sh" -o "$_DETECTOR_TMP" 2>/dev/null; then
    # FT-39 APPLIES HERE TOO, and it was skipped. `curl -f` rejects a 4xx/5xx,
    # but a proxy, CDN or captive portal answers 200 with an HTML body — and this
    # body is EXECUTED. An empty or HTML file `bash`es to rc 0 (or a parse error),
    # so the detector silently became a no-op and the advisory NEVER fired: a
    # vacuous pre-commit gate would ship unreported, which is precisely F3, the
    # defect this check exists to catch. Validate before executing, exactly as
    # `fetch_template` does for every template.
    if validate_fetched "$_DETECTOR_TMP" "check-precommit-hooks.sh" '^#!.*(bash|sh)'; then
      # Capture rc — warn ONLY on 1 (genuinely zero hooks). rc 2 means the check
      # could not determine (no PyYAML / unparseable), which is not the same as
      # "zero" and must not raise a false vacuous-config alarm.
      bash "$_DETECTOR_TMP" ".pre-commit-config.yaml" >/dev/null 2>&1 && _drc=0 || _drc=$?
      if [ "${_drc:-0}" -eq 1 ]; then
        echo "  ⚠️  WARN  .pre-commit-config.yaml selects ZERO hooks at the pre-commit stage —" >&2
        echo "           the required 'call / Lint / format / security hooks' check would inspect" >&2
        echo "           nothing. Run: install/check-precommit-hooks.sh .pre-commit-config.yaml" >&2
      elif [ "${_drc:-0}" -eq 2 ]; then
        # rc 2 was DISCARDED entirely — `>/dev/null 2>&1` and no branch — so an
        # environment that cannot run the check at all was indistinguishable from
        # a clean pass. "Could not determine" is not "fine"; say which it was.
        echo "  ⚠️  WARN  could not determine whether .pre-commit-config.yaml selects a" >&2
        echo "           pre-commit-stage hook (no PyYAML, or the config did not parse)." >&2
        echo "           The vacuous-gate check (FT-31/F3) did NOT run. Re-run by hand:" >&2
        echo "           install/check-precommit-hooks.sh .pre-commit-config.yaml" >&2
      fi
    else
      echo "  ⚠️  WARN  the zero-hook detector fetched an empty or non-script body —" >&2
      echo "           skipping the FT-31 vacuous-gate check rather than executing it." >&2
    fi
  fi
  rm -f "$_DETECTOR_TMP"
fi

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
echo "==> done. Next steps (founder) — SECRETS BEFORE THE PR, or the first PR's ai-review gate fails:"
echo "    1. Inspect bootstrapped files: cd $WORK_DIR/consumer && git diff"
echo "       Pre-write backup of everything that already existed (FT-57):"
echo "         $BACKUP_DIR"
echo "       Restore one file:  cp \"$BACKUP_DIR/<path>\" $WORK_DIR/consumer/<path>"
# PLAN-018 F4 — runner-pool probe, visibility-INDEPENDENT. The ai-review
# template is visibility-uniform (PLAN-013) and pins the self-hosted pool for
# PUBLIC repos too, so a public adopter with no pool gets permanently-queued
# trust/review jobs just like a private one. GitHub's timeout-minutes starts at
# job START, so a never-started (Queued) job never times out — the checks sit
# pending with no error anywhere. Gating this probe on VISIBILITY=private would
# reproduce exactly the fork-code-on-self-hosted anti-pattern the AI-flow
# routing avoids. Output only: install.sh writes to no other repo.
echo "    2. Runner pool — REQUIRED for the AI-flows on BOTH visibilities (the ai-review"
echo "       review job pins the self-hosted pool even on public repos):"
if command -v "${GH:-gh}" >/dev/null 2>&1; then
  _runners="$("${GH:-gh}" api "repos/$TARGET_REPO/actions/runners" --jq '[.runners[]|select(.status=="online")|[.labels[].name]|join(",")]|join(" | ")' 2>/dev/null || echo '')"
  # CI-0033 §27: substring tests via `case` — no fork, no pipeline status to
  # invert, `grep -F` semantics from the quoted expansion. The decision this
  # makes is whether to tell the operator their AI-flow jobs will sit Queued
  # forever, so a false negative here is a silently mis-provisioned repo.
  # `gh --jq` prints a STRING result RAW — no quotes in the haystack — so match
  # on comma/pipe token boundaries. A quoted needle never matches; a bare `ci`
  # would also match `ci-runner`.
  _rl=",${_runners//[ |]/,},"
  if [[ "$_rl" == *,ci,* && "$_rl" == *,ephemeral,* ]]; then
    echo "         ✅ online ci/ephemeral pool: $_runners"
  else
    echo "         🔴 NO online ci/ephemeral pool — every AI-flow job will sit Queued forever"
    echo "            (timeout-minutes never fires on a job that never starts). Register the pool per"
    echo "            docs/runners.md §2/§3 (templates: install/templates/runner/). Do NOT use ubuntu-latest."
  fi
else
  echo "         ⚠️  could not probe (gh unavailable) — confirm an online ci/ephemeral pool exists;"
  echo "            without it every AI-flow job sits Queued forever. docs/runners.md §2/§3."
fi
echo "    3. Add secrets to the consumer NOW (the ai-review gate hard-fails without them):"
echo "         - APP_REVIEWER_1_ID + APP_REVIEWER_1_KEY   (reviewer GitHub App)"
echo "         - LLM_URL + LLM_API_KEY (ai-review proxy; REQUIRED since ci/v2.0.0)"
echo "       You must already operate a reachable LiteLLM proxy — see docs/AI_CI_DEPLOYMENT.md §1."
# PLAN-018 F4 — the LiteLLM HTTP flag. llm_client.py hard-fails unless the
# proxy scheme is HTTPS or litellm_allow_insecure_http is set, and the flag
# ships COMMENTED OUT in the ai-review caller template. The workspace's only
# proxy is HTTP on the docker bridge (172.17.0.1), so an adopter of it needs the
# flag uncommented in .github/workflows/ai-review.yml. install.sh does NOT
# uncomment it: ai-review.yml is safe_to_replace, so a later
# --update --non-interactive would silently re-comment it and the gate would go
# red — a breaking regression. This is operator-applied, by hand, deliberately."
echo "       If your proxy is HTTP (e.g. the docker-bridge proxy at 172.17.0.1), UNCOMMENT"
echo "         litellm_allow_insecure_http: true"
echo "       in .github/workflows/ai-review.yml — the client hard-fails on a non-HTTPS URL without it."
echo "    4. Set vars.APP_REVIEWER_1_BOT_ID = 294948438 (App-global; do NOT wait for a first review —"
echo "       until it is set, composition runs INERT and enforces nothing)."
echo "    5. Commit + push + open the adoption PR on the consumer."
echo "    6. SERVER-SIDE STANDARDS — verified now against tier ${TIER:-<none>} (files installed ≠ standards on):"
if verify_standards "$TIER" "$TARGET_REPO"; then vrc=0; else vrc=$?; fi
case "$vrc" in
  0) echo "       ✅ verified clean — branch protection + settings match the tier template." ;;
  1) echo "       ⚠️  NOT APPLIED — drift or missing branch protection (above). Arm per docs/BRANCH_PROTECTION.md (tier table + arming) + the fleet arming runbook BEFORE relying on the gate." ;;
  2) echo "       ⚠️  COULD NOT VERIFY — gh unauthenticated/missing tool, or the token lacks admin scope to read branch protection. Re-run: install.sh $TARGET_REPO --verify-standards --tier <tier> with an authenticated admin-scoped gh." ;;
  *) echo "       apply branch protection: docs/BRANCH_PROTECTION.md (tier table + arming)." ;;
esac
echo "    7. (Cleanup, your choice) rm -rf $WORK_DIR"
echo ""
echo "    Full dependency-ordered playbook + a preflight that audits all of the above:"
echo "      docs/AI_CI_DEPLOYMENT.md   +   install/deploy-ci-wizard.sh preflight <owner/repo>"
