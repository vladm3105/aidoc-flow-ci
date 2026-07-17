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
assert_ok "grep -q 'CI_TAG_FALLBACK=\"'$current_tag'\"' '$ROOT/install/install.sh'" "standalone installer fallback matches VERSION"

echo "== deploy wizard LiteLLM scaffold contract =="
cat > "$TMP/wizard-gh" <<'SH'
#!/usr/bin/env bash
if [ "$1 $2" = "repo view" ]; then printf 'PUBLIC\n'; exit 0; fi
exit 1
SH
chmod +x "$TMP/wizard-gh"
GH="$TMP/wizard-gh" bash "$ROOT/install/deploy-ci-wizard.sh" scaffold owner/repo "$TMP/scaffold" ai-review composition doc-maintainer >/dev/null
assert_ok "jq -e '.litellm.model == \"ai-reviewer\" and .trust.ai_review == [\"owner\"]' '$TMP/scaffold/.github/ai-review/config.json' >/dev/null" "wizard renders trusted LiteLLM config without placeholders"
# Read the expected pin from VERSION rather than hardcoding it: a literal
# `@ci/vX.Y.Z` here is the same hand-bump-per-release drift class that left
# VERSION + CI_TAG_FALLBACK at v2.0.0 after the v2.0.1 cut (see
# tests/test_version_sync.sh). Asserting against VERSION makes this test verify
# the invariant that matters — "the wizard scaffolds at the current release" —
# instead of freezing one tag string that must be remembered.
_EXPECT_TAG="$(tr -d '[:space:]' < "$ROOT/VERSION")"
assert_ok "grep -q '@${_EXPECT_TAG}' '$TMP/scaffold/.github/workflows/ai-review.yml' && grep -q 'model: ai-doc-maintainer' '$TMP/scaffold/.github/workflows/doc-maintainer.yml'" "wizard emits coherent v2 LiteLLM callers (pinned at VERSION=${_EXPECT_TAG})"

echo "== LiteLLM OpenAI-compatible adapter =="
assert_ok "python3 - '$ROOT/scripts/litellm_client.py' <<'PY'
import importlib.util, json, os, sys
spec = importlib.util.spec_from_file_location('litellm_client', sys.argv[1])
module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
seen = {}
class Response:
    def __enter__(self): return self
    def __exit__(self, *_args): pass
    def read(self, _limit): return json.dumps({'choices':[{'message':{'content':'{\"decision\":\"approve\"}'}}]}).encode()
def fake_urlopen(request, timeout):
    seen['url'] = request.full_url
    seen['auth'] = request.headers['Authorization']
    seen['payload'] = json.loads(request.data)
    seen['timeout'] = timeout
    return Response()
module.open_no_redirect = fake_urlopen
os.environ['LITELLM_BASE_URL'] = 'https://proxy.example/v1/'
os.environ['LITELLM_API_KEY'] = 'test-key'
result = module.completion('review', model='ai-reviewer', json_mode=True, timeout=30)
assert result.startswith('{\"decision\"')
assert seen['url'] == 'https://proxy.example/v1/chat/completions'
assert seen['auth'] == 'Bearer test-key'
assert seen['payload']['model'] == 'ai-reviewer'
assert seen['payload']['response_format'] == {'type':'json_object'}
assert 0 < seen['timeout'] <= 10
PY" "adapter sends the expected authenticated chat-completions request"

assert_ok "python3 - '$ROOT/scripts/litellm_client.py' <<'PY'
import importlib.util, json, os, sys
spec = importlib.util.spec_from_file_location('litellm_client', sys.argv[1])
module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
attempts = {'count': 0}
class Response:
    def __enter__(self): return self
    def __exit__(self, *_args): pass
    def read(self, _limit):
        attempts['count'] += 1
        fence = chr(96) * 3
        content = '' if attempts['count'] < 3 else fence + 'json\n{\"ok\":true}\n' + fence
        return json.dumps({'choices':[{'message':{'content':content}}]}).encode()
module.open_no_redirect = lambda request, timeout: Response()
module.time.sleep = lambda _delay: None
os.environ['LITELLM_BASE_URL'] = 'https://proxy.example/v1'
os.environ['LITELLM_API_KEY'] = 'test-key'
result = module.completion('review', model='ai-reviewer', json_mode=True, timeout=30)
assert attempts['count'] == 3
assert result == '{\"ok\":true}'
PY" "adapter retries empty responses and normalizes fenced JSON"

assert_ok "python3 - '$ROOT/scripts/litellm_client.py' <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location('litellm_client', sys.argv[1])
module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
valid = {'decision':'approve','summary':'ok','findings':[]}
module.validate_verdict(valid)
invalid = [
    {**valid, 'extra': True},
    {**valid, 'decision': 'maybe'},
    {**valid, 'findings': [{'severity':'urgent','path':'x','line':1,'body':'b','fix':'f'}]},
    {**valid, 'findings': [{'severity':'low','path':'x','line':1.5,'body':'b','fix':'f'}]},
    {**valid, 'findings': [{'severity':'low','path':'x','line':1,'body':'b'}]},
    {**valid, 'findings': [{'severity':'medium','path':'x','line':1,'body':'b','fix':'f'}]},
    {**valid, 'decision':'request_changes'},
    {**valid, 'decision':'request_changes', 'findings': [{'severity':'critical','path':'x','line':1,'body':'b','fix':''}]},
]
for value in invalid:
    try: module.validate_verdict(value)
    except module.ResponseShapeError: continue
    raise AssertionError(value)
PY" "verdict validator rejects schema violations fail-closed"

# PLAN-011 T1: verdict mode gets a larger max_tokens default than a plain call,
# and LITELLM_MAX_TOKENS overrides both.
assert_ok "python3 - '$ROOT/scripts/litellm_client.py' <<'PY'
import importlib.util, json, os, sys
spec = importlib.util.spec_from_file_location('litellm_client', sys.argv[1])
module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
seen = {}
class Response:
    def __enter__(self): return self
    def __exit__(self, *_a): pass
    def read(self, _l): return json.dumps({'choices':[{'message':{'content':'{\"decision\":\"approve\",\"summary\":\"ok\",\"findings\":[]}'}}]}).encode()
def fake(request, timeout):
    seen['payload'] = json.loads(request.data); return Response()
module.open_no_redirect = fake
os.environ['LITELLM_BASE_URL'] = 'https://proxy.example/v1'
os.environ['LITELLM_API_KEY'] = 'test-key'
os.environ.pop('LITELLM_MAX_TOKENS', None)
module.completion('r', model='ai-reviewer', json_mode=True, timeout=30, verdict_mode=True)
assert seen['payload']['max_tokens'] == 8192, seen['payload']['max_tokens']
module.completion('r', model='ai-reviewer', json_mode=True, timeout=30)
assert seen['payload']['max_tokens'] == 4096, seen['payload']['max_tokens']
os.environ['LITELLM_MAX_TOKENS'] = '3000'
module.completion('r', model='ai-reviewer', json_mode=True, timeout=30, verdict_mode=True)
assert seen['payload']['max_tokens'] == 3000, seen['payload']['max_tokens']
PY" "verdict mode budgets 8192 tokens (vs 4096 plain); LITELLM_MAX_TOKENS overrides"

# PLAN-011 F1/F2 (SECURITY LOCK): the strict parser was NOT loosened. It must
# still REJECT prose-wrapped and multi-object completions — a reasoning model's
# preamble, or a diff-planted verdict quoted before the real one, must fail
# closed, not be extracted. If a future edit loosens normalize_json_object, this
# test goes red.
assert_ok "python3 - '$ROOT/scripts/litellm_client.py' <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location('litellm_client', sys.argv[1])
module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
# bare + fenced still accepted (regression)
assert module.normalize_json_object('{\"decision\":\"approve\"}') == '{\"decision\":\"approve\"}'
fence = chr(96) * 3
assert '\"decision\"' in module.normalize_json_object(fence + 'json\n{\"decision\":\"approve\"}\n' + fence)
# prose-wrapped and multi-object must FAIL CLOSED (not be extracted)
must_reject = [
    'Here is my review: {\"decision\":\"approve\"}',                 # leading prose
    '{\"decision\":\"approve\"} — done.',                            # trailing prose
    '{\"decision\":\"approve\"}\\n{\"decision\":\"request_changes\"}',# two objects
    'reasoning...\\n{\"decision\":\"approve\",\"findings\":[]}',      # CoT preamble
]
for text in must_reject:
    try:
        module.normalize_json_object(text)
    except module.ResponseShapeError:
        continue
    raise AssertionError('parser accepted what it must reject: ' + repr(text))
PY" "strict JSON parser stays strict — rejects prose-wrapped + multi-object (PLAN-011 F1/F2 lock)"

assert_ok "python3 - '$ROOT/scripts/litellm_client.py' <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location('litellm_client', sys.argv[1])
module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
secret = 'sk-' + 'A' * 24
redacted, mapping = module.redact_secret_shaped('before ' + secret + ' after')
assert secret not in redacted and '[REDACTED_SECRET_0]' in redacted
assert module.restore_redactions(redacted, mapping) == 'before ' + secret + ' after'
PY" "prompt redaction hides and safely restores secret-shaped source content"

echo "== doc-maintainer planner + apply (mocked GitHub and LiteLLM adapter) =="
mkdir -p "$TMP/doc/bin" "$TMP/doc/repo/docs"
cp "$ROOT/scripts/doc-maintainer/planner.py" "$TMP/doc/planner.py"
cp "$ROOT/scripts/doc-maintainer/apply.py" "$TMP/doc/apply.py"
cat > "$TMP/doc/litellm_client.py" <<'PY'
import os
import re
class ResponseShapeError(ValueError): pass
SECRET_PATTERNS = (re.compile(r'\bsk-[A-Za-z0-9_-]{20,}\b'),)
def redact_secret_shaped(text):
    mapping = {}
    def replace(match):
        token = f'[REDACTED_SECRET_{len(mapping)}]'; mapping[token] = match.group(0); return token
    for pattern in SECRET_PATTERNS: text = pattern.sub(replace, text)
    return text, mapping
def restore_redactions(text, mapping):
    for token, original in mapping.items():
        if text.count(token) != 1: raise ResponseShapeError('redaction token missing')
        text = text.replace(token, original)
    return text
def completion(prompt, **_kwargs):
    mode = os.environ.get("LITELLM_FAKE_MODE", "")
    if mode == "secret":
        return "Existing sk-AAAAAAAAAAAAAAAAAAAA and new sk-BBBBBBBBBBBBBBBBBBBB"
    if mode == "destructive":
        return "one replacement line"
    if "CURRENT FILE:" in prompt:
        return "# Project\n\nThe API includes `/v2/items`.\n"
    return '{"updates":[{"path":"README.md","instruction":"Document /v2/items","rationale":"PR #42 adds the endpoint"},{"path":"docs/DECISIONS.md","instruction":"Record the API decision","rationale":"Public API changed"}]}'
PY
cat > "$TMP/doc/bin/gh" <<'SH'
#!/usr/bin/env bash
case "$*" in
  *commits/*/pulls*) echo '[{"number":42}]' ;;
  *pulls/42/files*) echo '[{"filename":"src/api.py","status":"modified","patch":"+new endpoint"}]' ;;
  *pulls/42*) echo '{"number":42,"title":"Add API endpoint","body":"Adds /v2/items","user":{"login":"owner"}}' ;;
  *) exit 1 ;;
esac
SH
chmod +x "$TMP/doc/bin/gh"
cat > "$TMP/doc/repo/config.json" <<'JSON'
{"dry_run":true,"allowed_paths":["README.md","docs/**"],"max_edits_per_pr":5,"auto_merge":{"low_risk_paths":["README.md"],"high_risk_paths":["docs/**"]}}
JSON
printf '# Project\n' > "$TMP/doc/repo/README.md"
printf '# Decisions\n' > "$TMP/doc/repo/docs/DECISIONS.md"
printf '# Conventions\n' > "$TMP/doc/repo/conventions.md"
(cd "$TMP/doc/repo" && PATH="$TMP/doc/bin:$PATH" python3 ../planner.py --merge-sha abc --gh-repo owner/repo --config config.json --conventions conventions.md --model ai-doc-maintainer --out-plan plan.json)
assert_ok "jq -e '.low_risk_set[0].path == \"README.md\" and .high_risk_set[0].path == \"docs/DECISIONS.md\"' '$TMP/doc/repo/plan.json' >/dev/null" "planner validates and classifies AI-selected docs"
(cd "$TMP/doc/repo" && PATH="$TMP/doc/bin:$PATH" python3 ../apply.py --plan plan.json --tier low_risk --gh-repo owner/repo --model ai-doc-maintainer --out-dir proposed)
assert_ok "grep -q '/v2/items' '$TMP/doc/repo/proposed/README.md.proposed'" "apply generates a bounded proposed documentation file"

printf 'Existing sk-AAAAAAAAAAAAAAAAAAAA\n' > "$TMP/doc/repo/README.md"
if (cd "$TMP/doc/repo" && LITELLM_FAKE_MODE=secret PATH="$TMP/doc/bin:$PATH" python3 ../apply.py --plan plan.json --tier low_risk --gh-repo owner/repo --model ai-doc-maintainer --out-dir proposed-secret) >/dev/null 2>&1; then
  _r "apply accepted newly introduced secret-shaped content"
else
  _g "apply rejects a new secret even when the source already contains another match"
fi

for n in $(seq 1 20); do echo "original line $n"; done > "$TMP/doc/repo/README.md"
if (cd "$TMP/doc/repo" && LITELLM_FAKE_MODE=destructive PATH="$TMP/doc/bin:$PATH" python3 ../apply.py --plan plan.json --tier low_risk --gh-repo owner/repo --model ai-doc-maintainer --out-dir proposed-destructive) >/dev/null 2>&1; then
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

echo "== standards-drift detects branching-server contract drift =="
mkdir -p "$TMP/drift-contract/bin" "$TMP/drift-contract/fixtures"
cp "$ROOT/install/templates/branch-protection-product.json" "$TMP/drift-contract/fixtures/bp-canon.json"
cp "$ROOT/install/templates/repo-settings.json" "$TMP/drift-contract/fixtures/repo-canon.json"
cp "$ROOT/install/templates/actions-permissions.json" "$TMP/drift-contract/fixtures/actions.json"
cp "$ROOT/install/templates/labels.json" "$TMP/drift-contract/fixtures/labels.json"
jq '.required_pull_request_reviews = null
  | .enforce_admins = {enabled:true}
  | .required_signatures = {enabled:false}
  | .allow_force_pushes = {enabled:false}
  | .allow_deletions = {enabled:false}' \
  "$TMP/drift-contract/fixtures/bp-canon.json" > "$TMP/drift-contract/fixtures/bp-actual.json"
jq '. + {default_branch:"main", visibility:"public"} | .allow_update_branch=false | .squash_merge_commit_title="COMMIT_OR_PR_TITLE" | .squash_merge_commit_message="COMMIT_MESSAGES"' \
  "$TMP/drift-contract/fixtures/repo-canon.json" > "$TMP/drift-contract/fixtures/repo-actual.json"
cat > "$TMP/drift-contract/bin/gh" <<'SH'
#!/usr/bin/env bash
case "$*" in
  "auth status") exit 0 ;;
  *"branches/main/protection"*) cat "$DRIFT_FIXTURES/bp-actual.json" ;;
  *"actions/permissions/selected-actions"*) echo '{"github_owned_allowed":true,"verified_allowed":true}' ;;
  *"actions/permissions/workflow"*) echo '{"default_workflow_permissions":"read"}' ;;
  *"actions/permissions/access"*) echo '{"access_level":"none"}' ;;
  *"actions/permissions"*) echo '{"allowed_actions":"selected"}' ;;
  *"labels?per_page=100"*) cat "$DRIFT_FIXTURES/labels.json" ;;
  *"repos/owner/repo --jq .default_branch"*) echo main ;;
  *"repos/owner/repo --jq .visibility"*) echo public ;;
  *"repos/owner/repo"*) cat "$DRIFT_FIXTURES/repo-actual.json" ;;
  *) echo "unexpected gh call: $*" >&2; exit 1 ;;
esac
SH
cat > "$TMP/drift-contract/bin/curl" <<'SH'
#!/usr/bin/env bash
case "$*" in
  *"branch-protection-product.json"*) cat "$DRIFT_FIXTURES/bp-canon.json" ;;
  *"repo-settings.json"*) cat "$DRIFT_FIXTURES/repo-canon.json" ;;
  *"actions-permissions.json"*) cat "$DRIFT_FIXTURES/actions.json" ;;
  *"labels.json"*) cat "$DRIFT_FIXTURES/labels.json" ;;
  *) echo "unexpected curl call: $*" >&2; exit 1 ;;
esac
SH
chmod +x "$TMP/drift-contract/bin/gh" "$TMP/drift-contract/bin/curl"
drift_out="$TMP/drift-contract/out.txt"
if DRIFT_FIXTURES="$TMP/drift-contract/fixtures" PATH="$TMP/drift-contract/bin:$PATH" \
  bash "$ROOT/sync/check-standards-drift.sh" --tier product --repo owner/repo --ci-tag ci/v2.0.0 --strict >"$drift_out" 2>&1; then
  _r "strict drift mode accepted missing PR protection and merge-setting drift"
else
  assert_ok "grep -q 'branch-protection.required_pull_request_reviews' '$drift_out' && grep -q 'repo-settings.allow_update_branch' '$drift_out' && grep -q 'repo-settings.squash_merge_commit_title' '$drift_out' && grep -q 'repo-settings.squash_merge_commit_message' '$drift_out'" "strict drift mode detects PR-only, update-branch, and squash metadata drift"
fi

suite_summary "scripts"
