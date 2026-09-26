#!/usr/bin/env bash
# tests/test_docs_sync_ops.sh — contract tests for the two docs-sync python
# operations (PLAN-031 Phase E / G06).
#
# WHY THESE EXIST. `scripts/docs-sync/{version_sync,cross_ref_repair}.py` run at
# RUNTIME ON EVERY CONSUMER, post-merge, via .github/workflows/docs-sync.yml:284
# and :291. They had zero tests and were structurally invisible to the coverage
# gate, because tests/test_exerciser_inventory.sh's walk globbed only
# `install/*.sh scripts/*.sh sync/*.sh` — no `*.py`, no subdirectories. That walk
# is now widened; this suite is the coverage the inventory row names.
#
# THE PROPERTY THAT MATTERS MOST is assertion group 4: these run AFTER a merge,
# in a job that commits and opens PRs. A detection stub that wrote anything
# would mutate a consumer's tree from a documentation job. So every scenario
# asserts the target files are byte-identical afterwards, not merely that the
# script exited 0.
#
# NOTE the deliberate DEFAULT ASYMMETRY, pinned in group 3 because it is exactly
# the kind of thing a refactor silently "tidies": version_sync defaults
# `enabled` to TRUE, cross_ref_repair defaults it to FALSE.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"

VS="$ROOT/scripts/docs-sync/version_sync.py"
CR="$ROOT/scripts/docs-sync/cross_ref_repair.py"

for f in "$VS" "$CR"; do
  assert_ok "[ -f '$f' ]" "operation script exists: $(basename "$f")"
done
command -v python3 >/dev/null 2>&1 || { echo "python3 missing — skipping"; suite_summary "docs-sync-ops"; exit 0; }

T="$(mktemp -d)"
trap 'rm -rf "$T"; exit 130' INT
trap 'rm -rf "$T"; exit 143' TERM
trap 'rm -rf "$T"' EXIT

# Runs an operation in an isolated dir. $1 = script, $2 = scenario name.
# Sets up VERSION + a target doc so group 4 can prove non-mutation.
_mk() {
  local d="$T/$2"
  rm -rf "$d"; mkdir -p "$d/.github"
  printf 'ci/v9.9.9\n' > "$d/VERSION"
  printf '# target doc\n\nPin at `ci/v1.0.0`.\n' > "$d/doc.md"
  printf '%s' "$d"
}
_run() { # $1 = script; $2 = dir; captures stdout+status into globals
  OUT="$( cd "$2" && CONFIG_PATH="$3" python3 "$1" 2>&1 )"; RC=$?
}

# --- 1. the skip paths (an absent or disabled config must be a clean no-op) ---
echo ""
echo "== absent / disabled / unconfigured paths exit 0 without touching files =="
d="$(_mk skip-absent vs)"; _run "$VS" "$d" "$d/.github/missing.json"
assert_eq "$RC" "0" "version_sync: absent config exits 0 (docs-sync is opt-in)"
assert_contains "$OUT" "not found; skipping" "version_sync: absent config says it is skipping, not silently succeeding"

d="$(_mk skip-disabled vs)"
printf '{"version_sync":{"enabled":false,"sources":[{"version_file":"VERSION","targets":["doc.md"]}]}}\n' > "$d/.github/docs-sync.json"
_run "$VS" "$d" "$d/.github/docs-sync.json"
assert_eq "$RC" "0" "version_sync: enabled=false exits 0"
assert_contains "$OUT" "disabled in config; skipping" "version_sync: enabled=false names the reason"

d="$(_mk skip-nosrc vs)"
printf '{"version_sync":{"enabled":true,"sources":[]}}\n' > "$d/.github/docs-sync.json"
_run "$VS" "$d" "$d/.github/docs-sync.json"
assert_eq "$RC" "0" "version_sync: empty sources exits 0"
assert_contains "$OUT" "no sources configured; skipping" "version_sync: empty sources is distinguished from disabled"

d="$(_mk skip-missing-src vs)"
printf '{"version_sync":{"enabled":true,"sources":[{"version_file":"NOPE","targets":["doc.md"]}]}}\n' > "$d/.github/docs-sync.json"
_run "$VS" "$d" "$d/.github/docs-sync.json"
assert_eq "$RC" "0" "version_sync: a missing version_file skips THAT source and still exits 0"
assert_contains "$OUT" "NOPE not found" "version_sync: names the version_file it could not read"

d="$(_mk skip-absent cr)"; _run "$CR" "$d" "$d/.github/missing.json"
assert_eq "$RC" "0" "cross_ref_repair: absent config exits 0"
assert_contains "$OUT" "not found; skipping" "cross_ref_repair: absent config says it is skipping"

# --- 2. detection actually detects (the stub's whole job) ---------------------
echo ""
echo "== version_sync reports the REAL version content, not a placeholder =="
d="$(_mk detect vs)"
printf '{"version_sync":{"enabled":true,"sources":[{"version_file":"VERSION","targets":["doc.md"]}]}}\n' > "$d/.github/docs-sync.json"
_run "$VS" "$d" "$d/.github/docs-sync.json"
assert_eq "$RC" "0" "version_sync: detection path exits 0"
assert_contains "$OUT" "ci/v9.9.9" \
  "version_sync: propagated string is the FILE CONTENT (read), not a hardcoded value"
assert_contains "$OUT" "doc.md" "version_sync: names the configured target"
assert_contains "$OUT" "would propagate" \
  "version_sync: still reports as WOULD (alpha.1 is detection-only, not a write)"

# --- 3. the default asymmetry -------------------------------------------------
echo ""
echo "== the two operations default 'enabled' DIFFERENTLY =="
# Pinned because a refactor that "harmonises" these defaults silently turns
# cross_ref_repair ON for every consumer that never mentioned it.
d="$(_mk default-vs vs)"; printf '{}\n' > "$d/.github/docs-sync.json"
_run "$VS" "$d" "$d/.github/docs-sync.json"
assert_contains "$OUT" "no sources configured" \
  "version_sync: with NO version_sync key it still RUNS (enabled defaults true)"
d="$(_mk default-cr cr)"; printf '{}\n' > "$d/.github/docs-sync.json"
_run "$CR" "$d" "$d/.github/docs-sync.json"
assert_contains "$OUT" "disabled in config; skipping" \
  "cross_ref_repair: with NO cross_ref_repair key it SKIPS (enabled defaults false)"
printf '{"cross_ref_repair":{"enabled":true}}\n' > "$d/.github/docs-sync.json"
_run "$CR" "$d" "$d/.github/docs-sync.json"
assert_eq "$RC" "0" "cross_ref_repair: enabled=true exits 0"
assert_contains "$OUT" "alpha.1 stub" "cross_ref_repair: enabled=true reaches the stub body"

# --- 4. fail closed on a broken config ---------------------------------------
echo ""
echo "== an unparseable config fails LOUD, not with a bare traceback =="
for pair in "vs:$VS" "cr:$CR"; do
  name="${pair%%:*}"; script="${pair#*:}"
  d="$(_mk "bad-$name" "$name")"; printf '{not json at all' > "$d/.github/docs-sync.json"
  _run "$script" "$d" "$d/.github/docs-sync.json"
  assert_eq "$RC" "1" "$(basename "$script"): malformed config exits 1 (fail closed)"
  assert_contains "$OUT" "::error::" "$(basename "$script"): malformed config emits a workflow-visible ::error::"
  assert_contains "$OUT" "not valid JSON" "$(basename "$script"): the error names the actual cause"
  assert_absent "$OUT" "Traceback (most recent call last)" \
    "$(basename "$script"): no raw traceback — a config typo must not read as a canon bug"
done

# --- 4b. fail closed on valid-JSON-wrong-shape config ---------------------------
echo ""
echo "== a parseable but misshapen config fails LOUD, not with a bare traceback =="
# Group 4 covers syntax-broken JSON. This covers shape-broken JSON: without the
# isinstance guards the .get/.strip below die on AttributeError/KeyError, i.e.
# the same bare traceback group 4 exists to prevent.
d="$(_mk bad-shape-vs-list vs)"; printf '[]\n' > "$d/.github/docs-sync.json"
_run "$VS" "$d" "$d/.github/docs-sync.json"
assert_eq "$RC" "1" "version_sync: top-level list exits 1 (fail closed)"
assert_contains "$OUT" "::error::" "version_sync: top-level list emits ::error::"
assert_absent "$OUT" "Traceback (most recent call last)" "version_sync: top-level list, no traceback"
d="$(_mk bad-shape-vs-sect vs)"; printf '{"version_sync":[]}\n' > "$d/.github/docs-sync.json"
_run "$VS" "$d" "$d/.github/docs-sync.json"
assert_eq "$RC" "1" "version_sync: non-object section exits 1 (fail closed)"
assert_contains "$OUT" "::error::" "version_sync: non-object section emits ::error::"
assert_absent "$OUT" "Traceback (most recent call last)" "version_sync: non-object section, no traceback"
d="$(_mk bad-shape-vs-entry vs)"
printf '{"version_sync":{"enabled":true,"sources":[{"targets":["doc.md"]}]}}\n' > "$d/.github/docs-sync.json"
_run "$VS" "$d" "$d/.github/docs-sync.json"
assert_eq "$RC" "1" "version_sync: source entry missing version_file exits 1 (fail closed)"
assert_contains "$OUT" "malformed source entry" "version_sync: names the malformed entry, not a KeyError"
assert_absent "$OUT" "Traceback (most recent call last)" "version_sync: malformed entry, no traceback"
d="$(_mk bad-shape-cr-list cr)"; printf '[]\n' > "$d/.github/docs-sync.json"
_run "$CR" "$d" "$d/.github/docs-sync.json"
assert_eq "$RC" "1" "cross_ref_repair: top-level list exits 1 (fail closed)"
assert_contains "$OUT" "::error::" "cross_ref_repair: top-level list emits ::error::"
assert_absent "$OUT" "Traceback (most recent call last)" "cross_ref_repair: top-level list, no traceback"
d="$(_mk bad-shape-cr-sect cr)"; printf '{"cross_ref_repair":false}\n' > "$d/.github/docs-sync.json"
_run "$CR" "$d" "$d/.github/docs-sync.json"
assert_eq "$RC" "1" "cross_ref_repair: non-object section exits 1 (fail closed)"
assert_contains "$OUT" "::error::" "cross_ref_repair: non-object section emits ::error::"
assert_absent "$OUT" "Traceback (most recent call last)" "cross_ref_repair: non-object section, no traceback"

# --- 5. NEVER MUTATES ---------------------------------------------------------
echo ""
echo "== no scenario writes to the consumer's tree =="
# These run post-merge in a job that commits and opens PRs, so a detection stub
# that wrote anything would mutate a consumer repo from a documentation job.
for pair in "vs:$VS" "cr:$CR"; do
  name="${pair%%:*}"; script="${pair#*:}"
  d="$(_mk "mut-$name" "$name")"
  printf '{"version_sync":{"enabled":true,"sources":[{"version_file":"VERSION","targets":["doc.md"]}]},"cross_ref_repair":{"enabled":true}}\n' \
    > "$d/.github/docs-sync.json"
  before_v="$(md5sum "$d/VERSION" | cut -d' ' -f1)"
  before_d="$(md5sum "$d/doc.md" | cut -d' ' -f1)"
  before_tree="$(cd "$d" && find . -type f | sort | xargs md5sum)"
  _run "$script" "$d" "$d/.github/docs-sync.json"
  assert_eq "$(md5sum "$d/VERSION" | cut -d' ' -f1)" "$before_v" \
    "$(basename "$script"): VERSION unchanged (fully-enabled config)"
  assert_eq "$(md5sum "$d/doc.md" | cut -d' ' -f1)" "$before_d" \
    "$(basename "$script"): the configured TARGET doc is unchanged — detection wrote nothing"
  assert_eq "$(cd "$d" && find . -type f | sort | xargs md5sum)" "$before_tree" \
    "$(basename "$script"): no file created, removed, or altered anywhere in the tree"
done

suite_summary "docs-sync-ops"
