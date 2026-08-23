#!/usr/bin/env bash
# tests/test_version_sync.sh — release-pointer drift guard.
#
# WHY THIS EXISTS: `install.sh` resolves the tag it installs/re-pins as
#   CI_TAG env > VERSION file > CI_TAG_FALLBACK
# so if VERSION or the fallback names anything other than the latest PUBLISHED
# tag, a `--repin` without an explicit CI_TAG silently writes the WRONG tag onto
# a consumer. Measured 2026-07-17: VERSION and CI_TAG_FALLBACK both said
# ci/v2.0.0 while ci/v2.0.1 was the live fleet target — so every documented
# `--repin` invocation would have pinned consumers BACKWARDS onto the three
# ai-review blockers v2.0.1 exists to fix, on the one armed live consumer.
# Nothing caught it: sync-version-refs.sh --check only proves the refs agree
# with VERSION, not that VERSION is right. It reported green.
#
# The fallback was documented as "hand-bumped per release". A release step that
# can be forgotten will be. This test is the guard; sync-version-refs.sh now
# rewrites the fallback mechanically.
#
# CONTRACT: VERSION == CI_TAG_FALLBACK == the latest published ci/v* tag.
#
# RELEASE ORDER (this test encodes it): bump VERSION -> run sync-version-refs.sh
# -> commit -> THEN `git tag`. Between the bump and the tag this test fails,
# which is correct and intentional: during that window VERSION names a tag that
# does not exist yet, and an install/repin in that window would 404. Cut the tag
# to make it pass. Do NOT "fix" a red here by reverting the bump.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
cd "$ROOT" || exit 1

echo "== version pointers (VERSION / CI_TAG_FALLBACK / latest tag) =="

VERSION_VAL="$(tr -d '[:space:]' < VERSION 2>/dev/null || echo '')"
FALLBACK_VAL="$(grep -oE 'CI_TAG_FALLBACK="ci/v[0-9]+\.[0-9]+\.[0-9]+"' install/install.sh \
  | head -1 | sed -E 's/.*"(ci\/v[0-9]+\.[0-9]+\.[0-9]+)"/\1/')"

if [ -z "$VERSION_VAL" ]; then
  _r "VERSION file is empty or unreadable"
elif [ -z "$FALLBACK_VAL" ]; then
  _r "could not parse CI_TAG_FALLBACK from install/install.sh"
else
  if [ "$VERSION_VAL" = "$FALLBACK_VAL" ]; then
    _g "VERSION ($VERSION_VAL) == CI_TAG_FALLBACK"
  else
    _r "VERSION ($VERSION_VAL) != CI_TAG_FALLBACK ($FALLBACK_VAL) — a CI_TAG-less install/repin would use the fallback and write the wrong tag. Run: bash scripts/sync-version-refs.sh"
  fi

  # Latest published tag. Sort with -V so ci/v2.0.10 > ci/v2.0.9. Skip the
  # comparison (do not fail) when tags are unavailable — a shallow CI clone or a
  # fresh fork has none, and a guard that fails on "cannot check" would be noise
  # rather than signal. The pointers-agree assertion above still runs.
  #
  # FILTER TO EXACT ci/vX.Y.Z, the same regex `scripts/release.sh` uses (:59-65)
  # and for the reason it documents: `sort -V` ranks `ci/v2.13.0-rc.1` ABOVE
  # `ci/v2.13.0`, so an unfiltered glob lets a pre-release — or a stray tag like
  # `ci/v0.0.1-ruletest` — become "latest". This is not hypothetical bookkeeping:
  # THIS assertion is the one `release.sh prep` keys its expected-red classifier
  # on (`:301`, "FAIL .*latest published tag"). If it reds for the WRONG reason,
  # a genuinely broken suite is classified as the benign FT-21 chicken-and-egg
  # and the operator is told to merge past it. `grep` exits 1 on no match, which
  # under `set -e` would abort the assignment rather than yield the empty string
  # the no-tags branch handles — hence `|| true`.
  LATEST_TAG="$(git tag --list 'ci/v[0-9]*' 2>/dev/null \
    | { grep -E '^ci/v[0-9]+\.[0-9]+\.[0-9]+$' || true; } | sort -V | tail -1)"
  if [ -z "$LATEST_TAG" ]; then
    echo "  ---  no ci/v* tags reachable (shallow clone?) — skipping latest-tag comparison"
  elif [ "$VERSION_VAL" = "$LATEST_TAG" ]; then
    _g "VERSION ($VERSION_VAL) == latest published tag"
  else
    _r "VERSION ($VERSION_VAL) != latest published tag ($LATEST_TAG) — install/repin would target a tag that is not the current release. If you are mid-release-cut, cut the tag; otherwise bump VERSION + run scripts/sync-version-refs.sh"
  fi
fi

echo ""
echo "== deploy-ci-wizard.sh resolves VERSION with NO literal fallback (PLAN-018 F7) =="

# The wizard once ended its CI_TAG resolution with `|| echo 'ci/v1.9.5'`. Under
# `set -euo pipefail` a missing/unreadable VERSION makes that fallback FIRE, so
# the wizard scaffolded callers pinned 14 releases back — green and silent.
# test above guards install.sh's fallback; NOTHING guarded the wizard's. These
# assertions do, by EXECUTING the shipped script against a VERSION that is
# missing/empty/good — never by re-reading its source.
WIZ="$ROOT/install/deploy-ci-wizard.sh"

# 1. No stale literal tag survives in the resolution line. A bare `grep` for any
#    ci/v* in the whole file would false-match doc examples, so scope to the
#    CI_TAG assignment region: the wizard must not carry a hardcoded pin there.
if grep -nE "CI_TAG=.*ci/v[0-9]+\.[0-9]+" "$WIZ" >/dev/null 2>&1; then
  _r "deploy-ci-wizard.sh carries a literal ci/v* tag in its CI_TAG resolution — a stale fallback can reappear"
else
  _g "deploy-ci-wizard.sh CI_TAG resolution carries no literal tag"
fi

# 2. Execute the resolution in isolation, exactly as shipped, against three
#    VERSION states. Extract the CI_TAG line + its guard block so the test runs
#    the REAL code, not a paraphrase.
wiz_probe() { # $1 = what to put at <sandbox>/VERSION ('' => remove the file)
  local sandbox; sandbox="$(mktemp -d)"
  mkdir -p "$sandbox/install"
  # the shipped resolution block: the CI_TAG= line through the closing `}`
  awk '/^CI_TAG="\$\(tr -d/{p=1} p{print} /^}$/{if(p)exit}' "$WIZ" > "$sandbox/install/probe_body.sh"
  {
    echo 'set -euo pipefail'
    echo 'HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"'
    cat "$sandbox/install/probe_body.sh"
    echo 'printf "OK:%s\n" "$CI_TAG"'
  } > "$sandbox/install/probe.sh"
  if [ -n "$1" ]; then printf '%s' "$1" > "$sandbox/VERSION"; else rm -f "$sandbox/VERSION"; fi
  local out rc
  out="$(bash "$sandbox/install/probe.sh" 2>/dev/null)"; rc=$?
  rm -rf "$sandbox"
  printf '%s\n' "rc=$rc out=$out"
}

# Guard extraction didn't silently produce an empty body (which would make every
# case "pass" for the wrong reason).
_probe_body_lines="$(awk '/^CI_TAG="\$\(tr -d/{p=1} p{print} /^}$/{if(p)exit}' "$WIZ" | wc -l | tr -d ' ')"
assert_ok "[ '${_probe_body_lines:-0}' -ge 3 ]" "wizard CI_TAG resolution block extracted ($_probe_body_lines lines)"

good_res="$(wiz_probe 'ci/v9.9.9')"
assert_contains "$good_res" "rc=0" "good VERSION resolves (rc=0)"
assert_contains "$good_res" "OK:ci/v9.9.9" "good VERSION yields its exact tag"

miss_res="$(wiz_probe '')"
assert_contains "$miss_res" "rc=2" "missing VERSION exits 2 (fails loud, no literal fallback)"
assert_absent "$miss_res" "OK:" "missing VERSION scaffolds NO tag"

empty_res="$(wiz_probe '   ')"
assert_contains "$empty_res" "rc=2" "whitespace-only VERSION exits 2 (no unresolvable @ pin)"

# ---------------------------------------------------------------------------
# 3. CI-0024 — sync-version-refs.sh must NOT rewrite illustrative/historical
#    install commands.
#
# The script's substitutions match install-reference SHAPE, not
# current-vs-historical. Its header noted that this was safe only while no target
# carried an illustrative old-tag install command, and said to mark such a line
# to exclude it. That was TRUE when written (a0fc68c, 2026-07-09: TARGETS held
# two READMEs). It stopped being true on 2026-07-17, when 1a027da (#175) added
# docs/MIGRATION_v2.0.0.md — which carries two such commands — to TARGETS. The
# prescribed exclusion was never implemented, so nothing failed. The Rollback
# command is meant to pin a consumer BACK to ci/v1.x; from that commit on, every
# release cut rewrote it FORWARD, publishing an instruction that did the opposite
# of its stated intent.
#
# These drive the SHIPPED functions, extracted from the real script rather than
# paraphrased, so deleting the negated address range or the validator goes red.
# ---------------------------------------------------------------------------
echo
echo "== sync-version-refs ignore markers (CI-0024) =="

SVR="$ROOT/scripts/sync-version-refs.sh"
_extract_fn() { awk -v fn="$1" '$0 ~ ("^" fn "\\(\\) \\{") {p=1} p{print} p && /^\}$/{exit}' "$SVR"; }

svr_probe_dir="$(mktemp -d)"
{
  echo 'set -uo pipefail'
  grep -E '^IGNORE_(START|END)=' "$SVR"
  echo 'TAG="ci/v9.9.9"'
  _extract_fn validate_ignore_markers
  _extract_fn sed_program
  echo 'if [ "${1:-}" = "--validate" ]; then validate_ignore_markers "$2"; exit $?; fi'
  echo 'sed -E -f <(sed_program) "$1"'
} > "$svr_probe_dir/probe.sh"

# Extraction guards — an empty body would make every case below "pass" for the
# wrong reason (the failure mode tests/test_contract.sh was itself caught by).
_svr_val_lines="$(_extract_fn validate_ignore_markers | wc -l | tr -d ' ')"
_svr_sed_lines="$(_extract_fn sed_program | wc -l | tr -d ' ')"
assert_ok "[ '${_svr_val_lines:-0}' -ge 5 ]" "validate_ignore_markers extracted ($_svr_val_lines lines)"
assert_ok "[ '${_svr_sed_lines:-0}' -ge 6 ]" "sed_program extracted ($_svr_sed_lines lines)"
assert_ok "grep -qE '^IGNORE_START=' '$SVR'" "IGNORE_START marker is defined in the shipped script"

# --- rewriting honours the markers -----------------------------------------
cat > "$svr_probe_dir/doc.md" <<'FIXTURE'
Install the current release:

```bash
CI_TAG=ci/v1.0.0 bash install.sh <owner/repo> --repin
```

<!-- sync-version-refs:ignore-start -->
To roll a consumer BACK to the last v1 tag:

```bash
CI_TAG=ci/v1.9.5 bash install.sh <owner/repo> --repin
```

    uses: vladm3105/aidoc-flow-ci/.github/workflows/ai-review.yml@ci/v1.9.5
<!-- sync-version-refs:ignore-end -->

And back to current:

    uses: vladm3105/aidoc-flow-ci/.github/workflows/ai-review.yml@ci/v1.0.0
FIXTURE

svr_out="$(bash "$svr_probe_dir/probe.sh" "$svr_probe_dir/doc.md" 2>&1)"

assert_contains "$svr_out" 'CI_TAG=ci/v9.9.9 bash install.sh' \
  "a CI_TAG= line OUTSIDE an ignore span is still rewritten (positive control)"
assert_contains "$svr_out" 'ai-review.yml@ci/v9.9.9' \
  "a uses:@tag line AFTER ignore-end is rewritten — the span closes"
assert_contains "$svr_out" 'CI_TAG=ci/v1.9.5 bash install.sh' \
  "the historical rollback CI_TAG= INSIDE the span is preserved (CI-0024)"
assert_contains "$svr_out" 'ai-review.yml@ci/v1.9.5' \
  "a historical uses:@tag INSIDE the span is preserved"
assert_contains "$svr_out" 'sync-version-refs:ignore-start' \
  "the markers themselves survive the rewrite"

# Mutation check: strip the negated address ranges and the guarded lines WOULD
# be rewritten. This proves the assertions above bind to the ranges rather than
# passing because the fixture never matched in the first place.
mutant="$svr_probe_dir/mutant.sh"
sed 's|/${IGNORE_START}/,/${IGNORE_END}/!||g' "$svr_probe_dir/probe.sh" > "$mutant"
assert_ok "! grep -q 'IGNORE_START}/,' '$mutant'" "mutant actually stripped the address ranges"
mut_out="$(bash "$mutant" "$svr_probe_dir/doc.md" 2>&1 || true)"
assert_contains "$mut_out" 'CI_TAG=ci/v9.9.9 bash install.sh <owner/repo> --repin' \
  "mutant rewrites the OUTSIDE line too — mutation harness is live"
assert_absent "$mut_out" 'CI_TAG=ci/v1.9.5' \
  "mutant DOES clobber the historical rollback command — this is the CI-0024 bug, reproduced"

# --- validator: malformed markers are a HARD error -------------------------
svr_validate() { printf '%s' "$1" > "$svr_probe_dir/v.md"; bash "$svr_probe_dir/probe.sh" --validate "$svr_probe_dir/v.md" 2>&1; printf 'rc=%s' "$?"; }

ok_res="$(svr_validate 'a
<!-- sync-version-refs:ignore-start -->
b
<!-- sync-version-refs:ignore-end -->
c')"
assert_contains "$ok_res" "rc=0" "balanced markers validate clean"

unterm_res="$(svr_validate 'a
<!-- sync-version-refs:ignore-start -->
b')"
assert_contains "$unterm_res" "rc=1" "an unterminated ignore-start is a hard error"
assert_contains "$unterm_res" "unterminated" "the unterminated error names the failure"
assert_contains "$unterm_res" ":2:" "the unterminated error names the LINE the span opened at"

stray_res="$(svr_validate 'a
<!-- sync-version-refs:ignore-end -->')"
assert_contains "$stray_res" "rc=1" "an ignore-end with no start is a hard error"

nested_res="$(svr_validate '<!-- sync-version-refs:ignore-start -->
<!-- sync-version-refs:ignore-start -->
<!-- sync-version-refs:ignore-end -->')"
assert_contains "$nested_res" "rc=1" "a nested ignore-start is a hard error"

oneline_res="$(svr_validate 'x <!-- sync-version-refs:ignore-start --> y <!-- sync-version-refs:ignore-end --> z')"
assert_contains "$oneline_res" "rc=1" "both markers on one line is a hard error (grep -c would miscount)"

rm -rf "$svr_probe_dir"

# --- the trigger that actually fired must fail a test, not a comment ---------
# CI-0024's real lesson: the caveat named a future trigger ("a target gains an
# illustrative install command") but only PROSE guarded it, so 1a027da (#175)
# tripped it silently by adding docs/MIGRATION_v2.0.0.md to TARGETS. §22.2 now
# legislates that such a trigger is enforced mechanically — this is that
# enforcement, and without it this change would violate the rule it ships.
#
# The list is pinned. Adding a target fails HERE, with instructions, so whoever
# adds the next one is forced to answer the question #175 was never asked.
# `{p=1;next}` on the opening line would skip an entry written on the SAME line
# as `TARGETS=(` — a silent bypass of this very guard. Strip the `TARGETS=(`
# prefix instead and keep the remainder of that line in scope.
_svr_targets="$(awk '/^TARGETS=\(/{p=1;sub(/^TARGETS=\(/,"")} p&&/^\)/{exit} p' "$SVR" \
  | sed -E 's/^[[:space:]]*#.*$//; s/^[[:space:]]*"([^"]+)".*$/\1/' | grep -v '^$' | sort)"
assert_ok "[ -n '$_svr_targets' ]" "TARGETS list extracted from the shipped script"
read -r -d '' _svr_expected <<'EXPECTED' || true
docs/AI_CI_DEPLOYMENT.md
docs/BRANCH_PROTECTION.md
docs/MIGRATION_v2.0.0.md
docs/MIGRATION_v3.0.0.md
docs/MIGRATION_v4.0.0.md
docs/PLAYBOOK_governance-canon-rollout.md
docs/REVIEWER_APP_ONBOARDING.md
docs/UPDATE_GUIDE.md
docs/architecture.md
docs/multi-project-guide.md
docs/overrides.md
docs/security.md
install/README.md
install/install.sh
install/templates/config.json.template
README.md
EXPECTED
_svr_expected="$(printf '%s\n' "$_svr_expected" | sort)"
if [ "$_svr_targets" = "$_svr_expected" ]; then
  _g "sync-version-refs TARGETS matches the reviewed set (CI-0024 trigger guard)"
else
  _r "sync-version-refs TARGETS changed. This is the CI-0024 trigger: a file
       entering TARGETS has EVERY install reference rewritten to VERSION at each
       release cut. Before updating this list, open the file and check for
       ILLUSTRATIVE or HISTORICAL install commands — a rollback command, a
       'repin to @ci/vX.Y.Z' step from a past migration. Wrap each in
       <!-- sync-version-refs:ignore-start --> / <!-- ...ignore-end --> or it
       will be silently falsified. Check too for any LITERAL occurrence of those
       marker strings in prose or fenced examples — once the file is a target
       they parse as real spans, and an unbalanced or same-line pair is a hard
       exit 2. Diff:
$(diff <(printf '%s\n' "$_svr_expected") <(printf '%s\n' "$_svr_targets") | sed 's/^/       /')"
fi

suite_summary "version-sync"
