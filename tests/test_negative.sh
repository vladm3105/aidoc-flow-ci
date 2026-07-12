#!/usr/bin/env bash
# tests/test_negative.sh — prove the contract checks have TEETH: a deliberately
# broken input must be rejected. Guards against a check silently degrading into
# a no-op (which would let the very regressions W1 exists to stop ship again).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"

# same allowlist predicate the contract test uses
allowed_use() { case "$1" in actions/*|github/*|vladm3105/aidoc-flow-ci/*|./*) return 0 ;; *) return 1 ;; esac; }

echo "== allowlist rejects third-party actions (the startup_failure class) =="
assert_fail "allowed_use 'gacts/gitleaks'"                 "gacts/gitleaks rejected"
assert_fail "allowed_use 'lycheeverse/lychee-action'"      "lycheeverse/lychee-action rejected"
assert_fail "allowed_use 'DavidAnson/markdownlint-cli2-action'" "DavidAnson/... rejected"
assert_ok   "allowed_use 'actions/checkout'"               "actions/* allowed"
assert_ok   "allowed_use 'github/codeql-action/upload-sarif'" "github/* allowed"
assert_ok   "allowed_use 'vladm3105/aidoc-flow-ci/.github/workflows/ai-review.yml'" "own reusable allowed"

echo "== runner_labels JSON validation rejects malformed input =="
assert_fail "printf '%s' '[self-hosted, aidoc, ci-ephemeral]' | jq -e . >/dev/null 2>&1" "unquoted array rejected (the heredoc-quote-strip bug)"
assert_ok   'printf %s '"'"'["self-hosted", "aidoc", "ci-ephemeral"]'"'"' | jq -e "type==\"array\"" >/dev/null 2>&1' "valid JSON array accepted"

echo "== permissions-block presence check catches an omission =="
tmp="$(mktemp)"; printf 'name: x\non:\n  workflow_call:\njobs:\n  j:\n    runs-on: ubuntu-latest\n' > "$tmp"
assert_fail "grep -qE '^permissions:|^  +permissions:' '$tmp'" "a permissions-less reusable is detectable"
rm -f "$tmp"

suite_summary "negative"
