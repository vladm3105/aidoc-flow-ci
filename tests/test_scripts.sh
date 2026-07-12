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
current_tag="$(tr -d '[:space:]' < "$ROOT/VERSION")"
cat > "$TMP/repo/.github/workflows/current.yml" <<YML
jobs:
  call:
    uses: vladm3105/aidoc-flow-ci/.github/workflows/composition.yml@${current_tag}
YML
out="$(cd "$TMP/repo" && bash "$ROOT/sync/check-pin-currency.sh" --canon "$current_tag" 2>&1)"
assert_contains "$out" "stale.yml pinned @ci/v1.0.0" "flags the stale @v1.0.0 pin"
assert_absent   "$out" "current.yml"                 "does not flag the current $current_tag pin"

echo "== install.sh --repin sed logic (tag + SHA pins; leaves others alone) =="
f="$TMP/wf.yml"
cat > "$f" <<'YML'
    uses: actions/checkout@abcdef0123456789abcdef0123456789abcdef01 # v7.0.0
    uses: vladm3105/aidoc-flow-ci/.github/workflows/ai-review.yml@ci/v1.8.1
    uses: vladm3105/aidoc-flow-ci/.github/workflows/audit-trail-check.yml@e15ec7d44234726195da316a740ad1684a2c5abd # ci/v1.6.0
    uses: some/other-action@main
YML
target="$current_tag"
sed -i -E "s#(^[[:space:]]*uses:[[:space:]]*vladm3105/aidoc-flow-ci/[^@]+)@ci/v[0-9.]+#\1@${target}#" "$f"
sed -i -E "s|(^[[:space:]]*uses:[[:space:]]*vladm3105/aidoc-flow-ci/[^@]+)@[0-9a-f]{40}([[:space:]]*# ci/v[0-9.]+.*)?\$|\1@${target}|" "$f"
body="$(cat "$f")"
assert_contains "$body" "ai-review.yml@$current_tag"        "tag pin bumped v1.8.1 -> $current_tag"
assert_contains "$body" "audit-trail-check.yml@$current_tag" "SHA pin converted -> @$current_tag"
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

echo "== doc-maintainer planner + apply (mocked GitHub and AI CLIs) =="
mkdir -p "$TMP/doc/bin" "$TMP/doc/repo/docs"
cp "$ROOT/scripts/doc-maintainer/planner.py" "$TMP/doc/planner.py"
cp "$ROOT/scripts/doc-maintainer/apply.py" "$TMP/doc/apply.py"
cat > "$TMP/doc/bin/gh" <<'SH'
#!/usr/bin/env bash
case "$*" in
  *commits/*/pulls*) echo '[{"number":42}]' ;;
  *pulls/42/files*) echo '[{"filename":"src/api.py","status":"modified","patch":"+new endpoint"}]' ;;
  *pulls/42*) echo '{"number":42,"title":"Add API endpoint","body":"Adds /v2/items","user":{"login":"owner"}}' ;;
  *) exit 1 ;;
esac
SH
cat > "$TMP/doc/bin/claude" <<'SH'
#!/usr/bin/env bash
input=$(cat)
if grep -q 'CURRENT FILE:' <<< "$input"; then
  printf '# Project\n\nThe API includes `/v2/items`.\n'
else
  printf '%s\n' '{"updates":[{"path":"README.md","instruction":"Document /v2/items","rationale":"PR #42 adds the endpoint"},{"path":"docs/DECISIONS.md","instruction":"Record the API decision","rationale":"Public API changed"}]}'
fi
SH
chmod +x "$TMP/doc/bin/gh" "$TMP/doc/bin/claude"
cat > "$TMP/doc/repo/config.json" <<'JSON'
{"dry_run":true,"allowed_paths":["README.md","docs/**"],"max_edits_per_pr":5,"auto_merge":{"low_risk_paths":["README.md"],"high_risk_paths":["docs/**"]}}
JSON
printf '# Project\n' > "$TMP/doc/repo/README.md"
printf '# Decisions\n' > "$TMP/doc/repo/docs/DECISIONS.md"
printf '# Conventions\n' > "$TMP/doc/repo/conventions.md"
(cd "$TMP/doc/repo" && PATH="$TMP/doc/bin:$PATH" python3 ../planner.py --merge-sha abc --gh-repo owner/repo --config config.json --conventions conventions.md --reviewer claude --out-plan plan.json)
assert_ok "jq -e '.low_risk_set[0].path == \"README.md\" and .high_risk_set[0].path == \"docs/DECISIONS.md\"' '$TMP/doc/repo/plan.json' >/dev/null" "planner validates and classifies AI-selected docs"
(cd "$TMP/doc/repo" && PATH="$TMP/doc/bin:$PATH" python3 ../apply.py --plan plan.json --tier low_risk --gh-repo owner/repo --reviewer claude --out-dir proposed)
assert_ok "grep -q '/v2/items' '$TMP/doc/repo/proposed/README.md.proposed'" "apply generates a bounded proposed documentation file"

cat > "$TMP/doc/bin/claude" <<'SH'
#!/usr/bin/env bash
cat >/dev/null
printf 'Existing sk-AAAAAAAAAAAAAAAAAAAA and new sk-BBBBBBBBBBBBBBBBBBBB\n'
SH
chmod +x "$TMP/doc/bin/claude"
printf 'Existing sk-AAAAAAAAAAAAAAAAAAAA\n' > "$TMP/doc/repo/README.md"
if (cd "$TMP/doc/repo" && PATH="$TMP/doc/bin:$PATH" python3 ../apply.py --plan plan.json --tier low_risk --gh-repo owner/repo --reviewer claude --out-dir proposed-secret) >/dev/null 2>&1; then
  _r "apply accepted newly introduced secret-shaped content"
else
  _g "apply rejects a new secret even when the source already contains another match"
fi

cat > "$TMP/doc/bin/claude" <<'SH'
#!/usr/bin/env bash
cat >/dev/null
printf 'one replacement line\n'
SH
chmod +x "$TMP/doc/bin/claude"
for n in $(seq 1 20); do echo "original line $n"; done > "$TMP/doc/repo/README.md"
if (cd "$TMP/doc/repo" && PATH="$TMP/doc/bin:$PATH" python3 ../apply.py --plan plan.json --tier low_risk --gh-repo owner/repo --reviewer claude --out-dir proposed-destructive) >/dev/null 2>&1; then
  _r "apply accepted a destructive full-document replacement"
else
  _g "apply rejects excessive document deletion/replacement"
fi

echo "== doc-maintainer reconciler ignores schedule-only coverage =="
if python3 - "$ROOT/scripts/doc-maintainer/reconcile.py" <<'PY'
import contextlib, importlib.util, io, sys
spec = importlib.util.spec_from_file_location("reconcile", sys.argv[1])
module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
sha = "a" * 40
def responses(path):
    if path == "repos/owner/repo": return {"default_branch": "main"}
    if "/commits?" in path: return [{"sha": sha}]
    if "/runs?" in path: return {"workflow_runs": [{"event": "schedule", "head_sha": sha, "status": "in_progress", "display_title": "doc-maintainer"}]}
    raise AssertionError(path)
module.gh_api = responses
sys.argv = [sys.argv[1], "--gh-repo", "owner/repo"]
out = io.StringIO()
with contextlib.redirect_stdout(out):
    assert module.main() == 0
assert "1 main commit" in out.getvalue(), out.getvalue()
PY
then _g "reconciler does not treat its schedule run as maintain coverage"
else _r "reconciler incorrectly treated its schedule run as maintain coverage"
fi

echo "== standards-drift strict mode fails closed =="
mkdir -p "$TMP/drift-bin"
cat > "$TMP/drift-bin/gh" <<'SH'
#!/usr/bin/env bash
if [ "$1 $2" = "auth status" ]; then exit 1; fi
exit 1
SH
chmod +x "$TMP/drift-bin/gh"
assert_ok "PATH='$TMP/drift-bin:$PATH' bash '$ROOT/sync/check-standards-drift.sh' --tier product --repo owner/repo >/dev/null" "warning-only drift mode tolerates an uncheckable control"
if PATH="$TMP/drift-bin:$PATH" bash "$ROOT/sync/check-standards-drift.sh" --tier product --repo owner/repo --strict >/dev/null 2>&1; then
  _r "strict drift mode unexpectedly passed without authentication"
else
  _g "strict drift mode fails when a control cannot be checked"
fi

suite_summary "scripts"
