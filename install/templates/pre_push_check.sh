#!/usr/bin/env bash
# aidoc-flow-ci canon pre_push_check.sh — run local validation before push
# so mechanical issues don't burn a long-running remote ai-review round.
# Wired via `.pre-commit-config.yaml` `default_install_hook_types:
# [pre-commit, pre-push]` per PLAN-002 §4.2; safe to run by hand:
# `scripts/pre_push_check.sh`
#
# CANONICAL SCOPE (per PLAN-002 §4.1):
#   1. markdownlint (skipped-with-notice if not installed)
#   2. yamllint (skipped-with-notice if not installed)
#   3. actionlint on .github/workflows/*.yml (skipped-with-notice if absent)
#   4. shellcheck (skipped-with-notice if not installed)
#   5. OPS-0069 audit-trail phrase check (mandatory; scans commit range)
#
# Repo-specific extra checks (e.g., verified-planning `check_plan.py`,
# operations classify-parity) live in a consumer-side wrapper
# `scripts/pre_push_check_<repo>.sh` that RUNS this canon as a subprocess (never
# `source` — it exits) and OR-accumulates its rc, never overwriting it. §14.1.
#
# OPS-0069 says: this hook does NOT — and cannot — perform the mandatory
# multi-agent SELF-REVIEW for you. That is an agent step (dispatch the
# diff-class-matched sub-agents and fold their findings). The hook
# requires a proof-of-dispatch AUDIT-TRAIL PHRASE in one of the pushed
# commits' messages — a paper trail, not a review substitute.
#
# NO env-var escape hatch (matches OPS-0069 removal of
# SKIP_LOCAL_AI_REVIEW). Only bypass path: `git push --no-verify` (git
# primitive; caught by CI belt-and-suspenders `audit-trail-check.yml`).
#
# `set -uo pipefail` (NOT -e) — the rc accumulator pattern below depends
# on per-check failures being non-fatal so all checks run per push.

set -uo pipefail

# M1 (code-review fold): fail-fast on bash <4. macOS ships bash 3.2 as
# /bin/bash (GPLv3 avoidance); mapfile requires bash 4+. Without this
# guard the script limps with empty arrays + silent audit-trail failure.
if (( BASH_VERSINFO[0] < 4 )); then
  echo "::error::pre_push_check.sh requires bash 4+ (found ${BASH_VERSION:-unknown})." >&2
  echo "::error::On macOS the default /bin/bash is 3.2. Install a newer bash (e.g., 'brew install bash') and ensure it precedes /bin/bash on PATH." >&2
  exit 2
fi

# M2 (code-review fold): script-branded error on non-git-repo invocation
# so the operator sees the source of the exit-2 (not a naked git error).
toplevel="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "::error::pre_push_check.sh must run inside a git working tree." >&2
  exit 2
}
cd "$toplevel" || exit 2

# --- PLAN-028 B3: the PROMOTION push ------------------------------------
# The bug this closes: `git push origin dev:staging` from a current
# `dev` produces an EMPTY commit range, and an empty range is a HARD FAILURE
# below (#432). So canon's own mandatory gate refused EVERY promotion the
# branching standard prescribes, and the failure message's remedy — amend a
# commit — could not clear it. A gate that cannot be satisfied is not a gate.
#
# THIS IS NOT A BYPASS, and the distinction is the whole design. A promotion
# pushes NO new content: every commit already exists on the integration branch,
# where this same gate ran on the way in. So the phrase check has nothing to
# check and the linters have no files — asserting either would be a lie. What
# IS checkable is that the promotion is what it claims to be, and all three
# conditions below must hold:
#
#   1. the target is a branch the repo DECLARED as a promotion branch;
#   2. HEAD is exactly the integration branch's REMOTE tip — so the content
#      being promoted is provably the reviewed, already-pushed content and not
#      a local commit riding along;
#   3. the target's remote tip is an ANCESTOR of HEAD — a true fast-forward.
#
# Fail any one and this refuses, with the remedy that actually clears it.
#
# The hook path never reaches here: pre-commit wires this entry with
# `pass_filenames: false` and passes no arguments, so an unopted repo runs the
# identical script it ran before. Arguments are parsed strictly so a typo
# surfaces instead of silently running the normal path.
PROMOTE_TARGET=""
while [ $# -gt 0 ]; do
  case "$1" in
    --promote)
      PROMOTE_TARGET="${2:-}"
      [ -n "$PROMOTE_TARGET" ] || { echo "::error::pre_push_check: --promote requires a target branch (e.g. --promote staging)" >&2; exit 2; }
      shift 2 ;;
    -h|--help)
      echo "usage: pre_push_check.sh [--promote <target-branch>]"
      echo "  (no arguments) validate the pending push: linters + the OPS-0069 audit-trail phrase"
      echo "  --promote <b>  validate a FAST-FORWARD promotion push into <b> (PLAN-028)"
      exit 0 ;;
    -*)
      echo "::error::pre_push_check: unknown option '$1' (see --help)" >&2; exit 2 ;;
    *)
      # POSITIONAL args are IGNORED, deliberately. git invokes a pre-push hook
      # as `hook <remote> <url>`, so a consumer who symlinks this script
      # straight into `.git/hooks/pre-push` — a shape that worked before this
      # parser existed — would otherwise have EVERY push fail with
      # `unknown argument 'origin'`. Only unrecognised OPTIONS are refused.
      shift ;;
  esac
done

# Reads `.github/aidoc-ci.json` once. Sets PROMO_DECL (1 if this repo declares a
# promotion model), PROMO_INTEGRATION, and PROMO_LIST (space-separated).
PROMO_DECL=0
PROMO_INTEGRATION=""
PROMO_LIST=""
promotion_decl_resolve() {
  local decl=".github/aidoc-ci.json" model
  [ -f "$decl" ] || return 0
  if ! command -v jq >/dev/null 2>&1; then
    # Say what is actually wrong. Falling through to "not a declared promotion
    # branch" sent the reader to edit a file that is already correct.
    echo "::error::pre_push_check: $decl exists but jq is not installed, so this repo's branching declaration cannot be read." >&2
    echo "::error::  Install jq, or push without the promotion gate at your own discretion." >&2
    exit 2
  fi
  if ! jq -e 'type == "object" and (.branching | type) == "object"' "$decl" >/dev/null 2>&1; then
    echo "::error::pre_push_check: $decl is present but is not a readable object with a .branching object — fix it or delete it." >&2
    exit 2
  fi
  if ! jq -e '["$schema","_note","version","branching"] as $top | ["_note","model","integration_branch","protected_branches","promotion_branches"] as $br
    | ((keys_unsorted - $top) | length) == 0
    and (.version == 1)
    and ((.branching | keys_unsorted - $br) | length) == 0' "$decl" >/dev/null 2>&1; then
    # AIDOC-CI-DECL-VALIDATE — keys + version. The schema declares
    # `additionalProperties: false` at both levels and requires `version`, and no
    # reader enforced any of it. `"promotion_branchs": []` (one transposed letter)
    # read as "not set", took the model default, and applied enforce_admins:false to
    # the two branches the operator was opting OUT of. jq, not jsonschema: this runs
    # on consumer machines and runner images that ship neither. Key lists are pinned
    # to schemas/aidoc-ci-v1.schema.json by tests/test_scripts.sh. NOT full schema
    # validation — no types, enums or maxItems; it covers unknown keys + version.
    echo "::error::pre_push_check: $decl has unknown keys or a bad version." >&2
    echo '::error::  Allowed top-level: $schema, _note, version, branching (version must be 1).' >&2
    echo "::error::  Allowed under .branching: _note, model, integration_branch, protected_branches, promotion_branches." >&2
    echo "::error::  A MISSPELLED key is silently ignored by every reader and takes the model DEFAULT instead." >&2
    exit 2
  fi
  model="$(jq -r '.branching.model // "single-branch"' "$decl")"
  PROMO_INTEGRATION="$(jq -r '.branching.integration_branch // empty' "$decl")"
  if [ -z "$PROMO_INTEGRATION" ]; then
    # NEVER a literal `dev` — the model's name is not the branch's name. Same
    # resolution rule as every other reader: declaration, then default branch.
    PROMO_INTEGRATION="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"
    [ -n "$PROMO_INTEGRATION" ] || PROMO_INTEGRATION=main
  fi
  # An explicit list wins — including an explicit EMPTY one, which is an opt-out.
  if jq -e '(.branching | has("promotion_branches")) and (.branching.promotion_branches != null)' "$decl" >/dev/null 2>&1; then
    PROMO_LIST="$(jq -r '.branching.promotion_branches // [] | join(" ")' "$decl")"
    PROMO_DECL=1
  elif [ "$model" = "dev-staging-main" ]; then
    PROMO_LIST="staging main"
    PROMO_DECL=1
  fi
  return 0
}

# TRUE only when this repo declares a promotion model AND HEAD is exactly the
# integration branch's already-pushed remote tip. Both halves are required: the
# first keeps every undeclared repo on the unchanged hard-fail path, and the
# second is what makes "nothing here is unverified" a fact rather than an
# assumption — content that exists only locally moves HEAD off origin's tip.
promo_head_sha=""
promotion_shaped_push() {
  promotion_decl_resolve
  [ "$PROMO_DECL" -eq 1 ] || return 1
  local int_sha
  int_sha="$(git rev-parse --verify --quiet "refs/remotes/origin/${PROMO_INTEGRATION}")" || return 1
  promo_head_sha="$(git rev-parse --verify HEAD 2>/dev/null)" || return 1
  [ "$promo_head_sha" = "$int_sha" ] || return 1
  return 0
}

promotion_is_declared_target() {
  local t="$1" b
  for b in $PROMO_LIST; do [ "$b" = "$t" ] && return 0; done
  return 1
}

if [ -n "$PROMOTE_TARGET" ]; then
  promotion_decl_resolve
  promo_ok=0
  integration="$PROMO_INTEGRATION"
  [ "$PROMO_DECL" -eq 1 ] && promotion_is_declared_target "$PROMOTE_TARGET" && promo_ok=1
  if [ "$promo_ok" -ne 1 ]; then
    echo "::error::pre_push_check: '$PROMOTE_TARGET' is not a declared promotion branch of this repo." >&2
    echo "::error::  Promotion is opt-in. Declare it in .github/aidoc-ci.json:" >&2
    echo "::error::    \"branching\": { \"model\": \"dev-staging-main\", \"promotion_branches\": [\"staging\", \"main\"] }" >&2
    echo "::error::  Without that declaration this repo has no promotion path and a normal push is the only route." >&2
    exit 1
  fi

  head_sha="$(git rev-parse --verify HEAD)"
  int_ref="refs/remotes/origin/${integration}"
  if ! int_sha="$(git rev-parse --verify --quiet "$int_ref")"; then
    # Offline by design (the hook has no network on the push path), so this is
    # a stale-clone report, not a lookup this script can perform for you.
    echo "::error::pre_push_check: $int_ref is not in this clone, so the promotion source cannot be verified." >&2
    echo "::error::  Run: git fetch origin ${integration}" >&2
    exit 1
  fi
  if [ "$head_sha" != "$int_sha" ]; then
    echo "::error::pre_push_check: HEAD is not the tip of origin/${integration}, so this is NOT a promotion." >&2
    echo "::error::    HEAD              $head_sha" >&2
    echo "::error::    origin/${integration}  $int_sha" >&2
    echo "::error::  A promotion moves ALREADY-REVIEWED content that is already on the integration" >&2
    echo "::error::  branch. Commits that exist only here have never been through this gate, and" >&2
    echo "::error::  promoting them would carry them past it. Push them as a normal PR instead," >&2
    echo "::error::  or fetch and reset: git fetch origin ${integration} && git checkout ${integration} && git reset --hard origin/${integration}" >&2
    exit 1
  fi
  tgt_ref="refs/remotes/origin/${PROMOTE_TARGET}"
  if tgt_sha="$(git rev-parse --verify --quiet "$tgt_ref")"; then
    if ! git merge-base --is-ancestor "$tgt_sha" "$head_sha"; then
      echo "::error::pre_push_check: origin/${PROMOTE_TARGET} is NOT an ancestor of HEAD — this push is not a fast-forward." >&2
      echo "::error::    origin/${PROMOTE_TARGET}  $tgt_sha" >&2
      echo "::error::  ${PROMOTE_TARGET} holds a commit that ${integration} does not. The usual cause is a" >&2
      echo "::error::  release-prep or hotfix merge made directly on the target. Back-merge it into" >&2
      echo "::error::  ${integration} first — a forced promotion would discard it." >&2
      exit 1
    fi
    # Say that this is measured against a LOCAL cache. The hook has no network
    # on the push path, so origin/<target> may be stale. It is stale in the safe
    # direction (the server rejects a genuine non-fast-forward), but the word
    # VERIFIED must not imply a fresh read.
    ff_note="fast-forward from ${tgt_sha} (against the last-fetched tip of origin/${PROMOTE_TARGET}; offline — run 'git fetch' first if in doubt)"
  else
    ff_note="target branch does not exist yet — the first push creates it (trivially a fast-forward)"
  fi

  echo "pre_push_check: PROMOTION ${integration} -> ${PROMOTE_TARGET}"
  echo "  VERIFIED: '${PROMOTE_TARGET}' is a declared promotion branch"
  echo "  VERIFIED: HEAD == origin/${integration} (${head_sha}) — the content is already reviewed and pushed"
  echo "  VERIFIED: ${ff_note}"
  echo "  NOT CHECKED, and deliberately so: the OPS-0069 phrase and the mechanical"
  echo "  linters. A promotion introduces NO new commit and NO changed file, so"
  echo "  both ran on this exact content on its way into ${integration}."
  echo "pre_push_check: PROMOTION OK"
  exit 0
fi

# --- push range ---
# ONE resolution, two consumers: the linters' file range (`BASE`...HEAD) and the
# OPS-0069 phrase range (`commit_range`). These were computed independently, and
# the canon and template copies of this script drifted apart on the first while
# the second stayed in sync, undetected for the life of the divergence (#477).
#
# base = the already-pushed point (@{upstream}) so the mechanical linters see
# only what THIS push ADDS — not every file that differs from main. PLAN-015 M3:
# merge-base-with-main re-linted every pre-existing branch commit on every push,
# so a push that touched only file A was blocked by stale lint on files B/C from
# earlier commits. Fall back to merge-base with origin/main on the FIRST push
# (no upstream yet), then local main, then the ROOT COMMIT for a fresh repo.
#
# SCOPE NOTE, so the next reader does not have to re-derive it: this range
# describes the CHECKED-OUT branch, not necessarily the refs being pushed.
# `git push origin feat` from an up-to-date `main` produces an EMPTY range while
# unreviewed commits are in flight, and a multi-ref push is not described at all.
# That is why an empty range below exits NON-ZERO. Treating it as "nothing to
# gate" and exiting 0 was measured to let an unreviewed commit reach a remote.
# Reading the pushed refs is the real fix and is tracked separately (#432).
# shellcheck disable=SC1083  # @{upstream} is git ref-syntax, not shell brace expansion
upstream_ref="$(git rev-parse --abbrev-ref --symbolic-full-name @{upstream} 2>/dev/null || echo '')"
# Resolved offline: the hook has no network on the push path.
#
# PLAN-028 B3: this used to be a hardcoded `origin/main`. On a repo whose
# integration branch is not `main` — a `master`/`develop` consumer today, or any
# adopter of the promotion model — the first-push fallback diverged from the
# WRONG branch, so the range was the `main..dev` delta PLUS the feature commits:
# the gate re-linted, and demanded an audit phrase for, commits that were
# reviewed and merged long ago. `refs/remotes/origin/HEAD` is the same answer
# without a network call, and on a single-branch repo it resolves to `main`, so
# the fallback is unchanged where it was already right.
DEFAULT_BRANCH_LOCAL="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"
[ -n "$DEFAULT_BRANCH_LOCAL" ] || DEFAULT_BRANCH_LOCAL=main

if [ -n "$upstream_ref" ] && git rev-parse --verify --quiet "$upstream_ref" >/dev/null; then
  commit_range="${upstream_ref}..HEAD"
  BASE="$(git rev-parse --verify --quiet "$upstream_ref")"
else
  # First push (no upstream yet) — scan since divergence from the DEFAULT branch.
  commit_range="origin/${DEFAULT_BRANCH_LOCAL}..HEAD"
  BASE="$(git merge-base HEAD "origin/${DEFAULT_BRANCH_LOCAL}" 2>/dev/null \
          || git merge-base HEAD "$DEFAULT_BRANCH_LOCAL" 2>/dev/null \
          || git rev-list --max-parents=0 HEAD | tail -1)"
fi

# An EMPTY range and an UNRESOLVABLE one are different, and neither is a pass.
# Both exit non-zero; only the message differs, and the message is the whole
# point — the generic "no phrase found" block tells the reader to amend a commit,
# which cannot clear either state and, for the empty range, sends them to amend a
# commit that already carries the phrase (#432).
range_empty=0
range_unresolvable=0
if range_shas="$(git log --format=%H "$commit_range" 2>/dev/null)"; then
  [ -n "$range_shas" ] || range_empty=1
else
  range_unresolvable=1
fi

rc=0

# `git diff` FAILING is not an empty change set. Unrelated histories exit 128
# here and the status was discarded, so zero files were linted and the run still
# printed the pass banner. A gate must not assert a verification it did not
# perform, and that applies to its own malfunction too.
diff_rc=0
diff_err="$(git diff --name-only --diff-filter=ACMR "$BASE"...HEAD 2>&1 >/dev/null)" || diff_rc=$?
mapfile -t CHANGED < <(git diff --name-only --diff-filter=ACMR "$BASE"...HEAD 2>/dev/null)
if [ "$diff_rc" -ne 0 ]; then
  echo "::error::pre_push_check: cannot compute the changed-file list (git diff exited ${diff_rc})."
  echo "::error::  range: ${BASE}...HEAD"
  [ -n "$diff_err" ] && echo "::error::  ${diff_err}"
  echo "::error::  This is a GATE MALFUNCTION, not an empty change set — no file was linted."
  rc=1
  CHANGED=()
elif [ "${#CHANGED[@]}" -eq 0 ]; then
  echo "pre_push_check: no changed files vs base — skipping mechanical linters."
  CHANGED=()
fi
have() { command -v "$1" >/dev/null 2>&1; }
exists() { [ -f "$1" ]; }
filter() {
  local pat="$1" f
  for f in "${CHANGED[@]:-}"; do
    [ -n "$f" ] && [[ "$f" =~ $pat ]] && exists "$f" && printf '%s\n' "$f"
  done
}

run() {
  # $1 = label ; rest = command (only invoked when FILES non-empty)
  local label="$1"; shift
  [ "${#FILES[@]}" -gt 0 ] || return 0
  echo "── ${label} (${#FILES[@]} file(s)) ──"
  "$@" "${FILES[@]}" || { echo "::error::${label} found issues — fix before pushing."; rc=1; }
}

# --- 1. markdownlint ---
mapfile -t FILES < <(filter '\.md$')
if [ "${#FILES[@]}" -gt 0 ]; then
  if have markdownlint-cli2; then
    run "markdownlint" markdownlint-cli2
  elif have npx && npx --no-install markdownlint-cli2 --version >/dev/null 2>&1; then
    run "markdownlint (npx)" npx --no-install markdownlint-cli2
  else
    echo "ℹ️  markdownlint skipped (markdownlint-cli2 not resolvable) — CI enforces."
  fi
fi

# --- 2. yamllint ---
mapfile -t FILES < <(filter '\.ya?ml$')
if [ "${#FILES[@]}" -gt 0 ]; then
  if have yamllint; then
    if [ -f .yamllint.yaml ]; then
      run "yamllint" yamllint -c .yamllint.yaml
    else
      run "yamllint" yamllint
    fi
  else
    echo "ℹ️  yamllint skipped (not installed)."
  fi
fi

# --- 3. actionlint on .github/workflows/ ---
mapfile -t FILES < <(filter '^\.github/workflows/.*\.ya?ml$')
if [ "${#FILES[@]}" -gt 0 ]; then
  if have actionlint; then
    run "actionlint" actionlint
  else
    echo "ℹ️  actionlint skipped (not installed) — recommended for local workflow lint."
  fi
fi

# --- 4. shellcheck ---
mapfile -t FILES < <(filter '\.sh$')
if [ "${#FILES[@]}" -gt 0 ]; then
  if have shellcheck; then
    run "shellcheck" shellcheck -S warning
  else
    echo "ℹ️  shellcheck skipped (not installed)."
  fi
fi

# --- 5. OPS-0069 audit-trail phrase check ---
#
# Every push must carry an audit-trail line in the NEW commits' messages
# proving that either (a) the OPS-0065 diff-class sub-agents were
# dispatched and their verdict folded, or (b) the founder explicitly
# OK'd skipping.
#
# Scan ONLY the commits being newly pushed. Scope: `@{upstream}..HEAD`
# when upstream is configured (so each push carries a fresh phrase on
# its new commits); falls back to `origin/main..HEAD` on the very first
# push before upstream is set. The BASE..HEAD merge-base range does NOT
# advance between pushes — once a phrase-bearing commit was anywhere
# in that range, subsequent pushes of never-reviewed commits also
# passed. Broken; do not revert.
#
# Canonical audit-trail phrases:
#   "Multi-agent self-review per OPS-0065"  — standard case; commit body
#                                             must also name the agents
#                                             + verdict.
#   "Self-review skipped per founder OK"    — override case only when
#                                             the founder authorizes the
#                                             skip in-session; reason
#                                             MUST follow the phrase.
#
# The hook verifies the phrase, not the review itself. Falsifying the
# phrase is a governance-Rule-2 violation caught at the CI ai-review
# layer.
#
# `commit_range` is resolved once at the top of this script, alongside the
# linters' BASE — see "push range" above.
push_msgs="$(git log --format=%B "$commit_range" 2>/dev/null || echo '')"

# --- Exemption logic (mirrors PLAN-002 §4.6; CI side implements the same +
# the two-signal skip-audit-trail label which needs PR context) ---
#
# Exemption 1: bot-authored — if ALL commits in range are authored by
# dependabot[bot] / renovate[bot] / github-actions[bot], skip the phrase
# check. Local hook rarely sees these (bots push via API), but the
# check is here for parity with CI.
push_authors="$(git log --format=%an "$commit_range" 2>/dev/null | sort -u || echo '')"
bot_only=1
while IFS= read -r author; do
  [ -z "$author" ] && continue
  case "$author" in
    "dependabot[bot]"|"renovate[bot]"|"github-actions[bot]") ;;
    *) bot_only=0; break ;;
  esac
done <<< "$push_authors"
if [ "$bot_only" = 1 ] && [ -n "$push_authors" ]; then
  echo "  ℹ️  OPS-0069 audit-trail check SKIPPED (bot-authored range: $push_authors)."
  audit_ok=1
else
  # Exemption 2: revert commits — if EVERY commit in range starts with
  # 'Revert "', skip. Mixed ranges (some revert + some non-revert) still
  # require the phrase.
  revert_only=1
  non_revert_found=0
  while IFS= read -r subject; do
    [ -z "$subject" ] && continue
    non_revert_found=1
    case "$subject" in
      'Revert "'*) ;;
      *) revert_only=0; break ;;
    esac
  done < <(git log --format=%s "$commit_range" 2>/dev/null)
  if [ "$revert_only" = 1 ] && [ "$non_revert_found" = 1 ]; then
    echo "  ℹ️  OPS-0069 audit-trail check SKIPPED (revert-only range)."
    audit_ok=1
  else
    audit_ok=0
    for phrase in "Multi-agent self-review per OPS-0065" \
                  "Self-review skipped per founder OK"; do
      # CI-0033: `case`, not `echo … | grep -qF`. `grep -q` exits on first
      # match, the writer takes EPIPE, and `set -o pipefail` turns that MATCH
      # into a non-zero pipeline status — a false "phrase missing" that grows
      # more likely as the push range grows. This bit the CI twin of this very
      # check on PR #416 (#417). A quoted expansion in a case pattern is a
      # literal, so this is `grep -F` semantics with no status to invert.
      case "$push_msgs" in
        *"$phrase"*)
          audit_ok=1
          break
          ;;
      esac
    done
  fi
fi
# ONE decision point for what this run is allowed to claim. The empty and
# unresolvable arms come FIRST so neither can reach the generic phrase block,
# whose remedies are both `git commit --amend` and cannot clear either state.
#
# There is deliberately no second guard setting `audit_ok=0` up in the exemption
# chain: mutation showed it was dead code. Neither exemption can fire on an empty
# or unresolvable range — the bot arm needs a non-empty author list and the
# revert arm needs at least one commit — so `audit_ok` is already 0 by the time
# control arrives here. A guard that cannot be observed to fail is not a guard.
if [ "$range_empty" = 1 ] && promotion_shaped_push; then
  # PLAN-028 B3, second half — found in pre-push review, and it is the half that
  # decides whether B3 is real.
  #
  # `--promote` is only reachable when a human types it. The pre-commit wiring
  # runs this script with NO arguments (`pass_filenames: false`), so on an actual
  # `git push origin dev:staging` control reached the empty-range arm below and
  # BLOCKED the push — the exact defect B3 claims to close — leaving
  # `git push --no-verify` as the only way through. That trains the operator to
  # disable every pre-push hook on a routine operation, which is worse than the
  # bug.
  #
  # So the no-argument path recognises the shape itself. This is not a
  # weakening: `promotion_shaped_push` requires a declaration AND that HEAD is
  # exactly the integration branch's already-pushed remote tip. When that holds,
  # every commit in play has already been through this gate on its way into the
  # integration branch, so there is genuinely nothing unverified — which is a
  # stronger statement than the empty range alone could make. An UNDECLARED repo
  # never takes this path and still hard-fails.
  echo "pre_push_check: PROMOTION-SHAPED push detected (no declared argument needed)."
  echo "  VERIFIED: HEAD == origin/${PROMO_INTEGRATION} (${promo_head_sha})"
  echo "            so every commit here is already on the integration branch, where"
  echo "            this gate ran on it. The empty range is expected, not a failure."
  echo "  Declared promotion branches: ${PROMO_LIST:-(none)}"
  echo "  NOT CHECKED, deliberately: the OPS-0069 phrase and the mechanical linters —"
  echo "  a promotion introduces no new commit and no changed file."
  # NOT CHECKED, and NOT deliberately — this arm cannot see the TARGET.
  #
  # `--promote <target>` enforces all three conditions a promotion is defined by:
  # (1) the target is a declared promotion branch, (2) HEAD == the integration
  # branch's remote tip, (3) the target's tip is an ancestor of HEAD. This arm
  # takes no argument, so it can only establish (2) — and it was printing
  # "PROMOTION OK" anyway. That banner passed `git push --force origin dev:main`
  # discarding a hotfix merged straight onto `main`, and it passed
  # `git push origin dev:anything-at-all` to a branch nobody declared, because
  # neither (1) nor (3) was ever evaluated. On an adopted repo `main` carries
  # `enforce_admins:false` (CI-0049), so the server does not refuse it either.
  #
  # State what was actually established. A gate that names a weaker fact is
  # worth more than one that names a stronger fact it did not check.
  echo "  NOT CHECKED, and this arm CANNOT check them — it receives no target:"
  echo "    · that the target is a DECLARED promotion branch"
  echo "    · that the push is a FAST-FORWARD of the target (a --force here can"
  echo "      discard commits made directly on the target, e.g. a merged hotfix)"
  echo "  For those two, name the target:"
  echo "    scripts/pre_push_check.sh --promote <target-branch>"
  echo "pre_push_check: EMPTY RANGE OK (promotion-shaped; target NOT verified)"
  # Do NOT clobber an earlier failure. `rc=0` here erased any prior rc=1 —
  # notably the gate-malfunction arm — turning a broken gate into a pass.
  [ "$rc" -eq 0 ] || echo "  NOTE: an earlier check already failed; that failure stands."
elif [ "$range_empty" = 1 ]; then
  # #432. The range holds no commits, so NOTHING was verified — not the phrase,
  # and not the mechanical linters, which had no files. That is neither a pass
  # nor an OPS-0069 violation, and the old message claimed the latter: it sent
  # the reader to `git commit --amend` a commit that already carried the phrase.
  echo "::error::pre_push_check: the push range ($commit_range) is EMPTY — NOTHING was verified."
  echo "::error::  This is NOT an OPS-0069 violation. The usual cause is that the branch has"
  echo "::error::  ALREADY been pushed, so @{upstream} is HEAD and no commit is in range."
  echo "::error::  Amending a commit will not change this — the phrase is not the problem."
  echo "::error::  Run this BEFORE 'git push'. To inspect a branch that is already pushed:"
  echo "::error::    git log --oneline origin/${DEFAULT_BRANCH_LOCAL}..HEAD"
  echo "::error::  Promoting ${DEFAULT_BRANCH_LOCAL} to a declared promotion branch? That push is"
  echo "::error::  legitimately empty of NEW commits — use the promotion mode instead:"
  echo "::error::    scripts/pre_push_check.sh --promote <target-branch>"
  echo "::error::  Exiting non-zero: a run that verified nothing must not approve a push."
  rc=1
elif [ "$range_unresolvable" = 1 ]; then
  # Distinct from empty: the range's base ref is missing, so the scan could not
  # run at all. The generic block's two remedies are both `git commit --amend`,
  # and neither can clear this.
  echo "::error::pre_push_check: the push range ($commit_range) does not resolve."
  echo "::error::  Its base ref is missing from this clone, so no OPS-0069 phrase check was possible."
  echo "::error::  Amending a commit will not clear this. Fetch the base ref this range names,"
  echo "::error::  or set the branch's upstream:"
  echo "::error::    git fetch origin && git branch --set-upstream-to=origin/<branch>"
  rc=1
elif [ "$audit_ok" -ne 1 ]; then
  echo "::error::no OPS-0069 audit-trail phrase found in any commit in the push range ($commit_range)."
  echo
  echo "Every push MUST carry one of these phrases in a commit message body:"
  echo
  echo "  Standard case (dispatch OPS-0065 diff-class agents pre-push, fold findings):"
  echo "    Multi-agent self-review per OPS-0065 (<agents>): <verdict summary>"
  echo
  echo "  Founder-OK skip case (only with in-session authorization):"
  echo "    Self-review skipped per founder OK <reason>"
  echo
  echo "Options to unblock this push:"
  echo "  (1) Dispatch the OPS-0065 diff-class-matched sub-agents by invoking"
  echo "      your AI-agent tool (Claude Code Agent() / Codex agents / etc.),"
  echo "      one call per matched agent-type (code-reviewer, documentation-"
  echo "      specialist, security-auditor, silent-failure-hunter, etc. — see"
  echo "      https://github.com/vladm3105/aidoc-flow-operations/blob/main/CLAUDE.md"
  echo "      § 'Multi-agent automated review' for the diff-class → agent map)."
  echo "      Fold their findings, THEN amend HEAD:"
  echo "        git commit --amend"
  echo "        # in the editor, append a line to the commit body:"
  echo "        #   Multi-agent self-review per OPS-0065 (<agents>): <verdict summary>"
  echo "  (2) Get founder authorization to skip AND amend HEAD to add the"
  echo "      'Self-review skipped per founder OK <reason>' line to the commit"
  echo "      body via 'git commit --amend'."
  echo
  echo "See https://github.com/vladm3105/aidoc-flow-operations/blob/main/ops/DECISIONS.md"
  echo "→ OPS-0069 for the full rule."
  rc=1
else
  echo "  ✅ OPS-0069 audit-trail present in push range."
fi


# --- 6. Post-merge branch hygiene (BRANCHING.md §3a) — WARN ONLY ---
#
# A4-residual, decided 2026-08-23. BRANCHING.md §3a asks you to delete a merged
# local branch and prune stale remote-tracking refs. Nothing server-side can
# enforce that — but this hook already ships into every adopting clone, and §7
# counts a local pre-push hook as enforcement for the OPS-0069 phrase, so the
# option was real and had to be decided rather than written off.
#
# TAKEN, as a WARNING and never a failure. It reports hygiene; it does not hold
# up a push, and `rc` is deliberately untouched below.
#
# ANCESTRY IS THE WRONG DETECTOR AND FAILS SILENTLY. Squash merge rewrites the
# SHA, so a merged branch is NOT an ancestor of the default branch: measured on
# canon, `git branch --merged main` listed nothing but `main` itself while 14 of
# 16 local branches had merged PRs. Merged-ness comes from PR state.
#
# `gh` is optional here on purpose — this must not become a network dependency
# on the push path. No `gh`, no warning.
if command -v gh >/dev/null 2>&1; then
  _stale=""
  for _b in $(git for-each-ref --format='%(refname:short)' refs/heads/ 2>/dev/null); do
    [ "$_b" = "$DEFAULT_BRANCH_LOCAL" ] && continue
    # any(), not .[0]: a reused or reopened branch has SEVERAL PRs, and an
    # arbitrary element can read CLOSED while a merged PR exists.
    if [ "$(gh pr list --head "$_b" --state all --json state \
              --jq 'any(.[]; .state == "MERGED")' 2>/dev/null)" = "true" ]; then
      _stale="$_stale $_b"
    fi
  done
  if [ -n "$_stale" ]; then
    echo "  ⚠️  hygiene: merged local branch(es) not yet deleted:$_stale"
    echo "      BRANCHING.md §3a — 'git branch -D <b>' (-d refuses; squash means"
    echo "      it is not an ancestor). Confirm containment first if you may have"
    echo "      committed to the branch after the merge. Then 'git fetch --prune'."
  fi
fi

echo "════════════════════════════════════════════════════════════════════"
if [ "$rc" = 0 ]; then
  echo "✅ local pre-push checks passed (including OPS-0069 audit-trail check)."
elif [ "$range_empty" = 1 ]; then
  # Not "FAILED" — nothing was checked, so nothing failed. Saying otherwise is
  # what sent readers to fix a commit that was never the problem.
  echo "❌ NOTHING VERIFIED — the push range is EMPTY (see above). This is not a pass."
else
  echo "❌ local pre-push checks FAILED — do not push until fixed."
fi
exit "$rc"
