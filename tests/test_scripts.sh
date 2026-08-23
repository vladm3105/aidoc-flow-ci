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

echo "== FT-50: portability (adopter macOS runs install.sh + wizard) =="
# No bare GNU `sed -i ` — BSD/macOS sed requires a backup suffix, so bare `-i`
# errors there. The portable `-i.bak … && rm` form has `-i.`, never `-i<space>`.
assert_ok "! grep -nE 'sed -i[[:space:]]' '$ROOT/install/install.sh' '$ROOT/install/deploy-ci-wizard.sh'" \
  "no bare GNU 'sed -i ' in install.sh / deploy-ci-wizard.sh (portable -i.bak only)"
# install.sh uses `mapfile` (bash 4+) and must guard it up front, not fail cryptically.
assert_ok "grep -q 'BASH_VERSINFO' '$ROOT/install/install.sh'" \
  "install.sh guards bash>=4 (mapfile) with an actionable message up front"

echo "== deploy wizard LiteLLM scaffold contract =="
cat > "$TMP/wizard-gh" <<'SH'
#!/usr/bin/env bash
if [ "$1 $2" = "repo view" ]; then printf 'PUBLIC\n'; exit 0; fi
exit 1
SH
chmod +x "$TMP/wizard-gh"
GH="$TMP/wizard-gh" bash "$ROOT/install/deploy-ci-wizard.sh" scaffold owner/repo "$TMP/scaffold" ai-review composition >/dev/null
assert_ok "jq -e '.litellm.model == \"ai-reviewer\" and .trust.ai_review == [\"owner\"]' '$TMP/scaffold/.github/ai-review/config.json' >/dev/null" "wizard renders trusted LiteLLM config without placeholders"
# Read the expected pin from VERSION rather than hardcoding it: a literal
# `@ci/vX.Y.Z` here is the same hand-bump-per-release drift class that left
# VERSION + CI_TAG_FALLBACK at v2.0.0 after the v2.0.1 cut (see
# tests/test_version_sync.sh). Asserting against VERSION makes this test verify
# the invariant that matters — "the wizard scaffolds at the current release" —
# instead of freezing one tag string that must be remembered.
_EXPECT_TAG="$(tr -d '[:space:]' < "$ROOT/VERSION")"
assert_ok "grep -q '@${_EXPECT_TAG}' '$TMP/scaffold/.github/workflows/ai-review.yml'" "wizard emits coherent v2 LiteLLM callers (pinned at VERSION=${_EXPECT_TAG})"

echo "== LiteLLM OpenAI-compatible adapter =="
assert_ok "python3 - '$ROOT/scripts/llm_client.py' <<'PY'
import importlib.util, json, os, sys
spec = importlib.util.spec_from_file_location('llm_client', sys.argv[1])
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
os.environ['LLM_URL'] = 'https://proxy.example/v1/'
os.environ['LLM_API_KEY'] = 'test-key'
result = module.completion('review', model='ai-reviewer', json_mode=True, timeout=30)
assert result.startswith('{\"decision\"')
assert seen['url'] == 'https://proxy.example/v1/chat/completions'
assert seen['auth'] == 'Bearer test-key'
assert seen['payload']['model'] == 'ai-reviewer'
assert seen['payload']['response_format'] == {'type':'json_object'}
assert 0 < seen['timeout'] <= 10
PY" "adapter sends the expected authenticated chat-completions request"

# #350: a bare 'proxy returned HTTP 401' named neither the secret nor a cause,
# while the URLError path already named its cause precisely. The asymmetry is
# what made the incident expensive to diagnose, so the 401 path is asserted to
# name the secret it cannot read back.
assert_ok "python3 - '$ROOT/scripts/llm_client.py' <<'PY'
import importlib.util, io, os, sys, urllib.error
import contextlib
spec = importlib.util.spec_from_file_location('llm_client', sys.argv[1])
module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
def raise_401(request, timeout):
    raise urllib.error.HTTPError(request.full_url, 401, 'Unauthorized', {}, None)
module.open_no_redirect = raise_401
os.environ['LLM_URL'] = 'https://proxy.example/v1'
os.environ['LLM_API_KEY'] = 'test-key'
err = io.StringIO()
with contextlib.redirect_stderr(err):
    try:
        module.completion('review', model='ai-reviewer', json_mode=False, timeout=30)
        raise AssertionError('a 401 must not be swallowed')
    except SystemExit:
        pass
msg = err.getvalue()
assert 'HTTP 401' in msg, msg
assert 'LLM_API_KEY' in msg, msg
assert 'set-llm-secrets.sh' in msg, msg
# A retryable status keeps the bare form — the hint is for auth failures only.
assert module.auth_hint(429) == '' and module.auth_hint(500) == ''
assert module.auth_hint(200) == '' and module.auth_hint(404) == ''
# 403 must NOT tell the operator to re-provision: it means the token
# authenticated but is not authorized for this model, which is exactly why
# install/set-llm-secrets.sh ACCEPTS 403 when probing /models. Sending them
# to re-provision a key the provisioner just certified is the loop #350 was.
h403 = module.auth_hint(403)
assert h403 != '', 'a 403 still deserves a hint'
assert 'not authorized' in h403, h403
assert 're-provision' not in h403.lower(), h403
PY" "a 401 names the secret to re-provision; a 403 says the opposite"

assert_ok "python3 - '$ROOT/scripts/llm_client.py' <<'PY'
import importlib.util, json, os, sys
spec = importlib.util.spec_from_file_location('llm_client', sys.argv[1])
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
os.environ['LLM_URL'] = 'https://proxy.example/v1'
os.environ['LLM_API_KEY'] = 'test-key'
result = module.completion('review', model='ai-reviewer', json_mode=True, timeout=30)
assert attempts['count'] == 3
assert result == '{\"ok\":true}'
PY" "adapter retries empty responses and normalizes fenced JSON"

assert_ok "python3 - '$ROOT/scripts/llm_client.py' <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location('llm_client', sys.argv[1])
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
# and LLM_MAX_TOKENS overrides both.
assert_ok "python3 - '$ROOT/scripts/llm_client.py' <<'PY'
import importlib.util, json, os, sys
spec = importlib.util.spec_from_file_location('llm_client', sys.argv[1])
module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
seen = {}
class Response:
    def __enter__(self): return self
    def __exit__(self, *_a): pass
    def read(self, _l): return json.dumps({'choices':[{'message':{'content':'{\"decision\":\"approve\",\"summary\":\"ok\",\"findings\":[]}'}}]}).encode()
def fake(request, timeout):
    seen['payload'] = json.loads(request.data); return Response()
module.open_no_redirect = fake
os.environ['LLM_URL'] = 'https://proxy.example/v1'
os.environ['LLM_API_KEY'] = 'test-key'
os.environ.pop('LLM_MAX_TOKENS', None)
module.completion('r', model='ai-reviewer', json_mode=True, timeout=30, verdict_mode=True)
assert seen['payload']['max_tokens'] == 24576, seen['payload']['max_tokens']
module.completion('r', model='ai-reviewer', json_mode=True, timeout=30)
assert seen['payload']['max_tokens'] == 4096, seen['payload']['max_tokens']
os.environ['LLM_MAX_TOKENS'] = '3000'
module.completion('r', model='ai-reviewer', json_mode=True, timeout=30, verdict_mode=True)
assert seen['payload']['max_tokens'] == 3000, seen['payload']['max_tokens']
PY" "verdict mode budgets 24576 tokens (vs 4096 plain); LLM_MAX_TOKENS overrides"

# PLAN-011 F1/F2 (SECURITY LOCK): the strict parser was NOT loosened. It must
# still REJECT prose-wrapped and multi-object completions — a reasoning model's
# preamble, or a diff-planted verdict quoted before the real one, must fail
# closed, not be extracted. If a future edit loosens normalize_json_object, this
# test goes red.
assert_ok "python3 - '$ROOT/scripts/llm_client.py' <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location('llm_client', sys.argv[1])
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

# REDACTION MOVED, AND THE TEST MOVED WITH IT. This drove
# `llm_client.redact_secret_shaped` / `restore_redactions` — helpers `completion()`
# never called. Their only real caller was `scripts/doc-maintainer/`, deleted by
# CI-0040/#496, after which the test proved a live-looking control over dead code
# while the ACTUAL redaction path went unasserted — and that path had a hole.
#
# ai-review redacts the diff before assembling the prompt and writes
# `.ai-review/diff-for-review.txt`. The reviewer read that file; the
# `ai-review-verdict` ARTIFACT and the `autofix` fixer prompt both read the RAW
# `.ai-review/diff.txt`. So a PR that committed an AWS key or a PAT had it hidden
# from the reviewer model and handed in the clear to the fixer model, plus stored
# for 24h in an artifact readable by anyone with Actions read. Assert the property
# that was violated: NO consumer outside the redaction step reads the raw diff.
_air=.github/workflows/ai-review.yml
if [ -f "$_air" ]; then
  assert_ok "grep -q \"Path('.ai-review/diff-for-review.txt').write_bytes\" '$_air'" \
    "ai-review: the redaction step still writes diff-for-review.txt"
  # The raw diff may be referenced ONLY where it is produced and consumed by the
  # redactor itself. Anywhere else is an egress path. Count the raw references
  # and pin them to those sites by line, so a NEW reader reds here.
  # Every non-comment line naming the raw diff. The redactor legitimately writes
  # it (the gh api capture), sizes it, and reads it once; nothing else may.
  # PIN THE WHOLE REFERENCE SET, not one shape. Counting only `read_text` readers
  # stated "no consumer outside the redaction step reads the raw diff" while
  # measuring "exactly one Python read". A new `path: .ai-review/diff.txt` on an
  # upload step, or a `cat .ai-review/diff.txt`, adds no `read_text` and the
  # count stays 1 — precisely the regression the comment says it prevents.
  # The raw diff has exactly four legitimate sites, all inside the step that
  # produces and redacts it: the `gh api` capture, the `-s` emptiness test, the
  # `wc -c` size line, and the redactor's own read.
  _raw_refs="$(grep -n '\.ai-review/diff\.txt' "$_air" | grep -v '^[0-9]*: *#' || true)"
  _raw_n="$(printf '%s\n' "$_raw_refs" | grep -c . || true)"
  assert_eq "$_raw_n" "4" \
    "ai-review: the raw diff is referenced at exactly its 4 producer/sizing/read sites — a 5th is a new egress path"
  _raw_readers="$(printf '%s\n' "$_raw_refs" | grep -c 'read_text' || true)"
  assert_eq "$_raw_readers" "1" "ai-review: ...and exactly ONE of them READS it — the redactor itself"
  assert_absent "$_raw_refs" "upload-artifact" "ai-review: ...and none of them is an artifact path"
  assert_absent "$_raw_refs" "cat " "ai-review: ...and none of them cats it into a prompt"

  # The two egress points must name the REDACTED file.
  _art_blk="$(sed -n '/name: ai-review-verdict/,/retention-days/p' "$_air")"
  assert_contains "$_art_blk" "diff-for-review.txt" \
    "ai-review: the uploaded artifact ships the REDACTED diff"
  assert_absent "$_art_blk" ".ai-review/diff.txt" \
    "ai-review: ...and NOT the raw one (it was 24h-readable by anyone with Actions read)"

  _fix_blk="$(grep 'cat verdict-in/' "$_air" || true)"
  assert_contains "$_fix_blk" "verdict-in/diff-for-review.txt" \
    "ai-review: the autofix fixer prompt reads the REDACTED diff"
  assert_absent "$_fix_blk" "verdict-in/diff.txt" \
    "ai-review: ...and never the raw one (the fixer got secrets the reviewer was shielded from)"
fi

# And the dead helpers must STAY dead: re-adding them to the client protects
# nothing (ai-review does not call it for redaction) while restoring the false
# impression that it does.
assert_absent "$(cat "$ROOT/scripts/llm_client.py")" "def redact_secret_shaped" \
  "llm_client.py carries no redaction helper (its only caller, doc-maintainer, is retired — CI-0040)"

# --- RETIRED CHECKS DECLARATION (PLAN-024 A7, DECISIONS.md CI-0040) ---
# Seven doc-maintainer blocks stood here and are REMOVED with the flow:
#   planner + apply (mocked GitHub/LiteLLM), #353 de-conflation, #354 the
#   apply-limit pre-filter, #360 inventory + prompt binding, #352 Step 9 dry-run
#   patch rendering (x2), and the reconciler schedule-coverage guard.
#
# Roughly 58 assertions go with them. They tested scripts/doc-maintainer/*.py
# and .github/workflows/doc-maintainer.yml, all deleted in this change, so they
# are not portable to a surviving surface — docs-sync has no planner, no apply
# tier model and no LiteLLM call at all.
#
# WHAT IS LOST, STATED: §24.2 error-message de-conflation and §24.3
# executable-default now have NO automated reader anywhere in the suite. Both
# rules are KEPT in REPO_STANDARDS.md — they are general and doc-maintainer was
# only their worked example — but they are enforced by review alone from here.
# Do not read the smaller suite as a smaller contract.

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
  *"actions/permissions/selected-actions"*) echo '{"github_owned_allowed":true,"verified_allowed":false,"patterns_allowed":["vladm3105/*","actions/*","github/*"]}' ;;
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

echo ""
echo "== standards-drift compares patterns_allowed (FT-53) =="
# Since CI-0011 set verified_allowed=false this list is the ONLY non-GitHub-owned
# admission, and it was the one field drift never compared. Vary ONLY it.
mkdir -p "$TMP/drift-pa/bin" "$TMP/drift-pa/fixtures"
cp "$ROOT/install/templates/actions-permissions.json" "$TMP/drift-pa/fixtures/actions.json"
cp "$ROOT/install/templates/branch-protection-product.json" "$TMP/drift-pa/fixtures/bp.json"
cp "$ROOT/install/templates/repo-settings.json" "$TMP/drift-pa/fixtures/repo.json"
cp "$ROOT/install/templates/labels.json" "$TMP/drift-pa/fixtures/labels.json"
jq '. + {default_branch:"main", visibility:"public"}' "$TMP/drift-pa/fixtures/repo.json" > "$TMP/drift-pa/fixtures/repo-actual.json"
cat > "$TMP/drift-pa/bin/gh" <<'SH'
#!/usr/bin/env bash
case "$*" in
  "auth status") exit 0 ;;
  *"branches/main/protection"*) cat "$DRIFT_FIXTURES/bp.json" ;;
  *"actions/permissions/selected-actions"*) echo "{\"github_owned_allowed\":true,\"verified_allowed\":false,\"patterns_allowed\":${PA_LOCAL}}" ;;
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
cat > "$TMP/drift-pa/bin/curl" <<'SH'
#!/usr/bin/env bash
case "$*" in
  *"branch-protection-product.json"*) cat "$DRIFT_FIXTURES/bp.json" ;;
  *"repo-settings.json"*) cat "$DRIFT_FIXTURES/repo.json" ;;
  *"actions-permissions.json"*) cat "$DRIFT_FIXTURES/actions.json" ;;
  *"labels.json"*) cat "$DRIFT_FIXTURES/labels.json" ;;
  *) echo "unexpected curl call: $*" >&2; exit 1 ;;
esac
SH
chmod +x "$TMP/drift-pa/bin/gh" "$TMP/drift-pa/bin/curl"
_pa_run() { # $1 = JSON array literal for the repo's live patterns_allowed; $2.. = extra flags
  local pa="$1"; shift
  PA_LOCAL="$pa" DRIFT_FIXTURES="$TMP/drift-pa/fixtures" PATH="$TMP/drift-pa/bin:$PATH" \
    bash "$ROOT/sync/check-standards-drift.sh" --tier product --repo owner/repo --ci-tag ci/v2.0.0 "$@" 2>&1 || true
}
_pa_rc() { # same, but yields the EXIT CODE (the strict gate is the point of the feature)
  local pa="$1"; shift
  PA_LOCAL="$pa" DRIFT_FIXTURES="$TMP/drift-pa/fixtures" PATH="$TMP/drift-pa/bin:$PATH" \
    bash "$ROOT/sync/check-standards-drift.sh" --tier product --repo owner/repo --ci-tag ci/v2.0.0 "$@" >/dev/null 2>&1
  echo $?
}
# Derive the fixtures FROM the template rather than freezing literals — adding a
# 4th canon pattern must not fail tests whose names are about ordering.
_pa_canon="$(jq -c '.selected_actions.patterns_allowed' "$TMP/drift-pa/fixtures/actions.json")"
_pa_reordered="$(jq -c '.selected_actions.patterns_allowed | reverse' "$TMP/drift-pa/fixtures/actions.json")"
_pa_dropone="$(jq -c '.selected_actions.patterns_allowed[1:]' "$TMP/drift-pa/fixtures/actions.json")"
_pa_dropped="$(jq -r '.selected_actions.patterns_allowed[0]' "$TMP/drift-pa/fixtures/actions.json")"
_pa_plus="$(jq -c '.selected_actions.patterns_allowed + ["aquasecurity/*"]' "$TMP/drift-pa/fixtures/actions.json")"

# (1) same SET, different ORDER => no drift. Paired with a POSITIVE control, so the
#     assertion cannot be satisfied merely by the feature not existing.
pa_ord="$(_pa_run "$_pa_reordered")"
assert_absent "$pa_ord" "patterns_allowed" "drift: identical patterns in a different ORDER is not drift"
assert_contains "$pa_ord" "0 drift" "drift: reordered set really produced ZERO drift (positive control)"
assert_eq "$(_pa_rc "$_pa_reordered" --strict)" "0" "drift: reordered set passes the strict gate"

# (2) a canon pattern MISSING and uncovered => availability drift, named, and it
#     must COUNT and FAIL the strict gate — warning text alone is not the feature.
pa_miss="$(_pa_run "$_pa_dropone")"
assert_contains "$pa_miss" "patterns_allowed: MISSING" "drift: a missing canon pattern is reported"
assert_contains "$pa_miss" "$_pa_dropped" "drift: names the missing pattern"
assert_contains "$pa_miss" "startup_failure" "drift: explains the missing-pattern consequence"
assert_contains "$pa_miss" "1 drift" "drift: a missing pattern INCREMENTS the drift count"
assert_eq "$(_pa_rc "$_pa_dropone" --strict)" "1" "drift: a missing pattern FAILS the strict gate"

# (3) an EXTRA owner => supply-chain drift, reported separately, counted, strict-fatal.
pa_extra="$(_pa_run "$_pa_plus")"
assert_contains "$pa_extra" "patterns_allowed: EXTRA" "drift: an extra owner is reported"
assert_contains "$pa_extra" "aquasecurity/*" "drift: names the extra owner"
assert_absent "$pa_extra" "patterns_allowed: MISSING" "drift: an extra owner is NOT reported as missing"
assert_contains "$pa_extra" "1 drift" "drift: an extra owner INCREMENTS the drift count"
assert_eq "$(_pa_rc "$_pa_plus" --strict)" "1" "drift: an extra owner FAILS the strict gate (supply-chain widening)"

# (4) both at once => both reported, and BOTH counted (2, not 1).
pa_both="$(_pa_run '["actions/*","aquasecurity/*"]')"
assert_contains "$pa_both" "patterns_allowed: MISSING" "drift: reports MISSING when both conditions hold"
assert_contains "$pa_both" "patterns_allowed: EXTRA" "drift: reports EXTRA when both conditions hold"
assert_contains "$pa_both" "2 drift" "drift: MISSING and EXTRA each count once"

# (5) GLOB SUBSUMPTION. `vladm3105/*` covers `vladm3105/aidoc-flow-ci/*`, so a
#     BROADENED pattern loses no coverage and must NOT be reported as blocked.
#     This is the live CI-0011 rollout shape: consumers pinned at an older tag whose
#     settings were already widened. A literal set-diff called it MISSING and
#     asserted a startup_failure that cannot happen — and failed the strict gate.
mkdir -p "$TMP/drift-pa/fixtures-old"
cp "$TMP/drift-pa/fixtures/"*.json "$TMP/drift-pa/fixtures-old/"
jq '.selected_actions.patterns_allowed = ["vladm3105/aidoc-flow-ci/*","actions/*","github/*"]' \
  "$TMP/drift-pa/fixtures/actions.json" > "$TMP/drift-pa/fixtures-old/actions.json"
pa_broad="$(PA_LOCAL='["vladm3105/*","actions/*","github/*"]' DRIFT_FIXTURES="$TMP/drift-pa/fixtures-old" \
  PATH="$TMP/drift-pa/bin:$PATH" bash "$ROOT/sync/check-standards-drift.sh" \
  --tier product --repo owner/repo --ci-tag ci/v2.0.0 2>&1 || true)"
assert_absent "$pa_broad" "patterns_allowed: MISSING" "drift: a BROADENED pattern is not a false MISSING (glob subsumption)"
assert_contains "$pa_broad" "patterns_allowed: EXTRA" "drift: the broadening is still reported as EXTRA"

# (6) the INVERSE — repo narrower than canon — IS a real loss of coverage and must fire.
pa_narrow="$(_pa_run '["vladm3105/aidoc-flow-ci/*","actions/*","github/*"]')"   # canon is account-wide
assert_contains "$pa_narrow" "patterns_allowed: MISSING" "drift: a NARROWED repo pattern is real drift (coverage lost)"
# ...and symmetrically: that narrower live pattern sits INSIDE canon's `vladm3105/*`,
# so it widens nothing. Reporting it EXTRA ("wider than canon") would be false.
assert_absent "$pa_narrow" "patterns_allowed: EXTRA" "drift: a live pattern subsumed BY canon is not a false EXTRA"

# (7) an unreadable API body must say so, not invent a missing-pattern list.
pa_bad="$(_pa_run '"not-an-object"')"
assert_contains "$pa_bad" "patterns_allowed" "drift: unreadable response is surfaced"
assert_absent "$pa_bad" "patterns_allowed: MISSING" "drift: unreadable response is NOT reported as missing patterns"

# ── CI-0018: repo-settings must apply the SAME unreadable-vs-drifted rule ──────
# Under the default GITHUB_TOKEN the admin-only merge settings are simply ABSENT
# from the `gh api repos/` body. The old arm compared canon against the missing
# value and printed `canon=false actual=null`, presenting unreadable state as a
# drift finding — while the neighbouring actions.* arm (case 7 above) correctly
# said "cannot check". These lock in the consistent behaviour.
mkdir -p "$TMP/drift-ro/fixtures" "$TMP/drift-ro/bin"
cp "$TMP/drift-pa/fixtures/"*.json "$TMP/drift-ro/fixtures/"
cp "$TMP/drift-pa/bin/gh" "$TMP/drift-pa/bin/curl" "$TMP/drift-ro/bin/"
# a read-only token's view: repo metadata present, admin-only merge fields absent
jq '{name:"repo", default_branch:"main", visibility:"public", private:false}' \
  "$TMP/drift-pa/fixtures/repo-actual.json" > "$TMP/drift-ro/fixtures/repo-actual.json"
ro_out="$(PA_LOCAL="$_pa_canon" DRIFT_FIXTURES="$TMP/drift-ro/fixtures" PATH="$TMP/drift-ro/bin:$PATH" \
  bash "$ROOT/sync/check-standards-drift.sh" --tier product --repo owner/repo --ci-tag ci/v2.0.0 2>&1 || true)"
assert_absent   "$ro_out" "actual=null"                "drift: an UNREADABLE repo-setting is never printed as canon-vs-null drift"
assert_absent   "$ro_out" "repo-settings.allow_merge_commit" "drift: no per-key drift line for fields the token could not read"
assert_contains "$ro_out" "cannot check repo-settings" "drift: unreadable repo-settings is reported as cannot-check"
assert_contains "$ro_out" "administration: read"       "drift: names the missing token scope (actionable)"
# ANCHORED to the cannot-check message. An unanchored "allow_merge_commit" match
# is satisfied by the OLD buggy output (`repo-settings.allow_merge_commit:
# canon=false actual=null`) — i.e. by the very defect it exists to detect.
assert_contains "$ro_out" "admin PAT: allow_merge_commit" "drift: names WHICH fields were unreadable"
assert_contains "$ro_out" "0 drift"                    "drift: unreadable repo-settings contributes ZERO drift"
assert_eq "$(PA_LOCAL="$_pa_canon" DRIFT_FIXTURES="$TMP/drift-ro/fixtures" PATH="$TMP/drift-ro/bin:$PATH" \
  bash "$ROOT/sync/check-standards-drift.sh" --tier product --repo owner/repo --ci-tag ci/v2.0.0 --strict >/dev/null 2>&1; echo $?)" \
  "1" "drift: strict still FAILS on uncheckable repo-settings (a gate that cannot read must not pass)"

# POSITIVE CONTROL — with the fields READABLE, genuine drift must still fire.
# Without this, the assertions above would be satisfied by the check not existing.
mkdir -p "$TMP/drift-rw/fixtures" "$TMP/drift-rw/bin"
cp "$TMP/drift-pa/fixtures/"*.json "$TMP/drift-rw/fixtures/"
cp "$TMP/drift-pa/bin/gh" "$TMP/drift-pa/bin/curl" "$TMP/drift-rw/bin/"
jq '.allow_merge_commit = (.allow_merge_commit | not)' \
  "$TMP/drift-pa/fixtures/repo-actual.json" > "$TMP/drift-rw/fixtures/repo-actual.json"
rw_out="$(PA_LOCAL="$_pa_canon" DRIFT_FIXTURES="$TMP/drift-rw/fixtures" PATH="$TMP/drift-rw/bin:$PATH" \
  bash "$ROOT/sync/check-standards-drift.sh" --tier product --repo owner/repo --ci-tag ci/v2.0.0 2>&1 || true)"
assert_contains "$rw_out" "repo-settings.allow_merge_commit" "drift: a READABLE drifted repo-setting is still reported"
assert_contains "$rw_out" "1 drift"                          "drift: a readable drifted repo-setting INCREMENTS the count"
assert_absent   "$rw_out" "cannot check repo-settings"        "drift: readable settings are not mislabelled uncheckable"

# ── CI-0018: the coverage summary bounds what a green result claims ────────────
assert_contains "$ro_out" "coverage — verified"    "drift: emits a coverage summary"
assert_contains "$ro_out" "NOT verified"           "drift: names the families it could NOT verify"
assert_contains "$ro_out" "NOT verified: repo-settings" "drift: the unverified list includes repo-settings"
assert_contains "$rw_out" "coverage — verified 4/4" "drift: a fully-readable run reports full coverage"

# ── CI-0017: the http:// opt-in and the loopback-in-container diagnosis ───────
assert_ok "python3 - '$ROOT/scripts/llm_client.py' <<'PY'
import importlib.util, os, sys
spec = importlib.util.spec_from_file_location('lc', sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)

# http:// is REJECTED without the opt-in, regardless of host.
os.environ.pop('LLM_ALLOW_INSECURE_HTTP', None)
try:
    m.endpoint('http://172.17.0.1:4001/v1')
    raise AssertionError('http:// accepted without the opt-in')
except SystemExit:
    pass
# ...and ACCEPTED with it. The flag is keyed on the SCHEME, not on any
# visibility/repo signal — that is the whole point of CI-0017.
os.environ['LLM_ALLOW_INSECURE_HTTP'] = 'true'
assert m.endpoint('http://172.17.0.1:4001/v1') == 'http://172.17.0.1:4001/v1/chat/completions'
assert m.endpoint('https://proxy.example/v1') == 'https://proxy.example/v1/chat/completions'

# Inside a container, loopback gets a NAMED cause; the bridge address does not.
os.environ['LLM_ASSUME_CONTAINER'] = 'true'
for host in ('127.0.0.1', 'localhost', '::1'):
    url = f'http://[{host}]:4001/v1' if host == '::1' else f'http://{host}:4001/v1'
    hint = m.loopback_hint(url)
    assert 'bridge' in hint and '172.17.0.1' in hint, f'no bridge hint for {host}: {hint!r}'
assert m.loopback_hint('http://172.17.0.1:4001/v1') == ''
assert m.loopback_hint('https://proxy.example/v1') == ''

# Outside a container the hint is silent — it must never fire on a developer
# host, where loopback is legitimately correct.
os.environ['LLM_ASSUME_CONTAINER'] = 'false'
m.Path = m.Path  # keep reference explicit
if not (m.Path('/.dockerenv').exists() or m.Path('/run/.containerenv').exists()):
    assert m.loopback_hint('http://127.0.0.1:4001/v1') == '' or m.in_container()

# The hint is message-only: it cannot raise, even on a URL endpoint() rejected.
assert isinstance(m.loopback_hint('http://127.0.0.1:4001/v1'), str)
PY" "litellm: http opt-in is scheme-keyed and loopback-in-container is named (CI-0017)"

# ── CI-0018 regressions found in review: "verified" must be ALL-OR-NOTHING ─────
# The first cut marked a family verified on ANY partial progress, so a run could
# say "cannot check repo-settings" AND "verified 4/4" in the same output — the
# exact defect the coverage summary exists to prevent.
mkdir -p "$TMP/drift-partial/fixtures" "$TMP/drift-partial/bin"
cp "$TMP/drift-pa/fixtures/"*.json "$TMP/drift-partial/fixtures/"
cp "$TMP/drift-pa/bin/gh" "$TMP/drift-pa/bin/curl" "$TMP/drift-partial/bin/"
# a token that can read exactly ONE of the eight admin-only merge settings
jq '{name:"repo",default_branch:"main",visibility:"public",allow_merge_commit:.allow_merge_commit}' \
  "$TMP/drift-pa/fixtures/repo-actual.json" > "$TMP/drift-partial/fixtures/repo-actual.json"
part_out="$(PA_LOCAL="$_pa_canon" DRIFT_FIXTURES="$TMP/drift-partial/fixtures" PATH="$TMP/drift-partial/bin:$PATH" \
  bash "$ROOT/sync/check-standards-drift.sh" --tier product --repo owner/repo --ci-tag ci/v2.0.0 2>&1 || true)"
assert_contains "$part_out" "cannot check repo-settings" "drift: a PARTIAL repo-settings read is reported uncheckable"
assert_absent   "$part_out" "verified 4/4"               "drift: a partially-read family is NOT counted as verified"
assert_contains "$part_out" "NOT verified: repo-settings" "drift: the partially-read family is named unverified"

# Same rule for `actions`, which has four independent arms. The pre-existing
# pa_bad fixture (unreadable selected-actions) used to report `verified 4/4`.
assert_absent   "$pa_bad" "verified 4/4"                 "drift: an unreadable actions arm withholds the actions verified mark"
assert_contains "$pa_bad" "NOT verified: actions"        "drift: the unreadable actions family is named unverified"

# An EMPTY-but-successful `gh api` body must be an API/transport error, never
# eight `actual=` drift lines. `jq -e` exits 0 on empty input for ANY filter, so
# the `[ -s ]` file test in the shape guard is load-bearing.
mkdir -p "$TMP/drift-empty/fixtures" "$TMP/drift-empty/bin"
cp "$TMP/drift-pa/fixtures/"*.json "$TMP/drift-empty/fixtures/"
cp "$TMP/drift-pa/bin/curl" "$TMP/drift-empty/bin/"
sed 's|\*"repos/owner/repo"\*) cat "$DRIFT_FIXTURES/repo-actual.json" ;;|*"repos/owner/repo"*) : ;;|' \
  "$TMP/drift-pa/bin/gh" > "$TMP/drift-empty/bin/gh"
chmod +x "$TMP/drift-empty/bin/gh"
empty_out="$(PA_LOCAL="$_pa_canon" DRIFT_FIXTURES="$TMP/drift-empty/fixtures" PATH="$TMP/drift-empty/bin:$PATH" \
  bash "$ROOT/sync/check-standards-drift.sh" --tier product --repo owner/repo --ci-tag ci/v2.0.0 2>&1 || true)"
assert_absent   "$empty_out" "actual="                    "drift: an empty API body yields NO canon-vs-blank drift lines"
assert_contains "$empty_out" "empty or is not a JSON object" "drift: an empty API body is diagnosed as a transport failure"
assert_contains "$empty_out" "0 drift"                    "drift: an empty API body contributes ZERO drift"
assert_absent   "$empty_out" "verified 4/4"               "drift: an empty API body does not report full coverage"

# A malformed (non-JSON) body takes the same path, not the token-scope message.
mkdir -p "$TMP/drift-html/fixtures" "$TMP/drift-html/bin"
cp "$TMP/drift-pa/fixtures/"*.json "$TMP/drift-html/fixtures/"
cp "$TMP/drift-pa/bin/curl" "$TMP/drift-html/bin/"
sed 's|\*"repos/owner/repo"\*) cat "$DRIFT_FIXTURES/repo-actual.json" ;;|*"repos/owner/repo"*) echo "<html>502</html>" ;;|' \
  "$TMP/drift-pa/bin/gh" > "$TMP/drift-html/bin/gh"
chmod +x "$TMP/drift-html/bin/gh"
html_out="$(PA_LOCAL="$_pa_canon" DRIFT_FIXTURES="$TMP/drift-html/fixtures" PATH="$TMP/drift-html/bin:$PATH" \
  bash "$ROOT/sync/check-standards-drift.sh" --tier product --repo owner/repo --ci-tag ci/v2.0.0 2>&1 || true)"
assert_contains "$html_out" "empty or is not a JSON object" "drift: a non-JSON body is diagnosed as a transport failure"
assert_absent   "$html_out" "actual="                       "drift: a non-JSON body yields no drift comparison"

# The emptiest possible run (no jq) must still state its coverage, rather than
# exiting 0 silently — that was the greenest result for the least verification.
# An invalid --tier bails out through the same `stop_uncheckable` path as a
# missing gh/jq, before any control family is examined. That run checks the
# LEAST while still exiting 0 in non-strict mode, so it is exactly the one that
# must not read as a clean pass.
early_out="$(bash "$ROOT/sync/check-standards-drift.sh" --tier bogus --repo owner/repo --ci-tag ci/v2.0.0 2>&1 || true)"
assert_contains "$early_out" "coverage — verified 0/4" "drift: an early bail-out still reports 0/4 coverage"
assert_contains "$early_out" "NOT verified"            "drift: an early bail-out names every family as unverified"

echo "== #323: the sync-version-refs pre-commit hook must stay always_run =="
# A `files:` regex on this hook is pure drift surface: it is `pass_filenames: false`,
# so the script always checks every TARGETS entry regardless — the regex only decides
# WHETHER the hook runs. The old one listed 6 of 14 targets and had drifted behind
# TARGETS, so a commit touching only docs/MIGRATION_v2.0.0.md (the file CI-0024 is
# about) skipped the hook locally and the author first learned at PR time.
svr_hook="$(python3 - "$ROOT" <<'PYEOF'
import yaml, os, sys
d = yaml.safe_load(open(os.path.join(sys.argv[1], ".pre-commit-config.yaml")))
h = [x for r in d.get("repos", []) for x in r.get("hooks", []) if x.get("id") == "sync-version-refs"]
if len(h) != 1:
    print("HOOK-NOT-FOUND:%d" % len(h)); raise SystemExit
h = h[0]
bad = []
if h.get("always_run") is not True:      bad.append("not-always_run")
if "files" in h:                          bad.append("has-files-filter:%s" % h["files"])
if h.get("pass_filenames") is not False:  bad.append("pass_filenames-not-false")
# `stages:` would silence the hook at commit time — the SAME outcome #323 fixes,
# and REPO_STANDARDS §14.1a records a prior vacuous-check bug on this exact
# surface. Absence of the key means "all default stages".
if "stages" in h:                         bad.append("has-stages:%s" % h["stages"])
# `--check-published` does a `git ls-remote`; the script's own header forbids
# wiring it into pre-commit because it would deadlock every release (VERSION
# names a tag that is cut FROM the bump commit).
entry = h.get("entry", "")
if "--check" not in entry:                bad.append("entry-not-check:%s" % entry)
if "--check-published" in entry:          bad.append("entry-is-check-published")
print(",".join(bad) or "OK")
PYEOF
)"
assert_eq "$svr_hook" "OK" "sync-version-refs hook is always_run with no files: filter (#323)"

echo "== FT-30 dry-run helper (scripts/ft30-dry-run.sh) =="
FT30="$ROOT/scripts/ft30-dry-run.sh"
assert_ok "[ -x '$FT30' ]" "ft30-dry-run.sh is executable"
assert_ok "bash -n '$FT30'" "ft30-dry-run.sh parses"
# A real run WRITES to another repo, so only the offline paths are exercised.
assert_ok "bash '$FT30' --nonsense >/dev/null 2>&1; [ \$? -eq 2 ]" "unknown arg exits 2"
assert_ok "bash '$FT30' --help 2>&1 | grep -q 'FT-30'" "--help prints usage"
# A real run without --target must refuse rather than write somewhere by default.
ft30_notarget="$(bash "$FT30" 2>&1; echo "rc=$?")"
assert_contains "$ft30_notarget" "--target owner/repo is required" "a real run without --target refuses"
assert_contains "$ft30_notarget" "rc=1" "  and exits non-zero"

# Drive the SHIPPED criteria block against crafted logs — the assertions are the
# point of the script, so a copy here would prove nothing.
FT30_CRIT="$(mktemp)"
# Stop at WHICHEVER section marker comes first. The log-criteria block and the
# file-set block (#358) are different tests with different fixtures — the
# file-set one needs a real tree on disk, so sweeping it into this extraction
# made the log battery fail for a reason that had nothing to do with logs.
# The alternation keeps this working if either block is ever moved or removed.
awk '/^note "==> FT-30 criteria"/,/^# ---.*(what actually landed|verdict)/' "$FT30" | head -n -1 > "$FT30_CRIT"
assert_ok "grep -q 'creating canonical labels' '$FT30_CRIT'" "criteria block extracted from the shipped script"
_ft30_drive() { # $1=log $2=rc -> failure count
  # `bad` MUST increment — a no-op stub makes every mutation look caught-free and
  # the whole battery passes for the wrong reason.
  LOG="$1" RC="$2" bash -c '
    RED=""; GRN=""; RST=""; BLD=""; FAILED=0
    ok(){ :; }; note(){ :; }
    bad(){ FAILED=$((FAILED+1)); }
    source "'"$FT30_CRIT"'" >/dev/null 2>&1
    echo "$FAILED"' 2>/dev/null
}
_ft30_good="$(mktemp)"
cat > "$_ft30_good" <<'GOODLOG'
==> backup: no pre-existing CI/governance surfaces (fresh repo)
==> creating canonical labels on owner/x
==> done. Next steps (founder) — SECRETS BEFORE THE PR:
       Pre-write backup of everything that already existed (FT-57):
       Restore one file:  cp "/b/<path>" /c/<path>
       review job pins the self-hosted pool even on public repos):
         - LLM_URL + LLM_API_KEY (ai-review proxy; REQUIRED since ci/v2.0.0)
GOODLOG
assert_eq "$(_ft30_drive "$_ft30_good" 0)" "0" "a complete run passes every criterion"
# Each removal must be caught individually — a criterion that never fails is decoration.
for _m in "creating canonical labels" "backup: no pre-existing" "Restore one file" "self-hosted pool even on public repos" "LLM_URL"; do
  _mut="$(mktemp)"; grep -vF "$_m" "$_ft30_good" > "$_mut"
  assert_ok "[ \"\$(_ft30_drive '$_mut' 0)\" -ge 1 ]" "removing '$_m' from the log is caught"
  rm -f "$_mut"
done
# And the failure markers must trip it.
_mut="$(mktemp)"; { cat "$_ft30_good"; echo "  FAIL  something broke"; } > "$_mut"
assert_ok "[ \"\$(_ft30_drive '$_mut' 0)\" -ge 1 ]" "a FAIL line in the installer output is caught"
{ cat "$_ft30_good"; echo "404: not found"; } > "$_mut"
assert_ok "[ \"\$(_ft30_drive '$_mut' 0)\" -ge 1 ]" "a 404 in the installer output is caught"
assert_ok "[ \"\$(_ft30_drive '$_ft30_good' 1)\" -ge 1 ]" "a non-zero installer exit is caught"
rm -f "$_mut" "$_ft30_good" "$FT30_CRIT"

# PORTABILITY OF THE CRITERIA THEMSELVES. The battery above runs under GNU grep,
# where `\s` works — so it can NEVER catch the BSD/macOS trap by driving. `\s` is
# a GNU extension: BSD grep matches a LITERAL 's', so `^\s+FAIL ` cannot match an
# indented FAIL line and the criterion prints "no FAIL lines" over a log that has
# them. This is a 🔴 founder-executed gate, frequently run by hand on macOS, and
# docs/RELEASE_CHECKLIST.md documents this exact trap for a different command
# while the script itself carried it. Assert the portable class STATICALLY —
# a static assertion is the only kind that can see this one.
assert_absent "$(grep -vE '^[[:space:]]*#' "$FT30" || true)" '\s' \
  "ft30-dry-run.sh uses no GNU-only \\s in its matchers (BSD grep reads it as a literal 's' → false all-clear)"

# THE OWED-COMPUTATION MUST DELEGATE, NOT RE-DERIVE. This block claimed to
# "Reuse release.sh's own definition rather than a copy of it, so this cannot
# drift" while carrying its own `git diff` over install/ — no manifest
# derivation, no `ci/vX.Y.Z` pin normalisation. Since every prep rewrites the
# self-pin in all ~37 shipped templates, the copy answered "OWED" on EVERY
# release while `release.sh tag` AUTO-WAIVED, sending the founder to run a 🔴
# write-to-another-repo dry-run that was not owed.
_owed_blk="$(awk '/Is the gate even owed\?/,/^if \[ -n "\$TARGET" \]/' "$FT30" | grep -vE '^[[:space:]]*#' || true)"
assert_ok "[ -n \"\$_owed_blk\" ]" "the owed-computation block was located in ft30-dry-run.sh"
assert_contains "$_owed_blk" "_coldstart-changed" \
  "ft30 asks release.sh whether the gate is owed (delegation, not a second definition)"
assert_absent "$_owed_blk" "git diff --name-only" \
  "ft30 does NOT re-derive the cold-start surface with its own git diff (the drift that made it always say OWED)"
# THE FAILURE ARM MUST WARN, NOT FAIL. `bad` increments FAILED, which makes
# `--check` exit 1 and the real run refuse to write to the target — so a
# preflight that cannot compute the surface would BLOCK the very dry-run that
# `release.sh tag` demands in exactly that state, leaving `--dry-run-verified`
# passed with nothing run. The fail-closed behaviour lives in `tag`; this script
# reports.
assert_absent "$_owed_blk" "bad \"could not compute" \
  "ft30's cannot-compute arm does not FAIL the preflight (it must not block the dry-run the gate then demands)"
assert_contains "$_owed_blk" "warn \"could not compute" \
  "ft30's cannot-compute arm WARNS and tells you to run it anyway"
# Streams separated: a stderr line must not become a 'changed file' on the
# success path — which would also break the agreement assertion below.
assert_absent "$_owed_blk" '_coldstart-changed "$PREV_TAG" 2>&1' \
  "ft30 captures release.sh's stderr separately (2>&1 would fold diagnostics into the file list)"

# And the two must AGREE on this tree. A delegation that returns something
# different from what `tag` computes is the same defect wearing the fix's clothes.
_rel_changed="$(bash "$ROOT/scripts/release.sh" _coldstart-changed 2>/dev/null | sort || true)"
_ft30_changed="$(bash "$FT30" --check 2>/dev/null | sed -n '/gate is OWED/,/^$/p' | grep '^         ' | sed 's/^ *//' | sort || true)"
# FLOOR. Both captures are "" whenever the cold-start surface is unchanged since
# the previous tag — which is the STEADY STATE between releases — and `assert_eq
# "" ""` passes having compared nothing. Non-vacuous for this release only by
# accident (install.sh and manifest.json both changed). Floors were added to the
# other derived comparisons in this same change; this one was missed.
if [ -n "$_rel_changed" ] || [ -n "$_ft30_changed" ]; then
  assert_eq "$_ft30_changed" "$_rel_changed" \
    "ft30 --check reports the SAME surface release.sh tag would gate on"
else
  # Not a failure — it is the correct answer when nothing on the bootstrap path
  # changed. Say so, rather than printing a green tick for an empty comparison.
  echo "  ---  ft30/release agreement: both report an unchanged cold-start surface (auto-waive state) — nothing to compare"
fi

echo ""
echo "== FT-30 verifies WHAT LANDED, not only what was printed (#358) =="
# Every other FT-30 criterion is a grep over the installer's own log, which
# asserts the bootstrap COMPLETED and says nothing about what it INSTALLED. A
# stanza that silently never runs prints every marker string those look for and
# passes the whole gate — the exact class FT-30 exists to catch, since the F1
# defect was a cold start shipping without ai-review.yml for nine releases.
#
# Extract the shipped block and drive it against synthetic trees. The block is
# extracted, never re-implemented here: a test carrying its own copy passes
# happily while the script rots.
FS_BLK="$(mktemp)"
sed -n '/^# ---* what actually landed/,/^# ---* verdict/p' "$FT30" | sed '$d' > "$FS_BLK"
assert_ok "[ -s '$FS_BLK' ]" "the file-set block was located in ft30-dry-run.sh"

FS_DRV="$(mktemp)"; cat > "$FS_DRV" <<'FSDRV'
FAILED=0
ok()   { :; }
bad()  { printf 'FAIL %s
' "$*"; FAILED=$((FAILED+1)); }
note() { :; }
CONSUMER="$1"; TARGET="o/r"; CI_TAG="testref"; VIS="$2"
curl() { local out=""; while [ $# -gt 0 ]; do case "$1" in -o) out="$2"; shift 2;; *) shift;; esac; done; cp "$MANIFEST" "$out"; }
gh()   { printf '%s
' "$VIS"; }
# shellcheck disable=SC1090
. "$3"
echo "FAILED=$FAILED"
FSDRV
_fs_mk() {  # $1=name $2=files $3=runner ; echoes the dir
  local d; d="$(mktemp -d)"; mkdir -p "$d/.github/workflows"
  local f; for f in $2; do printf 'runs-on: %s
' "${3:-ubuntu-latest}" > "$d/.github/workflows/$f"; done
  printf '%s' "$d"
}
_fs_run() { MANIFEST="$ROOT/install/templates/manifest.json" bash "$FS_DRV" "$1" "$2" "$FS_BLK" 2>/dev/null; }
# The expected set is READ FROM THE MANIFEST, not hardcoded — hardcoding it here
# would make this test drift the moment auto_install changes, which is exactly
# the change #441 makes.
_fs_expected="$(python3 - "$ROOT/install/templates/manifest.json" <<'PYFS'
import sys, json
m = json.load(open(sys.argv[1], encoding="utf-8"))
print(" ".join(f["path"].split("/")[-1] for f in (m.get("files") or [])
                if (f.get("path") or "").startswith(".github/workflows/") and f.get("auto_install")))
PYFS
)"
assert_ok "[ -n '$_fs_expected' ]" "manifest declares at least one auto_install caller to verify"

_d="$(_fs_mk ok "$_fs_expected")"
assert_contains "$(_fs_run "$_d" false)" "FAILED=0" "a complete public cold start passes the file-set check"
rm -rf "$_d"

# THE #358 CASE: a caller the manifest promises simply is not there.
_one="$(printf '%s' "$_fs_expected" | awk '{print $1}')"
_rest="$(printf '%s' "$_fs_expected" | cut -d' ' -f2-)"
_d="$(_fs_mk miss "$_rest")"
assert_contains "$(_fs_run "$_d" false)" "did NOT land" "a MISSING auto_install caller fails the gate (#358)"
rm -rf "$_d"

# Wrong VARIANT, BOTH directions. The first draft covered only private+ubuntu
# and fell through silently on public+self-hosted — which is the quadrant that
# was actually live, because bootstrap defaulted VISIBILITY to `private`.
_d="$(_fs_mk priv "$_fs_expected" "ubuntu-latest")"
assert_contains "$(_fs_run "$_d" true)" "queue forever" \
  "a private target handed ubuntu-latest callers fails (D1/OPS-0049)"
rm -rf "$_d"

_d="$(_fs_mk pubsh "$_fs_expected" '["self-hosted", "ci", "ephemeral"]')"
assert_contains "$(_fs_run "$_d" false)" "SELF-HOSTED but" \
  "a PUBLIC target handed self-hosted callers fails (D7 — fork code on the shared pool)"
rm -rf "$_d"

# FT-39: a 200-with-empty-body written over a gate. Present, and worthless.
_d="$(_fs_mk empty "$_fs_expected")"; : > "$_d/.github/workflows/$_one"
assert_contains "$(_fs_run "$_d" false)" "EMPTY" "a caller that landed empty fails (FT-39)"
rm -rf "$_d"

# And the block must refuse rather than pass when it cannot resolve visibility —
# "could not determine" must never read as "correct".
_d="$(_fs_mk novis "$_fs_expected")"
assert_contains "$(_fs_run "$_d" "")" "FAIL" "an unresolvable target visibility fails closed"
rm -rf "$_d" "$FS_BLK" "$FS_DRV"

suite_summary "scripts"
