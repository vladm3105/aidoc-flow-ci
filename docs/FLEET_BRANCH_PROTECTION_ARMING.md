# Fleet branch-protection arming runbook (PLAN-007 W4)

Arm the canon CI gates as **required status checks** on each consumer repo's
`main`. This is the "make the gates load-bearing" step: today most gates run
but are advisory, so a red gate does not block a merge.

## Why the founder executes this (🔴 — not AI-autonomous)

Branch-protection changes are classified 🔴 across the workspace and are
**never executed by an AI agent under verbal/chat authorization**:

- Autonomy tiers (operations `CLAUDE.md`): "writes to other repos" = 🔴 Never
  autonomous.
- OPS-0062 exceptions: "branch protection rule changes surface for human review
  even if green; cross-repo ordering matters."
- Memory `feedback_writes_to_other_repos_inbox_first` (2026-07-09): verbal chat
  auth does not override the runbook requirement.

So this file is a **runbook the founder runs** (or explicitly authorizes an
agent to run, per-repo, with an audit-trail note). It is deliberately per-repo
and verification-gated because a wrong required-context **bricks the gate**: a
required check that never posts leaves every PR stuck on "Expected — waiting for
status to be reported," mergeable only via `--admin`.

## The core subtlety — arm the name the repo ACTUALLY emits

A required context must exactly match an emitted check-run name, or it never
turns green. Two things vary per repo:

1. **Canon vs standalone.** A repo consuming the canon reusable emits
   `call / <job>` (e.g. `call / Lint / format / security hooks`,
   `call / gitleaks`). A repo running its own standalone workflow emits the
   bare name (e.g. `Lint / format / security hooks`, `Secret scan (gitleaks)`).
   **Never assume** — a repo can mix both (operations runs standalone lint +
   secret AND canon ai-review + composition).
2. **Conditional runs.** A path-filtered check (composition often is) may not
   run on a PR that doesn't touch its trigger paths. Arming a check that does
   not post on every PR blocks the PRs that don't trigger it. **Verify the
   check posts on a trivial non-governance PR before arming it as required.**

The FT-2 regression guard (`tests/test_checknames.sh`) proves the
branch-protection *templates* only name real reusable jobs — but the templates
carry the canon `call / …` names; a repo on standalone workflows needs the bare
names instead. This runbook reconciles template ↔ per-repo reality.

## Current fleet state (survey 2026-07-12, read-only)

Legend: ✅ emitted green · ⚠ armed-but-suspect · ✗ armed-phantom (never green).

| Repo | Tier | Currently armed | Anomaly |
|---|---|---|---|
| framework | governance | `Lint / format / security hooks`✗, `Framework + platform conformance`✅, `call / composition`✅ | armed **bare** lint but emits `call / Lint …`; missing ai-review/verify (governance tier skips gitleaks per canon §2) |
| iplan-standard | governance | **none (unprotected)** | needs full protection |
| iplan-runner | product | own tests (Lint, Conformance, Engine tests, `Secret scan (gitleaks)`)✅ | canon `call / ai-review`=skipped, `call / gitleaks`=**failure** — incomplete canon adoption |
| engramory | product | **none (unprotected)** | needs full protection; clean canon adopter |
| operations | ops | `Lint / format / security hooks`✅(standalone), `Secret scan (gitleaks)`✅, `call / ai-review`✅, `call / composition`✅ | missing `call / verify` |
| business | ops | `call / ai-review`✅, `call / trust`✅, `Lint / format / security hooks`✗, `Secret scan (gitleaks)`✅ | armed **bare** lint but emits `call / Lint …`; missing composition/verify |
| iplanic | ops | `call / ai-review`✅, `call / trust`✅, `Lint / format / security hooks`✗, `Secret scan (gitleaks)`✅ | same bare-lint phantom; missing composition/verify |
| interlog | ops | `Secret scan (gitleaks)`✅, `call / verify`✅, `call / Lint / format / security hooks`✅, `call / ai-review`✅, `call / composition`⚠ | composition did **not** emit on latest PR — verify it runs before keeping armed |

> The ✗ phantom rows (framework, business, iplanic) mean those repos have very
> likely been merging via `--admin` — a real gate gap, not a cosmetic one. Fix
> the context name and the gate becomes load-bearing without `--admin`.

## Target required-contexts per repo

Only **report-blocking, reliably-green** checks are armed. `call / markdownlint`
is **report-only** (PLAN-007 W3) → never arm it. `call / Auto-label by path` is
informational → never arm it. `call / trust` is a prerequisite job (feeds
ai-review); **preserve it where a repo already arms it** (business, iplanic) so a
PATCH-replace doesn't silently de-arm it. Governance tier **omits gitleaks** as a
required check per canon §2 (`branch-protection-governance.json` has no gitleaks
context) even though those repos emit `call / gitleaks` green — do not arm it
there. A repo emitting BOTH `call / gitleaks` and standalone `Secret scan
(gitleaks)` (iplanic) arms only the one it already has (`Secret scan (gitleaks)`)
to minimize change.

| Repo | Target contexts |
|---|---|
| framework | `call / ai-review`, `call / composition`, `call / verify`, `call / Lint / format / security hooks`, `Framework + platform conformance` |
| iplan-standard | `call / ai-review`, `call / composition`, `call / verify`, `call / Lint / format / security hooks` |
| iplan-runner | `call / verify` (green + independent of the broken canon callers), `Lint / format / security hooks`, `Lint + types (ruff, mypy --strict)`, `Conformance (vectors + isolation + spec parity)`, `Secret scan (gitleaks)`, `Engine tests (claude / py3.11)`, `Engine tests (claude / py3.12)`, `Engine tests (hermes / py3.11)`, `Engine tests (hermes / py3.12)` — **do NOT arm** `call / ai-review`/`call / gitleaks`/`call / composition` until canon adoption is fixed (FT-12) |
| engramory | `call / ai-review`, `call / composition`, `call / verify`, `call / Lint / format / security hooks`, `call / gitleaks` |
| operations | `call / ai-review`, `call / composition`, `call / verify`, `Lint / format / security hooks`, `Secret scan (gitleaks)` |
| business | `call / ai-review`, `call / composition`, `call / verify`, `call / trust`, `call / Lint / format / security hooks`, `Secret scan (gitleaks)` |
| iplanic | `call / ai-review`, `call / composition`, `call / verify`, `call / trust`, `call / Lint / format / security hooks`, `Secret scan (gitleaks)` |
| interlog | `call / ai-review`, `call / verify`, `call / Lint / format / security hooks`, `Secret scan (gitleaks)` (+ `call / composition` **only after** verifying it posts on every PR) |

> **Governance repos + gitleaks:** because the governance template omits
> gitleaks, Step A for iplan-standard produces exactly the 4-context target above
> — no gitleaks row, matching this table. framework routes through Step B (its
> bespoke PATCH) with the 5 contexts listed. Neither governance repo arms
> `call / gitleaks`.

## Execution — one repo at a time, verify before proceeding

Do the two unprotected repos (iplan-standard, engramory — Step A) and one
step-B pilot per remaining tier (framework for governance, business for ops)
first; confirm a test PR merges on each; then roll out to the rest.

### A. Add protection to an unprotected repo (iplan-standard, engramory)

```bash
# governance tier → iplan-standard ; product tier → engramory
REPO=vladm3105/aidoc-flow-engramory
TPL=install/templates/branch-protection-product.json   # or -governance.json
# strip ALL underscore-prefixed keys — GitHub REST strictly rejects unknown fields
python3 -c "import json;d=json.load(open('$TPL'));json.dump({k:v for k,v in d.items() if not k.startswith('_')},open('/tmp/bp.json','w'))"
env -u GH_TOKEN gh api -X PUT repos/$REPO/branches/main/protection --input /tmp/bp.json \
  --jq '.required_status_checks.contexts'
```

### B. Correct contexts on an already-protected repo (framework, business, iplanic, operations)

PATCH with the `contexts[]` string-array **replaces** the full context list
(dropping the phantom bare-lint). This form is reliably supported by `gh -f`.
**Snapshot first** so the revert is self-contained:

```bash
REPO=vladm3105/aidoc-flow-business
env -u GH_TOKEN gh api repos/$REPO/branches/main/protection/required_status_checks \
  --jq '.contexts' > "/tmp/${REPO##*/}-contexts.backup.json"   # revert reference
env -u GH_TOKEN gh api -X PATCH repos/$REPO/branches/main/protection/required_status_checks \
  -F strict=false \
  -f 'contexts[]=call / ai-review' \
  -f 'contexts[]=call / composition' \
  -f 'contexts[]=call / verify' \
  -f 'contexts[]=call / Lint / format / security hooks' \
  -f 'contexts[]=Secret scan (gitleaks)' \
  --jq '.contexts'
```

### C. Verify (mandatory, per repo)

1. Open a **trivial, non-governance** PR (e.g. touch a comment in a code file so
   composition's path filter is exercised):
   `gh pr create -R $REPO -t "chore: arming verification" -b "verify required checks post"`.
2. Confirm **every** target context reports (not "Expected"): `gh pr checks <n> -R $REPO`.
3. Confirm `mergeStateStatus = CLEAN` **without** `--admin`:
   `gh pr view <n> -R $REPO --json mergeStateStatus,statusCheckRollup`.
4. If a context stays "Expected," it does not post on this PR → **remove it**
   (step D) and treat it as conditional; do not leave the gate bricked.
5. Merge the verification PR, then proceed to the next repo.

### D. Rollback

```bash
# remove one bad context: re-run the step-B PATCH without it.
# full revert (return repo to prior state):
env -u GH_TOKEN gh api -X DELETE repos/$REPO/branches/main/protection   # if it was unprotected before
```

## Follow-ups this surfaced (track in plans/FRAMEWORK-TODO.md)

- **iplan-runner canon adoption is broken** — `call / ai-review` skipped +
  `call / gitleaks` failing. Separate remediation before its canon gates can be
  armed. (Its own product checks are green and armable now.)
- **interlog composition conditionality** — confirm `call / composition` posts
  on every PR or reclassify it non-required.
- **`--admin` merge dependence** — framework/business/iplanic phantom contexts
  imply routine `--admin` bypass; arming the correct names removes the need.
