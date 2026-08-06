#!/usr/bin/env bash
# tests/test_contract.sh — workflow-contract tests. These assert the invariants
# whose violation shipped as silent startup_failures during the 2026-07 rollout:
#   - a reusable that wraps a THIRD-PARTY action (allowed-actions block)
#   - a caller missing the permissions: block (composition/ai-review)
#   - an invalid runner_labels JSON string
#   - a floating / unpinned uses: ref
# Run from the repo root. No network / gh needed — pure static analysis.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
# `|| exit` (SC2164): every assertion below uses repo-relative paths, so a failed
# cd would silently run the whole suite against the wrong tree and pass.
cd "$ROOT" || exit 1

# allowlist: uses: owners permitted by the actions-permissions policy.
allowed_use() { # $1 = the ref after 'uses:'
  case "$1" in
    actions/*|github/*|vladm3105/aidoc-flow-ci/*|./*) return 0 ;;
    *) return 1 ;;
  esac
}

echo "== reusable-workflow contracts (.github/workflows/) =="
for wf in .github/workflows/*.yml; do
  [ -f "$wf" ] || continue
  name="$(basename "$wf")"
  # only the reusables (workflow_call) carry the reusable contract
  grep -qE '^\s*workflow_call:' "$wf" || continue
  # 1. must declare a top-level permissions: block
  assert_ok "grep -qE '^permissions:|^  +permissions:' '$wf'" "$name: declares permissions (top-level or job-level)"
  # 2. every uses: is on the allowlist (no third-party marketplace action)
  bad=""
  while read -r ref; do
    ref="${ref%%@*}"; [ -z "$ref" ] && continue
    allowed_use "$ref" || bad="$bad $ref"
  done < <(grep -oE '^[[:space:]]*uses:[[:space:]]*[^[:space:]#]+' "$wf" | sed -E 's/^[[:space:]]*uses:[[:space:]]*//')
  assert_eq "$bad" "" "$name: all uses: on allowlist (no third-party action)"
  # 3. no floating refs (@main/@master/@vN with no SHA/semver) on external actions
  float="$(grep -oE 'uses:[[:space:]]*(actions|github)/[^@]+@(main|master)' "$wf" || true)"
  assert_eq "$float" "" "$name: no @main/@master floating action pins"
done

echo "== caller-template contracts (install/templates/workflows/) =="
for tpl in install/templates/workflows/*.yml; do
  [ -f "$tpl" ] || continue
  name="$(basename "$tpl")"
  # pinned at a real @ci/v tag (not @main)
  assert_ok "grep -qE 'vladm3105/aidoc-flow-ci/[^@]+@ci/v[0-9.]+' '$tpl'" "$name: pins @ci/vX.Y.Z"
  assert_absent "$(cat "$tpl")" 'aidoc-flow-ci/.github/workflows/'"$(: )"'@main' "$name: no @main pin"
  # ai-review + composition callers MUST carry a permissions: block (startup_failure otherwise).
  # NB `ai-review.yml` (no suffix) is the PLAN-013 single protected template — match it too.
  case "$name" in
    ai-review.yml|ai-review-*.yml|composition-*.yml)
      assert_ok "grep -qE '^permissions:' '$tpl'" "$name: has permissions: block (avoids startup_failure)" ;;
  esac
  # private variants must carry a VALID JSON runner_labels array
  case "$name" in
    *-private.yml)
      rl="$(python3 - "$tpl" <<'PYEOF'
import yaml, sys, json
d = yaml.safe_load(open(sys.argv[1]))
def find(o):
    if isinstance(o, dict):
        if 'runner_labels' in o: return o['runner_labels']
        for v in o.values():
            r = find(v)
            if r is not None: return r
    return None
rl = find(d)
print(json.dumps(rl) if rl is not None else '')
PYEOF
)"
      if [ -n "$rl" ]; then
        # rl is JSON-encoded; a valid runner_labels input is itself a JSON string
        # holding a JSON array, so decode twice.
        inner="$(printf '%s' "$rl" | jq -r . 2>/dev/null)"
        if printf '%s' "$inner" | jq -e 'type=="array"' >/dev/null 2>&1; then
          _g "$name: runner_labels is a valid JSON array"
        else _r "$name: runner_labels INVALID ($rl)"; fi
        assert_contains "$inner" 'ci-runner' "$name: runner_labels targets ci-runner"
        assert_contains "$inner" 'single-use' "$name: runner_labels targets single-use"
      fi ;;
  esac
done

echo "== PLAN-013 uniform protected AI-flows (public+private, one self-hosted template) =="
# The AI-flow callers ship as ONE protected template each — no -public/-private
# split — so a repo visibility flip is a no-op. Each MUST carry self-hosted labels,
# have NO variant siblings, and NO visibility_variants in the manifest.
for flow in ai-review doc-maintainer docs-sync; do
  tpl="install/templates/workflows/${flow}.yml"
  assert_ok "test -f '$tpl'" "AI-flow $flow: single protected template exists"
  assert_absent "$(ls install/templates/workflows/ 2>/dev/null)" "${flow}-private.yml" "AI-flow $flow: no -private variant (uniform)"
  assert_absent "$(ls install/templates/workflows/ 2>/dev/null)" "${flow}-public.yml" "AI-flow $flow: no -public variant (uniform)"
  assert_ok "grep -q 'self-hosted' '$tpl' && grep -q 'single-use' '$tpl'" "AI-flow $flow: single template carries the self-hosted pool label"
  # manifest entry must NOT branch on visibility (flip = no-op)
  novar="$(python3 - "$flow" <<'PYEOF'
import json, sys
flow = sys.argv[1]
m = json.load(open("install/templates/manifest.json"))
e = next((f for f in m["files"] if f["path"] == f".github/workflows/{flow}.yml"), None)
print("MISSING" if e is None else ("HAS_VARIANTS" if "visibility_variants" in e else "OK"))
PYEOF
)"
  assert_contains "$novar" "OK" "AI-flow $flow: manifest entry has NO visibility_variants (flip is a no-op)"
done
# The wizard label-injector must recognize runner_labels_routine/_review (ai-review's
# inputs) so it does NOT inject a spurious bare `runner_labels:` into the single
# ai-review template — that is an undeclared reusable input → startup_failure.
assert_ok "grep -q 'runner_labels_routine' install/deploy-ci-wizard.sh && grep -q 'runner_labels_review' install/deploy-ci-wizard.sh" "wizard injector recognizes runner_labels_routine/_review (no spurious bare runner_labels on AI-flow singles)"

echo "== production-hardening contracts =="
assert_ok "grep -q 'GL_LINUX_X64_SHA256' .github/workflows/secret-scan.yml && grep -q 'sha256sum --check --strict' .github/workflows/secret-scan.yml" "secret-scan verifies the pinned gitleaks artifact"
secret_body="$(cat .github/workflows/secret-scan.yml)"
assert_absent "$secret_body" "'''(^|/)tests?/'''" "secret-scan does not blanket-exclude tests"
assert_absent "$secret_body" "fixtures|testdata|examples" "secret-scan does not blanket-exclude fixtures/examples"
assert_ok "grep -q 'pre-commit==.*PRE_COMMIT_VERSION' .github/workflows/pre-commit.yml" "pre-commit framework install is version-pinned"
assert_ok "grep -q 'actionlint_1.7.12_linux_amd64' .github/workflows/tests.yml && grep -q 'sha256sum --check --strict' .github/workflows/tests.yml" "actionlint binary is version-pinned and hash-verified"
assert_absent "$(cat .github/workflows/tests.yml)" 'actionlint@latest' "tests do not install floating actionlint"
for workflow in .github/workflows/tests.yml .github/workflows/links.yml .github/workflows/secret-scan.yml; do
  assert_ok "grep -q 'BIN_DIR=\"\$RUNNER_TEMP/bin\"' '$workflow' && grep -q 'mkdir -p \"\$BIN_DIR\"' '$workflow'" "$(basename "$workflow"): downloaded binary uses the canonical job-scoped bin directory"
done
assert_absent "$(cat .github/workflows/tests.yml)" '$HOME/.local/bin/actionlint' "actionlint install does not assume a user-local directory exists"
# FT-47: CI must exercise the ruamel.yaml merge backend, not only PyYAML — the
# ruamel path is install.sh's PREFERRED one and PyYAML-only CI let FT-44's
# ruamel-specific __ne__ bug slip past. Assert tests.yml installs ruamel AND
# re-runs a merge test under it.
assert_ok "grep -q 'python3-ruamel.yaml' .github/workflows/tests.yml && grep -q 'test_precommit_refresh.sh' .github/workflows/tests.yml && grep -q 'test_precommit_merge.sh' .github/workflows/tests.yml" "tests.yml exercises the ruamel.yaml merge backend (both merge + refresh), not only PyYAML (FT-47)"
assert_absent "$(cat install/templates/workflows/markdown-lint.yml)" $'    # with:\n    #   runner_labels:' "markdown-lint template does not suggest a duplicate with block"
# FT-41: markdown-lint's fail-on-findings input defaults to TRUE (blocking gate).
# The three report-only scanners (dep-scan/trivy/sast) assert their CALLERS ship
# `fail-on-findings: false`; the inverse invariant — the markdown-lint REUSABLE
# blocks by DEFAULT — was unasserted, so flipping its default to false would
# silently turn every consumer's markdown gate report-only with the suite green.
# Parse the input default (a bare `grep 'default: true'` would match any input).
mdl_default="$(python3 - .github/workflows/markdown-lint.yml <<'PYEOF'
import yaml, sys
d = yaml.safe_load(open(sys.argv[1]))
on = d.get(True, d.get("on", {}))   # PyYAML parses bare `on:` as boolean True
wc = on.get("workflow_call", {}) if isinstance(on, dict) else {}
inp = (wc.get("inputs") or {}).get("fail-on-findings", {})
print(repr(inp.get("default")))
PYEOF
)"
assert_eq "$mdl_default" "True" "markdown-lint fail-on-findings input defaults to True (blocking gate; FT-41 — a flip to false must go red)"
assert_absent "$(grep 'git commit' .github/workflows/doc-maintainer.yml)" '[skip ci]' "doc-maintainer bot commits do not suppress normal CI"
# Asserts the STEP, not its action version: a version literal here makes the
# assertion a dependabot tripwire that fails on a bump which changes nothing it
# claims to test (it did, on #365). Floating/unpinned refs are already covered
# generically above. What must hold is that the dry-run patch is uploaded and
# that a missing patch fails the step rather than passing silently.
assert_ok "python3 - <<'PYEOF'
import sys, yaml
d = yaml.safe_load(open('.github/workflows/doc-maintainer.yml'))
steps = [s for j in d['jobs'].values() for s in j.get('steps', [])]
up = [s for s in steps
      if str(s.get('uses', '')).startswith('actions/upload-artifact@')
      and s.get('with', {}).get('path') == '.doc-maintainer-proposed.patch']
sys.exit(0 if len(up) == 1 and up[0]['with'].get('if-no-files-found') == 'error' else 1)
PYEOF" "doc-maintainer preserves dry-run patches as an artifact"
assert_ok "jq -e '.auto_merge.high_risk_paths | index(\"**/DECISIONS.md\") and index(\"**/ROADMAP.md\") and index(\"**/HANDOFF.md\")' install/templates/doc-maintainer.json >/dev/null" "nested governance documents are high-risk by default"
assert_ok "jq -e '.allowed_paths | index(\"DECISIONS.md\")' install/templates/doc-maintainer.json >/dev/null" "high-risk root decisions file is consistently allowlisted"
# §24.3 — a default canon recommends must be executable by the code that
# consumes it. `low_risk_paths` is the knob that matters: it is what routes a
# path into apply.py, the only holder of the 200 KB refusal. So CHANGELOG.md
# must NOT be low-risk.
assert_ok "jq -e '.auto_merge.low_risk_paths | index(\"CHANGELOG.md\") | not' install/templates/doc-maintainer.json >/dev/null" "#354 the template does not mark CHANGELOG.md low-risk — apply refuses it once it passes 200 KB, and a changelog only grows"
# ...and it must STAY allowlisted. De-allowlisting relocates the failure rather
# than removing it: the conventions template canon installs alongside this file
# tells the model to use CHANGELOG.md and the merge's changed-file list reaches
# it unfiltered, so it is still proposed — and a non-allowlisted proposal is a
# run-killing `return 1`, where a high-risk one is an issue for a human.
# #360 narrowed the INVENTORY, which was the third route, and added an allowlist
# imperative — advisory, not enforcement (§20.2 rule 8), so this pair stands.
# Reverse this pair and a fresh adopter's first changelog-touching merge reds.
assert_ok "jq -e '(.allowed_paths | index(\"CHANGELOG.md\")) != null and (.auto_merge.high_risk_paths | index(\"CHANGELOG.md\")) != null' install/templates/doc-maintainer.json >/dev/null" "#354 CHANGELOG.md stays allowlisted and is high-risk, so a proposal reaches a human instead of failing the run"
assert_ok "grep -q 'CHANGELOG.md' install/templates/doc-maintainer-conventions.md" "#354 the conventions template still names CHANGELOG.md — the pair above is what keeps canon from contradicting itself (§24.3)"
# One declaration of the limit, imported rather than copied. An untested
# duplicate drifts, and the planner would then pre-filter on a number apply no
# longer enforces — which fails silently in the safe-looking direction.
# Count ASSIGNMENTS, not the literal: a second declaration written `= 200000`
# carries no underscore, so a grep for the literal token cannot see it, and the
# import assertion below still matches. That mutation survives a literal grep.
assert_eq "$(grep -hE '^[[:space:]]*MAX_APPLY_BYTES[[:space:]]*=' scripts/doc-maintainer/*.py | wc -l)" "1" "#354 exactly one assignment to MAX_APPLY_BYTES exists across the doc-maintainer scripts"
assert_eq "$(grep -hE '200_?000' scripts/doc-maintainer/*.py | wc -l)" "1" "#354 ...and the limit appears as a literal exactly once, so no caller re-states the number inline"
assert_ok "grep -q '^from apply import MAX_APPLY_BYTES$' scripts/doc-maintainer/planner.py" "#354 the planner imports that declaration instead of re-stating it"
# ...which only resolves because the workflow fetches both scripts into one
# directory. Nothing else asserts that co-fetch, and dropping `apply` from the
# loop would make the planner ImportError at import time, before any annotation.
assert_ok "grep -q 'for op in planner apply reconcile; do' .github/workflows/doc-maintainer.yml" "#354 the fetch loop still co-fetches planner and apply, which is what makes that import resolve"
assert_ok "jq -e '.version == 2 and .litellm.model == \"ai-reviewer\"' install/templates/config.json.template >/dev/null && jq -e '.properties.version.const == 2 and (.required | index(\"litellm\"))' schemas/ai-review-config-v2.schema.json >/dev/null" "AI-review config and schema share the v2 contract"
assert_ok "grep -q 'secrets.LITELLM_REVIEW_API_KEY' .github/workflows/ai-review.yml && grep -q 'secrets.LITELLM_DOC_API_KEY' .github/workflows/doc-maintainer.yml" "AI workflows use separate purpose-scoped LiteLLM keys"
assert_ok "grep -q 'LITELLM_REVIEW_API_KEY' .github/workflows/litellm-smoke.yml && grep -q 'LITELLM_DOC_API_KEY' .github/workflows/litellm-smoke.yml && grep -q 'ai-reviewer' .github/workflows/litellm-smoke.yml && grep -q 'ai-doc-maintainer' .github/workflows/litellm-smoke.yml" "real-proxy smoke workflow covers both canonical aliases and keys"
assert_ok "jq -e 'length == 21 and ([.[].name | ascii_downcase] | unique | length == 21)' install/templates/labels.json >/dev/null" "canonical labels are complete and case-insensitively unique"
assert_ok "jq -e 'all(.[]; (.description | length) <= 100)' install/templates/labels.json >/dev/null" "canonical label descriptions fit GitHub's 100-character limit"
# §5.4 issue-lifecycle labels. The count above pins the set size; these pin the
# three names, so renaming one fails here rather than silently leaving every
# `--label handoff` lookup in canon pointing at a label no consumer has.
assert_ok "jq -e '([.[].name] | index(\"handoff\") and index(\"todo\") and index(\"status:in-progress\"))' install/templates/labels.json >/dev/null" "canon provisions the three issue-lifecycle labels (§5.4)"
# Issue-label colors must not collide with a PR label's, or the two groups stop
# being separable at a glance in a mixed listing — the §5.4 rule that motivated
# not reusing the colors #386 originally suggested.
assert_ok "jq -e '[.[] | select(.name == \"handoff\" or .name == \"todo\" or .name == \"status:in-progress\") | .color] as \$i | [.[] | select((.name == \"handoff\" or .name == \"todo\" or .name == \"status:in-progress\") | not) | .color] as \$p | (\$i | map(. as \$c | \$p | index(\$c)) | all(. == null))' install/templates/labels.json >/dev/null" "issue-label colors do not collide with any PR-label color"
assert_ok "jq -e '.[] | select(.name == \"skip-ai-review\") | .description | test(\"suppress re-review\")' install/templates/labels.json >/dev/null" "skip-ai-review description matches suppress-and-carry-forward behavior"
assert_ok "grep -q '^# Branching standard' docs/BRANCHING.md && grep -q 'BRANCHING.md' docs/REPO_STANDARDS.md && grep -q 'BRANCHING.md' CHANGELOG.md && grep -q 'feat/' docs/BRANCHING.md && grep -q 'All changes reach the default branch through a pull request' docs/BRANCHING.md" "branching standard is linked, released, and retains core naming/lifecycle rules"
assert_ok "jq -e '.allow_merge_commit == false and .allow_squash_merge == true and .allow_rebase_merge == false and .delete_branch_on_merge == true and .allow_update_branch == true' install/templates/repo-settings.json >/dev/null" "repository settings enforce canonical merge and cleanup strategy"
assert_ok "jq -s -e 'all(.[]; .allow_force_pushes == false and .allow_deletions == false and .required_pull_request_reviews != null)' install/templates/branch-protection-governance.json install/templates/branch-protection-product.json install/templates/branch-protection-ops.json install/templates/branch-protection-bootstrap.json install/templates/branch-protection-umbrella.json >/dev/null" "active tier profiles protect default-branch history and require PRs"
assert_ok "jq -e '.enforce_admins == false' install/templates/branch-protection-umbrella.json >/dev/null && jq -s -e 'all(.[]; .enforce_admins == true)' install/templates/branch-protection-governance.json install/templates/branch-protection-product.json install/templates/branch-protection-ops.json install/templates/branch-protection-bootstrap.json >/dev/null" "umbrella alone retains the documented administrator bypass"

echo "== PLAN-012 autofix — security invariants (default-off, gated, deny-floor, two-step App push) =="
AR=.github/workflows/ai-review.yml
# The autofix job exists and is gated on ALL of: fork-excluding trust (auto_fix_ok),
# TRUSTED-config enable (autofix_enabled), and tier != spec.
assert_ok "grep -qE '^  autofix:' '$AR'" "autofix job exists in ai-review.yml"
assert_ok "grep -q \"needs.trust.outputs.auto_fix_ok == 'true'\" '$AR'" "autofix gated on auto_fix_ok (forks are never trusted → never autofixed)"
assert_ok "grep -q \"needs.trust.outputs.autofix_enabled == 'true'\" '$AR'" "autofix gated on autofix_enabled (resolved from the TRUSTED config, not the PR)"
assert_ok "grep -q \"inputs.tier != 'spec'\" '$AR'" "autofix never runs on the spec/governance tier"
# autofix.enabled is resolved from the trusted CFG in the trust job (a PR cannot self-enable).
assert_ok "grep -q 'AUTOFIX_ENABLED=\$(jq' '$AR' && grep -q 'autofix_enabled=\$AUTOFIX_ENABLED' '$AR'" "trust job resolves autofix.enabled from the trusted config"
# Default-off: inert unless the dedicated autofix App creds are present.
assert_ok "grep -q 'APP_AUTOFIX_PRESENT' '$AR'" "autofix is inert (default-off) unless APP_AUTOFIX_ID/KEY are set"
# Governance deny-floor is WORKFLOW LOGIC (hardcoded), covering the locked paths.
assert_ok "grep -E \"DENY_RE:.*governance/.*[.]github/.*framework/.*templates/ai-review/\" '$AR' >/dev/null" "autofix deny-floor REGEX covers governance / .github / framework / templates/ai-review"
assert_ok "grep -q '120000' '$AR' && grep -q 'symlink-escape guard' '$AR'" "autofix rejects staged symlinks (mode 120000)"
assert_ok "grep -q 'could not read the PR commit history to enforce the round cap' '$AR' && grep -q 'issues/\$PR/timeline' '$AR'" "autofix round cap is fail-closed with a rewrite-proof timeline backstop"
assert_ok "grep -q 'issues: write' '$AR' && grep -q 'pull-requests: write' '$AR'" "autofix job can write labels + comments (escalation surfaces to a human)"
assert_ok "grep -q 'LITELLM_ALLOW_INSECURE_HTTP: \${{ inputs.litellm_allow_insecure_http }}' '$AR'" "autofix fixer honors the private-HTTP opt-in (functional on the HTTP bridge)"
# Dedicated autofix App, contents:write, minted per-run (NOT a PAT).
assert_ok "grep -q 'app-id: \${{ secrets.APP_AUTOFIX_ID }}' '$AR' && grep -q 'permission-contents: write' '$AR'" "autofix mints a DEDICATED App token with contents:write (not a PAT)"
# Two-step push: the App token appears ONLY in the dedicated push step, never in the
# model-call/apply step (separation of duties — the fixer holds no push credential).
autofix_fix_step="$(awk '/- name: Generate \+ apply fix/{f=1} /- name: Push fix via the autofix App/{f=0} f' "$AR")"
assert_absent "$autofix_fix_step" 'APP_TOKEN' "the fix/model step holds NO push credential (App token is only in the push step)"
assert_ok "grep -q 'x-access-token:\${APP_TOKEN}@github.com' '$AR' && grep -q 'clone --quiet --depth 1 --branch' '$AR'" "autofix pushes from a PRISTINE clone with the App token (two-step)"
# Schema types the autofix knobs.
assert_ok "jq -e '.properties.autofix.properties.enabled.type == \"boolean\" and .properties.autofix.properties.max_fix_rounds.type == \"integer\"' schemas/ai-review-config-v2.schema.json >/dev/null" "config schema types autofix.enabled (boolean) + max_fix_rounds (integer)"
# The reviewer uploads the verdict so autofix can consume it.
assert_ok "grep -q 'name: ai-review-verdict' '$AR' && grep -q 'actions/upload-artifact@' '$AR' && grep -q 'actions/download-artifact@' '$AR'" "ai-review uploads the verdict artifact the autofix job downloads"

echo "== PLAN-014 dep-scan — SCA gate (osv-scanner) security invariants =="
DS=.github/workflows/dep-scan.yml
assert_ok "test -f '$DS'" "dep-scan reusable exists"
# osv-scanner installed as a SHA-verified BINARY (not a third-party action).
assert_ok "grep -q 'curl -sSfL .*osv-scanner_linux_amd64' '$DS' && grep -q 'sha256sum --check --strict' '$DS'" "dep-scan installs the osv-scanner binary with SHA-256 verification (no third-party action)"
assert_absent "$(cat "$DS")" 'uses: google/osv-scanner' "dep-scan does NOT use a third-party osv-scanner action (canon allowlist §4.3)"
# DATA-ONLY: never --call-analysis (which runs build scripts = executes PR code).
# Data-only ENFORCED: the invocation must pass --no-call-analysis (opt-out; Go call
# analysis compiles source by default) and must NOT pass a bare enabling --call-analysis.
assert_ok "grep 'scan source' '$DS' | grep -q -- '--no-call-analysis'" "dep-scan enforces data-only via --no-call-analysis (osv Go call-analysis compiles source by default)"
assert_absent "$(grep 'scan source' "$DS")" '--call-analysis' "dep-scan's invocation never passes the enabling --call-analysis flag"
# FORK GUARD: forks never run the scanner on the self-hosted pool.
assert_ok "grep -q 'github.event.pull_request.head.repo.fork != true' '$DS'" "dep-scan is fork-guarded (forks never scan on self-hosted)"
# Best-effort SARIF → Code scanning (continue-on-error + github/* action).
assert_ok "grep -q 'continue-on-error: true' '$DS' && grep -q 'github/codeql-action/upload-sarif@' '$DS'" "dep-scan uploads SARIF best-effort (continue-on-error; no-ops where GHAS absent)"
# Uniform protected caller: single template, self-hosted, report-only default, no variants.
DSC=install/templates/workflows/dep-scan.yml
assert_ok "test -f '$DSC'" "dep-scan caller template exists"
assert_absent "$(ls install/templates/workflows/ 2>/dev/null)" "dep-scan-private.yml" "dep-scan has no -private variant (uniform)"
assert_absent "$(ls install/templates/workflows/ 2>/dev/null)" "dep-scan-public.yml" "dep-scan has no -public variant (uniform)"
assert_ok "grep -q 'self-hosted' '$DSC' && grep -q 'single-use' '$DSC'" "dep-scan caller runs on the self-hosted pool (uniform public+private)"
assert_ok "grep -q 'fail-on-findings: false' '$DSC'" "dep-scan ships report-only (fail-on-findings: false) per PLAN-014 rollout"
novar="$(python3 - <<'PYEOF'
import json
m = json.load(open("install/templates/manifest.json"))
e = next((f for f in m["files"] if f["path"] == ".github/workflows/dep-scan.yml"), None)
print("MISSING" if e is None else ("HAS_VARIANTS" if "visibility_variants" in e else "OK"))
PYEOF
)"
assert_contains "$novar" "OK" "dep-scan manifest entry has NO visibility_variants (flip is a no-op)"

echo "== PLAN-014 trivy-scan — IaC/misconfig gate (trivy config) security invariants =="
TV=.github/workflows/trivy-scan.yml
assert_ok "test -f '$TV'" "trivy-scan reusable exists"
assert_ok "grep -q 'trivy_.*Linux-64bit.tar.gz' '$TV' && grep -q 'sha256sum --check --strict' '$TV'" "trivy-scan installs the trivy binary with SHA-256 verification (no third-party action)"
assert_absent "$(cat "$TV")" 'uses: aquasecurity/trivy' "trivy-scan does NOT use a third-party trivy action (canon allowlist §4.3)"
# Config/misconfig mode ONLY — never 'trivy fs' (which would duplicate osv/gitleaks).
assert_ok "grep -q 'trivy\" config' '$TV' || grep -qE 'trivy.* config ' '$TV'" "trivy-scan runs 'trivy config' (IaC/misconfig)"
assert_absent "$(grep -E 'BIN_DIR.*trivy|trivy\"' "$TV")" 'trivy" fs' "trivy-scan does not run 'trivy fs' (avoids duplicating dep-scan/secret-scan)"
# SSRF fix: restricted to STATIC scanners (no terraform/helm/ansible which fetch remote sources).
assert_ok "grep 'misconfig-scanners' '$TV' | grep -q 'dockerfile' && grep 'misconfig-scanners' '$TV' | grep -q 'kubernetes'" "trivy-scan restricts to static misconfig scanners (no-egress)"
assert_absent "$(grep 'misconfig-scanners' "$TV")" 'terraform' "trivy-scan does NOT enable the terraform scanner (SSRF: fetches PR-controlled remote modules)"
assert_absent "$(grep 'misconfig-scanners' "$TV")" 'helm' "trivy-scan does NOT enable the helm scanner (can fetch remote charts)"
assert_ok "grep -q 'github.event.pull_request.head.repo.fork != true' '$TV'" "trivy-scan is fork-guarded (forks never scan on self-hosted)"
assert_ok "grep -q 'continue-on-error: true' '$TV' && grep -q 'github/codeql-action/upload-sarif@' '$TV'" "trivy-scan uploads SARIF best-effort (continue-on-error)"
TVC=install/templates/workflows/trivy-scan.yml
assert_ok "test -f '$TVC'" "trivy-scan caller template exists"
assert_absent "$(ls install/templates/workflows/ 2>/dev/null)" "trivy-scan-private.yml" "trivy-scan has no -private variant (uniform)"
assert_absent "$(ls install/templates/workflows/ 2>/dev/null)" "trivy-scan-public.yml" "trivy-scan has no -public variant (uniform)"
assert_ok "grep -q 'self-hosted' '$TVC' && grep -q 'fail-on-findings: false' '$TVC'" "trivy-scan caller is self-hosted + report-only"
assert_ok "! grep -qE '^[[:space:]]*secrets: inherit' '$TVC'" "trivy-scan caller has no active secrets: inherit (least privilege)"
novar_tv="$(python3 - <<'PYEOF'
import json
m = json.load(open("install/templates/manifest.json"))
e = next((f for f in m["files"] if f["path"] == ".github/workflows/trivy-scan.yml"), None)
print("MISSING" if e is None else ("HAS_VARIANTS" if "visibility_variants" in e else "OK"))
PYEOF
)"
assert_contains "$novar_tv" "OK" "trivy-scan manifest entry has NO visibility_variants (flip is a no-op)"

echo "== PLAN-014 sast-scan — SAST gate (semgrep) security invariants =="
SG=.github/workflows/sast-scan.yml
assert_ok "test -f '$SG'" "sast-scan reusable exists"
assert_ok "grep -qE 'pip.* install .*semgrep==' '$SG'" "sast-scan installs semgrep via VERSION-pinned pip (semgrep is Python, not a binary)"
assert_ok "grep -q 'python3 -m venv' '$SG'" "sast-scan installs into an isolated venv"
assert_absent "$(cat "$SG")" 'uses: returntocorp/semgrep' "sast-scan does NOT use a third-party semgrep action (canon allowlist §4.3)"
assert_absent "$(cat "$SG")" 'uses: semgrep/semgrep' "sast-scan does NOT use the semgrep marketplace action (canon allowlist §4.3)"
assert_ok "grep -qE 'semgrep(\"|\`)? scan' '$SG' || grep -q 'semgrep\" scan' '$SG'" "sast-scan runs 'semgrep scan'"
assert_ok "grep -q -- '--metrics off' '$SG'" "sast-scan runs with --metrics off (no telemetry to semgrep.dev — private-repo privacy)"
assert_ok "grep -q -- '--config \"\$CONFIG\"' '$SG'" "sast-scan uses an EXPLICIT --config (never repo-local auto-discovery — a PR cannot inject rules)"
assert_absent "$(grep 'semgrep\" scan\|bin/semgrep' "$SG")" '--config auto' "sast-scan does NOT use --config auto (metrics-incompatible + registry auto-select)"
assert_ok "grep -qE \"name '.semgrepignore'\" '$SG' && grep -q -- '-delete' '$SG'" "sast-scan strips PR-supplied .semgrepignore before scanning (gate controls coverage — no '*'-ignore bypass)"
assert_ok "grep -q 'produced no SARIF' '$SG' && grep -q 'unparseable' '$SG'" "sast-scan fails loud on missing/unparseable SARIF (no silent green from a broken scan)"
assert_ok "grep -q 'jq -e' '$SG'" "sast-scan uses 'jq -e' so a SARIF parse error is caught, not swallowed"
assert_ok "grep -q 'github.event.pull_request.head.repo.fork != true' '$SG'" "sast-scan is fork-guarded (forks never scan on self-hosted)"
assert_ok "grep -q 'continue-on-error: true' '$SG' && grep -q 'github/codeql-action/upload-sarif@' '$SG'" "sast-scan uploads SARIF best-effort (continue-on-error)"
assert_ok "grep -q 'autofix-preview:' '$SG'" "sast-scan exposes an autofix-preview input (PLAN-014 Phase 4)"
assert_ok "grep -q -- '--autofix' '$SG'" "sast-scan autofix-preview runs semgrep --autofix (deterministic, rule-provided)"
assert_absent "$(cat "$SG")" 'git push' "sast-scan autofix-preview NEVER pushes (preview only — no App, no credential)"
assert_absent "$(cat "$SG")" 'create-github-app-token' "sast-scan mints NO App token (the preview path needs no push credential)"
SGC=install/templates/workflows/sast-scan.yml
assert_ok "test -f '$SGC'" "sast-scan caller template exists"
assert_absent "$(ls install/templates/workflows/ 2>/dev/null)" "sast-scan-private.yml" "sast-scan has no -private variant (uniform)"
assert_absent "$(ls install/templates/workflows/ 2>/dev/null)" "sast-scan-public.yml" "sast-scan has no -public variant (uniform)"
assert_ok "grep -q 'self-hosted' '$SGC' && grep -q 'fail-on-findings: false' '$SGC'" "sast-scan caller is self-hosted + report-only"
assert_ok "! grep -qE '^[[:space:]]*secrets: inherit' '$SGC'" "sast-scan caller has no active secrets: inherit (least privilege)"
novar_sg="$(python3 - <<'PYEOF'
import json
m = json.load(open("install/templates/manifest.json"))
e = next((f for f in m["files"] if f["path"] == ".github/workflows/sast-scan.yml"), None)
print("MISSING" if e is None else ("HAS_VARIANTS" if "visibility_variants" in e else "OK"))
PYEOF
)"
assert_contains "$novar_sg" "OK" "sast-scan manifest entry has NO visibility_variants (flip is a no-op)"

echo "== deploy-ci-wizard knows the PLAN-014 scanner surfaces =="
WZ=install/deploy-ci-wizard.sh
assert_ok "grep -q 'dep-scan:' '$WZ' && grep -q 'trivy-scan:' '$WZ' && grep -q 'sast-scan:' '$WZ'" "wizard ALL_WF surveys the three scanner surfaces"
assert_ok "grep -q 'scaffold .* dep-scan trivy-scan sast-scan' '$WZ'" "wizard plan() documents opt-in scanner scaffolding"
assert_absent "$(grep 'wfs=' "$WZ" | grep -v ALL_WF)" "dep-scan" "scanners are NOT in scaffold()'s default list (deliberate per-repo adoption, not a force-sweep)"

echo "== FT-27 least-privilege: AI-flow callers pass explicit secrets, not blanket inherit =="
TW=install/templates/workflows
# composition reads only the automatic GITHUB_TOKEN → NO secrets: block at all.
for f in composition-private composition-public; do
  assert_ok "! grep -qE '^[[:space:]]*secrets:' '$TW/$f.yml'" "$f: no secrets: block (reads only GITHUB_TOKEN)"
done
# these declare their secrets → explicit map, never inherit. FT-42 added ai-review
# to this set (its reusable now declares a secrets: block, so the caller can pass
# an explicit least-privilege map instead of blanket inherit).
for f in ai-review doc-maintainer docs-sync auto-merge-ai-prs-public auto-merge-ai-prs-private; do
  assert_ok "! grep -qE '^[[:space:]]*secrets: inherit' '$TW/$f.yml'" "$f: no blanket secrets: inherit"
  assert_ok "grep -qE '^[[:space:]]*secrets:' '$TW/$f.yml'" "$f: has an explicit secrets: map"
done
assert_ok "grep -q 'AIDOC_FLOW_BOT_ID: \${{ secrets.AIDOC_FLOW_BOT_ID }}' '$TW/doc-maintainer.yml'" "doc-maintainer: explicit bot-id secret"
assert_ok "grep -q 'APP_REVIEWER_1_ID: \${{ secrets.APP_REVIEWER_1_ID }}' '$TW/auto-merge-ai-prs-private.yml'" "auto-merge: explicit reviewer secret"
# FT-42: ai-review's reusable now DECLARES its secrets (was the FT-27 exception —
# no secrets: block existed, forcing inherit). Assert the contract both ways:
# every secret the reusable body reads (except the auto-provided GITHUB_TOKEN) is
# declared in workflow_call.secrets AND forwarded by the caller template — the
# same completeness the other AI-flows already meet.
assert_ok "grep -q 'APP_REVIEWER_1_ID: \${{ secrets.APP_REVIEWER_1_ID }}' '$TW/ai-review.yml'" "ai-review: caller forwards the reviewer secret explicitly (FT-42)"
ai_review_secret_gaps="$(python3 - <<'PYEOF'
import yaml, re
body = open(".github/workflows/ai-review.yml").read()
used = set(re.findall(r'secrets\.([A-Z_0-9]+)', body)) - {"GITHUB_TOKEN"}
d = yaml.safe_load(body)
on = d.get(True, d.get("on", {}))
declared = set((on.get("workflow_call", {}).get("secrets") or {}).keys())
forwarded = set(re.findall(r'^\s*([A-Z_0-9]+):\s*\$\{\{\s*secrets\.',
                           open("install/templates/workflows/ai-review.yml").read(), re.M))
gaps = []
if used - declared: gaps.append("undeclared:" + ",".join(sorted(used - declared)))
if used - forwarded: gaps.append("not-forwarded:" + ",".join(sorted(used - forwarded)))
# Also fail if the caller forwards a secret the reusable does NOT declare — GitHub
# rejects an undeclared secret in an explicit map with a startup_failure (0 jobs).
if forwarded - declared: gaps.append("forwarded-undeclared:" + ",".join(sorted(forwarded - declared)))
print("; ".join(gaps))
PYEOF
)"
assert_eq "$ai_review_secret_gaps" "" "ai-review: every body secret is declared in workflow_call.secrets AND forwarded by the caller (FT-42 completeness)"
# FT-27b: auto-PR-approval defaults OFF.
assert_ok "python3 -c \"import json,sys; sys.exit(0 if json.load(open('install/templates/actions-permissions.json'))['workflow']['can_approve_pull_request_reviews'] is False else 1)\"" "actions-permissions: can_approve_pull_request_reviews defaults false"
# FT-46: verified_allowed must be false — `true` admitted every verified-creator
# action, wider than REPO_STANDARDS §4.3 (github-owned + the 3 patterns only).
assert_ok "python3 -c \"import json,sys; sys.exit(0 if json.load(open('install/templates/actions-permissions.json'))['selected_actions']['verified_allowed'] is False else 1)\"" "actions-permissions: verified_allowed is false (FT-46/CI-0011 — verified marketplace not admitted)"
# CI-0011: with verified_allowed false, patterns_allowed is the ONLY non-GitHub-owned
# admission. It must carry the account-wide `vladm3105/*` or every canon reusable
# startup_failures on consumers; and it must NOT admit any other owner (re-widening
# the supply-chain boundary is a decision, not a drift).
assert_ok "python3 -c \"import json,sys; p=json.load(open('install/templates/actions-permissions.json'))['selected_actions']['patterns_allowed']; sys.exit(0 if 'vladm3105/*' in p else 1)\"" "actions-permissions: patterns_allowed admits the account-wide vladm3105/* (CI-0011)"
assert_ok "python3 -c \"import json,sys; p=json.load(open('install/templates/actions-permissions.json'))['selected_actions']['patterns_allowed']; bad=[x for x in p if x.split('/')[0] not in ('vladm3105','actions','github')]; sys.exit(0 if not bad else 1)\"" "actions-permissions: patterns_allowed admits no owner beyond vladm3105/actions/github (CI-0011 boundary)"

echo "== FT-29: skip-ai-review fails closed while composition is INERT =="
AR=.github/workflows/ai-review.yml
# The skip-notice step's `label)` branch must refuse to conclude green when the
# reviewer App is not armed — else skip-ai-review + inert composition = both
# required checks green with zero review.
assert_ok "grep -q 'COMPOSITION_BOT_ID: \${{ vars.APP_REVIEWER_1_BOT_ID }}' '$AR'" "ai-review reads composition's arm state"
assert_ok "grep -q 'merge with ZERO review (FT-29)' '$AR'" "skip-ai-review label branch fails closed on inert composition"
# Behavioural teeth: the close logic blocks label+inert, allows label+armed, and
# leaves the r3/review-event skips untouched.
skip_ok() { # $1=SKIP_REASON $2=COMPOSITION_BOT_ID -> 0 proceed(green) / 1 fail(blocked)
  case "$1" in label) [ -n "$2" ] || return 1 ;; esac; return 0
}
if skip_ok label "";     then _r "label + inert composition blocked"; else _g "label + inert composition blocked"; fi
if skip_ok label "294948438"; then _g "label + armed composition proceeds"; else _r "label + armed composition proceeds"; fi
if skip_ok r3 "";        then _g "r3 skip unaffected by composition arm state"; else _r "r3 skip unaffected"; fi
if skip_ok review-event ""; then _g "review-event skip unaffected"; else _r "review-event skip unaffected"; fi

echo "== FT-43 triggers + the removal of its fail-closed step (#331) =="
ARTPL=install/templates/workflows/ai-review.yml
# (1) template triggers cover the draft transitions (a draft→ready must trigger a
# real review, not merge un-reviewed) — parsed, not grepped loosely.
ft43_triggers="$(python3 - "$ARTPL" <<'PYEOF'
import yaml, sys
d = yaml.safe_load(open(sys.argv[1]))
on = d.get(True, d.get("on", {}))
types = set((on.get("pull_request_target", {}) or {}).get("types", []))
need = {"ready_for_review", "converted_to_draft"}
print(",".join(sorted(need - types)) or "OK")
PYEOF
)"
assert_eq "$ft43_triggers" "OK" "template pull_request_target adds ready_for_review + converted_to_draft (FT-43)"
# (2) CONCURRENCY: only a genuinely code-changing event may cancel an in-flight
#     run. Every other subscribed event fires at the CURRENT head SHA, and a
#     cancelled required check is NOT success and is NOT replaced by a later
#     SUCCESS of the same context on that SHA — so such a cancel blocks the PR
#     permanently (CI-0025).
#
#     The case list is DERIVED FROM THE CALLER TEMPLATE'S OWN `types:`, not
#     hand-written: every subscribed (event, action) pair must be classified, so
#     adding a trigger to the template fails here until someone decides whether it
#     may cancel. A hand-written table is exactly how the first fix shipped still
#     broken — it exempted the events known to be self-emitted and missed
#     `reopened`, `ready_for_review` and `converted_to_draft`.
#
#     Asserted by EVALUATING the shipped expression, not by grepping its text: the
#     original version matched a literal prefix, so it stayed green while the
#     `pull_request_review` case was absent entirely.
ft43_cancel="$(python3 - "$AR" "$ARTPL" <<'PYEOF'
import yaml, sys, re, json

wf   = yaml.safe_load(open(sys.argv[1]))
tpl  = yaml.safe_load(open(sys.argv[2]))
expr = wf["concurrency"]["cancel-in-progress"]
if not isinstance(expr, str) or "${{" not in expr:
    print("NOT-AN-EXPRESSION:%r" % (expr,)); raise SystemExit
body = " ".join(expr.strip()[3:-2].split())

# Tiny evaluator for the allowlist grammar actually shipped. Anything outside it
# must fail LOUDLY — a checker that cannot understand its input goes red, never
# green.
TERM = r"""(?:[\w.]+\s*[!=]=\s*'[^']*'|contains\(fromJSON\('\[[^\]]*\]'\),\s*[\w.]+\))"""
if not re.fullmatch(rf"{TERM}(?:\s*&&\s*{TERM})*", body):
    print("UNSUPPORTED-GRAMMAR:%s" % body); raise SystemExit

def ev(ctx):
    for clause in re.split(r"\s*&&\s*", body):
        m = re.fullmatch(r"contains\(fromJSON\('(\[[^\]]*\])'\),\s*([\w.]+)\)", clause)
        if m:
            ok = ctx.get(m.group(2)) in json.loads(m.group(1))
        else:
            lhs, op, rhs = re.fullmatch(r"([\w.]+)\s*([!=]=)\s*'([^']*)'", clause).groups()
            ok = (ctx.get(lhs) == rhs) if op == "==" else (ctx.get(lhs) != rhs)
        if not ok:
            return False
    return True

on = tpl.get(True, tpl.get("on", {}))
pairs = set((e, a) for e, cfg in on.items() for a in (cfg or {}).get("types", []))

# EQUALITY, not a length floor. A floor only catches trigger REMOVAL: an ADDED
# pair evaluates False under the allowlist and would agree with a default
# want=False, so the suite would stay green and nobody would re-derive the
# predicate — which is precisely the CI-0025 history (FT-43 added
# ready_for_review + converted_to_draft and the predicate was never revisited).
# Changing the caller's triggers must therefore land HERE, deliberately.
CLASSIFIED = {
    ("pull_request_target", "opened"),
    ("pull_request_target", "synchronize"),
    ("pull_request_target", "reopened"),
    ("pull_request_target", "labeled"),
    ("pull_request_target", "unlabeled"),
    ("pull_request_target", "ready_for_review"),
    ("pull_request_target", "converted_to_draft"),
    ("pull_request_review", "submitted"),
}
if pairs != CLASSIFIED:
    print("TEMPLATE-TRIGGERS-CHANGED:added=%s removed=%s" % (
        sorted(pairs - CLASSIFIED), sorted(CLASSIFIED - pairs))); raise SystemExit

# The ONLY actions that may cancel. `synchronize` moves the head SHA, so its
# cancelled context lands on the superseded commit; `opened` can have nothing in
# flight. Everything else fires at the live head.
MAY_CANCEL = {("pull_request_target", "opened"), ("pull_request_target", "synchronize")}

bad = []
for e, a in pairs:
    got  = ev({"github.event_name": e, "github.event.action": a})
    want = (e, a) in MAY_CANCEL
    if got is not want:
        bad.append("%s/%s=%s(want %s)" % (e, a, got, want))

# Fail-direction: an unavailable context (community #107552; reported as recently
# as GHES 3.18.4) must
# NOT degrade into "cancel everything" — that IS the CI-0025 bug.
if ev({}) is not False:
    bad.append("empty-context-cancels")

print(",".join(bad) or "OK")
PYEOF
)"
assert_eq "$ft43_cancel" "OK" \
  "cancel-in-progress: ONLY opened/synchronize cancel; all 8 subscribed events classified; empty context fails safe (FT-43 + CI-0025)"
# (3) both jobs' if: gain the unarmed clause — armed repos still clean-skip a
# would-skip event (composition holds); unarmed repos RUN so the guard fails closed.
unarmed_ifs=$(grep -Fc "vars.APP_REVIEWER_1_BOT_ID == ''" "$AR" || true)
assert_ok "[ ${unarmed_ifs:-0} -ge 2 ]" "trust + ai-review job if: both carry the unarmed clause (found ${unarmed_ifs})"
# #331: the unarmed clause must EXCLUDE the gate's own `ai:review-*` label writes.
# It exists so an unarmed repo still runs a real review — but run1 sets
# `ai:review-passed`, which fires `labeled`, which would start run2, which would
# label again on any verdict flip. Unbounded paid reviews on a SERIAL pool, from
# a label anyone with write access can toggle.
amp_guard=$(grep -Fc "!startsWith(github.event.label.name, 'ai:review-')" "$AR" || true)
assert_eq "$amp_guard" "2" "both job if: exclude the gate's OWN ai:review-* label writes from the unarmed path (#331 amplification)"
# (4) The FT-43 fail-closed STEP is GONE (#331) and must stay gone. Its premise
#     was disproved by #330 (a later SUCCESS from a separate run does not replace
#     an earlier conclusion), and it was not preventing an unearned green — it
#     `exit 1`d on every label/draft event while unarmed, writing a PERMANENT
#     non-success required context on the live head SHA.
assert_ok "! grep -q 'name: FT-43 fail-closed' '$AR'" \
  "the FT-43 fail-closed STEP is absent (#331 — it wrote a permanent non-success and prevented nothing)"
assert_ok "! grep -q 'FT43-FAIL-CLOSED' '$AR'" "no FT43-FAIL-CLOSED markers remain"

# (5) FT-29 is now the guard that actually holds this line: a PR carrying
#     `skip-ai-review` must NOT pass while composition is INERT. Previously
#     grep-asserted only; DRIVEN here, because removing FT-43 makes it
#     load-bearing.
SKIPSTEP="$(mktemp)"
awk '/- name: ai-review skipped \(label OR R3 pre-approved OR review-event\)/{f=1}
     f&&/^          case "\$\{SKIP_REASON:-\}" in/{c=1}
     c{print}
     c&&/^          esac/{exit}' "$AR" > "$SKIPSTEP"
assert_ok "[ -s '$SKIPSTEP' ]" "FT-29 skip-notice branch extracted from the shipped workflow"
assert_ok "grep -q 'merge with ZERO review (FT-29)' '$SKIPSTEP'" "extracted block is the FT-29 branch"
drive_ft29() { # $1=COMPOSITION_BOT_ID  $2=SKIP_REASON -> rc
  { echo 'set -uo pipefail'
    printf 'COMPOSITION_BOT_ID=%s\n' "$1"; printf 'SKIP_REASON=%s\n' "$2"
    echo 'PR=1'; echo 'gh() { :; }'
    cat "$SKIPSTEP"; } | bash >/dev/null 2>&1
}
drive_ft29 "" "label";          assert_eq "$?" "1" "UNARMED + skip-ai-review → FAILS CLOSED (rc=1) — the FT-29 teeth, now load-bearing"
drive_ft29 "294948438" "label"; assert_eq "$?" "0" "ARMED + skip-ai-review → proceeds (rc=0; composition holds the gate)"
drive_ft29 "" "r3";             assert_eq "$?" "0" "UNARMED + r3 reason → proceeds (App already approved at HEAD; not the skip path)"

echo "== CI-0021: infrastructure break-glass (issue #311) =="
# Drives the REAL block out of composition.yml (marker-delimited, like FT-43
# above) with a stubbed `gh`. The control under test has THREE conditions and
# no two of them may substitute for the third:
#   label = signal, allowlisted approval = authorization, non-authorship = SoD.
CY=.github/workflows/composition.yml
assert_eq "$(grep -c '# >>> CI0021-INFRA-BREAKGLASS >>>' "$CY" || true)" "1" "CI-0021 exactly one break-glass start marker"
assert_eq "$(grep -c '# <<< CI0021-INFRA-BREAKGLASS <<<' "$CY" || true)" "1" "CI-0021 exactly one break-glass end marker"
BS="$(grep -n '# >>> CI0021-INFRA-BREAKGLASS >>>' "$CY" | cut -d: -f1)"
BE="$(grep -n '# <<< CI0021-INFRA-BREAKGLASS <<<' "$CY" | cut -d: -f1)"
BG="$(mktemp)"; awk "NR>${BS} && NR<${BE}" "$CY" > "$BG"
assert_ok "grep -q 'BREAKGLASS_APPROVERS' '$BG'" "CI-0021 break-glass block extracted (carries the approver allowlist)"

_bg_bin="$(mktemp -d)"
# The stub emits the SLURPED shape the block now requests (an array of pages).
# BG_COMMITS is a space-separated author list; "null" yields an unattributed commit.
cat > "$_bg_bin/gh" <<'SH'
#!/usr/bin/env bash
case "$*" in
  *"/pulls/7/reviews"*) [ "${BG_REVIEWS_RC:-0}" = "0" ] || exit 1; [ -n "$BG_REVIEWS" ] && printf '%s\n' "$BG_REVIEWS"; exit 0 ;;
  *"/pulls/7/commits"*)
    [ "${BG_COMMITS_RC:-0}" = "0" ] || exit 1
    printf '[['; sep=""
    for a in ${BG_COMMITS:-}; do
      if [ "$a" = "null" ]; then printf '%s{"author":null,"committer":null}' "$sep"
      else printf '%s{"author":{"login":"%s"},"committer":{"login":"%s"}}' "$sep" "$a" "$a"; fi
      sep=","
    done
    printf ']]\n'; exit 0 ;;
  *"--jq .commits"*|*"--jq"*".commits"*) printf '%s\n' "${BG_NCOMMITS:-$(set -- ${BG_COMMITS:-}; echo $#)}" ;;
  *"/pulls/7"*)         [ "${BG_LABEL_RC:-0}" = "0" ] || exit 1; printf '%s\n' "$BG_LABEL" ;;
  *) exit 1 ;;
esac
SH
chmod +x "$_bg_bin/gh"
drive_bg() { # env: BG_LABEL BG_REVIEWS BG_COMMITS BREAKGLASS_APPROVERS (+_RC) -> rc
  { echo 'set -uo pipefail'; echo 'GH_REPO=acme/demo'; echo 'PR=7'; echo 'HEAD_SHA=deadbeef';
    echo 'EXPECTED_ID=123'; cat "$BG"; echo 'exit 9'; } \
    | PATH="$_bg_bin:$PATH" bash >/dev/null 2>&1
}

# (1) No infra label -> inert; falls through to the normal App-approval block.
BG_LABEL="" BG_REVIEWS="" BG_COMMITS="" BREAKGLASS_APPROVERS="alice" drive_bg
assert_eq "$?" "9" "CI-0021 without the infra label the break-glass is inert (normal path unchanged)"

# (2) OPT-IN: label present but no allowlist configured -> does NOT engage.
BG_LABEL="1" BG_REVIEWS="alice" BG_COMMITS="bob" BREAKGLASS_APPROVERS="" drive_bg
assert_eq "$?" "9" "CI-0021 unconfigured (no allowlist var) the break-glass cannot apply — opt-in"

# (3) Label + allowlisted approval by someone who did NOT write the code -> passes.
BG_LABEL="1" BG_REVIEWS="alice" BG_COMMITS="bob" BREAKGLASS_APPROVERS="alice carol" drive_bg
assert_eq "$?" "0" "CI-0021 label + allowlisted approval by a non-author -> passes"

# (4) Label alone, no approval -> BLOCKS. A label is not authorization.
BG_LABEL="1" BG_REVIEWS="" BG_COMMITS="bob" BREAKGLASS_APPROVERS="alice" drive_bg
assert_eq "$?" "1" "CI-0021 the label alone does NOT open the gate"

# (5) SEPARATION OF DUTIES — the blocker found in review. GitHub forbids the
#     PR AUTHOR from approving but says nothing about whoever PUSHED the
#     commits, and canon's tiers set required_approving_review_count: 0, so
#     without this a single account could push code and self-clear it.
BG_LABEL="1" BG_REVIEWS="alice" BG_COMMITS="alice" BREAKGLASS_APPROVERS="alice" drive_bg
assert_eq "$?" "1" "CI-0021 an approver who authored/pushed a commit at HEAD does NOT qualify (SoD)"
BG_LABEL="1" BG_REVIEWS="Alice" BG_COMMITS="alice" BREAKGLASS_APPROVERS="alice" drive_bg
assert_eq "$?" "1" "CI-0021 the SoD check is case-insensitive (GitHub logins are)"

# (6) Approver not on the allowlist -> BLOCKS, even though the review is valid.
#     author_association alone is not a permission check: MEMBER/COLLABORATOR
#     do not imply write access.
BG_LABEL="1" BG_REVIEWS="mallory" BG_COMMITS="bob" BREAKGLASS_APPROVERS="alice" drive_bg
assert_eq "$?" "1" "CI-0021 an approval from a login off the allowlist does not qualify"

# (7) FAIL-CLOSED on every unreadable input — never as an implicit approval.
BG_LABEL="1" BG_REVIEWS="" BG_REVIEWS_RC=1 BG_COMMITS="bob" BREAKGLASS_APPROVERS="alice" drive_bg
assert_eq "$?" "1" "CI-0021 unreadable reviews fail CLOSED"
BG_LABEL="1" BG_REVIEWS="alice" BG_COMMITS="" BG_COMMITS_RC=1 BREAKGLASS_APPROVERS="alice" drive_bg
assert_eq "$?" "1" "CI-0021 unreadable commit authorship fails CLOSED (SoD cannot be verified)"

# (7b) UNATTRIBUTABLE commit -> FAIL-CLOSED. A commit whose email matches no
#      GitHub account has null author AND committer; dropping it (the first
#      draft's `// empty`) silently exempted the one actor SoD exists to catch —
#      one `git -c user.email=x@invalid commit` away from self-clearing.
BG_LABEL="1" BG_REVIEWS="alice" BG_COMMITS="null" BREAKGLASS_APPROVERS="alice" drive_bg
assert_eq "$?" "1" "CI-0021 an unattributable commit at HEAD fails CLOSED (SoD unverifiable)"
BG_LABEL="1" BG_REVIEWS="alice" BG_COMMITS="bob null" BREAKGLASS_APPROVERS="alice" drive_bg
assert_eq "$?" "1" "CI-0021 one unattributable commit among attributed ones still fails CLOSED"

# (7c) TRUNCATED commit listing -> FAIL-CLOSED. The API caps at 250 and exits 0,
#      so a shortfall must not read as "no other authors".
BG_LABEL="1" BG_REVIEWS="alice" BG_COMMITS="bob" BG_NCOMMITS="250" BREAKGLASS_APPROVERS="alice" drive_bg
assert_eq "$?" "1" "CI-0021 an incomplete commit listing fails CLOSED (250-commit cap)"

# (7d) Allowlist accepts newline/CRLF separation, not just commas — the repo
#      variable UI is a multi-line textarea, and rejecting a plainly-listed login
#      would disable the break-glass during the outage it exists for.
BG_LABEL="1" BG_REVIEWS="carol" BG_COMMITS="bob" BREAKGLASS_APPROVERS="$(printf 'alice\ncarol')" drive_bg
assert_eq "$?" "0" "CI-0021 a newline-separated allowlist is honoured"
BG_LABEL="1" BG_REVIEWS="carol" BG_COMMITS="bob" BREAKGLASS_APPROVERS="$(printf 'alice\r\ncarol')" drive_bg
assert_eq "$?" "0" "CI-0021 a CRLF-separated allowlist is honoured"
BG_LABEL="1" BG_REVIEWS="bo" BG_COMMITS="bob" BREAKGLASS_APPROVERS="bob" drive_bg
assert_eq "$?" "1" "CI-0021 allowlist matching is word-exact ('bo' is not admitted by 'bob')"

# (8) The shipped query must pin the head SHA, exclude bots, and take the LATEST
#     review per user — an APPROVED later retracted at the same SHA by a
#     REQUEST_CHANGES is still returned by the API as its own APPROVED object.
assert_ok "grep -q 'commit_id ==' '$BG'" "CI-0021 the approval must be at THIS head SHA (no stale carry)"
assert_ok "grep -q 'user.type' '$BG'" "CI-0021 bot approvals are excluded from the human-approval test"
assert_ok "grep -q 'group_by(.user.login) | map(last)' '$BG'" "CI-0021 latest review per user wins (a retracted approval does not qualify)"
# `--slurp` is what makes that aggregation span pages: without it `gh --paginate`
# applies --jq PER PAGE, so latest-per-user would be computed within 30 reviews.
assert_ok "grep -q -- '--paginate --slurp' '$BG'" "CI-0021 the reviews aggregation spans pages (--slurp, not per-page --jq)"
assert_ok "grep -q 'CHANGES_REQUESTED' '$BG'" "CI-0021 only state-CHANGING reviews take part in latest-wins (a COMMENTED review does not disqualify)"
assert_ok "grep -q 'UNATTRIBUTED' '$BG'" "CI-0021 a null commit login becomes a sentinel, never dropped"
rm -rf "$_bg_bin"

# The signal must be a canonical label, or the break-glass is unreachable.
assert_ok "jq -e '.[] | select(.name == \"ai:review-infra-error\")' install/templates/labels.json >/dev/null" "CI-0021 ai:review-infra-error is a canonical label"
# The allowlist must be a repo VARIABLE, not a caller input — otherwise the repo
# being gated would choose its own overriders.
assert_ok "grep -q 'vars.CI0021_BREAKGLASS_APPROVERS' '$CY'" "CI-0021 the approver allowlist is an admin-writable repo variable"
assert_absent "$(sed -n '/workflow_call:/,/^permissions:/p' "$CY")" "CI0021_BREAKGLASS_APPROVERS" "CI-0021 the allowlist is NOT a caller-settable input"

echo "== FT-25: adopter-facing wizard/doc gaps =="
WZ=install/deploy-ci-wizard.sh
# .1 labeler config is now installable (scaffold drops the starter when labeler is chosen).
assert_ok "grep -q 'cp \"\$TPL/labeler.yml\" \"\$dir/.github/labeler.yml\"' '$WZ'" "wizard scaffolds .github/labeler.yml for labeler"
# behavioural: scaffolding labeler drops the config; not scaffolding it does not.
_b25="$(mktemp -d)"; printf '#!/usr/bin/env bash\n[ "$1" = repo ] && echo PUBLIC && exit 0\nexit 0\n' > "$_b25/gh"; chmod +x "$_b25/gh"
GH="$_b25/gh" bash "$WZ" scaffold acme/demo "$_b25/withlab" labeler >/dev/null 2>&1
GH="$_b25/gh" bash "$WZ" scaffold acme/demo "$_b25/nolab" links >/dev/null 2>&1
assert_ok "[ -f '$_b25/withlab/.github/labeler.yml' ]" "scaffold labeler → .github/labeler.yml present"
assert_ok "[ ! -f '$_b25/nolab/.github/labeler.yml' ]" "scaffold without labeler → no labeler.yml"
rm -rf "$_b25"
# .3a preflight surveys ALL canon labels from labels.json, not a hardcoded 5.
assert_ok "grep -q 'templates/labels.json' '$WZ'" "preflight reads the full label set from labels.json"
assert_absent "$(sed -n '/hdr \"3. Canon labels\"/,/hdr \"4./p' "$WZ")" "for l in ai:review-passed ai:review-changes ai:human-review-required skip-ai-review skip-audit-trail" "preflight no longer hardcodes 5 labels"
# .3b §4 reads /actions/permissions and branches on allowed_actions (no raw 409 mask).
assert_ok "grep -q 'repos/\$repo/actions/permissions.*allowed_actions' '$WZ'" "preflight reads allowed_actions first"
# local_only + selected-without-github-owned BOTH startup_failure (canon reusables
# use actions/* + github/*), so neither is a green state.
assert_ok "grep -q 'local_only BLOCKS GitHub-authored actions' '$WZ'" "preflight flags local_only as a block (not green)"
assert_ok "grep -q 'github_owned_allowed' '$WZ'" "preflight also requires github-owned actions on the selected branch"
# .4 verify short-circuits when the caller is not yet on the default branch.
assert_ok "grep -q 'is not on the default branch yet' '$WZ'" "verify handles the pre-merge adoption PR (no 10-min empty poll)"
# .2 doc no longer tells private adopters to use the single generic template.
assert_ok "grep -q 'On a private repo use the' docs/AI_CI_DEPLOYMENT.md && grep -q 'FT-9 brick' docs/AI_CI_DEPLOYMENT.md" "AI_CI_DEPLOYMENT names the -private variants (FT-9 brick)"

# ── CI-0014/CI-0015: enforce the contracts this canon now DEPENDS on ───────────
# CI-0014's whole thesis is that an unenforced contract eventually breaks
# silently. These assertions exist so this change does not ship three new ones.
echo "== CI-0014/CI-0015: contracts the new rules depend on =="

# .1 The schema-assert block is duplicated across the `trust` and `ai-review`
#    jobs. Only the FATAL env may differ; a body that drifts means one job
#    stops agreeing with the other about what a valid config is.
_sa_blocks=$(awk '/# >>> CI0014-SCHEMA-ASSERT >>>/{f=1;n++;next} /# <<< CI0014-SCHEMA-ASSERT <<</{f=0} f{print n": "$0}' .github/workflows/ai-review.yml)
assert_eq "$(grep -c '# >>> CI0014-SCHEMA-ASSERT >>>' .github/workflows/ai-review.yml)" "2" "CI-0014 schema-assert block appears exactly twice (trust + ai-review)"
assert_eq "$(grep -c '# <<< CI0014-SCHEMA-ASSERT <<<' .github/workflows/ai-review.yml)" "2" "CI-0014 schema-assert block has both end markers"
_sa_1=$(printf '%s\n' "$_sa_blocks" | sed -n 's/^1: //p' | sed 's/^[[:space:]]*//')
_sa_2=$(printf '%s\n' "$_sa_blocks" | sed -n 's/^2: //p' | sed 's/^[[:space:]]*//')
assert_eq "$_sa_1" "$_sa_2" "CI-0014 the two schema-assert copies are identical (only the FATAL env differs)"
assert_ok "[ -n \"\$(printf '%s' \"\$_sa_1\")\" ]" "CI-0014 schema-assert extraction is non-empty (the assertion above is not vacuous)"

# .2 The version the reusable enforces MUST equal the schema's declared const.
#    A v3 bump that edits the schema but not the shell would silently reject
#    every valid config — the mirror image of CI-0014.
_sa_supported=$(grep -m1 -oE '^ *SUPPORTED=[0-9]+' .github/workflows/ai-review.yml | grep -oE '[0-9]+')
assert_eq "$_sa_supported" "$(jq -r '.properties.version.const' schemas/ai-review-config-v2.schema.json)" "CI-0014 SUPPORTED tracks the schema's version const"

# .3 The trust-job copy must stay NON-fatal and the review-job copy fatal.
#    Inverting them re-creates the skip-to-green fail-open: `ai-review` is
#    `needs: trust`, so failing `trust` SKIPS the required context to green.
_sa_nonfatal=$(grep -c "FATAL: '0'" .github/workflows/ai-review.yml || true)
_sa_fatal=$(grep -c "FATAL: '1'" .github/workflows/ai-review.yml || true)
assert_eq "$_sa_nonfatal" "1" "CI-0014 exactly one schema-assert copy is non-fatal (the trust job)"
assert_eq "$_sa_fatal" "1" "CI-0014 exactly one schema-assert copy is fatal (the required ai-review context)"

# .4 CI-0015 caller-vs-callee permission parity. A reusable's token is the
#    INTERSECTION, so a callee capped below what its own steps need is
#    unreachable for every consumer no matter what the caller grants.
assert_ok "python3 - <<'PY'
import sys, yaml, pathlib, re
LEVEL = {'none': 0, 'read': 1, 'write': 2}
bad = []
for caller in sorted(pathlib.Path('install/templates/workflows').glob('*.yml')):
    ctext = caller.read_text()
    cdoc = yaml.safe_load(ctext) or {}
    cperm = cdoc.get('permissions') or {}
    if not isinstance(cperm, dict):
        continue
    for m in re.finditer(r'uses:\s*vladm3105/aidoc-flow-ci/\.github/workflows/([A-Za-z0-9._-]+\.yml)@', ctext):
        callee = pathlib.Path('.github/workflows') / m.group(1)
        if not callee.exists():
            continue
        edoc = yaml.safe_load(callee.read_text()) or {}
        # A reusable may declare permissions at workflow level, per job, or
        # both; each job's token is intersect(caller grant, that job's block).
        # The ceiling that matters is therefore the HIGHEST level the callee
        # declares anywhere — if no job asks for it, the caller's grant is dead.
        ceiling = {}
        blocks = [edoc.get('permissions') or {}]
        blocks += [j.get('permissions') or {} for j in (edoc.get('jobs') or {}).values() if isinstance(j, dict)]
        for blk in blocks:
            if not isinstance(blk, dict):
                continue
            for scope, lvl in blk.items():
                if LEVEL.get(str(lvl), 0) > LEVEL.get(str(ceiling.get(scope, 'none')), 0):
                    ceiling[scope] = lvl
        for scope, want in cperm.items():
            have = ceiling.get(scope, 'none')
            if LEVEL.get(str(want), 0) > LEVEL.get(str(have), 0):
                bad.append(f'{caller.name} grants {scope}:{want} but {callee.name} caps it at {have}')
if bad:
    print('\n'.join(bad), file=sys.stderr)
    sys.exit(1)
PY" "CI-0015 no caller template grants a permission its callee caps lower (intersection parity)"

# ── CI-0022: the rubric describes the inputs the reviewer actually gets ───────
# The v2 reviewer is a single-shot completion with no checkout, so every
# "list/read the file" instruction in the rubric was unexecutable — and an
# unexecutable instruction is not skipped, it is answered from nothing. These
# assertions keep the rubric and the prompt assembly describing the same world.
echo "== CI-0022: rubric ↔ prompt-assembly input parity =="
RP=ai-review/review-prompt.md
AR=.github/workflows/ai-review.yml

# .1 The rubric must not re-acquire a filesystem it does not have. These are the
#    exact claims that shipped through ci/v1.x and every ci/v2.x tag.
for phrase in \
  "changed files are in the current directory" \
  "The working tree is the" \
  "VERIFY by listing the file" \
  "Read \`.ai-review/diff.txt\`"; do
  assert_absent "$(cat "$RP")" "$phrase" "rubric claims no filesystem access: '$phrase'"
done
# Phrase bans are one-directional — a reworded reintroduction of the same false
# claim slips past them. Assert the true disclaimer positively too, so diluting
# it also goes red.
assert_ok "grep -q 'no shell, no tools, no network, no' '$RP' && grep -q 'no working tree' '$RP'" "rubric states positively that it has no tools and no working tree"
assert_ok "grep -q 'never evidence that something is absent' '$RP'" "rubric states UNAVAILABLE is not evidence of absence"

# .2 The rubric must enumerate the blocks the assembly actually appends, by the
#    SAME tag names in the SAME order, and there must be exactly three. Either
#    half drifting on its own is the CI-0022 defect returning.
_asm=$(sed -n '/^          if ! {/,/} | python3 reviewer-assets\/litellm_client.py/p' "$AR")
assert_ok "[ -n \"\$_asm\" ]" "prompt-assembly block extracted (the assertions below are not vacuous)"
_asm_tags=$(printf '%s' "$_asm" | grep -o '<untrusted_[a-z_]*>' | tr -d '<>' | awk '!seen[$0]++' | tr '\n' ' ')
_rp_tags=$(grep -o '<untrusted_[a-z_]*>' "$RP" | tr -d '<>' | awk '!seen[$0]++' | tr '\n' ' ')
assert_eq "$_asm_tags" "untrusted_changed_files untrusted_root_inventory untrusted_diff " "assembly fences exactly the three input blocks, in order"
assert_eq "$_rp_tags" "$_asm_tags" "rubric names the same three blocks in the same order as the assembly"
assert_contains "$_asm" "Changed-file inventory:" "assembly labels the changed-file inventory"
assert_contains "$_asm" "Repo-root file inventory" "assembly labels the repo-root inventory"
assert_contains "$_asm" "cat .ai-review/root.txt" "assembly reads the root inventory the fetch step writes"
assert_contains "$_asm" 'FILES_COMPLETE:-false' "assembly reports an unprovable changed-file listing as UNAVAILABLE, not as the whole set"
assert_ok "grep -q 'echo \"FILES_COMPLETE=' '$AR'" "the fetch step exports the completeness bit the assembly branches on"

# .3 The unavailable marker is a CONTRACT between the workflow and the rubric:
#    the workflow writes the literal, the rubric branches on it. A rename on
#    one side silently turns "unknowable" into "root has no CHANGELOG.md".
assert_ok "grep -q \"printf 'UNAVAILABLE\\\\\\\\n' > .ai-review/root.txt\" '$AR'" "workflow writes the literal UNAVAILABLE marker"
assert_ok "grep -q 'UNAVAILABLE' '$RP'" "rubric branches on the same UNAVAILABLE marker"
# A degraded input set produces a GREEN check, so the log is the one place
# nobody looks. The verdict comment has to say it.
assert_ok "grep -q 'Degraded inputs (CI-0022)' '$AR'" "the verdict comment discloses a degraded input set"

# .4 DRIVEN: extract the shipped root-inventory block and run it with `gh`
#    stubbed. A static grep would stay green if the fallback were deleted, so
#    every outcome is executed for real — and the stub RECORDS ITS ARGUMENTS and
#    runs the shipped `-q` filter through real jq, because a stub that only
#    controls the return value leaves the URL and the filter untested.
assert_eq "$(grep -c '# >>> CI0022-ROOT-INVENTORY >>>' "$AR")" "1" "CI-0022 root-inventory block is extractable"
assert_eq "$(grep -c '# <<< CI0022-ROOT-INVENTORY <<<' "$AR")" "1" "CI-0022 root-inventory block has its end marker"
_ci22_fix="$(mktemp -d)"
trap 'rm -rf "$_ci22_fix"' EXIT
awk '/# >>> CI0022-ROOT-INVENTORY >>>/{f=1;next} /# <<< CI0022-ROOT-INVENTORY <<</{f=0} f' "$AR" > "$_ci22_fix/block.sh"
assert_ok "grep -q 'ROOT_OK' '$_ci22_fix/block.sh'" "CI-0022 block body extracted"

# $1 = stub `gh` body; $2 = BASE_SHA (default deadbeef).
# Leaves $_ci22_fix/run intact so callers can inspect gh_args.log; echoes root.txt.
drive_root() {
  rm -rf "$_ci22_fix/run"; mkdir -p "$_ci22_fix/run/.ai-review"
  {
    # Mirrors the GitHub Actions default shell + the step's own `set`.
    echo 'set -eo pipefail'
    echo 'set -uo pipefail'
    echo 'GH_REPO=owner/repo'
    printf 'BASE_SHA=%s\n' "${2-deadbeef}"
    echo 'sleep() { :; }'
    # every stub records the call before doing anything else
    printf 'gh() { printf "%%s\\n" "$*" >> gh_args.log; %s\n}\n' "$1"
    cat "$_ci22_fix/block.sh"
  } > "$_ci22_fix/run/drive.sh"
  ( cd "$_ci22_fix/run" && bash drive.sh >/dev/null 2>&1; cat .ai-review/root.txt )
}

# A real contents-API payload pushed through the block's OWN `-q` filter (arg 4).
# This is what proves directories survive with a trailing slash: a files-only
# filter would drop `docs`, and the rubric treats "absent" as decidable.
_ci22_json='[{"name":"CHANGELOG.md","type":"file"},{"name":"docs","type":"dir"},{"name":"link.md","type":"symlink"}]'
assert_eq "$(drive_root "printf '%s' '$_ci22_json' | jq -r \"\$4\"" | tr '\n' ' ')" "CHANGELOG.md docs/ link.md " "CI-0022 the shipped jq filter keeps directories, marked with a trailing slash"
assert_ok "grep -q 'contents?ref=deadbeef' '$_ci22_fix/run/gh_args.log'" "CI-0022 the listing is fetched at the PR BASE sha, not the default branch"
assert_eq "$(grep -c 'contents' "$_ci22_fix/run/gh_args.log")" "1" "CI-0022 a first-attempt success makes exactly one API call"

assert_eq "$(drive_root 'printf "CHANGELOG.md\nREADME.md\n"' | tr '\n' ' ')" "CHANGELOG.md README.md " "CI-0022 a successful listing reaches the reviewer verbatim"
assert_eq "$(drive_root 'return 1')" "UNAVAILABLE" "CI-0022 an API failure yields UNAVAILABLE, never an empty listing"
assert_eq "$(drive_root 'return 0')" "UNAVAILABLE" "CI-0022 an empty listing yields UNAVAILABLE (200-but-empty pathology)"
assert_eq "$(drive_root 'printf "partial.md\n"; return 1')" "UNAVAILABLE" "CI-0022 output written before a failing call is discarded, not shipped as the listing"
assert_eq "$(drive_root 'seq 1 1000')" "UNAVAILABLE" "CI-0022 a listing at the 1000-entry API cap is not provably complete → UNAVAILABLE"
assert_eq "$(drive_root 'seq 1 999' | wc -l | tr -d ' ')" "999" "CI-0022 a listing below the cap is passed through"
# The retry loop is load-bearing per its own comment; a stub that always returns
# the same thing can never prove it runs more than once.
assert_eq "$(drive_root 'n=$(cat n.txt 2>/dev/null || echo 0); n=$((n+1)); echo $n > n.txt; [ "$n" -ge 3 ] || return 1; printf "CHANGELOG.md\n"')" "CHANGELOG.md" "CI-0022 a transient blip is survived — the third attempt's listing is used"
# An unknown base sha would silently list the DEFAULT branch while the prompt
# header still says "at the PR base commit". That substitution must not happen.
assert_eq "$(drive_root 'printf "CHANGELOG.md\n"' '')" "UNAVAILABLE" "CI-0022 a missing base sha is UNAVAILABLE, not a silent default-branch listing"

echo "== CI-0025 caller-side: a required-context caller may only cancel on code-changing events =="
# §23.2. The ai-review fix was reusable-side; these callers set cancel-in-progress
# themselves, so the same defect lived here too — audit-trail's `labeled` trigger
# is the DOCUMENTED skip-audit-trail hatch, so canon's own instructions fired it.
ci0025_callers="$(python3 - "$ROOT" <<'PYEOF'
import yaml, sys, os, re, json, subprocess

root = sys.argv[1]

# DERIVED, not hardcoded: every caller template feeding a required context, from
# install/required-context-map.py, plus this repo's own callers (Wave 0 §16.6) and
# the live-protection-only `call / markdownlint`. A hardcoded list would let a NEW
# required-context caller ship unguarded — the drift class this whole section is about.
def derived():
    out = set()
    try:
        r = subprocess.run([sys.executable, os.path.join(root, "install/required-context-map.py")],
                           capture_output=True, text=True, timeout=60)
        for line in (r.stdout or "").splitlines():
            m = re.search(r"([\w.-]+)\.ya?ml\s*$", line.strip())
            if not m: continue
            # The map emits the caller BASE name; several ship only as
            # -public/-private variants. Expand to whatever exists on disk.
            base = m.group(1)
            for cand in (base, base + "-public", base + "-private"):
                rel = "install/templates/workflows/%s.yml" % cand
                if os.path.exists(os.path.join(root, rel)): out.add(rel)
    except Exception:
        pass
    return out

CALLERS = derived() | {
    "install/templates/workflows/%s.yml" % n for n in
    ("audit-trail-public", "audit-trail-private", "pre-commit", "pre-commit-private",
     "secret-scan", "secret-scan-private", "markdown-lint", "markdown-lint-private")
} | {
    # Wave 0: canon's own callers behind its five required contexts.
    ".github/workflows/%s.yml" % n for n in
    ("audit-trail", "self-pre-commit", "self-markdown-lint", "self-secret-scan", "tests")
}

# Actions coerces null and '' alike, so probe the degraded context with '' — using
# Python None would make `x == ''` read False here while it is TRUE in Actions.
EMPTY = {"github.event_name": "", "github.event.action": ""}
CODE_ACTIONS = {"opened", "synchronize"}
PR_EVENTS = {"pull_request", "pull_request_target"}
SUPERSEDABLE = {"push", "workflow_dispatch", "schedule"}

def ev(expr, ctx):
    body = " ".join(expr.split())
    if not body.startswith("${{"): raise ValueError("not an expression: %s" % body[:40])
    body = body[3:-2]
    def term(t):
        t = t.strip()
        m = re.fullmatch(r"contains\(fromJSON\('(\[[^\]]*\])'\),\s*([\w.]+)\)", t)
        if m: return ctx.get(m.group(2)) in json.loads(m.group(1))
        m = re.fullmatch(r"([\w.]+)\s*==\s*'([^']*)'", t)
        if not m: raise ValueError("unsupported term: %s" % t)
        return ctx.get(m.group(1)) == m.group(2)
    def parse(e):
        e = e.strip()
        while e.startswith("(") and e.endswith(")"):
            d = 0; whole = True
            for i, c in enumerate(e):
                d += c == "("; d -= c == ")"
                if d == 0 and i < len(e) - 1: whole = False; break
            if not whole: break
            e = e[1:-1].strip()
        for op, fn in (("||", any), ("&&", all)):
            parts, d, cur, i = [], 0, "", 0
            while i < len(e):
                d += e[i] == "("; d -= e[i] == ")"
                if d == 0 and e[i:i+2] == op:
                    parts.append(cur); cur = ""; i += 2; continue
                cur += e[i]; i += 1
            parts.append(cur)
            if len(parts) > 1: return fn(parse(x) for x in parts)
        return term(e)
    return parse(body)

# Default action sets, so a non-PR event with real actions is probed with ITS
# actions rather than a bare None.
DEFAULT_TYPES = {
    "pull_request": ["opened", "synchronize", "reopened"],
    "pull_request_target": ["opened", "synchronize", "reopened"],
}

bad = []
for rel in sorted(CALLERS):
    f = os.path.join(root, rel)
    if not os.path.exists(f): bad.append("%s:MISSING" % rel); continue
    d = yaml.safe_load(open(f))
    expr = (d.get("concurrency") or {}).get("cancel-in-progress")
    if expr is None: continue                 # no concurrency: nothing can be cancelled
    if expr is False: continue                # flat false: the safest form, §23.2's default
    if expr is True: bad.append("%s:literal-true" % rel); continue
    if not isinstance(expr, str): bad.append("%s:%r" % (rel, expr)); continue
    on = d.get(True, d.get("on", {})) or {}
    try:
        if ev(expr, EMPTY) is not False: bad.append("%s:empty-context-cancels" % rel)
        for e, cfg in on.items():
            types = (cfg or {}).get("types") if isinstance(cfg, dict) else None
            acts = types or DEFAULT_TYPES.get(e, [None])
            for a in acts:
                got = ev(expr, {"github.event_name": e, "github.event.action": a or ""})
                # A cancel is legitimate only when the event supersedes work: a push
                # or dispatch, or a CODE-CHANGING action on a PR event. Keyed on the
                # (event, action) PAIR — an action name alone is ambiguous, e.g.
                # `issues: [opened]` is not code-changing.
                want = (e in SUPERSEDABLE) or (e in PR_EVENTS and a in CODE_ACTIONS)
                if got is not want: bad.append("%s:%s/%s=%s(want %s)" % (rel, e, a, got, want))
    except ValueError as x:
        bad.append("%s:UNSUPPORTED(%s)" % (rel, x))
print(",".join(bad) or "OK")
PYEOF
)"
assert_eq "$ci0025_callers" "OK" \
  "required-context callers cancel ONLY on push/dispatch/opened/synchronize, and fail safe on an empty context (CI-0025 §23.2)"

suite_summary "contract"
