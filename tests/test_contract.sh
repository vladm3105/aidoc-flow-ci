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
        assert_contains "$inner" 'ci-ephemeral' "$name: runner_labels targets ci-ephemeral"
      fi ;;
  esac
done

suite_summary "contract"
