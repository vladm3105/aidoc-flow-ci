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
  # ai-review + composition callers MUST carry a permissions: block (startup_failure otherwise)
  case "$name" in
    ai-review-*.yml|composition-*.yml)
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
assert_ok "jq -e 'length == 17 and ([.[].name | ascii_downcase] | unique | length == 17)' install/templates/labels.json >/dev/null" "canonical PR labels are complete and case-insensitively unique"
assert_ok "jq -e 'all(.[]; (.description | length) <= 100)' install/templates/labels.json >/dev/null" "canonical PR label descriptions fit GitHub's 100-character limit"
assert_ok "jq -e '.[] | select(.name == \"skip-ai-review\") | .description | test(\"suppress re-review\")' install/templates/labels.json >/dev/null" "skip-ai-review description matches suppress-and-carry-forward behavior"
assert_ok "grep -q '^# Branching standard' docs/BRANCHING.md && grep -q 'BRANCHING.md' docs/REPO_STANDARDS.md && grep -q 'BRANCHING.md' CHANGELOG.md && grep -q 'feat/' docs/BRANCHING.md && grep -q 'All changes reach the default branch through a pull request' docs/BRANCHING.md" "branching standard is linked, released, and retains core naming/lifecycle rules"
assert_ok "jq -e '.allow_merge_commit == false and .allow_squash_merge == true and .allow_rebase_merge == false and .delete_branch_on_merge == true and .allow_update_branch == true' install/templates/repo-settings.json >/dev/null" "repository settings enforce canonical merge and cleanup strategy"
assert_ok "jq -s -e 'all(.[]; .allow_force_pushes == false and .allow_deletions == false and .required_pull_request_reviews != null)' install/templates/branch-protection-governance.json install/templates/branch-protection-product.json install/templates/branch-protection-ops.json install/templates/branch-protection-bootstrap.json install/templates/branch-protection-umbrella.json >/dev/null" "active tier profiles protect default-branch history and require PRs"
assert_ok "jq -e '.enforce_admins == false' install/templates/branch-protection-umbrella.json >/dev/null && jq -s -e 'all(.[]; .enforce_admins == true)' install/templates/branch-protection-governance.json install/templates/branch-protection-product.json install/templates/branch-protection-ops.json install/templates/branch-protection-bootstrap.json >/dev/null" "umbrella alone retains the documented administrator bypass"

suite_summary "contract"
