#!/usr/bin/env bash
# deploy-ci-wizard.sh — AI-agent wizard for deploying the aidoc-flow CI stack
# on a workspace repo. Companion to docs/AI_CI_DEPLOYMENT.md (read it for the
# judgment calls + gotchas this script can't make).
#
# SAFE BY DESIGN: this wizard never commits, pushes, merges, sets secrets, or
# installs Apps. It only READS (preflight/plan/verify) or writes caller files to
# a LOCAL scratch dir you review before committing (scaffold). All remote
# mutations stay under the operator's control.
#
# Usage:
#   deploy-ci-wizard.sh preflight <owner/repo>          # 🟢/🔴 prerequisite audit
#   deploy-ci-wizard.sh plan      <owner/repo>          # ordered deployment plan
#   deploy-ci-wizard.sh scaffold  <owner/repo> <dir> [wf...]   # write caller files + configs
#   deploy-ci-wizard.sh verify    <owner/repo> <pr>     # poll ai-review + composition + App review
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TPL="$HERE/templates"
# PLAN-018 F7 — fail loud, carry NO literal fallback.
#
# The previous form ended `|| echo 'ci/v1.9.5'`. That was not dead code: under
# `set -euo pipefail` a missing or unreadable VERSION makes `cat` exit 1, the
# pipeline exit 1, and the fallback FIRE — so the wizard scaffolded callers
# pinned to ci/v1.9.5 while VERSION said ci/v2.10.0. Fourteen releases back,
# green and silent, with nothing to indicate the pin was not the one requested.
# (Verified by execution across all five modes: missing / empty / whitespace-only
# / unreadable / good. The empty case produced the unresolvable `@` pin.)
#
# The obvious replacement dies before reaching its own guard: under `set -e` an
# assignment whose command substitution fails terminates the script, and the
# redirection error is reported before `2>/dev/null` applies to it. Hence the
# explicit `|| CI_TAG=""` and the `2>/dev/null` BEFORE the `<` redirection.
#
# `tests/test_version_sync.sh` asserts this shipped behaviour, including the
# missing-file case, so a literal fallback cannot reappear unnoticed.
CI_TAG="$(tr -d '[:space:]' 2>/dev/null < "$HERE/../VERSION")" || CI_TAG=""
[ -n "$CI_TAG" ] || {
  echo "deploy-ci-wizard: cannot resolve the canon version — $HERE/../VERSION is missing, empty, or unreadable." >&2
  echo "                  Refusing to scaffold: a guessed pin would silently write callers at the wrong canon tag." >&2
  exit 2
}
BOT_ID="294948438"                    # aidoc-reviewer App bot-user id (App-global)
GH="${GH:-gh}"

# All workflows in dependency order. Format: name:phase
# dep-scan/trivy-scan/sast-scan (PLAN-014 own security scanners) are OPTIONAL +
# report-only — surveyed here + offered by plan(), but NOT in scaffold()'s default
# list (deliberate per-repo adoption; pass them explicitly to scaffold).
ALL_WF="pre-commit:1 links:2 markdown-lint:2 labeler:2 secret-scan:3 dep-scan:3 trivy-scan:3 sast-scan:3 audit-trail:4 ai-review:5 composition:5 auto-merge-ai-prs:6 doc-maintainer:7 docs-sync:7 codeql:8 standards-drift:8"

c_ok() { printf '  \033[32m🟢 %s\033[0m\n' "$*"; }
c_no() { printf '  \033[31m🔴 %s\033[0m\n' "$*"; }
c_wn() { printf '  \033[33m⚠️  %s\033[0m\n' "$*"; }
hdr()  { printf '\n\033[1m%s\033[0m\n' "$*"; }

visibility() { $GH repo view "$1" --json visibility -q .visibility 2>/dev/null; }

preflight() {
  local repo="$1"
  hdr "Preflight — $repo   (canon tag: $CI_TAG)"
  local vis; vis="$(visibility "$repo" || true)"
  [ -z "$vis" ] && { c_no "cannot read repo (auth? name?). gh repo view $repo failed."; return 1; }
  echo "  visibility: $vis"

  hdr "1. Runner pool"
  if [ "$vis" = PRIVATE ]; then
    local runners; runners="$($GH api "repos/$repo/actions/runners" --jq '[.runners[]|select(.status=="online")|[.labels[].name]|join(",")]|join(" | ")' 2>/dev/null || echo '')"
    if echo "$runners" | grep -q 'ci-runner' && echo "$runners" | grep -q 'single-use'; then c_ok "self-hosted ci-runner/single-use pool online: $runners"
    else c_no "PRIVATE repo has NO online ci-runner/single-use pool → 🔴 founder registers the pool (docs/runners.md §2/§3; templates: install/templates/runner/). Do NOT use ubuntu-latest."; fi
  else
    local prunners; prunners="$($GH api "repos/$repo/actions/runners" --jq '[.runners[]|select(.status=="online")|[.labels[].name]|join(",")]|join(" | ")' 2>/dev/null || echo '')"
    if echo "$prunners" | grep -q 'ci-runner' && echo "$prunners" | grep -q 'single-use'; then c_ok "PUBLIC → generic lint flows use ubuntu-latest; ci-runner/single-use pool ALSO online (needed by the uniform-protected AI-flows + PLAN-014 scanners): $prunners"
    else c_wn "PUBLIC → generic lint flows use ubuntu-latest, but the uniform-protected AI-flows (ai-review review job) + PLAN-014 scanners run self-hosted here too and need a ci-runner/single-use pool — none online. Register one before adopting those surfaces (docs/runners.md §5a)."; fi
  fi

  hdr "2. Reviewer App secrets + bot-id (for ai-review + composition)"
  local secs; secs="$($GH secret list -R "$repo" --json name -q '.[].name' 2>/dev/null || echo '')"
  local missing=0
  for s in APP_REVIEWER_1_ID APP_REVIEWER_1_KEY LITELLM_BASE_URL LITELLM_REVIEW_API_KEY LITELLM_DOC_API_KEY; do
    echo "$secs" | grep -qx "$s" && c_ok "secret $s set" || { c_no "secret $s MISSING → 🔴 founder sets it (+ installs the aidoc-reviewer App)"; missing=1; }
  done
  local botid; botid="$($GH variable list -R "$repo" --json name,value -q '.[]|select(.name=="APP_REVIEWER_1_BOT_ID")|.value' 2>/dev/null || echo '')"
  if [ "$botid" = "$BOT_ID" ]; then c_ok "APP_REVIEWER_1_BOT_ID var = $botid"
  elif [ -n "$botid" ]; then c_wn "APP_REVIEWER_1_BOT_ID var = $botid (expected $BOT_ID — verify it's this repo's App)"
  else c_no "APP_REVIEWER_1_BOT_ID var UNSET → 🟢 you set it: gh variable set APP_REVIEWER_1_BOT_ID -R $repo --body $BOT_ID  (else composition runs INERT)"; fi
  [ "$missing" = 1 ] && c_wn "ai-review/composition cannot work until the 🔴 secrets land."

  hdr "3. Canon labels"
  local labs; labs="$($GH label list -R "$repo" --json name -q '.[].name' 2>/dev/null || echo '')"
  for l in ai:review-passed ai:review-changes ai:human-review-required skip-ai-review skip-audit-trail; do
    echo "$labs" | grep -qx "$l" && c_ok "label $l" || c_wn "label $l missing → 🟢 gh label create $l -R $repo (see §1.4)"
  done

  hdr "4. Allowed-actions policy"
  local pol; pol="$($GH api "repos/$repo/actions/permissions/selected-actions" --jq '.patterns_allowed|join(", ")' 2>/dev/null || echo 'unreadable/all-allowed')"
  echo "  patterns_allowed: $pol"
  echo "$pol" | grep -q 'aidoc-flow-ci' && c_ok "aidoc-flow-ci allowlisted" || c_wn "confirm aidoc-flow-ci/* is allowlisted (else reusables startup_failure)"

  hdr "5. Already-deployed workflows"
  # Resolve the repo's DEFAULT BRANCH once — do not assume `main`. A repo on
  # `master`/`develop` would otherwise read as "no workflows" (and skip the
  # FT-31 check below) rather than reporting its real state.
  local defbr; defbr="$($GH api "repos/$repo" --jq '.default_branch' 2>/dev/null || echo main)"
  [ -n "$defbr" ] || defbr=main
  local have; have="$($GH api "repos/$repo/contents/.github/workflows?ref=$defbr" --jq '[.[].name]|join(" ")' 2>/dev/null || echo '')"
  for pair in $ALL_WF; do
    local wf="${pair%%:*}"
    echo "$have" | grep -qw "$wf.yml" && c_ok "$wf.yml present" || echo "     ·  $wf.yml — not yet"
  done
  echo "$have" | grep -qw 'security.yml'  && c_wn "ships own security.yml → treat secret-scan as covered-by-own (don't double-add)"
  echo "$have" | grep -qw 'docs-lint.yml' && c_wn "ships own docs-lint.yml → treat markdown-lint as covered-by-own (don't clobber .markdownlint.json)"

  # PLAN-018 FT-31 — zero-hook detector. If the repo already runs the pre-commit
  # caller, its required 'call / Lint / format / security hooks' check is only
  # meaningful if the repo's .pre-commit-config.yaml selects a hook at the
  # pre-commit stage. A config with only pre-push hooks passes green while
  # inspecting nothing (F3). Same standalone check install.sh + the release
  # checklist run — never on the reusable's gating path.
  if echo "$have" | grep -qw 'pre-commit.yml'; then
    local pcfg; pcfg="$($GH api "repos/$repo/contents/.pre-commit-config.yaml?ref=$defbr" --jq '.content' 2>/dev/null | base64 -d 2>/dev/null || echo '')"
    if [ -z "$pcfg" ]; then
      c_wn "pre-commit.yml present but .pre-commit-config.yaml unreadable — cannot verify the required check has hooks (FT-31)"
    else
      local pctmp; pctmp="$(mktemp)"; printf '%s' "$pcfg" > "$pctmp"
      local pcrc; bash "$HERE/check-precommit-hooks.sh" "$pctmp" >/dev/null 2>&1 && pcrc=0 || pcrc=$?
      case "$pcrc" in
        0) c_ok ".pre-commit-config.yaml selects ≥1 pre-commit-stage hook (required check is real)" ;;
        1) c_no ".pre-commit-config.yaml selects ZERO pre-commit-stage hooks → the required 'call / Lint / format / security hooks' check would inspect NOTHING (F3/FT-31). Add commit-stage hooks (canon fragment: check-yaml/end-of-file-fixer/trailing-whitespace)." ;;
        *) c_wn "could not verify .pre-commit-config.yaml hooks (FT-31 detector rc=$pcrc — PyYAML missing or unparseable config)" ;;
      esac
      rm -f "$pctmp"
    fi
  fi

  # PLAN-018 FT-18 — required-context ↔ producer validator (general form of F2).
  # For each tier, does every required status-check context have an INSTALLED
  # caller producing it? A required context with no producer never reports, so
  # arming protection at that tier pins every PR on "Expected — Waiting for
  # status to be reported" forever (exactly F2). The context->producer map is
  # DERIVED from canon (required-context-map.py), never hand-maintained.
  hdr "6. Required-context producers (FT-18) — would arming brick a PR?"
  local mapout; mapout="$(python3 "$HERE/required-context-map.py" "$HERE/.." 2>/dev/null || echo '')"
  if [ -z "$mapout" ] || [ "$mapout" = SKIP ]; then
    c_wn "could not derive the required-context map (PyYAML missing?) — cannot check producers"
  else
    # List tiers from the template FILES (not only tiers the map emitted rows
    # for) so umbrella — which has no required contexts — still gets a line
    # rather than being silently omitted.
    local tiers; tiers="$(ls "$HERE"/templates/branch-protection-*.json 2>/dev/null | sed -E 's#.*/branch-protection-(.*)\.json#\1#' | sort -u)"
    local t
    for t in $tiers; do
      local missing="" ctx producer nreq=0
      while IFS=$'\t' read -r ctx producer; do
        nreq=$((nreq+1))
        case "$producer" in
          '?non-call') : ;;  # a bare (repo-local) required context — no canon producer expected, not a defect
          '?') missing="$missing\n       · $ctx → canon ships NO producer — canon defect" ;;
          *) echo "$have" | grep -qw "$producer" || missing="$missing\n       · $ctx → needs $producer (NOT installed)" ;;
        esac
      done < <(printf '%s\n' "$mapout" | awk -F'\t' -v tt="$t" '$1==tt{print $2"\t"$3}')
      if [ "$nreq" -eq 0 ]; then
        c_ok "$t: no required contexts (nothing to produce)"
      elif [ -z "$missing" ]; then
        c_ok "$t: all $nreq required-context producer(s) installed"
      else
        c_no "$t: arming would HANG PRs — required context(s) with no installed producer:$(printf '%b' "$missing")"
      fi
    done
  fi
  echo; echo "→ Next: 'plan $repo' then 'scaffold $repo <dir>'. See docs/AI_CI_DEPLOYMENT.md."
}

plan() {
  local repo="$1"; local vis; vis="$(visibility "$repo" || echo '?')"
  hdr "Deployment plan — $repo ($vis)  @ $CI_TAG"
  cat <<EOF
  Deploy in dependency order (one PR per workflow or batch the content-checks):
   1. pre-commit           (needs .pre-commit-config.yaml)
   2. links, markdown-lint(report-only), labeler   (+ configs §4)
   3. secret-scan          (SKIP if repo ships own security.yml)
   3b. dep-scan, trivy-scan, sast-scan   (OPTIONAL own security scanners — PLAN-014;
       report-only; self-hosted even on PUBLIC (uniform-protected); no secrets needed;
       opt-in → pass them explicitly: scaffold $repo <dir> dep-scan trivy-scan sast-scan)
   4. audit-trail          (needs skip-audit-trail label)
   5. ai-review + composition   (needs 🔴 App+secrets+ 🟢 bot-id var)
   6. auto-merge-ai-prs    (inert without ai-review)
   7. doc-maintainer (dry-run)  (LiteLLM required; live-mode App is 🔴)
      docs-sync is legacy and should not be co-installed on new v2 adopters.
   8. codeql               (skip docs-only repos)
  Variant: $([ "$vis" = PRIVATE ] && echo 'PRIVATE → runner_labels ["self-hosted","ci-runner","single-use"]' || echo 'PUBLIC → ubuntu-latest')
  Each PR: branch-first · pin @$CI_TAG · CHANGELOG entry · OPS-0069 audit phrase · verify green.
  Gotchas: docs/AI_CI_DEPLOYMENT.md §5.  Verify: §6.  Arm: §7.
EOF
}

scaffold() {
  local repo="$1" dir="$2"; shift 2 || true
  local wfs="${*:-pre-commit links markdown-lint labeler secret-scan audit-trail ai-review composition auto-merge-ai-prs doc-maintainer}"
  # FAIL CLOSED: never guess PUBLIC — a private repo scaffolded as public gets
  # ubuntu-latest callers that queue forever (OPS-0049 policy). If visibility is
  # unreadable, stop rather than pick the unsafe variant.
  local vis; vis="$(visibility "$repo" || true)"
  [ -z "$vis" ] && { c_no "cannot read visibility for $repo (auth? name?). Refusing to guess PUBLIC — private repos MUST be self-hosted. Fix access or pass a repo you can 'gh repo view'."; return 1; }
  local suffix; [ "$vis" = PRIVATE ] && suffix=private || suffix=public
  mkdir -p "$dir/.github/workflows"
  hdr "Scaffolding into $dir  ($vis, @$CI_TAG)"
  for wf in $wfs; do
    local src=""
    if   [ -f "$TPL/workflows/$wf-$suffix.yml" ]; then src="$TPL/workflows/$wf-$suffix.yml"
    elif [ -f "$TPL/workflows/$wf.yml" ];         then src="$TPL/workflows/$wf.yml"
    else c_wn "$wf: no template — skipped"; continue; fi
    local dst="$dir/.github/workflows/$wf.yml"
    cp "$src" "$dst"
    # normalize pin to current tag
    sed -i "s#@ci/v[0-9.]*#@$CI_TAG#g" "$dst"
    # single-template repos: for PRIVATE inject runner_labels into EVERY job's
    # with: (handles multi-job links). Variant templates already bake in their
    # labels, and the injector re-checks that per job, so they are inert here.
    #
    # PLAN-018 F6 — markdown-lint runs the injector REGARDLESS of whether a
    # variant exists. Gating the whole block on `[ ! -f <variant> ]` gave new
    # PUBLIC adopters report-only (no markdown-lint-public.yml → injected) and
    # new PRIVATE adopters a blocking gate (markdown-lint-private.yml exists →
    # skipped), even though BOTH templates ship `fail-on-findings` commented out
    # and carry the same rollout recommendation in their headers. The asymmetry
    # was never intended — it was a side effect of which variant files happen to
    # exist.
    #
    # The fix stays in the WIZARD, not the template. Uncommenting
    # `fail-on-findings: false` in markdown-lint-private.yml would silently
    # downgrade live gates: business/iplanic/interlog deliberately carry
    # `fail-on-findings: true  # graduated to blocking (PLAN-007 W3)`, and the
    # caller is safe_to_replace, so `--update --non-interactive` would replace
    # them with a report-only canon template and turn three graduated blocking
    # gates back off with nobody asking. Graduating a repo stays a per-repo,
    # deliberate act (FT-11).
    if [ ! -f "$TPL/workflows/$wf-$suffix.yml" ] || [ "$wf" = markdown-lint ]; then
      python3 - "$dst" "$wf" "$vis" <<'PY'
import sys, re
d, wf, vis = sys.argv[1], sys.argv[2], sys.argv[3]
LBL = "      runner_labels: '[\"self-hosted\", \"ci-runner\", \"single-use\"]'"
FOF = "      fail-on-findings: false"
lines = open(d).read().split('\n')
out, i, in_jobs = [], 0, False
while i < len(lines):
    l = lines[i]
    if re.match(r'^jobs:\s*$', l): in_jobs = True; out.append(l); i += 1; continue
    if in_jobs and re.match(r'^  \S.*:\s*$', l):        # a job header (2-space indent)
        job = [l]; i += 1
        while i < len(lines) and not re.match(r'^  \S.*:\s*$', lines[i]) and not re.match(r'^\S', lines[i]):
            job.append(lines[i]); i += 1
        def active(key): return any(re.match(r'\s*'+key+r'\s*:', jl) and not jl.lstrip().startswith('#') for jl in job)
        adds = []
        # Skip injection when ANY runner-label input is already present — the
        # PLAN-013 single AI-flow templates (ai-review) use runner_labels_routine/
        # _review (NOT bare runner_labels), which are undeclared for a bare
        # `runner_labels:` inject → startup_failure. Match the whole family.
        has_labels = active('runner_labels') or active('runner_labels_routine') or active('runner_labels_review')
        if vis == 'PRIVATE' and not has_labels: adds.append(LBL)
        if wf == 'markdown-lint' and not active('fail-on-findings'): adds.append(FOF)
        if adds:
            widx = next((k for k, jl in enumerate(job) if re.match(r'^    with:\s*$', jl)), None)
            if widx is not None:                        # inject into existing with:
                for a in reversed(adds): job.insert(widx + 1, a)
            else:                                       # no with: — add one after uses:
                uidx = next((k for k, jl in enumerate(job) if re.match(r'^    uses:', jl)), None)
                if uidx is not None:
                    for off, a in enumerate(['    with:'] + adds): job.insert(uidx + 1 + off, a)
        out.extend(job); continue
    out.append(l); i += 1
open(d, 'w').write('\n'.join(out))
PY
    fi
    if python3 -c 'import sys,yaml;yaml.safe_load(open(sys.argv[1]))' "$dst" 2>/dev/null; then c_ok "$wf.yml"; else c_no "$wf.yml — INVALID YAML (or PyYAML not installed), inspect it"; fi
    if [ "$vis" = PRIVATE ] && [ ! -f "$TPL/workflows/$wf-$suffix.yml" ] && ! grep -qE '^\s*runner_labels(_routine|_review)?:' "$dst"; then
      c_wn "$wf.yml: PRIVATE repo but no runner_labels injected (job has no with: block) — add ci-runner + single-use labels manually per §5 item 1"
    fi
    if [ "$wf" = ai-review ] || [ "$wf" = composition ]; then
      grep -q '^permissions:' "$dst" || c_no "$wf.yml MISSING permissions block (would startup_failure) — check template"
    fi
  done
  # config files
  for pair in ".markdownlint.json:.markdownlint.json" ".lychee.toml:.lychee.toml" "docs-sync.json:.github/docs-sync.json" "doc-maintainer.json:.github/doc-maintainer.json" "doc-maintainer-conventions.md:.github/doc-maintainer-conventions.md"; do
    local from="${pair%%:*}" to="${pair##*:}"
    if [ -f "$TPL/$from" ]; then mkdir -p "$dir/$(dirname "$to")"; cp "$TPL/$from" "$dir/$to"; c_ok "config $to"; fi
  done
  case " $wfs " in
    *" ai-review "*|*" composition "*)
      mkdir -p "$dir/.github/ai-review"
      python3 - "$TPL/config.json.template" "$dir/.github/ai-review/config.json" "${repo%%/*}" <<'PY'
import pathlib, sys
source, destination, owner = sys.argv[1:]
text = pathlib.Path(source).read_text().replace("${CODEOWNER_HANDLE}", owner)
pathlib.Path(destination).write_text(text)
PY
      c_ok "config .github/ai-review/config.json"
      ;;
  esac
  cat <<EOF

  ⚠️  REVIEW before committing (docs/AI_CI_DEPLOYMENT.md §4-§5):
   - .markdownlint.json — DELETE it if the repo already has one (don't clobber).
   - .lychee.toml — add repo-specific cross-repo/sibling + debt excludes.
   - .github/labeler.yml — author it: map THIS repo's paths → THIS repo's labels.
   - set APP_REVIEWER_1_BOT_ID var (=$BOT_ID) if unset; ensure 🔴 App+secrets before ai-review.
  Then: branch-first, one PR per workflow, CHANGELOG + OPS-0069 phrase, verify (§6).
EOF
}

verify() {
  local repo="$1" pr="$2"
  hdr "Verifying ai-review + composition on $repo #$pr"
  local air_done=0
  for i in $(seq 1 24); do
    local air comp
    air="$($GH pr view "$pr" -R "$repo" --json statusCheckRollup -q '[.statusCheckRollup[]|select(.name|test("ai-review";"i"))|(.conclusion//.status)]|join(",")' 2>/dev/null || echo '')"
    comp="$($GH pr view "$pr" -R "$repo" --json statusCheckRollup -q '[.statusCheckRollup[]|select(.name|test("composition";"i"))|(.conclusion//.status)]|join(",")' 2>/dev/null || echo '')"
    local app; app="$($GH api "repos/$repo/pulls/$pr/reviews" --jq '[.[]|select(.user.type=="Bot")|.user.login+":"+.state]|join(",")' 2>/dev/null || echo '')"
    printf '  [%02d] ai-review=[%s] composition=[%s] app-review=[%s]\n' "$i" "$air" "$comp" "$app"
    # stop once ai-review + composition both conclude; also stop 2 polls after
    # ai-review concludes if no composition check exists (inert / not deployed).
    echo "$air" | grep -qE 'SUCCESS|FAILURE' && { air_done=$((air_done+1)); }
    echo "$air" | grep -qE 'SUCCESS|FAILURE' && echo "$comp" | grep -qE 'SUCCESS|FAILURE' && break
    [ "$air_done" -ge 3 ] && [ -z "$comp" ] && { echo "  (no composition check seen — inert bot-id, not deployed, or not yet triggered)"; break; }
    sleep 25
  done
  echo; echo "  Expect: ai-review SUCCESS + aidoc-reviewer[bot]:APPROVED + composition SUCCESS."
  echo "  If startup_failure → docs/AI_CI_DEPLOYMENT.md §5 (items 3,4,6) + §8."
}

audit_pins() {  # $@ = owner/repo… (default: the workspace fleet)
  local repos=("$@")
  [ ${#repos[@]} -eq 0 ] && repos=(vladm3105/aidoc-flow-operations vladm3105/aidoc-flow-framework \
    vladm3105/aidoc-flow-business vladm3105/aidoc-flow-iplanic vladm3105/aidoc-flow-interlog \
    vladm3105/aidoc-flow-engramory vladm3105/aidoc-flow-iplan-standard vladm3105/iplan-runner)
  GH="$GH" bash "$HERE/../sync/check-pin-currency.sh" --canon "$CI_TAG" --fleet "${repos[@]}"
}

case "${1:-help}" in
  preflight)  preflight "${2:?owner/repo}";;
  plan)       plan "${2:?owner/repo}";;
  scaffold)   scaffold "${2:?owner/repo}" "${3:?target dir}" "${@:4}";;
  verify)     verify "${2:?owner/repo}" "${3:?pr number}";;
  audit-pins) audit_pins "${@:2}";;
  *) sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; echo "  deploy-ci-wizard.sh audit-pins [owner/repo…]        # fleet pin-staleness audit";;
esac
