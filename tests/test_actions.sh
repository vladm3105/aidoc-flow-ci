#!/usr/bin/env bash
# tests/test_actions.sh — contract for the v3 COMPOSITE ACTIONS (PLAN-025 §3.1).
#
# A composite action shares the caller's runner, which is the whole point: a
# `workflow_call` reusable gets its own runner, so twelve checks cost twelve
# provisioning cycles. Sharing a runner also means these actions inherit the
# caller's working tree and token, so the defenses that used to live in each
# reusable's own job have to be asserted HERE instead — nothing else checks them.
#
# Each assertion below maps to a PLAN-025 §2 defense row and exists because that
# defense was paid for once already. Do not relax one without amending §2.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
cd "$ROOT"

mapfile -t ACTIONS < <(find actions -name action.yml 2>/dev/null | sort)

echo "== composite actions exist =="
if [ "${#ACTIONS[@]}" -eq 0 ]; then
  _r "no actions/*/action.yml found — PLAN-025 P2 has not landed"
  suite_summary "test_actions.sh"; exit $?
fi
_g "found ${#ACTIONS[@]} composite action(s)"

for a in "${ACTIONS[@]}"; do
  name="$(basename "$(dirname "$a")")"
  body="$(cat "$a")"

  echo "== $name =="

  assert_ok "python3 -c \"import yaml,sys; yaml.safe_load(open('$a'))\"" \
    "$name: valid YAML"

  assert_contains "$body" "using: composite" \
    "$name: declares 'using: composite'"

  # D-checkout (PLAN-025 §3.2): checkout is the CALLER's job — the shared tree is
  # where the saving comes from, and a second checkout inside an action would
  # clobber a tree another action already depends on.
  assert_absent "$body" "actions/checkout" \
    "$name: does NOT check out (caller owns the tree)"

  # D5 (REPO_STANDARDS §4.3): every `uses:` SHA-pinned. A git tag is
  # attacker-mutable state on infrastructure we do not control, and these
  # actions run on the ephemeral pool, which re-resolves refs every run — a
  # moved tag reaches the whole fleet in one CI cycle.
  unpinned="$(grep -nE '^\s*uses:\s' "$a" | grep -vE 'uses:\s*[^@]+@[0-9a-f]{40}' || true)"
  if [ -z "$unpinned" ]; then
    _g "$name: every 'uses:' is SHA-pinned (D5)"
  else
    _r "$name: unpinned 'uses:' — $unpinned"
  fi

  # A composite action's `run:` steps MUST declare a shell; GitHub does not
  # default one (unlike a workflow job), and omitting it is a load error.
  runs="$(grep -c '^\s*run: |' "$a" || true)"
  shells="$(grep -c '^\s*shell: bash' "$a" || true)"
  assert_eq "$runs" "$shells" "$name: every run: has 'shell: bash' ($runs run / $shells shell)"

  # D15 (REPO_STANDARDS §24.1): GitHub already applies an implicit `bash -e`, so
  # a step that does not set its own strict mode aborts at the first non-zero
  # BEFORE any guard can forgive it. Declaring it makes the behaviour explicit
  # and adds -u/-o pipefail.
  if [ "$runs" -gt 0 ]; then
    assert_contains "$body" "set -euo pipefail" "$name: run: uses strict mode (D15)"
  fi
done

echo "== tool parity (PLAN-025 §3.3) =="
# The CI check and the local hook must run the SAME markdownlint. The
# pre-commit ecosystem's usual hook is markdownlint-cli (v1) with different
# ignore semantics; a mismatch means local passes and CI reds, which trains
# contributors to bypass hooks.
if [ -f actions/markdownlint/action.yml ]; then
  ml="$(cat actions/markdownlint/action.yml)"
  assert_contains "$ml" "markdownlint-cli2@" "markdownlint: pins cli2 with a version"
  # cli1 would appear as `markdownlint-cli@` — the `2` is what distinguishes them.
  assert_absent "$ml" "markdownlint-cli@" "markdownlint: does NOT use cli1"
  assert_contains "$ml" "--ignore-scripts" "markdownlint: npm install skips lifecycle scripts"
fi

echo "== quick-gates caller (PLAN-025 §3.2) =="
QG=install/templates/workflows/quick-gates.yml
if [ -f "$QG" ]; then
  qg="$(cat "$QG")"

  # D3 / CI-0025 / §23: an allowlist, never a blanket cancel. This job feeds a
  # required context, and a cancelled required check is not success — it is
  # retained alongside any later success, so the rollup stays FAILURE.
  assert_contains "$qg" 'contains(fromJSON(' "quick-gates: concurrency uses the §23 allowlist (D3)"
  assert_absent "$qg" "cancel-in-progress: true" "quick-gates: no blanket cancel (D3)"

  # D4: the job id renders the required context `call / quick-gates`.
  assert_contains "$qg" "  quick-gates:" "quick-gates: job id is 'quick-gates' (D4)"

  # audit-trail's fork-PR false-pass guard needs full history at the PR head, and
  # the shared checkout must satisfy the strictest consumer.
  assert_contains "$qg" "fetch-depth: 0" "quick-gates: full history for audit-trail"
  assert_contains "$qg" "persist-credentials: false" "quick-gates: no persisted creds"

  # D7: this job runs pre-commit over the PR's own files — fork-code execution.
  # The public variant must stay ubuntu-latest; moving it to the self-hosted
  # pool is the untrusted-code leak.
  assert_contains "$qg" "runs-on: ubuntu-latest" "quick-gates: public variant is ubuntu-latest (D7)"

  # composition fires on pull_request_review/workflow_run, so it cannot share
  # this job's trigger. Catching it here stops the consolidation from silently
  # swallowing a check that would then never run.
  assert_absent "$qg" "actions/composition" "quick-gates: does not absorb composition (different trigger)"

  if command -v actionlint >/dev/null 2>&1; then
    assert_ok "actionlint '$QG' >/dev/null 2>&1" "quick-gates: actionlint clean"
  else
    printf '  \033[33mskip\033[0m actionlint not installed\n'
  fi
else
  _r "quick-gates caller template missing"
fi

suite_summary "test_actions.sh"
