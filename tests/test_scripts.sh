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

# #350: a bare 'proxy returned HTTP 401' named neither the secret nor a cause,
# while the URLError path already named its cause precisely. The asymmetry is
# what made the incident expensive to diagnose, so the 401 path is asserted to
# name the secret it cannot read back.
assert_ok "python3 - '$ROOT/scripts/litellm_client.py' <<'PY'
import importlib.util, io, os, sys, urllib.error
import contextlib
spec = importlib.util.spec_from_file_location('litellm_client', sys.argv[1])
module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
def raise_401(request, timeout):
    raise urllib.error.HTTPError(request.full_url, 401, 'Unauthorized', {}, None)
module.open_no_redirect = raise_401
os.environ['LITELLM_BASE_URL'] = 'https://proxy.example/v1'
os.environ['LITELLM_API_KEY'] = 'test-key'
err = io.StringIO()
with contextlib.redirect_stderr(err):
    try:
        module.completion('review', model='ai-reviewer', json_mode=False, timeout=30)
        raise AssertionError('a 401 must not be swallowed')
    except SystemExit:
        pass
msg = err.getvalue()
assert 'HTTP 401' in msg, msg
assert 'LITELLM_REVIEW_API_KEY' in msg, msg
assert 'set-litellm-secrets.sh' in msg, msg
# A retryable status keeps the bare form — the hint is for auth failures only.
assert module.auth_hint(429) == '' and module.auth_hint(500) == ''
assert module.auth_hint(200) == '' and module.auth_hint(404) == ''
# 403 must NOT tell the operator to re-provision: it means the token
# authenticated but is not authorized for this model, which is exactly why
# install/set-litellm-secrets.sh ACCEPTS 403 when probing /models. Sending them
# to re-provision a key the provisioner just certified is the loop #350 was.
h403 = module.auth_hint(403)
assert h403 != '', 'a 403 still deserves a hint'
assert 'not authorized' in h403, h403
assert 're-provision' not in h403.lower(), h403
PY" "a 401 names the secret to re-provision; a 403 says the opposite"

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
assert seen['payload']['max_tokens'] == 24576, seen['payload']['max_tokens']
module.completion('r', model='ai-reviewer', json_mode=True, timeout=30)
assert seen['payload']['max_tokens'] == 4096, seen['payload']['max_tokens']
os.environ['LITELLM_MAX_TOKENS'] = '3000'
module.completion('r', model='ai-reviewer', json_mode=True, timeout=30, verdict_mode=True)
assert seen['payload']['max_tokens'] == 3000, seen['payload']['max_tokens']
PY" "verdict mode budgets 24576 tokens (vs 4096 plain); LITELLM_MAX_TOKENS overrides"

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
    # The assembled prompt, verbatim, for the #360 assertions. A prompt-side
    # rule is otherwise untestable: it is a sentence in a string, deletable
    # without breaking anything else in CI.
    capture = os.environ.get("LITELLM_PROMPT_CAPTURE", "")
    if capture:
        with open(capture, "w") as handle:
            handle.write(prompt)
    mode = os.environ.get("LITELLM_FAKE_MODE", "")
    if mode == "secret":
        return "Existing sk-AAAAAAAAAAAAAAAAAAAA and new sk-BBBBBBBBBBBBBBBBBBBB"
    if mode == "destructive":
        return "one replacement line"
    if "CURRENT FILE:" in prompt:
        return "# Project\n\nThe API includes `/v2/items`.\n"
    # Planner-only modes — below the apply branch above, so an apply test run
    # under one of these still gets file content rather than a plan document.
    if mode == "rejects":
        return '{"updates":[{"path":"README.md","instruction":"Document /v2/items","rationale":"PR #42 adds the endpoint"},{"path":"README.md","instruction":"Document it a second time","rationale":"duplicate proposal"},{"path":"CLAUDE.md","instruction":"Edit a non-allowlisted file that IS on disk","rationale":"outside allowed_paths"},{"path":"CLAUDE.md","instruction":"Edit it a second time","rationale":"repeat of an already-rejected path"},{"path":"notes/ABSENT.md","instruction":"Edit a non-allowlisted file that is NOT on disk","rationale":"outside allowed_paths and missing"}]}'
    if mode == "duplicate":
        return '{"updates":[{"path":"README.md","instruction":"Document /v2/items","rationale":"PR #42 adds the endpoint"},{"path":"README.md","instruction":"Document it a second time","rationale":"duplicate proposal"}]}'
    if mode == "oversize":
        return '{"updates":[{"path":"README.md","instruction":"Edit an over-limit LOW-risk file","rationale":"apply would refuse it"},{"path":"SMALL.md","instruction":"Edit an under-limit low-risk file","rationale":"apply can process it"},{"path":"CRLF.md","instruction":"Edit a low-risk file whose on-disk size exceeds the limit but whose decoded size does not","rationale":"apply measures the decoded text"},{"path":"ATLIMIT.md","instruction":"Edit a low-risk file sitting exactly ON the limit","rationale":"apply accepts it, so the planner must too"},{"path":"UTF8.md","instruction":"Edit a low-risk file under the limit in characters but over it in bytes","rationale":"apply measures bytes"},{"path":"docs/BIG.md","instruction":"Edit an over-limit HIGH-risk file","rationale":"never reaches apply"}]}'
    if mode == "nonallowlisted-present":
        return '{"updates":[{"path":"README.md","instruction":"Document /v2/items","rationale":"PR #42 adds the endpoint"},{"path":"CLAUDE.md","instruction":"Edit a non-allowlisted file that IS on disk","rationale":"outside allowed_paths"}]}'
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

echo "== doc-maintainer planner de-conflates and records rejections (#353) =="
# A fresh repo dir with its own config: the apply cases above overwrite
# README.md, and copying `repo/config.json` would couple this block's allowlist
# to a fixture some future apply test may edit.
# The two `continue`s are what these assertions are really for. Recording a
# rejection without continuing re-creates the defect 353a fixes, because the
# entry falls through into the per-entry validation below it — an absent
# rejected path then aborts with `planned documentation file does not exist`
# (planner.py:227, one condition reported as another) and a present one is
# classified into high_risk_set (planner.py:235), putting a recorded violation
# into the written plan. The two shapes are caught by DIFFERENT assertions and
# both are needed: the absent path is caught by the missing-file assert and by
# the plan never being written, the on-disk one by `.high_risk_set == []` —
# which only becomes load-bearing in the `nonallowlisted-present` run below,
# where no absent path aborts first.
mkdir -p "$TMP/doc/repo353"
cat > "$TMP/doc/repo353/config.json" <<'JSON'
{"dry_run":true,"allowed_paths":["README.md","docs/**"],"max_edits_per_pr":10,"auto_merge":{"low_risk_paths":["README.md"],"high_risk_paths":["docs/**"]}}
JSON
printf '# Project\n' > "$TMP/doc/repo353/README.md"
printf '# Conventions\n' > "$TMP/doc/repo353/conventions.md"
printf '# Claude\n' > "$TMP/doc/repo353/CLAUDE.md"
if (cd "$TMP/doc/repo353" && LITELLM_FAKE_MODE=rejects PATH="$TMP/doc/bin:$PATH" python3 ../planner.py --merge-sha abc --gh-repo owner/repo --config config.json --conventions conventions.md --model ai-doc-maintainer --out-plan plan.json) >"$TMP/doc/repo353/rejects.log" 2>&1; then
  _r "#353 planner exited 0 on a non-allowlisted path (D12 requires a loud failure)"
else
  _g "#353 a non-allowlisted path still fails the run (D12 preserved)"
fi
REJ353=$(cat "$TMP/doc/repo353/rejects.log")
assert_contains "$REJ353" '::warning::planner: dropping duplicate plan path: README.md' "#353 a duplicate is a ::warning:: naming only its own condition"
assert_contains "$REJ353" '::error::planner: non-allowlisted plan path: CLAUDE.md' "#353 a non-allowlisted path is an ::error:: naming only its own condition"
assert_contains "$REJ353" '::error::planner: non-allowlisted plan path: notes/ABSENT.md' "#353 the absent-on-disk violation gets its own ::error:: too — both shapes annotated"
assert_contains "$REJ353" '::error::planner: 2 non-allowlisted plan path(s) rejected' "#353 the aggregate line counts DISTINCT violating paths, not occurrences"
assert_eq "$(grep -c '::error::planner: non-allowlisted plan path:' "$TMP/doc/repo353/rejects.log")" "2" "#353 one ::error:: per DISTINCT violating path — the lines and the aggregate must add up"
assert_ok "[ \"$(grep -n '::warning::planner: dropping duplicate' "$TMP/doc/repo353/rejects.log" | cut -d: -f1)\" -lt \"$(grep -n '::error::planner: non-allowlisted' "$TMP/doc/repo353/rejects.log" | head -1 | cut -d: -f1)\" ]" "#353 the warning is not block-buffered behind the errors (the flush=True fix)"
assert_absent "$REJ353" 'duplicate or non-allowlisted' "#353 the conflated message is gone (REPO_STANDARDS §24.2)"
assert_absent "$REJ353" 'planned documentation file does not exist' "#353 a rejected path is never re-reported as a missing file"
assert_ok "jq -e '.validation.rejected == [{\"path\":\"README.md\",\"reason\":\"duplicate\"},{\"path\":\"CLAUDE.md\",\"reason\":\"not-allowlisted\"},{\"path\":\"CLAUDE.md\",\"reason\":\"not-allowlisted\"},{\"path\":\"notes/ABSENT.md\",\"reason\":\"not-allowlisted\"}]' '$TMP/doc/repo353/plan.json' >/dev/null" "#353 plan written on a non-allowlisted entry; rejected is per-entry, in input order, and a repeat of a REJECTED path is never relabelled \`duplicate\`"
assert_ok "jq -e '[.validation.allowlist_violations[].path] == [\"CLAUDE.md\",\"notes/ABSENT.md\"]' '$TMP/doc/repo353/plan.json' >/dev/null" "#353 allowlist_violations is populated and DISTINCT — a path proposed twice is one violation"
assert_ok "jq -e '[.low_risk_set[].path] == [\"README.md\"] and .high_risk_set == []' '$TMP/doc/repo353/plan.json' >/dev/null" "#353 no rejected path reaches low_risk_set or high_risk_set (the \`continue\` assertion)"

if (cd "$TMP/doc/repo353" && LITELLM_FAKE_MODE=duplicate PATH="$TMP/doc/bin:$PATH" python3 ../planner.py --merge-sha abc --gh-repo owner/repo --config config.json --conventions conventions.md --model ai-doc-maintainer --out-plan plan-dup.json) >"$TMP/doc/repo353/dup.log" 2>&1; then
  _g "#353 a duplicate alone no longer discards the whole plan (353b)"
else
  _r "#353 a duplicate alone still kills the run"
fi
assert_ok "jq -e '.validation.rejected == [{\"path\":\"README.md\",\"reason\":\"duplicate\"}] and .validation.allowlist_violations == [] and [.low_risk_set[].path] == [\"README.md\"]' '$TMP/doc/repo353/plan-dup.json' >/dev/null" "#353 the duplicate is recorded once and the surviving entry is still planned"

# The pure `continue` probe for the ALLOWLIST branch. In the `rejects` run above,
# deleting that branch's `continue` aborts on notes/ABSENT.md before a plan is
# written, so `.high_risk_set == []` never gets to fire. Here the only rejected
# path is on disk, so dropping the `continue` writes a plan with CLAUDE.md
# classified into high_risk_set — caught by nothing else in this block.
if (cd "$TMP/doc/repo353" && LITELLM_FAKE_MODE=nonallowlisted-present PATH="$TMP/doc/bin:$PATH" python3 ../planner.py --merge-sha abc --gh-repo owner/repo --config config.json --conventions conventions.md --model ai-doc-maintainer --out-plan plan-present.json) >"$TMP/doc/repo353/present.log" 2>&1; then
  _r "#353 an on-disk non-allowlisted path exited 0"
else
  _g "#353 an on-disk non-allowlisted path still fails the run"
fi
assert_ok "jq -e '.high_risk_set == [] and [.low_risk_set[].path] == [\"README.md\"] and [.validation.allowlist_violations[].path] == [\"CLAUDE.md\"]' '$TMP/doc/repo353/plan-present.json' >/dev/null" "#353 an on-disk rejected path is dropped, not classified (the allowlist branch's \`continue\`)"

echo "== doc-maintainer planner drops what apply will refuse, LOW-risk only (#354) =="
# Its own repo dir again: this fixture needs files an order of magnitude larger
# than any other block's, and README.md is rewritten in place by the apply cases.
#
# The tier scoping is the half that is easy to get wrong and impossible to see
# afterwards. apply.py's 200 KB refusal is reachable only with `--tier low_risk`
# (doc-maintainer.yml:402), so an unscoped filter would silently delete
# over-limit HIGH-risk proposals that work correctly today — they become the
# issue body or the dry-run comment and never touch apply. `docs/BIG.md` is here
# to fail that mutation: it is over the limit and must SURVIVE.
mkdir -p "$TMP/doc/repo354/docs"
cat > "$TMP/doc/repo354/config.json" <<'JSON'
{"dry_run":true,"allowed_paths":["README.md","SMALL.md","CRLF.md","ATLIMIT.md","UTF8.md","docs/**"],"max_edits_per_pr":10,"auto_merge":{"low_risk_paths":["README.md","SMALL.md","CRLF.md","ATLIMIT.md","UTF8.md"],"high_risk_paths":["docs/**"]}}
JSON
printf '# Conventions\n' > "$TMP/doc/repo354/conventions.md"
printf '# Small\n'       > "$TMP/doc/repo354/SMALL.md"
# Five fixtures, one per way the measurement can be got wrong. 300 KB is 1.5x
# the limit with no arithmetic to get wrong. The other three each kill a
# distinct wrong implementation that every remaining assertion would pass:
#   CRLF.md    — `read_text()` translates CRLF, so on-disk size is OVER and the
#                bytes apply measures are UNDER. Kills `stat().st_size`.
#   ATLIMIT.md — exactly ON the limit. apply's guard is `>`, so apply ACCEPTS
#                this file; a planner using `>=` silently drops what apply would
#                have processed. Kills the off-by-one.
#   UTF8.md    — under the limit in characters, over it in bytes. Every other
#                fixture here is ASCII, where the two are identical. Kills
#                `len(read_text())` without the `.encode()`.
python3 - "$TMP/doc/repo354" <<'PY'
import pathlib, sys
root = pathlib.Path(sys.argv[1])
big = "# Big\n" + ("x" * 79 + "\n") * 3750
assert len(big.encode()) > 200_000, "fixture must exceed the apply limit"
(root / "README.md").write_text(big)
(root / "docs" / "BIG.md").write_text(big)
crlf = root / "CRLF.md"
crlf.write_bytes((b"x" * 78 + b"\r\n") * 2520)
assert crlf.stat().st_size > 200_000, "CRLF fixture must look over-limit on disk"
assert len(crlf.read_text().encode()) <= 200_000, "...and under it once decoded"
atlimit = root / "ATLIMIT.md"
atlimit.write_text("x" * 199_999 + "\n")
assert len(atlimit.read_text().encode()) == 200_000, "at-limit fixture must sit exactly ON the limit"
utf8 = root / "UTF8.md"
utf8.write_text("—" * 70_000)
assert len(utf8.read_text()) <= 200_000, "utf8 fixture must be UNDER the limit in characters"
assert len(utf8.read_text().encode()) > 200_000, "...and OVER it in bytes"
PY
if (cd "$TMP/doc/repo354" && LITELLM_FAKE_MODE=oversize PATH="$TMP/doc/bin:$PATH" python3 ../planner.py --merge-sha abc --gh-repo owner/repo --config config.json --conventions conventions.md --model ai-doc-maintainer --out-plan plan.json) >"$TMP/doc/repo354/oversize.log" 2>&1; then
  _g "#354 an over-limit low-risk path is a warning, not a failed run"
else
  _r "#354 the planner failed the run over a path it should have dropped"
fi
OVER354=$(cat "$TMP/doc/repo354/oversize.log")
assert_ok "jq -e '[.low_risk_set[].path] == [\"SMALL.md\",\"CRLF.md\",\"ATLIMIT.md\"]' '$TMP/doc/repo354/plan.json' >/dev/null" "#354 the over-limit low-risk paths are dropped and the rest still ship — pinning all three ways the measurement can be wrong: st_size (CRLF), >= instead of > (ATLIMIT), and characters instead of bytes (UTF8)"
assert_ok "jq -e '[.high_risk_set[].path] == [\"docs/BIG.md\"]' '$TMP/doc/repo354/plan.json' >/dev/null" "#354 an over-limit HIGH-risk path is KEPT — the filter is tier-scoped, because high-risk never reaches apply"
assert_ok "jq -e '.validation.rejected == [{\"path\":\"README.md\",\"reason\":\"over-apply-limit\"},{\"path\":\"UTF8.md\",\"reason\":\"over-apply-limit\"}]' '$TMP/doc/repo354/plan.json' >/dev/null" "#354 both drops are recorded in validation.rejected under their own reason, distinct from duplicate/not-allowlisted (§24.2)"
assert_contains "$OVER354" '::warning::planner: dropping low-risk README.md' "#354 the drop is annotated"
assert_contains "$OVER354" 'auto_merge.low_risk_paths nominates a path apply will refuse' "#354 the message names the CONFIG that nominated the path, not only the file — the diagnosis #354 was hard to reach"
assert_absent "$OVER354" '::error::' "#354 nothing about an over-limit path is an error; it is a configuration note"
# The planner must reject exactly what apply rejects. The CRLF fixture pins the
# measurement; driving the real apply over the same file pins the number, so a
# planner filtering on a limit apply no longer enforces cannot pass both.
echo '{"pr_number":42,"low_risk_set":[{"path":"README.md","instruction":"i","rationale":"r"}],"high_risk_set":[]}' > "$TMP/doc/repo354/forced-plan.json"
_apply354_out="$( (cd "$TMP/doc/repo354" && PATH="$TMP/doc/bin:$PATH" python3 ../apply.py --plan forced-plan.json --tier low_risk --gh-repo owner/repo --model ai-doc-maintainer --out-dir proposed) 2>&1 || true )"
assert_contains "$_apply354_out" "refusing autonomous full-file generation over 200 KB: README.md" "#354 apply does refuse the very file the planner dropped — the two agree on the limit and on how it is measured"
# An unreadable document is a DIFFERENT condition and gets the opposite
# disposition: named and loud, not dropped (§24.2 — one message, one condition).
# Without the guard this is a bare UnicodeDecodeError traceback naming neither
# the file nor the cause, and no plan is written at all.
printf '# Small\n\xff\xfe not utf-8\n' > "$TMP/doc/repo354/SMALL.md"
_unread354="$( (cd "$TMP/doc/repo354" && LITELLM_FAKE_MODE=oversize PATH="$TMP/doc/bin:$PATH" python3 ../planner.py --merge-sha abc --gh-repo owner/repo --config config.json --conventions conventions.md --model ai-doc-maintainer --out-plan plan-unreadable.json) 2>&1 || true )"
assert_contains "$_unread354" "::error::planner: cannot read planned documentation file SMALL.md" "#354 an unreadable planned file fails LOUD and names the file, rather than raising a bare traceback"
assert_absent "$_unread354" "Traceback (most recent call last)" "#354 ...and does not surface as a Python traceback"
printf '# Small\n' > "$TMP/doc/repo354/SMALL.md"

echo "== doc-maintainer planner inventory respects allowed_paths, and the prompt binds the model to it (#360) =="
# Both halves are asserted against the prompt the planner actually assembled,
# because both are prompt-side and neither is observable in the plan JSON.
#
# EVERY assertion here reads the parsed facts file, never the raw prompt, and
# the parser below fails LOUD when a block it is asked for is absent. That is
# not fastidiousness: a `grep | sed` extractor yields the empty string when its
# anchor misses, `jq -e ''` exits 0 on empty input, and `assert_absent` passes
# on the empty string — so a two-space indent in the prompt silently disarmed
# three assertions at once, including the central one, and the whole D-1 defect
# came back green. Fail closed.
#
# The fixture's shape IS the test:
#   * `aaa-NNN.md` x (MAX_DOC_INVENTORY + 100), non-allowlisted, sorting between
#     `README.md` and `docs/` — under the old unfiltered inventory the slice
#     keeps these and truncates `docs/DECISIONS.md`, an allowlisted on-disk
#     document, away. This is what separates "filter before the slice" from
#     "filter after it". The count is DERIVED from the constant, never a second
#     literal: raising `MAX_DOC_INVENTORY` past a hardcoded 600 would retire
#     that coverage in silence.
#   * `zzz-INDEX.md` — allowlisted, at the root, sorting AFTER `docs/`. `rglob`
#     yields a directory's own entries before recursing, so it comes out before
#     `docs/DECISIONS.md`; only `sorted()` puts it last. Without it the sort is
#     ungated and the inventory becomes filesystem-order-dependent.
#   * a `gh` double of its own whose second changed file carries a patch over
#     `MAX_PATCH_BYTES`, so `patches` truncates to one entry while the
#     changed-file list keeps both. With a single changed file, "passed whole"
#     is indistinguishable from "passed the byte-budgeted subset".
MAXINV360=$(python3 -c "import re;print(re.search(r'^MAX_DOC_INVENTORY = ([0-9_]+)', open('$ROOT/scripts/doc-maintainer/planner.py').read(), re.M).group(1).replace('_',''))")
assert_ok "[ '$MAXINV360' -gt 0 ]" "#360 the fixture reads MAX_DOC_INVENTORY from the planner — one declaration, so the cap and the fixture cannot drift apart"
mkdir -p "$TMP/doc/repo360/docs" "$TMP/doc/bin360"
cat > "$TMP/doc/repo360/config.json" <<'JSON'
{"dry_run":true,"allowed_paths":["README.md","zzz-INDEX.md","docs/**"],"max_edits_per_pr":5,"auto_merge":{"low_risk_paths":["README.md"],"high_risk_paths":["docs/**","zzz-INDEX.md"]}}
JSON
printf '# Project\n'     > "$TMP/doc/repo360/README.md"
printf '# Decisions\n'   > "$TMP/doc/repo360/docs/DECISIONS.md"
printf '# Index\n'       > "$TMP/doc/repo360/zzz-INDEX.md"
printf '# Conventions\n' > "$TMP/doc/repo360/conventions.md"
printf '# Claude\n'      > "$TMP/doc/repo360/CLAUDE.md"
python3 - "$TMP/doc/repo360" "$MAXINV360" <<'PY'
import pathlib, sys
root, cap = pathlib.Path(sys.argv[1]), int(sys.argv[2])
for n in range(cap + 100):
    (root / f"aaa-{n:04d}.md").write_text("# noise\n")
PY
python3 - "$TMP/doc/bin360" <<'PY'
import json, pathlib, sys
# Two changed files; the second's patch alone exceeds MAX_PATCH_BYTES (120_000),
# so the planner's patch loop breaks and `patches` holds one entry.
pathlib.Path(sys.argv[1], "files.json").write_text(json.dumps([
    {"filename": "src/api.py", "status": "modified", "patch": "+new endpoint"},
    {"filename": "docs/DECISIONS.md", "status": "modified", "patch": "+x" * 70_000},
]))
PY
cat > "$TMP/doc/bin360/gh" <<'SH'
#!/usr/bin/env bash
case "$*" in
  *commits/*/pulls*) echo '[{"number":42}]' ;;
  *pulls/42/files*) cat "$(dirname "$0")/files.json" ;;
  *pulls/42*) echo '{"number":42,"title":"Add API endpoint","body":"Adds /v2/items","user":{"login":"owner"}}' ;;
  *) exit 1 ;;
esac
SH
chmod +x "$TMP/doc/bin360/gh"
(cd "$TMP/doc/repo360" && LITELLM_PROMPT_CAPTURE="$TMP/doc/prompt360.txt" PATH="$TMP/doc/bin360:$PATH" python3 ../planner.py --merge-sha abc --gh-repo owner/repo --config config.json --conventions conventions.md --model ai-doc-maintainer --out-plan plan.json)
# One parse, anchored, loud on absence — see the header comment.
if python3 - "$TMP/doc/prompt360.txt" "$TMP/doc/facts360.json" <<'PY'
import json, pathlib, re, sys
text = pathlib.Path(sys.argv[1]).read_text()
lines = text.split("\n")
IMPERATIVE = 'Propose only paths matching the "Allowed documentation paths:" list'


def block(label):
    prefix = label + ": "
    hits = [n for n, line in enumerate(lines) if line.startswith(prefix)]
    if len(hits) != 1:
        raise SystemExit(f"block {label!r} appears {len(hits)} times, expected exactly 1")
    return hits[0], lines[hits[0]][len(prefix):]


def json_block(label):
    index, payload = block(label)
    return index, json.loads(payload)

# Every label the assembly emits, in order — §20.2 rule 6: the assembly and the
# prompt are one contract, so an EXTRA block (say a second, unfiltered
# inventory under another name) has to be a test failure, not a silent pass.
labels = [line.split(":")[0] for line in lines if re.match(r"^[A-Z][A-Za-z0-9 ()_-]*: ", line)]
imperative = [n for n, line in enumerate(lines) if IMPERATIVE in line]
if len(imperative) != 1:
    raise SystemExit(f"the D-2 imperative appears {len(imperative)} times, expected exactly 1")
inventory_line, inventory = json_block("Documentation inventory (allowed_paths only)")
allowed_line, allowed = json_block("Allowed documentation paths")
changed_line, changed = json_block("Complete changed-file list")
_, patches = json_block("Changed files and bounded patches")
first_block, _ = block("Repository")
pathlib.Path(sys.argv[2]).write_text(json.dumps({
    "labels": labels,
    "inventory": inventory,
    "allowed": allowed,
    "changed_files": changed,
    "patch_count": len(patches),
    "imperative_line": imperative[0],
    "first_block_line": first_block,
    "inventory_line": inventory_line,
}, indent=2))
PY
then
  _g "#360 the assembled prompt parses — exactly one of each named block, and one D-2 imperative"
else
  _r "#360 the assembled prompt did not parse; every assertion below would be vacuous"
fi
F360="$TMP/doc/facts360.json"
# §20.2 rule 6 — the block roster, in order. Kills the mutation that leaves
# every assertion below intact and simply adds a SECOND, unfiltered inventory
# under a different label, restoring the model's access to the whole repo.
assert_ok "jq -e '.labels == [\"Repository\",\"PR\",\"PR body\",\"Author\",\"Allowed documentation paths\",\"Documentation inventory (allowed_paths only)\",\"Repository conventions\",\"Complete changed-file list\",\"Changed files and bounded patches\"]' '$F360' >/dev/null" "#360 the prompt's block roster is exactly the nine the assembly declares, in order — no tenth block, and the inventory's label states its scope (§20.2 rules 5 + 6)"
assert_ok "jq -e '.inventory == [\"README.md\",\"docs/DECISIONS.md\",\"zzz-INDEX.md\"]' '$F360' >/dev/null" "#360 D-1 the inventory is exactly the allowlisted set, sorted — docs/DECISIONS.md survives MAX_DOC_INVENTORY+100 higher-sorting non-allowlisted files (filter BEFORE the slice) and zzz-INDEX.md is last (sorted, not rglob order)"
assert_ok "jq -e '[.inventory[] | select(startswith(\"aaa-\") or . == \"CLAUDE.md\")] == []' '$F360' >/dev/null" "#360 D-1 no non-allowlisted markdown file on disk is offered as a candidate, including one the consumer keeps at its root"
# D-2 is the load-bearing half: D-1 alone leaves the bucket red, because the
# offending proposals came from the changed-file list, not the inventory.
assert_contains "$(cat "$TMP/doc/prompt360.txt")" 'Propose only paths matching the "Allowed documentation paths:" list; a path that appears in "Complete changed-file list:" but not in the allowed documentation paths must not be proposed.' "#360 D-2 the prompt carries an IMPERATIVE binding the model to the allowlist, not just the labelled datum"
# WHERE it sits is as load-bearing as whether it is there. The prompt's own
# preamble declares everything from the first data block onward untrusted DATA,
# so an imperative that drifts below that line is one canon has already told the
# model to ignore — and presence-only assertions cannot see the difference.
assert_ok "jq -e '.imperative_line < .first_block_line' '$F360' >/dev/null" "#360 D-2 the imperative sits in the INSTRUCTION region, above the first data block — below it, canon's own untrusted-DATA preamble disowns it"
# ...and it names its datum by LABEL, so the block must exist and carry the
# real allowlist, not an empty or placeholder one.
assert_ok "jq -e '.allowed == [\"README.md\",\"zzz-INDEX.md\",\"docs/**\"]' '$F360' >/dev/null" "#360 D-2 the block the imperative names carries the consumer's actual allowed_paths — a label alone constrains nothing"
# IPLAN-0025 §2.1 mandates the merge diff as an input; PR-D narrows the
# inventory and must NOT narrow or drop this. Its unfiltered breadth is why D-2
# is needed at all. The patch set is byte-budgeted and this list is not: the
# fixture makes them differ, so "whole" is a real assertion.
assert_ok "jq -e '.changed_files == [\"src/api.py\",\"docs/DECISIONS.md\"] and .patch_count == 1' '$F360' >/dev/null" "#360 the changed-file list is passed WHOLE — it is not the byte-budgeted patch set, which truncated to one entry on the same PR"
assert_ok "jq -e '[.low_risk_set[].path] == [\"README.md\"] and [.high_risk_set[].path] == [\"docs/DECISIONS.md\"]' '$TMP/doc/repo360/plan.json' >/dev/null" "#360 classification is unchanged by the inventory narrowing"

# The slice itself, which the block above cannot reach: after filtering, that
# fixture leaves three entries, so MAX_DOC_INVENTORY could be deleted, raised or
# set to 2 with everything still green. Its own fixture puts MAX_DOC_INVENTORY+2
# ALLOWLISTED documents on disk.
mkdir -p "$TMP/doc/repo360cap/docs"
cat > "$TMP/doc/repo360cap/config.json" <<'JSON'
{"dry_run":true,"allowed_paths":["README.md","docs/**"],"max_edits_per_pr":5,"auto_merge":{"low_risk_paths":["README.md"],"high_risk_paths":["docs/**"]}}
JSON
printf '# Project\n'     > "$TMP/doc/repo360cap/README.md"
printf '# Decisions\n'   > "$TMP/doc/repo360cap/docs/DECISIONS.md"
printf '# Conventions\n' > "$TMP/doc/repo360cap/conventions.md"
python3 - "$TMP/doc/repo360cap" "$MAXINV360" <<'PY'
import pathlib, sys
root, cap = pathlib.Path(sys.argv[1]), int(sys.argv[2])
for n in range(cap + 2):
    (root / "docs" / f"zz-{n:04d}.md").write_text("# filler\n")
PY
(cd "$TMP/doc/repo360cap" && LITELLM_PROMPT_CAPTURE="$TMP/doc/prompt360cap.txt" PATH="$TMP/doc/bin:$PATH" python3 ../planner.py --merge-sha abc --gh-repo owner/repo --config config.json --conventions conventions.md --model ai-doc-maintainer --out-plan plan.json)
assert_ok "python3 -c \"
import json, sys
prefix = 'Documentation inventory (allowed_paths only): '
hits = [l for l in open('$TMP/doc/prompt360cap.txt').read().split(chr(10)) if l.startswith(prefix)]
assert len(hits) == 1, hits
inventory = json.loads(hits[0][len(prefix):])
assert len(inventory) == $MAXINV360, len(inventory)
assert inventory[:2] == ['README.md', 'docs/DECISIONS.md'], inventory[:2]
\"" "#360 the MAX_DOC_INVENTORY slice still bounds the inventory — MAX_DOC_INVENTORY+2 allowlisted documents are cut to exactly the cap, lowest-sorting kept"

echo "== doc-maintainer Step 9 renders a dry-run patch when the files differ (#352) =="
# Extract-and-drive, never re-implement (how FT-40's SHA-peel guard passed while
# untested). The fenced region is the expression-free `while … done` loop, NOT
# the whole step — the step's `run:` body carries five `${{ }}` expressions that
# are a bash syntax error, so a whole-step extraction would go red for the wrong
# reason. The markers keep this off line ranges, which silently break on edits above.
DMW="$ROOT/.github/workflows/doc-maintainer.yml"
assert_eq "$(grep -c '# >>> CI0027-DRYRUN-PATCH >>>' "$DMW")" "1" "#352 patch loop has exactly one start marker"
assert_eq "$(grep -c '# <<< CI0027-DRYRUN-PATCH <<<' "$DMW")" "1" "#352 patch loop has exactly one end marker"
mkdir -p "$TMP/step9/.doc-maintainer-proposed/docs" "$TMP/step9/docs"
awk '/# >>> CI0027-DRYRUN-PATCH >>>/{f=1;next} /# <<< CI0027-DRYRUN-PATCH <<</{f=0} f' "$DMW" > "$TMP/step9/loop.sh"
assert_absent "$(cat "$TMP/step9/loop.sh")" '${{' "#352 extracted loop is expression-free"
# An empty extraction would make the drive assertions below pass vacuously —
# `assert_absent` on "" also passes. Prove the block is really there.
assert_ok "grep -q 'diff -u --label' '$TMP/step9/loop.sh'" "#352 extracted block really contains the diff loop"
printf '# Project\n'                                    > "$TMP/step9/README.md"
printf '# Project\n\nThe API includes `/v2/items`.\n'    > "$TMP/step9/.doc-maintainer-proposed/README.md.proposed"
printf '# Guide\n'                                      > "$TMP/step9/docs/GUIDE.md"
printf '# Guide\n\nSee `/v2/items`.\n'                   > "$TMP/step9/.doc-maintainer-proposed/docs/GUIDE.md.proposed"
echo '{"low_risk_set":[{"path":"README.md"},{"path":"docs/GUIDE.md"}]}' > "$TMP/step9/.doc-maintainer-plan.json"
# $PATCH is assigned outside the extracted range, so the driver defines it. The
# driver opens with the step's own `set -uo pipefail` and is invoked with -e:
# together that is the step's real flag set, since GitHub's IMPLICIT default
# shell is `bash -e {0}` (this workflow sets no `shell:` and no `defaults:`).
_step9_driver() { { echo 'set -uo pipefail'; echo 'PATCH=out.patch'; echo ': > "$PATCH"'; cat; } > "$1"; }
_step9_driver "$TMP/step9/run-fixed.sh" < "$TMP/step9/loop.sh"
sed '/^[[:space:]]*set +e$/d; /^[[:space:]]*set -e$/d' "$TMP/step9/loop.sh" | _step9_driver "$TMP/step9/run-mutated.sh"
assert_ok "(cd '$TMP/step9' && bash -euo pipefail run-fixed.sh) >/dev/null 2>&1" "#352 patch loop survives a differing file instead of dying at the diff"
assert_ok "grep -qF 'a/README.md' '$TMP/step9/out.patch' && grep -qF 'a/docs/GUIDE.md' '$TMP/step9/out.patch'" "#352 loop iterates past the first differing file; both patches render"
# The `[ "$rc" -le 1 ]` branch is the D12 half — the annotation the fix makes
# reachable. `diff` returns 2 on trouble, e.g. a .proposed file apply.py never
# wrote. Assert BOTH that it fails and that it says why: assert_fail alone would
# also pass against the unfixed code, which died silently one line earlier.
rm -f "$TMP/step9/.doc-maintainer-proposed/docs/GUIDE.md.proposed"
assert_fail "(cd '$TMP/step9' && bash -euo pipefail run-fixed.sh) >/dev/null 2>&1" "#352 a missing .proposed file (diff rc=2) fails the step"
# Decide on the captured OUTPUT, not on a pipeline's status: this file runs under
# `pipefail`, so piping the failing script into `grep -q` would return the
# script's rc=2 even when grep matched — turning a match into a miss.
_step9_rc2_out="$( (cd "$TMP/step9" && bash -euo pipefail run-fixed.sh) 2>&1 || true )"
assert_contains "$_step9_rc2_out" "::error::could not render dry-run patch for docs/GUIDE.md" "#352 rc=2 fails LOUD with the ::error:: annotation, per D12"
printf '# Guide\n\nSee `/v2/items`.\n' > "$TMP/step9/.doc-maintainer-proposed/docs/GUIDE.md.proposed"

# Mutation, asserted rather than merely recorded: strip the `set +e`/`set -e`
# scoping and the same loop must die at the first `diff`. If this ever passes,
# the harness has stopped reproducing GitHub's shell and the assertions above
# prove nothing — the failure mode PLAN-021 §5 says to distrust.
# Assert the exit code AND how far it got: a bare "exits non-zero" would also be
# satisfied by a syntax error in the mutated script, silently ending the proof.
_step9_mut_rc=0
(cd "$TMP/step9" && bash -euo pipefail run-mutated.sh) >/dev/null 2>&1 || _step9_mut_rc=$?
assert_eq "$_step9_mut_rc" "1" "#352 mutation: dies with diff's own rc=1, not a harness or syntax error"
assert_ok "grep -qF 'a/README.md' '$TMP/step9/out.patch' && ! grep -qF 'a/docs/GUIDE.md' '$TMP/step9/out.patch'" "#352 mutation: died AT the first diff — first patch written, second never reached"

echo "== doc-maintainer Step 9 tells a PR-less merge apart from a faulty plan (#352) =="
# The PR-resolution change is PR-A's other behaviour change, and it is the one
# that regressed silently before: the old `gh api … || echo ""` reported an API
# fault as "no PR found" and exited 0. Drive the real block so a later edit
# cannot collapse the fault gate back into the exit-0 branch with CI green.
assert_eq "$(grep -c '# >>> CI0027-PR-RESOLVE >>>' "$DMW")" "1" "#352 PR-resolve block has exactly one start marker"
assert_eq "$(grep -c '# <<< CI0027-PR-RESOLVE <<<' "$DMW")" "1" "#352 PR-resolve block has exactly one end marker"
mkdir -p "$TMP/step9pr"
awk '/# >>> CI0027-PR-RESOLVE >>>/{f=1;next} /# <<< CI0027-PR-RESOLVE <<</{f=0} f' "$DMW" > "$TMP/step9pr/resolve.sh"
assert_ok "grep -q 'jq -r' '$TMP/step9pr/resolve.sh'" "#352 extracted PR-resolve block really reads .pr_number"
assert_absent "$(cat "$TMP/step9pr/resolve.sh")" '${{' "#352 extracted PR-resolve block is expression-free"
# $MERGE_SHA is an env: var supplied by the job, so the driver defines it, as
# GitHub would. Same flags as Step 9 itself: implicit `bash -e {0}` + `set -uo pipefail`.
{ echo 'set -uo pipefail'; echo 'MERGE_SHA=deadbeef'; cat "$TMP/step9pr/resolve.sh"; echo 'echo "FELL-THROUGH pr=$PR"'; } > "$TMP/step9pr/run.sh"
_step9pr() { # $1 = plan JSON content ('' = zero-byte file, 'NOFILE' = absent)
  case "$1" in
    NOFILE) rm -f "$TMP/step9pr/.doc-maintainer-plan.json" ;;
    *)      printf '%s' "$1" > "$TMP/step9pr/.doc-maintainer-plan.json" ;;
  esac
  _s9pr_rc=0
  _s9pr_out="$( (cd "$TMP/step9pr" && bash -euo pipefail run.sh) 2>&1 )" || _s9pr_rc=$?
}
_step9pr '{"pr_number": 353}'
assert_eq "$_s9pr_rc" "0" "#352 a real PR number falls through to the comment path"
assert_contains "$_s9pr_out" "FELL-THROUGH pr=353" "#352 the resolved PR number is what the rest of the step sees"
_step9pr '{"pr_number": null}'
assert_eq "$_s9pr_rc" "0" "#352 a PR-less merge exits 0 — not a failure"
assert_contains "$_s9pr_out" "::notice::dry-run: no PR found" "#352 the PR-less merge says so with a notice"
_step9pr ''
assert_eq "$_s9pr_rc" "1" "#352 a truncated plan is a FAULT — exit 1, never the exit-0 notice"
assert_contains "$_s9pr_out" "::error::dry-run: .pr_number is empty" "#352 the truncated plan fails LOUD, per D12"
_step9pr '{not json'
assert_eq "$_s9pr_rc" "1" "#352 a malformed plan is a fault — exit 1"
_step9pr NOFILE
assert_eq "$_s9pr_rc" "1" "#352 an absent plan is a fault — exit 1"
assert_contains "$_s9pr_out" "::error::dry-run: could not read .pr_number" "#352 the absent plan fails LOUD, per D12"

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
assert_ok "python3 - '$ROOT/scripts/litellm_client.py' <<'PY'
import importlib.util, os, sys
spec = importlib.util.spec_from_file_location('lc', sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)

# http:// is REJECTED without the opt-in, regardless of host.
os.environ.pop('LITELLM_ALLOW_INSECURE_HTTP', None)
try:
    m.endpoint('http://172.17.0.1:4001/v1')
    raise AssertionError('http:// accepted without the opt-in')
except SystemExit:
    pass
# ...and ACCEPTED with it. The flag is keyed on the SCHEME, not on any
# visibility/repo signal — that is the whole point of CI-0017.
os.environ['LITELLM_ALLOW_INSECURE_HTTP'] = 'true'
assert m.endpoint('http://172.17.0.1:4001/v1') == 'http://172.17.0.1:4001/v1/chat/completions'
assert m.endpoint('https://proxy.example/v1') == 'https://proxy.example/v1/chat/completions'

# Inside a container, loopback gets a NAMED cause; the bridge address does not.
os.environ['LITELLM_ASSUME_CONTAINER'] = 'true'
for host in ('127.0.0.1', 'localhost', '::1'):
    url = f'http://[{host}]:4001/v1' if host == '::1' else f'http://{host}:4001/v1'
    hint = m.loopback_hint(url)
    assert 'bridge' in hint and '172.17.0.1' in hint, f'no bridge hint for {host}: {hint!r}'
assert m.loopback_hint('http://172.17.0.1:4001/v1') == ''
assert m.loopback_hint('https://proxy.example/v1') == ''

# Outside a container the hint is silent — it must never fire on a developer
# host, where loopback is legitimately correct.
os.environ['LITELLM_ASSUME_CONTAINER'] = 'false'
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
awk '/^note "==> FT-30 criteria"/,/^# ---.*verdict/' "$FT30" | head -n -1 > "$FT30_CRIT"
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
         - LITELLM_BASE_URL + LITELLM_REVIEW_API_KEY (ai-review proxy; REQUIRED since ci/v2.0.0)
GOODLOG
assert_eq "$(_ft30_drive "$_ft30_good" 0)" "0" "a complete run passes every criterion"
# Each removal must be caught individually — a criterion that never fails is decoration.
for _m in "creating canonical labels" "backup: no pre-existing" "Restore one file" "self-hosted pool even on public repos" "LITELLM_BASE_URL"; do
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

suite_summary "scripts"
