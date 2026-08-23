#!/usr/bin/env bash
# tests/test_pre_push_range.sh — behavioural tests for pre_push_check.sh's push
# range, run against BOTH copies (canon + the template consumers install).
#
# Why both: #477. The two copies had diverged on `BASE=` — canon carried the
# PLAN-015 M3 fix, the template shipped the pre-M3 behaviour — and nothing
# detected it for the life of the divergence. The one guard that existed
# (tests/test_sigpipe_guard.sh) compared a single `sed`-scoped hunk while its
# comment claimed a general no-drift invariant. Every assertion below runs
# twice, once per copy, so a future divergence reds the suite instead of ageing
# quietly. The byte-identity guard at the end is the backstop.
#
# The scripts are EXECUTED, not grepped: a grep over the implementation's source
# survives every refactor that keeps the string and breaks the logic. Linters
# are stubbed onto PATH so the changed-file list is observable in the output.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
trap 'rm -rf "$TMP"; exit 130' INT
trap 'rm -rf "$TMP"; exit 143' TERM

PHRASE="Multi-agent self-review per OPS-0065 (code-reviewer): PASS"

# Stub markdownlint-cli2 so `run` prints the exact file list it was handed.
# `have markdownlint-cli2` then resolves and the CHANGED set becomes observable.
mkdir -p "$TMP/bin"
cat > "$TMP/bin/markdownlint-cli2" <<'STUB'
#!/usr/bin/env bash
for f in "$@"; do printf 'LINTED:%s\n' "$f"; done
STUB
chmod +x "$TMP/bin/markdownlint-cli2"

# A fresh repo with a real remote. $1 = destination dir.
new_repo() {
  local d="$1"
  mkdir -p "$d"
  git init -q --bare "$d/remote.git"
  git init -q -b main "$d/work"
  git -C "$d/work" config user.email tester@example.invalid
  git -C "$d/work" config user.name  Tester
  git -C "$d/work" remote add origin "$d/remote.git"
  : > "$d/work/seed.md"
  git -C "$d/work" add -A
  git -C "$d/work" commit -q -m "seed" -m "$PHRASE"
  # A SECOND pushed commit, deliberately. seed.md is in the ROOT commit, so
  # `git diff <any-ancestor>...HEAD` can never name it — an assert_absent on
  # seed.md is inert for every possible value of BASE, including the script's
  # root-commit fallback. base.md is reachable from the root, so an assertion
  # that it is not re-linted actually constrains BASE.
  : > "$d/work/base.md"
  git -C "$d/work" add -A
  git -C "$d/work" commit -q -m "base" -m "$PHRASE"
  git -C "$d/work" push -q -u origin main
}

# A repo with commits but NO resolvable range base: no remote at all, so
# `origin/main..HEAD` does not resolve. Distinct from an EMPTY range.
new_repo_no_remote() {
  local d="$1"
  mkdir -p "$d/work"
  git init -q -b main "$d/work"
  git -C "$d/work" config user.email tester@example.invalid
  git -C "$d/work" config user.name  Tester
}

# Commit one new file. $1 = work dir, $2 = filename, $3 = "phrase" | "nophrase"
add_commit() {
  local w="$1" f="$2" mode="$3"
  : > "$w/$f"
  git -C "$w" add -A
  if [ "$mode" = phrase ]; then
    git -C "$w" commit -q -m "add $f" -m "$PHRASE"
  else
    git -C "$w" commit -q -m "add $f"
  fi
}

# Run the script under test inside the work tree; sets OUT and RC.
# Deliberately NOT `out=$(run_check …)` at the call sites — a command
# substitution is a subshell, and RC set inside it would never reach the
# assertions. Globals, called bare.
RC=0; OUT=""
run_check() {
  local script="$1" w="$2"
  OUT="$(cd "$w" && PATH="$TMP/bin:$PATH" bash "$script" </dev/null 2>&1)" && RC=0 || RC=$?
}

# Same, with arguments — for the PLAN-028 B3 promotion mode.
run_check_args() {
  local script="$1" w="$2"; shift 2
  OUT="$(cd "$w" && PATH="$TMP/bin:$PATH" bash "$script" "$@" </dev/null 2>&1)" && RC=0 || RC=$?
}

# A repo whose integration branch is `dev` and whose remote already has it.
# $1 = destination dir; $2 = the .github/aidoc-ci.json body ('' = no file).
new_promo_repo() {
  local d="$1" decl="${2:-}"
  mkdir -p "$d"
  git init -q --bare "$d/remote.git"
  git init -q -b dev "$d/work"
  git -C "$d/work" config user.email tester@example.invalid
  git -C "$d/work" config user.name  Tester
  git -C "$d/work" remote add origin "$d/remote.git"
  if [ -n "$decl" ]; then
    mkdir -p "$d/work/.github"
    printf '%s\n' "$decl" > "$d/work/.github/aidoc-ci.json"
  fi
  : > "$d/work/seed.md"
  git -C "$d/work" add -A
  git -C "$d/work" commit -q -m "seed" -m "$PHRASE"
  git -C "$d/work" push -q -u origin dev
  # Set origin/HEAD so an UNDECLARED repo resolves the SAME integration branch
  # a declared one does. Without this, 10b would hard-fail because
  # refs/remotes/origin/main is missing rather than because no declaration
  # exists — and the assertion would survive deleting the declaration check.
  git -C "$d/work" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/dev
}

PROMO_DECL='{"version":1,"branching":{"model":"dev-staging-main","integration_branch":"dev"}}'

for copy in scripts/pre_push_check.sh install/templates/pre_push_check.sh; do
  script="$ROOT/$copy"
  echo "== $copy =="
  assert_ok "[ -f '$script' ]" "$copy exists"

  # --- 1. The normal case: commits staged for a push that has not happened ---
  d="$TMP/$(printf '%s' "$copy" | tr '/.' '__')_normal"; new_repo "$d"
  add_commit "$d/work" new.md phrase
  run_check "$script" "$d/work"
  assert_eq "$RC" "0" "$copy: unpushed commit with the phrase exits 0"
  assert_contains "$OUT" "OPS-0069 audit-trail present" "$copy: phrase found in the push range"
  assert_contains "$OUT" "local pre-push checks passed" "$copy: claims a pass, having done the work"
  assert_contains "$OUT" "LINTED:new.md" "$copy: M3 — the newly committed file IS linted"
  assert_absent   "$OUT" "LINTED:base.md" "$copy: M3 — the already-pushed file is NOT re-linted"

  # --- 1b. The case that actually separates M3 from pre-M3 ------------------
  # Scenario 1 cannot tell the two apart: on `main` with one unpushed commit,
  # @{upstream} and merge-base-with-origin/main are the SAME commit, so both
  # BASE= forms lint exactly new.md. The divergence only appears once a branch
  # has been pushed MORE THAN ONCE — then @{upstream} has advanced past the fork
  # point and merge-base has not. This is the assertion that fails on the
  # pre-M3 template, i.e. the one that catches #477.
  d="$TMP/$(printf '%s' "$copy" | tr '/.' '__')_secondpush"; new_repo "$d"
  git -C "$d/work" checkout -q -b feat
  add_commit "$d/work" first.md phrase
  git -C "$d/work" push -q -u origin feat
  add_commit "$d/work" second.md phrase
  run_check "$script" "$d/work"
  assert_eq "$RC" "0" "$copy: second push on a branch exits 0"
  assert_contains "$OUT" "LINTED:second.md" "$copy: M3 — the second push's own file IS linted"
  assert_absent   "$OUT" "LINTED:first.md" \
    "$copy: M3 — the file from the ALREADY-PUSHED commit is NOT re-linted (#477)"
  assert_absent   "$OUT" "LINTED:base.md" "$copy: M3 — does not reach back past the fork point"

  # --- 2. #432: an empty range verified NOTHING ------------------------------
  # It must not be reported as an OPS-0069 violation (the old behaviour sent the
  # reader to amend a commit that already carried the phrase), and it must not
  # be reported as a pass. It exits NON-ZERO: this range describes the
  # checked-out branch, so "empty" is not proof that nothing is being pushed —
  # exiting 0 here was measured to let an unreviewed commit reach a remote.
  d="$TMP/$(printf '%s' "$copy" | tr '/.' '__')_pushed"; new_repo "$d"
  add_commit "$d/work" new.md phrase
  git -C "$d/work" push -q
  run_check "$script" "$d/work"
  assert_eq "$RC" "1" "$copy: an empty range does not approve the push"
  assert_absent "$OUT" "no OPS-0069 audit-trail phrase found" \
    "$copy: empty range is NOT reported as a phrase violation (#432)"
  assert_absent "$OUT" "local pre-push checks passed" \
    "$copy: empty range does not claim a pass it did not perform"
  assert_absent "$OUT" "OPS-0069 audit-trail present" \
    "$copy: empty range does not affirm a check that never ran"
  assert_contains "$OUT" "NOTHING was verified" "$copy: empty range names what happened"
  assert_contains "$OUT" "NOTHING VERIFIED" "$copy: the banner says nothing was verified"
  assert_absent "$OUT" "local pre-push checks FAILED" \
    "$copy: nothing was checked, so nothing FAILED — the banner must not say so"
  assert_absent "$OUT" "LINTED:" "$copy: nothing is linted on an empty range"

  # --- 3. A real violation is still a real violation ------------------------
  d="$TMP/$(printf '%s' "$copy" | tr '/.' '__')_missing"; new_repo "$d"
  add_commit "$d/work" new.md nophrase
  run_check "$script" "$d/work"
  assert_eq "$RC" "1" "$copy: a non-empty range with no phrase still fails"
  assert_contains "$OUT" "no OPS-0069 audit-trail phrase found" \
    "$copy: names the OPS-0069 violation"
  assert_contains "$OUT" "local pre-push checks FAILED" "$copy: the banner reports the failure"

  # --- 4. First push of a new branch: no upstream yet, fall back to main -----
  d="$TMP/$(printf '%s' "$copy" | tr '/.' '__')_firstpush"; new_repo "$d"
  git -C "$d/work" checkout -q -b feat
  add_commit "$d/work" feat.md phrase
  run_check "$script" "$d/work"
  assert_eq "$RC" "0" "$copy: first push of a branch with no upstream exits 0"
  assert_contains "$OUT" "OPS-0069 audit-trail present" \
    "$copy: no upstream falls back to origin/main..HEAD for the phrase"
  assert_contains "$OUT" "LINTED:feat.md" "$copy: no upstream lints the branch's own files"
  assert_absent "$OUT" "LINTED:base.md" "$copy: no upstream does not reach back past the fork point"

  # --- 5. Unresolvable range is NOT an empty range --------------------------
  # The single `if` wrapping the range_shas assignment is the whole mechanism.
  # Dropping it (the obvious "simplification") leaves the two states
  # indistinguishable and the reader with a remedy that cannot work.
  d="$TMP/$(printf '%s' "$copy" | tr '/.' '__')_unresolvable"; new_repo_no_remote "$d"
  add_commit "$d/work" a.md phrase
  run_check "$script" "$d/work"
  assert_eq "$RC" "1" "$copy: an unresolvable range fails closed even WITH the phrase"
  assert_contains "$OUT" "does not resolve" "$copy: unresolvable names its own cause"
  assert_absent "$OUT" "NOTHING VERIFIED" "$copy: unresolvable is not reported as empty"
  assert_absent "$OUT" "no OPS-0069 audit-trail phrase found" \
    "$copy: unresolvable is not reported as a phrase violation"
  assert_absent "$OUT" "local pre-push checks passed" "$copy: unresolvable claims no pass"

  d="$TMP/$(printf '%s' "$copy" | tr '/.' '__')_unresolvable_nophrase"; new_repo_no_remote "$d"
  add_commit "$d/work" a.md nophrase
  run_check "$script" "$d/work"
  assert_eq "$RC" "1" "$copy: an unresolvable range fails closed WITHOUT the phrase too"

  # --- 6. `git diff` FAILING is not an empty change set ---------------------
  # Unrelated histories make `git diff BASE...HEAD` exit 128. The status was
  # discarded, so zero files were linted and the run still printed the pass
  # banner — a green claim over work that could not be done.
  d="$TMP/$(printf '%s' "$copy" | tr '/.' '__')_difffail"; new_repo "$d"
  git -C "$d/work" checkout -q --orphan alt
  git -C "$d/work" rm -rq --cached . 2>/dev/null || true
  rm -f "$d/work"/*.md
  : > "$d/work/alt.md"
  git -C "$d/work" add -A
  git -C "$d/work" commit -q -m "unrelated root" -m "$PHRASE"
  git -C "$d/work" push -q -u origin alt
  git -C "$d/work" checkout -q main
  git -C "$d/work" checkout -q -b feat
  add_commit "$d/work" broken.md phrase
  git -C "$d/work" branch --set-upstream-to=origin/alt >/dev/null 2>&1
  run_check "$script" "$d/work"
  assert_eq "$RC" "1" "$copy: a git-diff malfunction fails closed"
  assert_contains "$OUT" "GATE MALFUNCTION" "$copy: the malfunction names itself"
  assert_absent "$OUT" "local pre-push checks passed" \
    "$copy: no pass banner when the changed-file list could not be computed"
  assert_absent "$OUT" "no changed files vs base" \
    "$copy: a failed diff is not reported as an empty change set"

  # --- 7. The two OPS-0069 exemptions, and the phrase they are not ----------
  # The empty/unresolvable arms were inserted FIRST in this if/elif chain, so the
  # chain's ordering is load-bearing. Both exemption arms survived replacement
  # with `false` at a fully green suite before these landed.
  d="$TMP/$(printf '%s' "$copy" | tr '/.' '__')_bot"; new_repo "$d"
  : > "$d/work/bot.md"
  git -C "$d/work" add -A
  git -C "$d/work" -c user.name='dependabot[bot]' commit -q -m "bump a dependency"
  run_check "$script" "$d/work"
  assert_eq "$RC" "0" "$copy: a bot-authored range is exempt from the phrase"
  assert_contains "$OUT" "bot-authored range" "$copy: the bot exemption names itself"

  d="$TMP/$(printf '%s' "$copy" | tr '/.' '__')_botmixed"; new_repo "$d"
  : > "$d/work/bot.md"; git -C "$d/work" add -A
  git -C "$d/work" -c user.name='dependabot[bot]' commit -q -m "bump a dependency"
  add_commit "$d/work" human.md nophrase
  run_check "$script" "$d/work"
  assert_eq "$RC" "1" "$copy: a MIXED bot+human range is NOT exempt"

  d="$TMP/$(printf '%s' "$copy" | tr '/.' '__')_revert"; new_repo "$d"
  : > "$d/work/r.md"; git -C "$d/work" add -A
  git -C "$d/work" commit -q -m 'Revert "add r"'
  run_check "$script" "$d/work"
  assert_eq "$RC" "0" "$copy: a revert-only range is exempt from the phrase"
  assert_contains "$OUT" "revert-only range" "$copy: the revert exemption names itself"

  d="$TMP/$(printf '%s' "$copy" | tr '/.' '__')_revertmixed"; new_repo "$d"
  : > "$d/work/r.md"; git -C "$d/work" add -A
  git -C "$d/work" commit -q -m 'Revert "add r"'
  add_commit "$d/work" normal.md nophrase
  run_check "$script" "$d/work"
  assert_eq "$RC" "1" "$copy: a MIXED revert+normal range is NOT exempt"

  d="$TMP/$(printf '%s' "$copy" | tr '/.' '__')_founder"; new_repo "$d"
  : > "$d/work/f.md"; git -C "$d/work" add -A
  git -C "$d/work" commit -q -m "add f" -m "Self-review skipped per founder OK urgent hotfix"
  run_check "$script" "$d/work"
  assert_eq "$RC" "0" "$copy: the founder-OK phrase satisfies OPS-0069"
  assert_contains "$OUT" "OPS-0069 audit-trail present" "$copy: founder-OK is accepted as the audit trail"

  # --- 9. PLAN-028 B3: the PROMOTION push -----------------------------------
  # The bug: a fast-forward promotion has an EMPTY range, and empty is a hard
  # failure — so canon's own gate refused every promotion the standard
  # prescribes. These assert the mode is a real check and not an escape hatch:
  # each of its three conditions must be able to REFUSE.

  # 9a. No declaration = no promotion path. This is the guard that keeps
  #     --promote from being a bypass any repo can invoke.
  d="$TMP/$(printf '%s' "$copy" | tr '/.' '__')_promo_undecl"; new_promo_repo "$d" ""
  run_check_args "$script" "$d/work" --promote staging
  assert_eq "$RC" "1" "$copy: --promote on a repo with NO declaration is refused"
  assert_contains "$OUT" "not a declared promotion branch" "$copy: names the missing declaration"
  assert_absent   "$OUT" "PROMOTION OK" "$copy: an undeclared promotion claims no pass"

  # 9b. A branch outside the declared set is refused even WITH a declaration.
  d="$TMP/$(printf '%s' "$copy" | tr '/.' '__')_promo_wrongtgt"; new_promo_repo "$d" "$PROMO_DECL"
  run_check_args "$script" "$d/work" --promote release
  assert_eq "$RC" "1" "$copy: --promote to an undeclared branch is refused"

  # 9c. The happy path: HEAD is origin/dev, staging does not exist yet.
  d="$TMP/$(printf '%s' "$copy" | tr '/.' '__')_promo_ok"; new_promo_repo "$d" "$PROMO_DECL"
  run_check_args "$script" "$d/work" --promote staging
  assert_eq "$RC" "0" "$copy: a genuine promotion of already-pushed content passes"
  assert_contains "$OUT" "PROMOTION OK" "$copy: the promotion reports its own pass"
  assert_contains "$OUT" "does not exist yet" "$copy: names why the fast-forward is trivial"
  assert_contains "$OUT" "NOT CHECKED" "$copy: states what it did NOT verify"

  # 9d. A LOCAL commit that was never pushed must not ride along on a
  #     promotion — it has never been through this gate.
  d="$TMP/$(printf '%s' "$copy" | tr '/.' '__')_promo_local"; new_promo_repo "$d" "$PROMO_DECL"
  add_commit "$d/work" sneaky.md nophrase
  run_check_args "$script" "$d/work" --promote staging
  assert_eq "$RC" "1" "$copy: an unpushed local commit blocks the promotion"
  assert_contains "$OUT" "not the tip of origin/dev" "$copy: names the real cause"
  assert_absent   "$OUT" "PROMOTION OK" "$copy: claims no pass with unreviewed content in the range"

  # 9e. A target holding a commit the integration branch does not = NOT a
  #     fast-forward. Promoting anyway would discard it.
  d="$TMP/$(printf '%s' "$copy" | tr '/.' '__')_promo_ff"; new_promo_repo "$d" "$PROMO_DECL"
  git -C "$d/work" checkout -q -b staging
  add_commit "$d/work" hotfix.md phrase
  git -C "$d/work" push -q -u origin staging
  git -C "$d/work" checkout -q dev
  run_check_args "$script" "$d/work" --promote staging
  assert_eq "$RC" "1" "$copy: a non-fast-forward promotion is refused"
  assert_contains "$OUT" "not a fast-forward" "$copy: names the divergence"

  # 9f. Argument handling fails loudly rather than falling through to the
  #     normal path, where a typo would look like a clean run.
  d="$TMP/$(printf '%s' "$copy" | tr '/.' '__')_promo_args"; new_promo_repo "$d" "$PROMO_DECL"
  run_check_args "$script" "$d/work" --promote
  assert_eq "$RC" "2" "$copy: --promote with no target exits 2"
  run_check_args "$script" "$d/work" --bogus
  assert_eq "$RC" "2" "$copy: an unknown argument exits 2"
  assert_absent "$OUT" "local pre-push checks passed" "$copy: a bad argument never reports a pass"

  # 9g. THE BEHAVIOUR-PRESERVING DEFAULT. A repo carrying a declaration must
  #     run the identical normal path when invoked with no arguments — the
  #     promotion mode is reachable only by asking for it.
  d="$TMP/$(printf '%s' "$copy" | tr '/.' '__')_promo_noargs"; new_promo_repo "$d" "$PROMO_DECL"
  add_commit "$d/work" work.md phrase
  run_check "$script" "$d/work"
  assert_eq "$RC" "0" "$copy: a declared repo with no arguments runs the normal path"
  assert_contains "$OUT" "OPS-0069 audit-trail present" "$copy: the normal phrase check still runs"
  assert_absent   "$OUT" "PROMOTION" "$copy: no argument, no promotion mode"

  # --- 10. The hook path. pre-commit runs this with NO arguments, so if the
  # no-argument path cannot recognise a promotion, `--promote` is unreachable on
  # a real `git push` and the push is blocked anyway — leaving --no-verify as
  # the only route, which disables every pre-push hook.
  d="$TMP/$(printf '%s' "$copy" | tr '/.' '__')_promoauto"; new_promo_repo "$d" "$PROMO_DECL"
  run_check "$script" "$d/work"
  assert_eq "$RC" "0" "$copy: a promotion-shaped push passes with NO arguments (the hook path)"
  assert_contains "$OUT" "PROMOTION-SHAPED push detected" "$copy: the no-argument path recognises the shape"
  assert_contains "$OUT" "PROMOTION OK" "$copy: and reports its own pass"

  # 10b. THE TEETH. An UNDECLARED repo must still hard-fail on an empty range —
  # the auto-detect must not become a general empty-range amnesty.
  d="$TMP/$(printf '%s' "$copy" | tr '/.' '__')_promoauto_undecl"; new_promo_repo "$d" ""
  run_check "$script" "$d/work"
  assert_eq "$RC" "1" "$copy: an UNDECLARED repo still hard-fails on an empty range"
  assert_contains "$OUT" "is EMPTY" "$copy: and still names the empty range"
  assert_absent   "$OUT" "PROMOTION OK" "$copy: no declaration, no auto-pass"

  # 10b-ii. THE DECLARATION TOOTH. A repo that HAS a declaration but declares
  # no promotion model must still hard-fail. This is the case that isolates the
  # PROMO_DECL check: with a file present, the integration branch DOES resolve
  # and HEAD IS its tip, so every other condition is satisfied — only "this repo
  # declared a promotion model" stands between it and an auto-pass. Without this
  # case, deleting that check leaves the suite green.
  d="$TMP/$(printf '%s' "$copy" | tr '/.' '__')_promoauto_single"; \
    new_promo_repo "$d" '{"version":1,"branching":{"model":"single-branch","integration_branch":"dev"}}'
  run_check "$script" "$d/work"
  assert_eq "$RC" "1" "$copy: a declared SINGLE-BRANCH repo still hard-fails on an empty range"
  assert_absent "$OUT" "PROMOTION OK" "$copy: no promotion model declared, no auto-pass"

  # 10b-iii. An explicit `"promotion_branches": []` is an opt-OUT and must be
  # honoured, not overwritten by the model default.
  d="$TMP/$(printf '%s' "$copy" | tr '/.' '__')_promoauto_optout"; \
    new_promo_repo "$d" '{"version":1,"branching":{"model":"dev-staging-main","integration_branch":"dev","promotion_branches":[]}}'
  run_check_args "$script" "$d/work" --promote staging
  assert_eq "$RC" "1" "$copy: an explicit empty promotion_branches is an opt-out, not the model default"
  assert_contains "$OUT" "not a declared promotion branch" "$copy: and says so"

  # 10c. THE OTHER TOOTH. An EMPTY range on a branch that is NOT the integration
  # tip must still hard-fail — re-pushing an already-pushed feature branch is the
  # everyday case, and the auto-detect must not swallow it. This is the assertion
  # that fails if the HEAD == origin/<integration> condition is removed; a test
  # using a NEW local commit cannot reach it, because a new commit makes the
  # range non-empty and the empty-range arm never runs.
  d="$TMP/$(printf '%s' "$copy" | tr '/.' '__')_promoauto_offtip"; new_promo_repo "$d" "$PROMO_DECL"
  git -C "$d/work" checkout -q -b feat
  add_commit "$d/work" feat.md phrase
  git -C "$d/work" push -q -u origin feat
  run_check "$script" "$d/work"
  assert_eq "$RC" "1" "$copy: an empty range on a NON-integration branch still hard-fails"
  assert_absent "$OUT" "PROMOTION OK" "$copy: an already-pushed feature branch is not a promotion"
  assert_contains "$OUT" "is EMPTY" "$copy: and is still reported as the empty range it is"

  # 10d. A local commit moves HEAD off origin's tip; content that never went
  # through this gate must not ride along.
  d="$TMP/$(printf '%s' "$copy" | tr '/.' '__')_promoauto_local"; new_promo_repo "$d" "$PROMO_DECL"
  add_commit "$d/work" local.md nophrase
  run_check "$script" "$d/work"
  assert_absent "$OUT" "PROMOTION-SHAPED" "$copy: unpushed content is not a promotion shape"
  assert_eq "$RC" "1" "$copy: and the phrase check still refuses it"

  # --- 11. git invokes a pre-push hook as `hook <remote> <url>`. A consumer
  # symlinking this straight into .git/hooks/pre-push worked before the parser
  # existed and must keep working.
  d="$TMP/$(printf '%s' "$copy" | tr '/.' '__')_gitargs"; new_repo "$d"
  add_commit "$d/work" hookarg.md phrase
  run_check_args "$script" "$d/work" origin "https://example.invalid/r.git"
  assert_eq "$RC" "0" "$copy: git's positional hook arguments are ignored, not rejected"
  assert_absent "$OUT" "unknown" "$copy: and are not reported as unknown"
  run_check_args "$script" "$d/work" --bogus
  assert_eq "$RC" "2" "$copy: an unknown OPTION is still refused"
done

# --- 8. Byte-identity drift guard (#477) --------------------------------------
# Replaces the sed-scoped hunk comparison that let the BASE= divergence age.
# `cmp`, not `$(cat) == $(cat)`: command substitution strips TRAILING newlines,
# so the string form calls two files identical when one ends in extra blank
# lines — measured, and `end-of-file-fixer` is a live hook here.
echo "== canon/template drift =="
assert_ok "[ -s '$ROOT/scripts/pre_push_check.sh' ]"           "canon pre_push_check.sh is non-empty"
assert_ok "[ -s '$ROOT/install/templates/pre_push_check.sh' ]" "template pre_push_check.sh is non-empty"
assert_ok "cmp -s '$ROOT/scripts/pre_push_check.sh' '$ROOT/install/templates/pre_push_check.sh'" \
  "scripts/ and install/templates/ pre_push_check.sh are identical, byte-for-byte"

suite_summary "test_pre_push_range"
