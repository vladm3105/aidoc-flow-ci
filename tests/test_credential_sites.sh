#!/usr/bin/env bash
# tests/test_credential_sites.sh — PLAN-030: the LLM credential is presented in
# exactly TWO places, and the runtime one still hard-fails without a key.
#
# WHY THIS EXISTS. Neither ai-review job builds an auth header; both run
# scripts/llm_client.py, which reads LLM_API_KEY and builds the bearer header.
# A plan once proposed retiring the credential by editing only the two workflow
# `env:` blocks — every review would have died at llm_client.py's hard-fail with
# `call / ai-review`, a required context, red across the fleet. The inverse error
# was also made: asserting llm_client.py is the ONLY builder, which is false —
# install/set-llm-secrets.sh builds one too, so that assertion goes red at HEAD
# and has to be weakened to ship. Hence a CLOSED allowlist of two, not one.
#
# SCOPE GUARD. Canon builds many GitHub-API bearer headers. Sweeping those in
# would make this test fail on unrelated future work, and a test that fails for
# unrelated reasons gets weakened or deleted. A header line is GitHub-family iff
# its post-`Bearer` credential expression names a known GitHub token. That the
# scope guard HOLDS is itself asserted below — see "a new GitHub-API header".
#
# No network, no gh. Fixture runs use copies of the real files so the fixture
# tracks reality rather than a hand-written imitation of it.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

SCAN="$TMP/scan.py"
cat > "$SCAN" <<'PYEOF'
"""Report every LLM-credential presentation site under a root.

A PRESENTATION is a line that BUILDS an Authorization: Bearer header. A line
that merely reads one, or a comment that mentions one, is not a presentation.
Classification is by the credential expression that follows `Bearer`: if it
names a known GitHub token the line is GitHub-family and out of scope; anything
else is an LLM-credential candidate.

Exit 0 iff the candidate file set is exactly the allowlist AND the runtime
hard-fail is intact. Prints one `LLM_SITE`/`GH_SITE` line per site so a failure
says WHICH file, not just that the count moved.
"""
import os, re, sys

root = sys.argv[1]
allow = {"scripts/llm_client.py", "install/set-llm-secrets.sh"}
# Known GitHub token identifiers. Deliberately a closed list: an unknown name is
# treated as an LLM candidate (fail-loud), never silently exempted.
gh_names = {"GH_TOKEN", "GITHUB_TOKEN", "TOK", "TOKEN", "GH_PAT", "PAT",
            "BOT_TOKEN", "APP_TOKEN"}
skip_dirs = {".git", "tests", "docs", "plans", "node_modules", ".pytest_cache"}
exts = {".sh", ".py", ".yml", ".yaml"}

ident = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
bearer = re.compile(r"bearer", re.I)
llm_sites, gh_sites, llm_named_outside = [], [], []


def source_files(root):
    """Tracked files under a git root; a plain walk otherwise (fixtures).

    NOT a bare os.walk on the real repo. install.sh leaves gitignored bootstrap
    scratch trees (`aidoc-flow-ci-bootstrap-<pid>/consumer/...`) on disk that
    carry .yml/.sh copies, and .mypy_cache/ holds hundreds more. A walk reaches
    them, so a developer's local run reds on files that are not theirs while CI
    on a fresh clone stays green — an unreproducible failure, which is how a
    guard gets deleted. CLAUDE.md records this exact trap for markdownlint
    ("use `git ls-files`, never a `**/*` glob"); same rule here.
    """
    import subprocess
    try:
        out = subprocess.run(["git", "-C", root, "ls-files", "-z"],
                             capture_output=True, check=True).stdout
        rels = [r.decode() for r in out.split(b"\0") if r]
        if rels:
            return [(r, os.path.join(root, r)) for r in rels
                    if os.path.splitext(r)[1] in exts]
    except (OSError, subprocess.CalledProcessError):
        pass
    found = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in skip_dirs]
        for fn in filenames:
            if os.path.splitext(fn)[1] in exts:
                ap = os.path.join(dirpath, fn)
                found.append((os.path.relpath(ap, root), ap))
    return found


if True:
    for rel, p in source_files(root):
        if any(rel == d or rel.startswith(d + os.sep) for d in skip_dirs):
            continue
        try:
            lines = open(p, encoding="utf-8", errors="replace").read().splitlines()
        except OSError:
            continue
        for i, line in enumerate(lines, 1):
            if line.lstrip().startswith("#"):
                continue                      # a comment ABOUT a header is not one
            low = line.lower()
            if "authorization" not in low or "bearer" not in low:
                continue                      # a READ has no Bearer
            # Case-insensitive: `headers={"authorization": f"bearer {k}"}` is
            # idiomatic in requests/httpx and equally valid over the wire.
            cred = bearer.split(line, 1)[1]
            names = set(ident.findall(cred))
            # Classify on the FIRST identifier after `Bearer` — the credential
            # itself — NOT on every identifier to end of line. Matching the
            # whole remainder let one word anywhere after the header exempt a
            # site: a trailing comment naming GH_TOKEN filed a genuine
            # `Bearer ${LLM_API_KEY}` line as GitHub-family and the suite went
            # GREEN with a third presentation site in canon (measured). Trailing
            # comments on a header line are house style here — see
            # install/set-llm-secrets.sh:257.
            first = ident.search(cred)
            if first and first.group() in gh_names:
                gh_sites.append(f"{rel}:{i}")
            else:
                llm_sites.append(f"{rel}:{i}")
                # The credential is usually held in a local (`{api_key}`,
                # `${!1}`) and named LLM_* on an EARLIER line, so look at the
                # whole file. This corroborates WHY a site is a candidate — it
                # separates "a third LLM presenter" from "a GitHub presenter
                # using a token name we do not know yet". It is not an
                # independent detector: it only inspects lines already
                # classified as candidates.
                if rel not in allow and re.search(r"\bLLM_[A-Z0-9_]+", "\n".join(lines)):
                    llm_named_outside.append(f"{rel}:{i}")

for s in sorted(gh_sites):
    print("GH_SITE  " + s)
for s in sorted(llm_sites):
    print("LLM_SITE " + s)

found = sorted({s.rsplit(":", 1)[0] for s in llm_sites})
print("LLM_FILES: " + (",".join(found) if found else "<none>"))

rc = 0
if set(found) != allow:
    for extra in sorted(set(found) - allow):
        print(f"UNEXPECTED presentation site: {extra}")
        print("  -> if this DOES present the LLM credential, add it to `allow` "
              "and say why in the plan; if it presents some OTHER service's "
              "bearer token, add that credential's name to `gh_names`. "
              "Do not weaken the comparison.")
    for missing in sorted(allow - set(found)):
        print(f"MISSING presentation site: {missing}")
    rc = 1
# Corroboration, not a second detector (see the note above): says WHY an
# unexpected site is an LLM one rather than an unknown-token GitHub one.
for s in llm_named_outside:
    print(f"UNEXPECTED LLM credential referenced by {s}")
    rc = 1

client = os.path.join(root, "scripts/llm_client.py")
if os.path.exists(client):
    body = open(client, encoding="utf-8", errors="replace").read()
    # The CONDITION and the call, adjacent. A bare substring search for the
    # message passes when the guard is SOFTENED rather than deleted: changing
    # `if not api_key:` to `if not api_key and os.environ.get("LLM_STRICT"):`
    # leaves the literal untouched, so the check said "ok" while the client
    # would build `Bearer ` with an empty credential and 401 fleet-wide
    # (measured). Deletion is the one direction a substring search catches, and
    # deletion was the only mutation originally run.
    wired = re.search(r"if not api_key:\s*\n\s*fail\(\"LLM_API_KEY is not set\"\)", body)
    if wired:
        print("HARDFAIL ok")
    else:
        print("HARDFAIL MISSING — the client would proceed without a credential")
        rc = 1
else:
    print("HARDFAIL MISSING — scripts/llm_client.py absent")
    rc = 1

sys.exit(rc)
PYEOF

echo "== the real tree: exactly two presentation sites, hard-fail intact =="
out="$(python3 "$SCAN" "$ROOT" 2>&1)"; rc=$?
assert_eq "$rc" "0" "HEAD passes the closed-allowlist guard"
assert_contains "$out" "LLM_FILES: install/set-llm-secrets.sh,scripts/llm_client.py" \
  "the allowlist is exactly the two known sites"
assert_contains "$out" "LLM_SITE scripts/llm_client.py:209"   "runtime site located"
assert_contains "$out" "LLM_SITE install/set-llm-secrets.sh:257" "provisioning probe located"
assert_contains "$out" "LLM_SITE install/set-llm-secrets.sh:319" "provisioning mint located"
assert_contains "$out" "HARDFAIL ok"                          "the runtime hard-fail is intact"

echo "== the scope guard: canon's GitHub-API headers are classified, not swept in =="
assert_contains "$out" "GH_SITE  .github/workflows/ai-review.yml:236"      "ai-review GitHub header excluded"
assert_contains "$out" "GH_SITE  .github/workflows/standards-drift.yml:141" "drift GitHub header excluded"
assert_absent   "$out" "LLM_SITE .github/workflows/ai-review.yml"          "no ai-review line misread as an LLM site"
# set-llm-secrets.sh:254 is excluded by the COMMENT-SKIP: after lstrip() it
# begins with `#`, so the comment arm returns before the Bearer filter is ever
# reached. (An earlier comment here claimed the reverse. The Bearer filter is a
# sufficient BACKUP — which is why disabling the comment-skip left this green —
# but it is not the arm that fires.) Because two arms independently exclude this
# line, it cannot witness either one; the comment-skip gets its own fixture
# below, outside the allowlist, where it is the only thing in the way.
assert_absent   "$out" "LLM_SITE install/set-llm-secrets.sh:254"  "a commented Authorization line is not a site"
# NOT asserted here: that "reading a header is not presenting one". `tests` is in
# skip_dirs, so tests/test_scripts.sh is never opened — an absence assertion on
# it would pass even with the Bearer filter deleted. The read-vs-present
# distinction is witnessed by a fixture in a SCANNED directory instead.

# ---- fixture: real files, so mutations are measured against reality ----------
mk_fixture() {
  local d="$1"; rm -rf "$d"; mkdir -p "$d/scripts" "$d/install"
  cp "$ROOT/scripts/llm_client.py"      "$d/scripts/llm_client.py"
  cp "$ROOT/install/set-llm-secrets.sh" "$d/install/set-llm-secrets.sh"
}

echo "== DoD: a clean fixture of just the two files passes =="
F="$TMP/fx"; mk_fixture "$F"
out="$(python3 "$SCAN" "$F" 2>&1)"; rc=$?
assert_eq "$rc" "0" "the two-file fixture is green (mutations below start from green)"

echo "== DoD: deleting the runtime hard-fail turns it RED =="
mk_fixture "$F"
python3 - "$F/scripts/llm_client.py" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
old = '        fail("LLM_API_KEY is not set")'
assert old in s, "anchor missing — the mutation did not apply, so this test proves nothing"
open(p, "w").write(s.replace(old, "        pass"))
PY
out="$(python3 "$SCAN" "$F" 2>&1)"; rc=$?
assert_eq "$rc" "1" "removing the hard-fail is caught"
assert_contains "$out" "HARDFAIL MISSING" "...and the failure names the missing guard"

echo "== DoD: a THIRD LLM presentation site turns it RED =="
mk_fixture "$F"; mkdir -p "$F/scripts"
cat > "$F/scripts/rogue_client.py" <<'PY'
import os
def call():
    key = os.environ.get("LLM_API_KEY", "")
    return {"Authorization": f"Bearer {key}"}
PY
out="$(python3 "$SCAN" "$F" 2>&1)"; rc=$?
assert_eq "$rc" "1" "a third LLM auth builder is caught"
assert_contains "$out" "UNEXPECTED presentation site: scripts/rogue_client.py" \
  "...and the failure NAMES the offending file"
assert_contains "$out" "UNEXPECTED LLM credential referenced by" \
  "...and the corroborating LLM_* signal says WHY it is an LLM site"

echo "== DoD (the scope guard): a new GitHub-API bearer header stays GREEN =="
mk_fixture "$F"; mkdir -p "$F/.github/workflows"
cat > "$F/.github/workflows/new-thing.yml" <<'YML'
jobs:
  x:
    steps:
      - run: |
          curl -sS -H "Authorization: Bearer ${GH_TOKEN}" \
               -H "Accept: application/vnd.github+json" https://api.github.com/user
YML
out="$(python3 "$SCAN" "$F" 2>&1)"; rc=$?
assert_eq "$rc" "0" "unrelated GitHub-API work does NOT red this test"
assert_contains "$out" "GH_SITE  .github/workflows/new-thing.yml" "...it is classified as GitHub-family"

echo "== a header that is READ, not built, is not a presentation site =="
# In a SCANNED directory, unlike tests/ which is skipped.
# KNOWN LIMIT, found by this fixture defeating itself: detection is line-scoped,
# so a trailing COMMENT containing the word "bearer" next to an Authorization
# read makes the line look like a construction. That errs toward a false
# POSITIVE — it fails loud and the printed remediation applies — which is the
# safe direction for a guard. Stripping trailing comments before the test was
# rejected: `#` appears inside URLs and quoted strings, so the strip would
# create false NEGATIVES, which is the unsafe direction.
mk_fixture "$F"; mkdir -p "$F/scripts"
cat > "$F/scripts/reader.py" <<'PY'
def check(resp):
    seen = resp.headers["Authorization"]   # a read, not a construction
    return seen
PY
out="$(python3 "$SCAN" "$F" 2>&1)"; rc=$?
assert_eq "$rc" "0" "reading a header is not presenting one"

echo "== DoD (teeth): SOFTENING the hard-fail condition turns it RED =="
# Deletion was the only mutation originally run, and a substring search catches
# deletion. Softening the CONDITION leaves the message intact — measured GREEN
# before this fixture existed, with the client shipping `Bearer ` empty.
mk_fixture "$F"
python3 - "$F/scripts/llm_client.py" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
old = '    if not api_key:\n        fail("LLM_API_KEY is not set")'
assert old in s, "anchor missing — the mutation did not apply, so this test proves nothing"
new = '    if not api_key and os.environ.get("LLM_STRICT"):\n        fail("LLM_API_KEY is not set")'
open(p, "w").write(s.replace(old, new))
PY
out="$(python3 "$SCAN" "$F" 2>&1)"; rc=$?
assert_eq "$rc" "1" "softening the hard-fail CONDITION is caught, not just deleting the call"
assert_contains "$out" "HARDFAIL MISSING" "...and it names the missing guard"

echo "== DoD (teeth): a trailing GH_TOKEN comment does NOT exempt a real LLM site =="
# Classification reads the FIRST identifier after Bearer. Matching the whole
# remainder let this line file as GitHub-family — measured GREEN with a third
# presentation site present. Trailing comments on a header line are house style
# (install/set-llm-secrets.sh:257), so this is not a contrived case.
mk_fixture "$F"; mkdir -p "$F/scripts"
cat > "$F/scripts/sneaky.sh" <<'SH'
curl -H "Authorization: Bearer ${LLM_API_KEY}" "$LLM_URL/v1/chat"  # same shape as the GH_TOKEN header in ai-review.yml
SH
out="$(python3 "$SCAN" "$F" 2>&1)"; rc=$?
assert_eq "$rc" "1" "a GH token named in a trailing comment does not exempt the site"
assert_contains "$out" "UNEXPECTED presentation site: scripts/sneaky.sh" "...and it names the file"
assert_contains "$out" "Do not weaken the comparison" "...and the failure offers the sanctioned fix"

echo "== a lowercase authorization/bearer builder is still detected =="
mk_fixture "$F"; mkdir -p "$F/scripts"
cat > "$F/scripts/lower.py" <<'PY'
import os
def h():
    return {"authorization": f"bearer {os.environ['LLM_API_KEY']}"}
PY
out="$(python3 "$SCAN" "$F" 2>&1)"; rc=$?
assert_eq "$rc" "1" "case does not hide a presentation site"

echo "== a COMMENTED-OUT builder is not a presentation site =="
# The comment-skip is the ONLY thing excluding this line: it carries both
# Authorization and Bearer and a non-GitHub credential, so without the skip it
# is a full-blown candidate and the fixture goes red.
# It must live OUTSIDE the allowlist: appending it to an already-allowed file
# leaves the file set unchanged, so the assertion passes either way and proves
# nothing. Measured — that first version stayed green under the mutation.
mk_fixture "$F"; mkdir -p "$F/scripts"
cat > "$F/scripts/legacy_notes.sh" <<'SH'
# legacy, kept for reference:
#   printf 'Authorization: Bearer %s\n' "$LLM_LEGACY_KEY" > "$hdr"
SH
out="$(python3 "$SCAN" "$F" 2>&1)"; rc=$?
assert_eq "$rc" "0" "a commented-out builder does not create a site"

echo "== an UNKNOWN credential name fails LOUD rather than being exempted =="
mk_fixture "$F"; mkdir -p "$F/.github/workflows"
cat > "$F/.github/workflows/mystery.yml" <<'YML'
jobs:
  x:
    steps:
      - run: curl -H "Authorization: Bearer ${SOME_NEW_CRED}" "$LLM_URL/chat"
YML
out="$(python3 "$SCAN" "$F" 2>&1)"; rc=$?
assert_eq "$rc" "1" "an unrecognised credential name is treated as a candidate, not exempted"

suite_summary "credential-sites"
