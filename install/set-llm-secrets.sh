#!/usr/bin/env bash
# set-llm-secrets.sh — provision the unified LLM CI secrets on the aidoc-flow
# fleet. Endpoint-agnostic: any OpenAI-compatible URL (CI-0051).
# PLAN-009 Phase 0 (founder-executed). Sets REPOSITORY-level GitHub Actions secrets:
#   LLM_URL, LLM_API_KEY
#
# SECURITY:
#   * Never hardcodes secret VALUES — reads them from env vars.
#   * Values reach `gh secret set` on STDIN and the proxy probe via a 0600
#     header file — never argv, so they never appear in `ps`/the process table.
#   * GitHub stores them encrypted + write-only; they are masked in Actions logs.
#   * Store only the SCOPED virtual key — never the endpoint master key.
#
# WHAT `LLM_API_KEY` IS. Not a model-provider API key, despite the name. The
# ai-reviewer is a SHARED service; `LLM_API_KEY` is the per-repo VIRTUAL key it
# issues, so the proxy can tell its callers apart — attribute spend, cap a
# budget, and cut off ONE repo without cutting off the rest. `--mint` creates
# exactly that: `/key/generate` with `models` scoped to the alias, `max_budget`,
# and `metadata.repo` set to the target. The model-provider credential lives
# inside the proxy and is never written to a repository.
#
# Mint per repo. Pasting one key across the fleet gives up the only property
# that makes a shared service safe to share — per-repo revocability.
#
# SAFETY (issue #350): a run adding ONE optional secret also rewrote the two
# that were already correct, from an environment holding a loopback URL.
# All three writes printed ✓, the script exited 0, and a REQUIRED ai-review gate
# on a consumer went red until the key was re-provisioned by hand. Hence:
#   * An EXISTING secret is NEVER replaced without --overwrite, so a run that
#     adds one secret to a provisioned repo writes that secret and nothing else.
#     (The incident's vehicle was the `--doc` key, retired with `doc-maintainer`
#     per CI-0040. The rule is general and outlives it — do NOT delete it on the
#     grounds that its original trigger is gone.)
#   * A loopback LLM_URL is refused (--allow-loopback forces it): it
#     resolves to the job CONTAINER, not the host running the proxy, so it works
#     in every check an operator can run locally and fails only in CI (CI-0017).
#     The check is BEST-EFFORT: it normalizes case and trailing dots, knows the
#     integer forms of 127.0.0.1, and resolves the host when `getent` is present
#     — but a DNS name that only sometimes answers 127.0.0.1 can still pass.
#   * URL + key are probed against <base>/models before ANY repo is touched
#     (--skip-validate bypasses). Anything but 200/403 aborts the run — 403 is
#     accepted because a scoped key may be forbidden on /models yet valid for
#     chat completions. --dry-run makes NO network call at all: the probe sends
#     a live bearer token, and the flag exists to inspect a suspect config
#     safely, not to transmit a credential to whatever host it names.
#   * If the existing secret set cannot be READ, the repo is SKIPPED — always,
#     including under --overwrite. An unreadable list is not evidence of an
#     empty one, and listing and writing need the same admin scope, so a failed
#     list means the token is wrong rather than the repo being empty.
#   * Value equality is NOT checkable: GitHub secrets are write-only, so this
#     script can see that a secret EXISTS but never whether it differs.
#
# EXIT STATUS: 0 only if every requested repo was fully processed. A skipped repo
# (no access, or an unreadable secret list) or a failed write exits 1 — a run
# that touched nothing must not look like a run that did the work. A failed write
# does NOT abort the fan-out: it is reported, the remaining repos are still
# attempted, and the summary always prints. Ctrl-C exits 130 (SIGTERM 143).
#
# REQUIRES: gh, and curl unless --skip-validate is passed (jq too, for --mint).
#
# TWO MODES:
#   shared : one review key applied to every repo.
#            export LLM_URL LLM_API_KEY
#   mint   : mint a fresh, per-repo, review-scoped virtual key from the master key
#            (revocable per repo; tagged with the repo name). --mint
#            export LLM_URL LLM_MASTER_KEY
#
# USAGE:
#   export LLM_URL="https://proxy.example/v1"
#   export LLM_API_KEY="<key>"         # shared mode
#   bash set-llm-secrets.sh --pilot            # engramory only (pilot first)
#   bash set-llm-secrets.sh                     # all 7 consumers
#   bash set-llm-secrets.sh --repos "vladm3105/aidoc-flow-framework vladm3105/iplan-runner"
#   bash set-llm-secrets.sh --dry-run          # print the per-secret plan; no writes, no network
#   bash set-llm-secrets.sh --overwrite        # REPLACE secrets that already exist
#   bash set-llm-secrets.sh --allow-loopback   # permit a loopback base URL (rarely correct)
#   bash set-llm-secrets.sh --skip-validate    # skip the pre-write proxy probe
#
#   # per-repo revocable keys (recommended once you have the master key locally):
#   export LLM_MASTER_KEY="<key>"
#   bash set-llm-secrets.sh --mint --budget 50
#
# LLM_MASTER_KEY IS THIS SCRIPT'S NAME FOR IT, NOT YOUR ENDPOINT'S (CI-0051).
# Canon unified the names IT owns — the Actions secrets and the workflow inputs.
# Your endpoint product keeps whatever it calls its own admin key, and this
# script does not try to rename it. The workspace's LiteLLM deployment, for
# instance, calls it LITELLM_MASTER_KEY; OpenAI would be OPENAI_API_KEY. Bridge
# it at the call site, in a SUBSHELL so the key does not linger in your
# interactive environment:
#   ( export LLM_URL=... LLM_MASTER_KEY="$(...read your endpoint's var...)"
#     bash set-llm-secrets.sh --mint --repos "owner/repo" )
# A vendor-specific name on the LEFT of that bridge is expected; one inside
# canon is not.
#
# TIP: run in a subshell so the exported keys leave no trace in your shell history:
#   ( export LLM_URL=... LLM_API_KEY=...; bash set-llm-secrets.sh )

set -euo pipefail

OWNER="vladm3105"
# The 7 PLAN-009 consumers (exact repo names; note iplan-runner has no aidoc-flow- prefix).
CONSUMERS=(
  aidoc-flow-framework
  aidoc-flow-business
  aidoc-flow-iplanic
  iplan-runner
  aidoc-flow-iplan-standard
  aidoc-flow-engramory
  aidoc-flow-interlog
)
PILOT="aidoc-flow-engramory"
BRIDGE_DEFAULT="http://172.17.0.1:4001/v1"

DRY_RUN=0; MINT=0; BUDGET=50
OVERWRITE=0; ALLOW_LOOPBACK=0; VALIDATE=1
REPOS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)        DRY_RUN=1 ;;
    --mint)           MINT=1 ;;
    --overwrite)      OVERWRITE=1 ;;
    --allow-loopback) ALLOW_LOOPBACK=1 ;;
    --skip-validate)  VALIDATE=0 ;;
    --pilot)   REPOS=("$OWNER/$PILOT") ;;
    --budget)
      BUDGET="${2:?--budget needs a number}"
      # Unvalidated, this both swallowed the next flag (`--budget --mint` set
      # BUDGET=--mint and silently ran in SHARED mode) and interpolated into the
      # key-minting JSON body, where a crafted value can widen the minted key's
      # model scope.
      case "$BUDGET" in ''|*[!0-9]*) echo "ERROR: --budget needs a whole number, got: $BUDGET" >&2; exit 2 ;; esac
      shift ;;
    --repos)   IFS=' ' read -r -a REPOS <<< "${2:?--repos needs a list}"; shift ;;
    -h|--help) sed -n '2,/^set -euo/p' "$0" | sed '$d'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done
if [ "${#REPOS[@]}" -eq 0 ]; then for r in "${CONSUMERS[@]}"; do REPOS+=("$OWNER/$r"); done; fi

# ---- preflight ----
command -v gh >/dev/null || { echo "ERROR: gh CLI required" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "ERROR: run 'gh auth login' first" >&2; exit 1; }
: "${LLM_URL:?export LLM_URL first}"
case "$LLM_URL" in
  https://*) ;;
  http://*)  echo "WARN: HTTP base URL — the bearer key travels in cleartext. Prefer HTTPS / a private mesh." >&2 ;;
  *) echo "ERROR: LLM_URL must be an http(s) URL" >&2; exit 1 ;;
esac

# Host of a URL, minus scheme, userinfo, port and any [v6] brackets.
url_host() {
  local u="${1#*://}"; u="${u%%/*}"; u="${u##*@}"
  case "$u" in
    \[*\]*) u="${u#\[}"; u="${u%%\]*}" ;;
    *:*)    u="${u%%:*}" ;;
  esac
  printf '%s' "$u"
}

# Best-effort loopback detection. `case` is case-sensitive and DNS is not, and
# 127.0.0.1 has decimal/hex/octal spellings that every resolver accepts — all of
# LOCALHOST, localhost. and 2130706433 reached loopback while an earlier version
# of this guard called them safe.
is_loopback() {
  local h="${1,,}" n                     # lower-case; drop a trailing root dot
  h="${h%.}"
  case "$h" in
    localhost|localhost.localdomain|*.localhost) return 0 ;;
    127.*|0.0.0.0) return 0 ;;
    ::1|0:0:0:0:0:0:0:1|::|0:0:0:0:0:0:0:0) return 0 ;;
    ::ffff:127.*|::ffff:7f00:*) return 0 ;;
  esac
  # Integer spellings of an IPv4 address: 2130706433, 0x7f000001 and
  # 017700000001 are all 127.0.0.1, and every resolver accepts them. Validate
  # the literal SHAPE first, then evaluate with an EXPLICIT base — a bash
  # arithmetic ERROR unwinds the CALLER's `if` and skips the guard entirely
  # without running either branch (measured with `3fa`), and its message is
  # emitted before 2>/dev/null can suppress it. These are detected locally
  # rather than left to the resolver because the proxy is addressed by IP
  # literal, so the resolver below is often never consulted at all.
  n=""
  case "$h" in
    0x*)     case "${h#0x}" in ''|*[!0-9a-f]*) : ;;
               *) if [ "${#h}" -le 18 ]; then n=$(( 16#${h#0x} )); fi ;; esac ;;
    0[0-7]*) case "${h#0}"   in *[!0-7]*) : ;;
               *) if [ "${#h}" -le 22 ]; then n=$(( 8#${h#0} )); fi ;; esac ;;
    ''|*[!0-9]*) : ;;
    *)       if [ "${#h}" -le 10 ]; then n=$(( 10#$h )); fi ;;
  esac
  if [ -n "$n" ]; then
    if [ "$n" -eq 0 ] || [ "$(( n >> 24 & 255 ))" = 127 ]; then return 0; fi
  fi
  # Last resort: ask the resolver, for a DNS name that points at loopback.
  # Decide on the ANSWER, never on the pipeline's exit status. With `timeout` at
  # the head of a `pipefail` pipeline, a resolver that answers 127.0.0.1 and
  # then stalls returns 124 even though grep already matched — measured, and it
  # turned a correct refusal into a silent accept, which is the #350 outcome.
  if command -v getent >/dev/null 2>&1; then
    local answers=""
    if command -v timeout >/dev/null 2>&1; then
      answers="$(timeout 3 getent ahosts "$h" 2>/dev/null | awk '{print $1}')" || true
    else
      answers="$(getent ahosts "$h" 2>/dev/null | awk '{print $1}')" || true
    fi
    if grep -qE '^(127\.|::1$|0\.0\.0\.0$)' <<< "$answers"; then return 0; fi
  fi
  return 1
}

BASE_HOST="$(url_host "$LLM_URL")"
if is_loopback "$BASE_HOST"; then
  if [ "$ALLOW_LOOPBACK" -eq 0 ]; then
    cat >&2 <<EOF
ERROR: LLM_URL points at loopback ($BASE_HOST) — refusing to write it.

  CI jobs run INSIDE an ephemeral container, so loopback resolves to the
  container itself, not the host running the proxy. This value passes every
  check you can run from the host (both addresses answer 401 there) and fails
  only in CI, which is what makes it expensive to diagnose. (CI-0017, #350.)

  Use the Docker bridge gateway instead:  $BRIDGE_DEFAULT
  If you really mean loopback, pass --allow-loopback.
EOF
    exit 1
  fi
  echo "WARN: loopback base URL accepted via --allow-loopback — this breaks CI unless the proxy is inside the job container." >&2
fi

# LiteLLM MANAGEMENT endpoints (/key/generate) live at the ROOT, NOT under /v1
# (the /v1 path is the OpenAI-compat surface). Derive the root from the base URL
# so a canonical `…/v1` base URL still mints against `…/key/generate`.
MGMT_URL="${LLM_URL%/}"; MGMT_URL="${MGMT_URL%/v1}"
MODELS_URL="${LLM_URL%/}/models"

if [ "$MINT" -eq 1 ]; then
  command -v jq   >/dev/null || { echo "ERROR: jq required for --mint" >&2; exit 1; }
  command -v curl >/dev/null || { echo "ERROR: curl required for --mint" >&2; exit 1; }
  : "${LLM_MASTER_KEY:?export LLM_MASTER_KEY for --mint}"
else
  : "${LLM_API_KEY:?export LLM_API_KEY (or use --mint)}"
fi

# One directory for every file that ever holds a bearer token, removed on ANY
# exit. A per-function RETURN trap does not fire on SIGINT — measured: Ctrl-C
# during the probe left a 0600 file containing the key behind indefinitely.
SECRET_TMP="$(mktemp -d)"; chmod 700 "$SECRET_TMP"
# A bash INT/TERM handler that only cleans up does NOT stop the script: bash
# runs the handler and RESUMES. Trapping INT without exiting would delete
# SECRET_TMP out from under a still-running fan-out and take away the only lever
# an operator has once they realize a run is writing the wrong values. Each
# signal handler therefore exits with its conventional 128+signal status.
trap 'rm -rf "$SECRET_TMP"' EXIT
trap 'rm -rf "$SECRET_TMP"; exit 130' INT
trap 'rm -rf "$SECRET_TMP"; exit 143' TERM

# ---- pre-write proxy probe ----
# One request per key, before any repo is touched. It catches the half of #350
# the loopback guard cannot: a base URL that is CORRECT with a key the proxy
# rejects. (The converse also holds — a good key on a loopback URL answers 200
# from the host — which is why both guards exist and neither subsumes the other.)
probe() {  # probe VALUE_VARNAME -> prints the HTTP status, 000 if unreachable
  # --globoff: a stray {} or [] in the URL would otherwise fan the SAME bearer
  # token out to several hosts. --proto: no gopher/file/etc. No -L, deliberately
  # — following a redirect would forward the Authorization header to the
  # redirect target. Do not "helpfully" add it.
  local hdr code; hdr="$(mktemp -p "$SECRET_TMP")"
  printf 'Authorization: Bearer %s\n' "${!1}" > "$hdr"   # printf is a BUILTIN: no argv exposure
  code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 --globoff \
            --proto '=http,https' -H @"$hdr" "$MODELS_URL" 2>/dev/null)" || true
  rm -f "$hdr"
  case "${code:-}" in ''|000*) code="000" ;; esac
  printf '%s' "$code"
}

validate_or_die() {  # validate_or_die VALUE_VARNAME SECRET_NAME
  local code; code="$(probe "$1")"
  case "$code" in
    # 403 = authenticated but not authorized for /models; a review-scoped key
    # can legitimately answer this and still work for chat completions.
    200|403) echo "  ✓ probe: $2 accepted by $MODELS_URL (HTTP $code)" ;;
    401)
      cat >&2 <<EOF
ERROR: the proxy REJECTS \$$1 (HTTP 401) — refusing to write it as $2.

  Writing it would replace a possibly-working secret with one that cannot
  authenticate, and the break would surface only on the next PR. Check the
  value you exported, then re-run. (#350.)
EOF
      exit 1 ;;
    000)
      echo "ERROR: $MODELS_URL is unreachable — refusing to provision against a proxy that does not answer." >&2
      echo "       Check LLM_URL, or pass --skip-validate to write anyway." >&2
      exit 1 ;;
    *)
      # Fail CLOSED on anything else. 404 is the likeliest operator error the
      # probe exists to catch — MODELS_URL appends /models, so a base URL
      # missing or doubling /v1 lands here — and warning-then-writing would let
      # the guard pass the exact failure it was built for.
      echo "ERROR: probe of $MODELS_URL returned HTTP $code, which is neither success nor a" >&2
      echo "       recognized auth answer. A 404 usually means LLM_URL is missing or" >&2
      echo "       doubling its /v1 suffix. Fix it, or pass --skip-validate to write anyway." >&2
      exit 1 ;;
  esac
}

if [ "$VALIDATE" -eq 1 ] && [ "$DRY_RUN" -eq 1 ]; then
  echo "  [dry-run] skipping the proxy probe — it would send a live bearer token to $MODELS_URL"
elif [ "$VALIDATE" -eq 1 ]; then
  command -v curl >/dev/null || { echo "ERROR: curl required for the pre-write probe (or pass --skip-validate)" >&2; exit 1; }
  if [ "$MINT" -eq 1 ]; then
    validate_or_die LLM_MASTER_KEY "the master key"
  else
    # Probe only the keys this run can actually write. A key that is unset
    # would be KEPT, so probing it would abort the run over a secret nobody is
    # touching.
    if [ -n "$LLM_API_KEY" ]; then validate_or_die LLM_API_KEY LLM_API_KEY; fi
  fi
fi

mint() {  # mint REPO PURPOSE MODEL_ALIAS  -> prints the scoped key
  # PLAN-015 L3: the master key (mints all others) must NOT sit on the curl
  # argv, where any local process-table reader sees it — honoring this script's
  # STDIN-only contract (header comment). Write it to a temp file with the
  # `printf` BUILTIN (no argv exposure) and read it via `curl -H @file`
  # (curl >= 7.55). The file lives in $SECRET_TMP, which the EXIT/INT/TERM trap
  # removes — a per-function RETURN trap does not survive Ctrl-C, and this file
  # holds the MASTER key.
  local hdr rc=0; hdr="$(mktemp -p "$SECRET_TMP")"
  printf 'Authorization: Bearer %s\n' "$LLM_MASTER_KEY" > "$hdr"
  curl -fsS -X POST "$MGMT_URL/key/generate" --max-time 30 --globoff --proto '=http,https' \
    -H @"$hdr" -H "Content-Type: application/json" \
    -d "{\"models\":[\"$3\"],\"max_budget\":$BUDGET,\"metadata\":{\"purpose\":\"$2\",\"repo\":\"$1\"}}" \
    | jq -er '.key' || rc=$?
  rm -f "$hdr"
  return "$rc"
}

# ---- per-secret decision ----
# EXISTING is the newline-separated set of secret names already on the repo.
EXISTING=""
CREATED=0; OVERWROTE=0; KEPT=0; SKIPPED=0; FAILED=0

action_for() {  # action_for SECRET_NAME -> create | overwrite | keep
  # A here-string, not `printf | grep`: with a pipeline, `grep -q` exits at the
  # first match, `printf` takes SIGPIPE, and `pipefail` turns the whole thing
  # non-zero — which would report an EXISTING secret as `create` and overwrite
  # it without --overwrite, inverting the one invariant this script exists for.
  if grep -qxF -- "$1" <<< "$EXISTING"; then
    if [ "$OVERWRITE" -eq 1 ]; then printf 'overwrite'; else printf 'keep'; fi
  else
    printf 'create'
  fi
}

report_keep() {
  printf '    – %-23s (exists, kept — pass --overwrite to replace)\n' "$1"
  KEPT=$((KEPT+1))
}

provision() {  # provision SECRET_NAME REPO VALUE_VARNAME
  local name="$1" repo="$2" var="$3" act
  act="$(action_for "$name")"
  if [ "$act" = keep ]; then report_keep "$name"; return 0; fi
  if [ -z "${!var}" ]; then
    # This repo needs the secret CREATED and nothing was exported.
    # Never write a blank secret.
    printf '    ✗ %-23s (needs to be %s, but $%s is empty — export it and re-run)\n' "$name" "$act" "$var" >&2
    FAILED=$((FAILED+1)); return 0
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '    [dry-run] %-23s would be %s\n' "$name" \
      "$([ "$act" = create ] && printf 'created' || printf 'OVERWRITTEN')"
  elif printf '%s' "${!var}" | gh secret set "$name" -R "$repo"; then
    printf '    ✓ %-23s (%s)\n' "$name" \
      "$([ "$act" = create ] && printf 'created' || printf 'overwritten')"
  else
    # Not fatal: `set -e` would abort mid-fleet with no summary, leaving the
    # operator unable to tell which repos were written and which were never
    # reached. Record it, keep going, and fail the run at the end.
    printf '    ✗ %-23s (write FAILED)\n' "$name" >&2
    FAILED=$((FAILED+1)); return 0
  fi
  if [ "$act" = create ]; then CREATED=$((CREATED+1)); else OVERWROTE=$((OVERWROTE+1)); fi
}

echo "LLM secret provisioning — mode=$([ "$MINT" -eq 1 ] && echo mint || echo shared)  dry_run=$DRY_RUN  repos=${#REPOS[@]}  overwrite=$OVERWRITE  validate=$VALIDATE"
for repo in "${REPOS[@]}"; do
  echo "• $repo"
  if ! gh repo view "$repo" >/dev/null 2>&1; then
    echo "    SKIP: no access to $repo" >&2; SKIPPED=$((SKIPPED+1)); continue
  fi

  # Fail closed, with no override. Listing secret NAMES and writing them need the
  # same admin scope, so a failed list means the token is wrong — not that the
  # repo is empty. Writing blind here is the #350 class of bug, and --overwrite
  # is an instruction about known-stale values, not consent to write unseen.
  if ! EXISTING="$(gh secret list -R "$repo" --json name --jq '.[].name' 2>/dev/null)"; then
    echo "    SKIP: cannot read the existing secrets on $repo — refusing to write blind." >&2
    echo "          An unreadable list is not an empty one; check the token's admin scope." >&2
    SKIPPED=$((SKIPPED+1)); continue
  fi

  provision LLM_URL "$repo" LLM_URL
  if [ "$MINT" -eq 1 ]; then
    # `provision` reads MINTED_* through ${!var} indirect expansion, which static
    # analysis cannot follow, so the directive below silences a false "unused".
    # (Keep "shellcheck" off the start of a comment line unless you mean a
    # directive — a prose line beginning with it is parsed as one, and fails.)
    # shellcheck disable=SC2034
    # Decide BEFORE minting: a key minted for a secret we then keep is a live
    # credential nobody ever uses.
    if [ "$(action_for LLM_API_KEY)" = keep ]; then
      report_keep LLM_API_KEY
    else
      MINTED_REVIEW="(dry-run — not minted)"
      if [ "$DRY_RUN" -eq 0 ]; then
        MINTED_REVIEW="$(mint "$repo" ci-review ai-reviewer)" || MINTED_REVIEW=""
      fi
      if [ -n "$MINTED_REVIEW" ]; then
        provision LLM_API_KEY "$repo" MINTED_REVIEW
      else
        # Covers a hard mint failure AND a proxy answering {"key":""} — `jq -er`
        # exits 0 on an empty string, so a successful mint is not proof of a key.
        printf '    ✗ %-23s (mint produced no key)\n' LLM_API_KEY >&2
        FAILED=$((FAILED+1))
      fi
      unset MINTED_REVIEW
    fi
  else
    provision LLM_API_KEY "$repo" LLM_API_KEY
  fi
done

printf 'Done%s. %d created, %d overwritten, %d kept, %d repo(s) skipped.\n' \
  "$([ "$DRY_RUN" -eq 1 ] && printf ' (dry-run — nothing written)')" \
  "$CREATED" "$OVERWROTE" "$KEPT" "$SKIPPED"
if [ "$KEPT" -gt 0 ]; then
  echo "  $KEPT secret(s) already existed and were left alone. Re-run with --overwrite to replace them."
fi
echo "Verify (names only, values are write-only):"
echo "  for r in ${REPOS[*]}; do echo \"== \$r\"; gh secret list -R \"\$r\" | grep -E 'LLM_(URL|API_KEY)'; done"

# A run that reached no repo, or skipped one, must not exit 0 — "printed ✓ and
# exited 0" is the shape of #350 itself, and a wrapper reading $? cannot tell a
# full fan-out from one that touched nothing.
if [ "$FAILED" -gt 0 ] || [ "$SKIPPED" -gt 0 ]; then
  echo "ERROR: $SKIPPED repo(s) skipped, $FAILED secret(s) not written — this run did NOT do what was asked." >&2
  exit 1
fi
