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
  #
  # PARSE, DO NOT GREP. The first version of this counted `grep -c '^\s*run: |'`,
  # which matches only the block-scalar spelling — so an action written
  # `run: npm ci` yielded 0 run / 0 shell, the equality passed VACUOUSLY, and the
  # strict-mode assertion below was skipped by the `-gt 0` guard. A measurement
  # mutation (verified 2026-08-08) sailed through the whole suite while shipping
  # an action GitHub would refuse to load. A test extractor must fail closed.
  # FAIL CLOSED — this is the SECOND instance of the same class, found inside the
  # fix for the first. The parsing version above still failed open two ways: a
  # raising extractor prints nothing, `read` assigns three empty strings, and
  # `assert_eq "" ""` reports PASS; and a `steps:` that is a scalar rather than a
  # list yields 0/0/0, so a structurally invalid action passed every assertion
  # (verified 2026-08-08). So the extractor now emits a sentinel and asserts the
  # SHAPE of its own output before any count is trusted.
  parsed="$(python3 - "$a" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1])) or {}
runs_block = d.get("runs")
if not isinstance(runs_block, dict):
    print("BADSHAPE runs-not-a-mapping"); raise SystemExit(0)
steps = runs_block.get("steps")
if not isinstance(steps, list):
    print("BADSHAPE steps-not-a-list"); raise SystemExit(0)
if any(not isinstance(s, dict) for s in steps):
    print("BADSHAPE step-not-a-mapping"); raise SystemExit(0)
runs = [s for s in steps if "run" in s]
shells = [s for s in runs if s.get("shell") == "bash"]
strict = [s for s in runs if "set -euo pipefail" in str(s.get("run", ""))]
print("OK", len(runs), len(shells), len(strict))
PY
  )" || parsed="CRASH"
  read -r tag runs shells strict <<< "$parsed"
  if [ "$tag" != "OK" ]; then
    _r "$name: step extractor could not read this action ($parsed) — refusing to report pass"
    runs=-1; shells=-2; strict=-3   # guarantee the assertions below also fail
  fi
  assert_eq "$runs" "$shells" "$name: every run: has 'shell: bash' ($runs run / $shells shell)"

  # D15 (REPO_STANDARDS §24.1): GitHub already applies an implicit `bash -e`, so
  # a step that does not set its own strict mode aborts at the first non-zero
  # BEFORE any guard can forgive it. Asserted PER STEP, not "somewhere in the
  # file" — one strict step must not vouch for four sloppy ones.
  assert_eq "$runs" "$strict" "$name: every run: sets strict mode ($strict/$runs) (D15)"

  # D21: canon may `uses:` only actions/*, github/* or vladm3105/*. A marketplace
  # action is a run-init `startup_failure` with a web-UI-only message that
  # actionlint does not catch, in every consumer at once.
  #
  # PARSED, not grepped — the first version matched the literal text `uses:`
  # inside a COMMENT explaining this very rule, and reported the prose as a
  # non-allowlisted owner. Grepping a structured file for a key finds the key's
  # name wherever it appears, including in the documentation of the key.
  badowner="$(python3 - "$a" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1])) or {}
ok = ("actions/", "github/", "vladm3105/")
for s in ((d.get("runs") or {}).get("steps") or []):
    u = s.get("uses") if isinstance(s, dict) else None
    if u and not u.startswith(ok):
        print(u)
PY
  )"
  if [ -z "$badowner" ]; then
    _g "$name: every 'uses:' is an allowlisted owner (D21)"
  else
    _r "$name: non-allowlisted action owner — $badowner"
  fi

  # D20: any action that downloads a binary MUST verify it before executing it.
  # D21 forces these bodies to curl their own tools instead of using a
  # marketplace action, so the integrity check is the only thing standing
  # between a substituted release asset and code execution on the runner.
  # Added after a mutation deleting `sha256sum -c` survived the whole suite.
  if printf '%s' "$body" | grep -qE 'curl .*(-o|--output|>)'; then
    if printf '%s' "$body" | grep -qE 'sha256sum (-c|--check)'; then
      _g "$name: downloads a binary and SHA-256 verifies it (D20)"
    else
      _r "$name: downloads a binary with NO checksum verification (D20)"
    fi
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

  # D4: the job id renders the required context `quick-gates`.
  assert_contains "$qg" "  quick-gates:" "quick-gates: job id is 'quick-gates' (D4)"

  # The shared checkout must NOT pin a ref. On `pull_request` the default is the
  # MERGE commit, which is what the v2 pre-commit/markdown-lint/links reusables
  # lint. An earlier draft pinned `pull_request.head.sha` (copied from
  # audit-trail), which lints the branch TIP — so a PR whose merge result is
  # dirty but whose tip is clean would go green. Weaker, not stricter.
  assert_absent "$qg" "ref: \${{ github.event.pull_request.head.sha }}" \
    "quick-gates: no head.sha pin — lints the merge commit like v2"
  assert_contains "$qg" "persist-credentials: false" "quick-gates: no persisted creds"

  # audit-trail is deliberately NOT consolidated here (PLAN-025 §3.2d): it needs
  # label types the other checks must not have, a job-level event refusal (D31),
  # and the D36 credential asymmetry. Three defenses for one provisioning cycle.
  assert_absent "$qg" "actions/audit-trail" \
    "quick-gates: does not absorb audit-trail (types/D31/D36 conflict)"

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

echo "== links posture: internal blocks, external is weekly and report-only (D42) =="
# The v2 split is a defense: external link rot is TIME-based, so blocking a PR on
# a third party's 429 is a false signal — but the check must still run. An
# earlier draft defaulted the action to mode=external and passed nothing from
# quick-gates, which would have made the REQUIRED gate do live network calls.
LA=actions/links/action.yml
if [ -f "$LA" ]; then
  la="$(cat "$LA")"
  assert_contains "$la" "default: 'internal'" "links action: defaults to internal (offline), not external"
  assert_contains "$la" "default: '.lychee.toml'" "links action: default config path is the one canon installs"
fi
if [ -f "$QG" ]; then
  # Explicit beats inherited on a required gate.
  assert_contains "$qg" "mode: internal" "quick-gates: passes mode explicitly"
  assert_contains "$qg" "config-file: .lychee.toml" "quick-gates: passes the config path explicitly"
  assert_contains "$qg" "github-token:" "quick-gates: passes the token (no secrets context inside an action)"
fi
LX=install/templates/workflows/links-external.yml
if [ -f "$LX" ]; then
  lx="$(cat "$LX")"
  assert_contains "$lx" "schedule:" "links-external: is scheduled"
  assert_contains "$lx" "mode: external" "links-external: checks external URLs"
  assert_contains "$lx" "fail-on-error: 'false'" "links-external: report-only, never blocking"
else
  _r "links-external.yml missing — adopting quick-gates would drop external link checking entirely (D42)"
fi

echo "== forward pins are marker-guarded (blocker found in the final review) =="
# `sync-version-refs --check` is a DEFAULT-STAGE, always_run pre-commit hook, so
# it runs on every commit AND inside canon's `call / Lint / format / security
# hooks` required context. A v3 template pinning `@ci/v3.0.0` while VERSION is
# ci/v2.16.0 reports STALE and reds the branch. Worse, the rewriter's suggested
# remedy would point the pin at a tag where `actions/` does not exist.
# These are forward references (FT-21 shape) and need the ignore markers.
for tpl in install/templates/workflows/quick-gates.yml \
           install/templates/workflows/quick-gates-private.yml \
           install/templates/workflows/links-external.yml; do
  [ -f "$tpl" ] || continue
  b="$(basename "$tpl")"
  if grep -q 'vladm3105/aidoc-flow-ci/actions/.*@ci/v' "$tpl"; then
    if grep -q 'sync-version-refs:ignore-start' "$tpl" && grep -q 'sync-version-refs:ignore-end' "$tpl"; then
      _g "$b: forward pin is inside ignore markers"
    else
      _r "$b: pins a v3 action with NO ignore markers — sync-version-refs --check will red the branch"
    fi
  fi
done
if command -v bash >/dev/null && [ -x scripts/sync-version-refs.sh ]; then
  assert_ok "bash scripts/sync-version-refs.sh --check >/dev/null 2>&1" \
    "sync-version-refs --check passes (the gate that blocks the branch)"
fi

echo "== private variant (D1) =="
# D1: install.sh --update resolves each surface through manifest.json's
# visibility_variants. With no private variant it re-applies the label-less
# generic, the ubuntu-latest default wins, and jobs QUEUE FOREVER on a private
# repo — the defect ci/v2.1.0 shipped the variants to close.
QGP=install/templates/workflows/quick-gates-private.yml
if [ -f "$QGP" ]; then
  qgp="$(cat "$QGP")"

  # Assert the LABEL LINE, not the file. `assert_contains "$qgp" "self-hosted"`
  # is satisfied by the header comment that explains the private variant, so it
  # would survive a revert of runs-on: to ubuntu-latest — the same
  # grep-the-key's-own-documentation failure this suite already fixed for D21.
  runsline="$(grep -E '^\s*runs-on:' "$QGP" || true)"
  assert_contains "$runsline" "self-hosted" "quick-gates-private: runs-on line uses the self-hosted pool (D1/OPS-0049)"
  assert_contains "$runsline" "ci-runner" "quick-gates-private: runs-on names the real pool label"
  # 'runner-self' was a placeholder shipped before ci/v1.9.0 and is NOT a
  # registered label — a caller left on it queues forever.
  assert_absent "$runsline" "runner-self" "quick-gates-private: not the dead 'runner-self' placeholder"

  # The private variant carries D3, D4, D9 and the checkout posture exactly as
  # the public one does, and NOTHING else in the repo reaches it:
  # test_contract.sh's caller checks key off `runner_labels` (v3 uses a literal
  # runs-on, so they skip), and its CI-0025 evaluator builds its set from
  # required-context-map.py, which only sees jobs whose body is `uses:` a
  # reusable. Per §3.2a, a defense that moved to a file nothing checks is a
  # defense that was dropped — so assert the two files are identical apart from
  # the documented runner line and header block.
  assert_contains "$qgp" 'contains(fromJSON(' "quick-gates-private: §23 allowlist (D3)"
  assert_absent "$qgp" "cancel-in-progress: true" "quick-gates-private: no blanket cancel (D3)"
  assert_contains "$qgp" "  quick-gates:" "quick-gates-private: same job id, same context (D4)"
  assert_contains "$qgp" "persist-credentials: false" "quick-gates-private: no persisted creds"
  assert_absent "$qgp" "ref: \${{ github.event.pull_request.head.sha }}" \
    "quick-gates-private: no head.sha pin — merge-commit parity"
  assert_contains "$qgp" "contents: read" "quick-gates-private: least-privilege grant (D9)"

  # Drift guard: normalise the two known deltas and require the rest to match.
  # Without this the variants diverge silently, which is what regenerating one
  # by script was meant to prevent — and a script can be run once and forgotten.
  if command -v diff >/dev/null 2>&1; then
    d="$(diff <(sed -E 's/^\s*runs-on:.*/RUNNER/' "$QGP" | sed -n '/^name:/,$p') \
              <(sed -E 's/^\s*runs-on:.*/RUNNER/' "$QG"  | sed -n '/^name:/,$p') | grep -c '^[<>]' || true)"
    assert_eq "$d" "0" "quick-gates public/private bodies identical below the header (drift guard)"
  fi

  if command -v actionlint >/dev/null 2>&1; then
    assert_ok "actionlint '$QGP' >/dev/null 2>&1" "quick-gates-private: actionlint clean (needs .github/actionlint.yaml)"
  fi
else
  _r "quick-gates-private variant missing — --update will revert private consumers to ubuntu-latest (D1)"
fi

echo "== actionlint knows the self-hosted labels (PLAN-025 §3.2e) =="
# v3 callers carry a LITERAL runs-on with custom labels (v2 passed a JSON string
# input, so actionlint never saw a label). Without this config every private
# caller fails actionlint — here, in pre_push_check.sh, and on every consumer.
AL=.github/actionlint.yaml
if [ -f "$AL" ]; then
  al="$(cat "$AL")"
  assert_contains "$al" "ci-runner" "actionlint.yaml declares ci-runner"
  assert_contains "$al" "single-use" "actionlint.yaml declares single-use"
else
  _r "no .github/actionlint.yaml — every private v3 caller fails the runner-label rule"
fi

echo "== every referenced action resolves =="
# A caller naming an action that does not exist in the tree is a run-init
# `startup_failure` on every consumer — the same invisible class as an
# unmatched runner label, and nothing else in the suite catches it. The first
# quick-gates draft referenced three actions that had not been written.
missing=0
while IFS= read -r ref; do
  [ -n "$ref" ] || continue
  act="${ref#vladm3105/aidoc-flow-ci/actions/}"; act="${act%@*}"
  if [ -f "actions/$act/action.yml" ]; then
    _g "resolves: actions/$act/action.yml"
  else
    _r "DANGLING: '$ref' has no actions/$act/action.yml"
    missing=$((missing+1))
  fi
done < <(grep -rhoE 'vladm3105/aidoc-flow-ci/actions/[^@[:space:]]+@[^[:space:]]+' \
           install/templates/workflows/ .github/workflows/ 2>/dev/null | sort -u)
[ "$missing" -eq 0 ] || printf '  \033[33mnote\033[0m %d dangling reference(s) — the caller will startup_failure\n' "$missing"

echo "== timeout is the SUM of absorbed budgets (PLAN-025 §3.2b) =="
# v2: pre-commit 15 + markdownlint 10 + links 20 = 45. A consolidated job that
# takes the MAX kills checks that already passed when the slowest one runs long.
if [ -f "$QG" ]; then
  tmo="$(grep -oE 'timeout-minutes: [0-9]+' "$QG" | grep -oE '[0-9]+' || echo 0)"
  if [ "${tmo:-0}" -ge 45 ]; then
    _g "quick-gates: timeout ${tmo} >= 45 (sum of absorbed budgets)"
  else
    _r "quick-gates: timeout ${tmo} < 45 — a slow links run would kill passed checks"
  fi
fi

suite_summary "test_actions.sh"
