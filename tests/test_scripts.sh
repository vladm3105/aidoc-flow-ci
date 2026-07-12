#!/usr/bin/env bash
# tests/test_scripts.sh — unit tests for the logic-heavy scripts, on fixtures.
# No network / gh: pin-currency runs in a fixture repo (in-repo mode reads local
# files); the --repin seds are exercised directly + guarded against regression.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

echo "== check-pin-currency.sh (in-repo staleness detection) =="
mkdir -p "$TMP/repo/.github/workflows"
cat > "$TMP/repo/.github/workflows/stale.yml" <<'YML'
jobs:
  call:
    uses: vladm3105/aidoc-flow-ci/.github/workflows/ai-review.yml@ci/v1.0.0
YML
cat > "$TMP/repo/.github/workflows/current.yml" <<'YML'
jobs:
  call:
    uses: vladm3105/aidoc-flow-ci/.github/workflows/composition.yml@ci/v1.9.5
YML
out="$(cd "$TMP/repo" && bash "$ROOT/sync/check-pin-currency.sh" --canon ci/v1.9.5 2>&1)"
assert_contains "$out" "stale.yml pinned @ci/v1.0.0" "flags the stale @v1.0.0 pin"
assert_absent   "$out" "current.yml"                 "does not flag the current @v1.9.5 pin"

echo "== install.sh --repin sed logic (tag + SHA pins; leaves others alone) =="
f="$TMP/wf.yml"
cat > "$f" <<'YML'
    uses: actions/checkout@abcdef0123456789abcdef0123456789abcdef01 # v7.0.0
    uses: vladm3105/aidoc-flow-ci/.github/workflows/ai-review.yml@ci/v1.8.1
    uses: vladm3105/aidoc-flow-ci/.github/workflows/audit-trail-check.yml@e15ec7d44234726195da316a740ad1684a2c5abd # ci/v1.6.0
    uses: some/other-action@main
YML
target=ci/v1.9.5
sed -i -E "s#(^[[:space:]]*uses:[[:space:]]*vladm3105/aidoc-flow-ci/[^@]+)@ci/v[0-9.]+#\1@${target}#" "$f"
sed -i -E "s|(^[[:space:]]*uses:[[:space:]]*vladm3105/aidoc-flow-ci/[^@]+)@[0-9a-f]{40}([[:space:]]*# ci/v[0-9.]+.*)?\$|\1@${target}|" "$f"
body="$(cat "$f")"
assert_contains "$body" "ai-review.yml@ci/v1.9.5"        "tag pin bumped v1.8.1 -> v1.9.5"
assert_contains "$body" "audit-trail-check.yml@ci/v1.9.5" "SHA pin converted -> @ci/v1.9.5 tag"
assert_absent   "$body" "e15ec7d4"                        "old SHA gone (no dangling # ci/v comment)"
assert_contains "$body" "actions/checkout@abcdef01"       "non-aidoc-flow-ci action left untouched"
assert_contains "$body" "some/other-action@main"          "@main on a third-party left untouched"
# idempotent: re-running is a no-op
cp "$f" "$f.1"
sed -i -E "s#(^[[:space:]]*uses:[[:space:]]*vladm3105/aidoc-flow-ci/[^@]+)@ci/v[0-9.]+#\1@${target}#" "$f"
assert_ok "diff -q '$f' '$f.1' >/dev/null" "repin is idempotent"

echo "== --repin regression guard (both seds present in install.sh) =="
assert_ok "grep -qE 's#.*aidoc-flow-ci.*@ci/v' '$ROOT/install/install.sh'" "install.sh has the tag-pin sed"
assert_ok "grep -qE '@\[0-9a-f\]\{40\}' '$ROOT/install/install.sh'"          "install.sh has the SHA-pin sed"

suite_summary "scripts"
