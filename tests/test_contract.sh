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
cd "$ROOT"

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
assert_absent "$(cat install/templates/workflows/markdown-lint.yml)" $'    # with:\n    #   runner_labels:' "markdown-lint template does not suggest a duplicate with block"
assert_absent "$(grep 'git commit' .github/workflows/doc-maintainer.yml)" '[skip ci]' "doc-maintainer bot commits do not suppress normal CI"
assert_ok "grep -q 'actions/upload-artifact@.*# v4.6.2' .github/workflows/doc-maintainer.yml" "doc-maintainer preserves dry-run patches as an artifact"
assert_ok "jq -e '.auto_merge.high_risk_paths | index(\"**/DECISIONS.md\") and index(\"**/ROADMAP.md\") and index(\"**/HANDOFF.md\")' install/templates/doc-maintainer.json >/dev/null" "nested governance documents are high-risk by default"
assert_ok "jq -e '.allowed_paths | index(\"DECISIONS.md\")' install/templates/doc-maintainer.json >/dev/null" "high-risk root decisions file is consistently allowlisted"
assert_ok "jq -e '.version == 2 and .litellm.model == \"ai-reviewer\"' install/templates/config.json.template >/dev/null && jq -e '.properties.version.const == 2 and (.required | index(\"litellm\"))' schemas/ai-review-config-v2.schema.json >/dev/null" "AI-review config and schema share the v2 contract"
assert_ok "grep -q 'secrets.LITELLM_REVIEW_API_KEY' .github/workflows/ai-review.yml && grep -q 'secrets.LITELLM_DOC_API_KEY' .github/workflows/doc-maintainer.yml" "AI workflows use separate purpose-scoped LiteLLM keys"
assert_ok "grep -q 'LITELLM_REVIEW_API_KEY' .github/workflows/litellm-smoke.yml && grep -q 'LITELLM_DOC_API_KEY' .github/workflows/litellm-smoke.yml && grep -q 'ai-reviewer' .github/workflows/litellm-smoke.yml && grep -q 'ai-doc-maintainer' .github/workflows/litellm-smoke.yml" "real-proxy smoke workflow covers both canonical aliases and keys"
assert_ok "jq -e 'length == 18 and ([.[].name | ascii_downcase] | unique | length == 18)' install/templates/labels.json >/dev/null" "canonical PR labels are complete and case-insensitively unique"
assert_ok "jq -e 'all(.[]; (.description | length) <= 100)' install/templates/labels.json >/dev/null" "canonical PR label descriptions fit GitHub's 100-character limit"
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

suite_summary "contract"
