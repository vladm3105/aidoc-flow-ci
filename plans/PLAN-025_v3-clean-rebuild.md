# PLAN-025 — `ci/v3.0.0` clean rebuild: composite-action architecture + new documentation set

**Status:** Draft
**Owner:** canon (aidoc-flow-ci)
**Origin:** founder directive 2026-08-08 — implement the target configuration as a
new release built from scratch, archiving the existing flows so stale docs cannot
confuse adopters.
**Change level:** C3 (new major; every consumer surface changes)
**Supersedes:** PLAN-024 Phases D, E, F, G (absorbed here). PLAN-024 Phases A, B,
C ship **first and separately** — see §7.

## 1. Why a rebuild, and the one risk that governs it

The current library is 16 reusable workflows, 25 templates and a 2,700-line
rulebook accreted over ~2.16 releases. The founder's rationale is that
incremental edits leave stale documentation that misleads adopters, and the
measured evidence supports it: PLAN-024 found canon telling adopters to install a
flow being deleted, a rulebook section describing a superseded delivery model,
and three different template naming conventions in one directory.

**The governing risk: this library's apparent redundancy is mostly encoded
defect history.** PLAN-024 proposed removing structure four times — the
`-public`/`-private` pairs, the naming rule, a `python-tests.yml` reusable, and
the whole of Phase G — and independent review withdrew every one, because each
target was a fix for a measured failure. A from-scratch rebuild is the same error
at library scale, unless it is explicitly a **port against an inventory**.

**Therefore the rule for this plan: §2 is the acceptance criterion.** No rebuilt
artifact ships until every defense in §2 is either carried forward or has a
written reason for being dropped. "We rewrote it and it looks cleaner" is not a
reason.

## 2. Defense inventory — carry or consciously drop, never silently lose

Each row is a defect this library already paid for. The rebuild must state, per
row, **carried** or **dropped + why**.

> **P1 SIGNED OFF 2026-08-08 — all 19 defenses CARRIED, none dropped.**
> The rebuild changes **packaging** (reusable workflow → composite action) and
> **job count**, not defenses. That is the finding: nothing in the current
> library was found to be safely droppable, which is consistent with PLAN-024's
> four withdrawals. Two rows gained sharper meaning under the new architecture:
>
> - **D7 binds `quick-gates`.** It runs `pre-commit` against the PR's own files,
>   which is fork-code execution — so on a public repo `quick-gates` **must** be
>   `ubuntu-latest`. Only `security` and `ai-review` may take the self-hosted
>   pool there.
> - **D1 therefore still applies.** Because `quick-gates` and `security` want
>   different runner labels by visibility, the v3 callers still need
>   `-public`/`-private` variants, or `install.sh --update` re-creates the
>   queue-forever defect on private consumers.

| # | Encoded defense | What it prevents | Cite |
| --- | --- | --- | --- |
| D1 | `-public`/`-private` template variants | `install.sh --update` re-applies the label-less generic → private jobs queue forever | Claim 1 |
| D2 | Literal template names in `install.sh` (never derived) | Canon ships three naming shapes; derivation is wrong for at least one | Claim 2 |
| D3 | CI-0025 / §23 concurrency **allowlist** (not blanket cancel) | A cancelled required context is not success; the rollup stays FAILURE and the PR is `--admin`-only | Claim 3 |
| D4 | Job **id** is the required-context name | Renaming silently un-satisfies branch protection, which never fires again | Claim 4 |
| D5 | SHA-pinned `uses:` and pre-commit `rev`s | A moved tag reaches the whole fleet in one CI cycle; pre-commit runs the upstream build backend at install time | Claim 5 |
| D6 | ai-review verdict step `FATAL=1` (fail closed) | A reviewer-infrastructure failure must not render a green required check | Claim 6 |
| D7 | Fork-code-executing flows stay `ubuntu-latest` on public repos | Untrusted PR code on the self-hosted pool | Claim 7 |
| D8 | `gitleaks git`, not `gitleaks dir` | Working-tree-only scanning misses history (CI-0016) | Claim 8 |
| D9 | Callee `permissions:` are an intersection ceiling | A callee capped at `read` can never be raised by a caller; the step dies under `pipefail` (CI-0015) | Claim 9 |
| D10 | Hook-block marker version as refresh key | An adopted consumer freezes forever; canon changes never reach it | Claim 10 |
| D11 | Commit-stage hooks must exist in the fragment | Otherwise `--all-files` matches zero hooks and the required check "exited 0 while inspecting nothing" | Claim 11 |
| D12 | `dep-scan` zero-coverage guard | A scanner that finds no manifests must fail loud, not report clean | Claim 12 |
| D13 | Own scanners are MUST-HAVE (founder, PLAN-014) | Deleting them cancels a founder-owned graduation step | Claim 13 |
| D14 | `fail-on-findings` is a *default*, and the flow honours it with `exit 1` | Treating report-only as "cannot fail" | Claim 14 |
| D15 | Implicit `bash -e` in every `run:` step | `set -e` kills a step at the first non-zero, before a guard can forgive it | Claim 15 |
| D16 | `timeout-minutes` does not save a **queued** job | The clock starts when the job starts | Claim 16 |
| D17 | Actions Runner `>= 2.327.1` floor | node24 actions die with an error naming neither the action nor the floor | Claim 17 |
| D18 | LiteLLM at the docker bridge, not loopback | Loopback resolves to the container; works on the host, fails only in CI (CI-0017) | Claim 18 |
| D19 | Live branch protection ≠ the templates | Canon's `main` requires `call / markdownlint` and `suite`, which appear in no template | §3 below |

**D19 is new to this plan and was the defect that killed PLAN-024 Phase G.** Every
step of this rebuild that touches a required context reads
`gh api repos/<r>/branches/<b>/protection` **and `gh api repos/<r>/rulesets`** —
never the templates. Rulesets are a separate aggregating surface that
`apply-standards.sh` never touches, and repo admins are not ruleset bypass actors
unless listed, so a ruleset-required context has no `--admin` escape (Claim 40).

### 2a. Added 2026-08-08 after independent review — §2 was ~20 rows short

The first cut of §2 was assembled from PLAN-024's ledger, which covered the
*packaging* defenses. Review found that the **scanner and gate bodies** carry a
second, larger family of defenses that no row named. Because §4.4 makes §2 the
acceptance test for `RULES.md` too, each of these would have been dropped from
the port checklist *and* the rulebook.

| # | Encoded defense | What it prevents | Cite |
| --- | --- | --- | --- |
| D20 | SHA-256 verify every downloaded tool binary before executing it | A substituted release tarball executes on the runner. D5 covers `uses:` pins only, not curl'd binaries | Claim 22 |
| D21 | Allowed-actions policy: only `actions/*`, `github/*`, `vladm3105/*`; `verified_allowed: false` | A marketplace action is a `startup_failure` with a web-UI-only message `actionlint` cannot catch. **This is why the checks are 100-line `run:` bodies and not thin wrappers** — the single biggest constraint on how a v3 action may be written | Claims 23, 24 |
| D22 | `secret-scan` config canary | A consumer `.gitleaks.toml` with an `[allowlist]` but no rules scans nothing and exits 0 — a green required check that scanned nothing. Plants a credential at a randomized path (a fixed one could be allowlisted away) | Claim 25 |
| D23 | `sast-scan` strips PR-supplied `.semgrepignore`/`.semgreprc` | A PR committing `.semgrepignore: *` is a **verified full SAST-gate bypass**. The gate, not the scanned PR, decides coverage | Claim 26 |
| D24 | `dep-scan` passes `--no-call-analysis=all` | osv-scanner's Go call-analysis is **on by default** and compiles source — arbitrary code execution at scan time on the self-hosted pool | Claim 27 |
| D25 | `trivy` restricted to `dockerfile,kubernetes,cloudformation,azure-arm` | terraform/helm fetch PR-controlled remote sources; a `.tf` `module { source = "https://…" }` makes the runner clone an attacker-chosen URL. `--tf-exclude-downloaded-modules` does **not** prevent the fetch | Claim 28 |
| D26 | `semgrep` uses an explicit `--config`, never repo-local auto-discovery; `--metrics off` | A PR injecting its own rules; telemetry from private repos | Claim 29 |
| D27 | Scanner fork guard is a **job-level** `if: head.repo.fork != true` | Keeps fork code off the self-hosted pool. **Distinct from D7** — that is the runner-label half; this is the admission half, and a composite action cannot express it (§3.2a) | Claim 30 |
| D28 | audit-trail identity: GitHub's `pull_request.user.type`/`.login`, never commit `%an` | `%an` is attacker-spoofable on fork PRs | Claim 31 |
| D29 | audit-trail **ordering**: the bot exemption runs before the fetch/cat-file guard | An unreachable `BASE_SHA` must not fail a PR the gate would have exempted outright | Claim 31 |
| D30 | audit-trail fails loud on an unreachable `BASE_SHA`/`HEAD_SHA` | "Silent PASS on unreachable BASE_SHA was the load-bearing failure mode this workflow exists to prevent" | Claim 32 |
| D31 | audit-trail's job-level `if:` refuses any event but `pull_request` | Pairing a PR-HEAD checkout with `pull_request_target`'s privileged context is the classic untrusted-checkout RCE | Claim 33 |
| D32 | The caller's `types: [… labeled, unlabeled]` | Without them, applying the escape-hatch label fires no event, the check never re-runs, and the operator is told to apply a label that cannot take effect | Claim 34 |
| D33 | Two-signal override: label **and** body marker, `jq` exact-array membership | `skip-audit-trail-later` must not substring-match | Claim 31 |
| D34 | `--redact` on gitleaks output | The scanner's own logs leaking the secret it found | Claim 35 |
| D35 | SARIF upload is best-effort: `continue-on-error` + a fork `if:` | A private repo without GHAS 403s; `security-events: write` is downgraded on fork PRs. **The gate is the scan step; the upload must never fail the job** | Claim 36 |
| D36 | `persist-credentials: false` everywhere **except** audit-trail | audit-trail runs `git fetch --no-tags origin "$BASE_SHA"` and needs the credential. The asymmetry is deliberate, and inverting it reds the check on private consumers | Claim 37 |
| D37 | The zero-hook detector (`check-precommit-hooks.sh`) | D11 states the rule; this is the **detector** that enforces it — and P4 rewrites the very file it inspects | Claim 38 |
| D38 | `lychee` must be the **musl** static build | The gnu build needs GLIBC 2.38+ and fails on older Debian ephemeral runners. Same class as D17 | Claim 39 |
| D39 | Required-context → producer derivation (FT-18/FT-45) | Arming a required context nothing produces pins every PR forever. **v3 breaks the tool that does this** — see P8 | Claim 41 |
| D40 | Rulesets are a second required-check surface | `apply-standards.sh` never touches them and admins are not bypass actors unless listed | Claim 40 |
| D41 | CI-0021 targeted break-glass; CI-0023 "a fail-closed guard fails on faults, not on shapes" | CI-0014: an ai-review outage normalised `--admin` across seven repos for ~9 days | Claims 42, 43 |

| D42 | The links internal/external split: offline+blocking on PRs, external+report-only weekly | External link rot is TIME-based, so blocking a PR on a third party's 429 is a false signal — but the check must still run. **This row was missing, and its absence produced two code defects**: the ported action defaulted to `external` and to a config path canon does not install, so the required PR gate would have made live network calls with the consumer's tolerance profile silently dropped | Claim 46 |
| D43 | VERSION single-source pin discipline, and its `sync-version-refs:ignore` escape | `--check` is a **default-stage, always_run** pre-commit hook, so it gates every commit *and* canon's `call / Lint / format / security hooks`. A template pinning a tag that is not `VERSION` reds the branch — and the rewriter's suggested remedy points the pin at a tag where the target does not exist. Forward references need the markers (PLAN-004 BL-4, then CI-0024). **This row's absence made the branch red; see the Pass 4 log** | Claim 49 |
| D44 | The F1 completeness guard (`tests/test_exerciser_inventory.sh`) | It derives its surface set from `manifest.json`, `workflow_call` reusables and `install\|scripts\|sync/*.sh`. **`actions/*/action.yml` is a new surface class it is structurally blind to** — exactly as the hook-block fragment was, which had to be named explicitly. P8 must add it, or v3's largest new surface is invisible to the completeness check | Claim 50 |
| D45 | Per-check arming granularity — the staged-adoption ladder | A repo can arm `call / Lint / format / security hooks` while leaving `call / markdownlint` unarmed, which is the documented way a repo with existing markdown debt adopts *without bricking merges*. **Fusing three checks into one required context removes that ladder.** §6 says consolidation reduces jobs not coverage — true, but it does reduce *adoption granularity*, and P7 must handle repos that today arm a subset | Claim 51 |
| D46 | The lychee cache (`actions/cache` restore + save, `if: always()`) | A documented design decision in the v2 reusable. The port kept `--cache --max-cache-age 1d` but dropped both cache steps, so the flag is a per-run no-op. Performance only — but an undocumented deviation under a plan whose §1 rests on verbatim porting is exactly what §2 exists to prevent | Claim 52 |

**All 23 CARRIED. None dropped.** D21 and D27 additionally constrain the
architecture and are answered in §3.2a.

**Three rows corrected 2026-08-08 after review flagged them as overstated —
an overstated defense becomes a `RULES.md` rule canon itself violates:**

- **D20** says "every downloaded tool binary". Scope it to **curl'd release
  artifacts**: `semgrep` is a version-pinned `pip install` and
  `markdownlint-cli2` a version-pinned `npm install`, neither checksum-verified,
  and pretending otherwise makes the rule immediately false.
- **D36** says `persist-credentials: false` everywhere *except* audit-trail.
  `standards-drift-self.yml` also checks out with no `with:` block at all. The
  rule is "omit it only where a later step needs the credential, and say why" —
  not "audit-trail is the sole exception".
- **D37** calls `check-precommit-hooks.sh` a detector that *enforces*. It is
  **advisory, not fatal** — it warns. It surfaces the D11 condition; it does not
  prevent it. P4 must decide whether v3 promotes it to fatal, since P4 rewrites
  the file it inspects.

**Two decisions still owed a row, recorded so the next pass starts from them:**
CI-0026 (*a fail-closed guard that cannot fail open is only a cost*) is the
direct counterweight to §3.2c's verdict step and is folded there rather than as
a row; and CI-0007 defers a runner-label rename **to a future major** — v3 *is*
that major, and §3.2e now bakes the current labels into a file shipped to ten
repos, so that deferral needs an explicit take-it-or-leave-it in P8.

## 3. Target architecture

### 3.1 The lever: composite actions

Canon currently ships **zero composite actions** — every check is a
`workflow_call` reusable, and a reusable always gets its own runner. That is the
root of the provisioning cost: on `operations`, `audit-trail` takes ~167s to run
a `grep`, almost entirely provisioning.

| Mechanism | Runner cost |
| --- | --- |
| Reusable workflow (16× today) | one runner per check |
| Composite action | shares the caller's runner |

The rebuild ships the lightweight checks as **composite actions** and keeps
reusable workflows only where a separate runner, a separate permission set or a
separate trust boundary is actually required.

### 3.2 CI: 12 PR jobs → 6

**Restated as the folds landed — the count moved 4 → 5 → 6.** Only checks
sharing a **trigger** can share a job. `composition` fires on
`pull_request_review` + `workflow_run`, never `pull_request` (Claim 21), so it
**cannot** join `quick-gates` and stays its own workflow. An earlier draft of
this table listed it inside `quick-gates`; that was wrong.

**This table is the CURRENT one. 12 → 6 PR jobs.** It was restated twice as the
folds landed (4, then 5, then 6); §3.2d records why each move happened, and any
"→ 4" or "→ 5" elsewhere in this document is superseded by this table.

| Job | Runs | Trigger | Required context |
| --- | --- | --- | --- |
| `quick-gates` | pre-commit `--all-files`, markdownlint (cli2), links (internal/offline) | `pull_request` | `quick-gates` |
| `scanners` | osv-scanner, trivy, semgrep — self-hosted, fork-guarded | `pull_request` | `scanners` |
| `secret-scan` | gitleaks (full history) — `ubuntu-latest`, **fork-visible** | `pull_request` | `call / gitleaks` *(unchanged)* |
| `audit-trail` | OPS-0069 phrase check — needs its own `types:` (D32) and event refusal (D31) | `pull_request` + label types | `call / verify` *(unchanged)* |
| `composition` | unchanged — different trigger, cannot consolidate | `pull_request_review`, `workflow_run` | `call / composition` |
| `ai-review` | unchanged — separate runner, own trust gate | `pull_request_target` | `call / ai-review` |
| `auto-merge` | unchanged — event-driven, no PR cost | `workflow_run` | none |

Only **two** contexts are new (`quick-gates`, `scanners`), so P7's irreversible
migration touches two names, not five. `secret-scan`, `audit-trail`,
`composition` and `ai-review` keep their existing contexts and need **no P7
step at all** — which is a large reduction in the risk P7 carries.

**Checkout is the caller's — and "strictest consumer" was the WRONG rule.**
Corrected 2026-08-08; the paragraph here previously mandated `fetch-depth: 0` at
`github.event.pull_request.head.sha`, and P2 would have been implemented from
it.

On `pull_request` the default checkout ref is the **merge commit**, which is what
the v2 `pre-commit`, `markdown-lint` and `links` reusables lint. Pinning
`head.sha` lints the branch **tip** instead — so a PR whose merge result is dirty
but whose tip is clean goes green. That is weaker, not stricter. `audit-trail`
was the only check that genuinely needed the head SHA and full history, and
§3.2d removes it from this job, so the requirement leaves with it.

**The shipped caller therefore takes the DEFAULT ref and no `fetch-depth`**, and
`tests/test_actions.sh` asserts the `head.sha` pin is *absent*. Three actions
share that one checkout, not four.

**Each action must still verify the precondition it depends on and fail loudly
if unmet**, rather than assume it: a job that checked out nothing would leave
every tool matching zero files and exiting 0 — a green required check that
inspected nothing, which is the D11/D22 shape re-created by consolidation.

`links` also carries a `schedule` trigger. That is unaffected — the scheduled
caller invokes the same composite action in its own small workflow.

### 3.2a What composite packaging CANNOT express — and the disposition for each

A composite action has no job of its own. It therefore cannot carry
`permissions:`, `concurrency:`, `timeout-minutes`, a job-level `if:`, or the
`secrets` context, and `continue-on-error` on its steps is undocumented. Each
ported check depends on at least one of these. **Resolved, not deferred:**

| Constraint | Affected | Disposition |
| --- | --- | --- |
| **Job-level `if:`** | D27 scanner fork guard; D31 audit-trail's event refusal | **Moves to the CALLER's job `if:`, never to a step.** A step-level skip runs *after* the job has already checked the fork's code out, which converts an admission guard into a no-op. The caller must therefore carry the guard, and `tests/` must assert it is present — a defense that moved to a file nothing checks is a defense that was dropped. |
| **`permissions:`** | Every check (D9) | One grant per job, and for `security` it is the **union** of four. §2 marks D9 carried; **structurally it is weakened** and this plan accepts that explicitly: the four scanners already run on the same trust boundary, same pool, same event. It is not acceptable for `quick-gates`, which stays `contents: read` — no ported check there needs more. |
| **`timeout-minutes`** | All | See §3.2b. |
| **`secrets` context** | `links` passes `GITHUB_TOKEN` to lychee for github.com rate limits | The action takes it as an **input**; the caller passes `${{ secrets.GITHUB_TOKEN }}`. `quick-gates.yml` currently passes nothing — a defect on the branch (§6a). |
| **`continue-on-error`** | D35, four SARIF uploads | **Must be verified on the target runner before P2 ships a scanner action.** If unsupported, a private consumer without GHAS turns a documented no-op 403 into a hard red on every PR. Until verified, the SARIF upload stays in a **caller step**, not inside the action. |
| **Marketplace `uses:` (D21)** | All | Unchanged — the allowlist admits `vladm3105/aidoc-flow-ci/actions/*`, so the new packaging is itself permitted, but the bodies must stay hand-rolled `run:` blocks. No action may introduce a marketplace `uses:`; `tests/` asserts owner, not just SHA-pinning. |

### 3.2b Timeouts: four budgets collapse into one, and the first number shipped was too small

v2 per-check: `pre-commit` 15, `markdown-lint` 10, `links` **20**, `audit-trail`
10. The branch shipped `quick-gates` at `timeout-minutes: 15` — **below the 20
`links` needs**, so a legitimately slow lychee run would kill the whole job
including the three checks that already passed.

**Rule: a consolidated job's timeout is the SUM of the checks it absorbs, not the
max and never a round number picked by eye.**

**Numbers corrected 2026-08-08** — the first version said 55 and 65, which
predated §3.2d (audit-trail, 10, split out) and P3a (`secret-scan`, 15, split
out). Current:

| Job | Absorbs | Ceiling |
| --- | --- | --- |
| `quick-gates` | pre-commit 15 + markdownlint 10 + links 20 | **45** |
| `scanners` | dep-scan 15 + sast-scan 20 + trivy 15 | **50** |

**And the "a high ceiling costs nothing" claim was wrong on the pool.**
Concurrency is one job per supervisor instance, so a hung `quick-gates` holds a
slot for 45 minutes and serialises the rest of the PR behind it. Summing is
still right for the *job* ceiling — a job-level number below any single check
kills work that already passed — but it does not restore the four per-check
budgets, and the job ceiling is now the only thing catching a hang.

**Consequence to carry into P2:** each action should wrap its long-running
command in `timeout <n>` so a single hung tool fails that check rather than
consuming the whole job's budget. Not yet implemented.

*(D16 does not undercut any of this. D16 is about jobs that never start; a
ceiling cannot fire on a queued job. This is about jobs that run.)*

### 3.2c Failure sequencing: a composite step failure aborts the job

In v2's job-per-check model every verdict arrives together. Consolidated, one
markdownlint error means the PR never learns its links are broken — and under
§3.4's graduation the first blocking scanner prevents the other three from
running or uploading SARIF.

**Corrected 2026-08-08 — the first version of this was not implementable, and
the shipped actions do the opposite of what it said.** It proposed that each
action "record its verdict and return success". That would require rewriting
every ported body to swallow its own exit — contradicting the verbatim-port
principle §1 rests on — and it still could not cover an infrastructure failure
in an action's *install* step (`npm install`, `pip install`, the lychee curl),
which aborts before any verdict could be written.

**Decision: collect at the CALLER, not inside the actions.** Each `uses:` step
takes an `id:` and `continue-on-error: true`; a final step with `if: always()`
reads `steps.<id>.outcome` and fails the job if any is `failure`. The action
bodies stay verbatim.

Two constraints on that shape, both load-bearing:

- **`continue-on-error` is supported on a job step**, which is where this puts
  it. §3.2a defers it *inside* a composite action as unverified — these are not
  the same surface, and the distinction is what makes this implementable.
- **The verdict step must fail closed** (D6, and CI-0026: *a fail-closed guard
  that cannot fail open is only a cost*). An `outcome` that is neither `success`
  nor `failure` — `cancelled`, or a step that never ran — must fail, not pass.
  `skipped` in particular must fail here, because a skipped *job* satisfies a
  required context (P3a) and the same reasoning applied to a step would launder
  a crash into a green gate.

**Not yet implemented.** The shipped `quick-gates` has no `id:`/verdict step, so
today a `pre-commit` failure still hides markdownlint and links. Tracked as the
next P3 task, not as done.

### 3.2e A new distribution artifact: `.github/actionlint.yaml`

Found while building the private variant. Under v2 a private caller **never
named a runner label directly** — it passed a JSON *string* input and the
reusable did the `fromJSON`, so actionlint only ever saw an expression and had
nothing to validate.

v3 callers carry a literal `runs-on: ["self-hosted","ci-runner","single-use"]`,
because a composite action runs in the caller's job. actionlint's `runner-label`
rule rejects any label it does not know, and canon ships no config — so **every
private v3 caller fails the lint**: canon's own `test_lint.sh`,
`pre_push_check.sh` check 3 on every consumer, and any consumer's own actionlint.

`.github/actionlint.yaml` declaring `ci-runner` and `single-use` fixes it, and
**must ship to consumers**: `scripts/pre_push_check.sh` actionlints every
installed `.github/workflows/*.yml` on every consumer push, and actionlint
resolves its config from the consumer's own project root — so without the file
there, every private consumer's pre-push hook fails on its own quick-gates.

**Shipping it needs a source path, which the first draft omitted.**
`install.sh` fetches from `install/templates/`, so every shipped dotfile has a
template copy (`.lychee.toml`, `.markdownlint.json` both do). P8 must create
`install/templates/actionlint.yaml` mapped to consumer path
`.github/actionlint.yaml`, and accept the second-copy drift risk that
`scripts/pre_push_check.sh` ↔ `install/templates/pre_push_check.sh` already has.

Note the file declares labels; it does not create runners. A job whose labels
match no registered runner queues forever and `timeout-minutes` cannot save it
(D16), so the list must stay in step with what is actually registered.

### 3.2d The `types:` conflict — resolved by splitting audit-trail back out

`audit-trail` needs `types: [opened, synchronize, reopened, labeled, unlabeled]`
for its D32 escape hatch. The other three want the default types, because
`ai-review`/`labeler`/`auto-merge` toggle labels routinely and re-running lint on
every label write burns runner minutes for no signal. **No single `types:`
satisfies both.**

**`audit-trail` therefore stays its own workflow.** It is a `grep` over a commit
range — the cheapest check in the set — and it carries the most trigger-specific
requirements (D31, D32) plus the D36 credential asymmetry. Consolidating it buys
one provisioning cycle and costs three defenses.

**The split is MANDATORY, not an economy — and the runner-minutes argument above
is the weaker reason.** Stated 2026-08-08 after review, because as first written
this section invited someone to reverse the decision later on cost grounds.

Adding `labeled`/`unlabeled` to a consolidated job whose `if:` skips those events
makes the job report **`skipped`** — and P3a establishes that a skipped job
**satisfies** a required context. So a red `quick-gates` could be laundered green
by applying any label to the PR. That is not a cost trade-off; it is a gate
bypass reachable by anyone who can label.

**Revised target: `quick-gates` = pre-commit + markdownlint + links.**
**12 → 6 jobs**, not 5 and not 4. Each successive count has moved in the same
direction as review found constraints; that is the estimate converging, and it
is recorded here rather than smoothed over.

Off the PR path: `codeql` (push-to-main + weekly only — report-only and
GitHub-native), `standards-drift` (weekly), `docs-sync` (post-merge),
`labeler` (event-driven).

**Also drop the redundant `push: branches: [main]` trigger** wherever a flow also
runs on `pull_request`: under squash-merge those scan identical content minutes
apart.

### 3.3 Local: comprehensive and fail-closed

**Commit stage:** `check-yaml`, `check-json`, `check-toml`, `end-of-file-fixer`,
`trailing-whitespace`, `check-merge-conflict`, `check-added-large-files`,
`mixed-line-ending`, `detect-private-key`, **`markdownlint-cli2`**, `yamllint`,
`actionlint`, `shellcheck`, `ruff` + `ruff-format`, `gitleaks` (working tree).

**Pre-push:** `pre_push_check.sh`, `bandit`, audit-trail phrase.

Two rules that make the local layer real rather than decorative:

1. **Fail closed on a missing tool.** Today checks 1–4 of `pre_push_check.sh`
   "skip with notice", so the layer silently evaporates on a machine without
   `actionlint`. Hard-fail with an install hint instead.
2. **Tool parity is mandatory.** Local markdownlint must be **cli2 with canon's
   `.markdownlint.json`** — the ecosystem's usual hook is cli1, with different
   ignore semantics. A mismatch means local passes and CI reds, which trains
   people to bypass hooks.

### 3.4 Security posture

- The three own scanners **graduate to `fail-on-findings: true`** (PLAN-014
  Phase 5 — a founder step, and the single largest security gain available).
- `gitleaks` gains a local working-tree pass; CI keeps full history (D8).
- **`actionlint` becomes enforced** — it currently has no enforcement anywhere,
  in a library whose product is GitHub workflows.
- `bandit` runs pre-push, before code leaves the machine.
- `ai-review` unchanged.

Net: ~12 checks (three unable to fail) → **~20 checks, all able to fail**, on
**6 PR jobs instead of 12** (§3.2 table — this said 4 before the §3.2d and P3a splits).

## 4. Documentation set

### 4.1 New

A rebuilt set, written for an adopter who has never seen v2:

| Doc | Replaces |
| --- | --- |
| `docs/v3/ARCHITECTURE.md` | `architecture.md`, parts of `WORKFLOWS.md` |
| `docs/v3/ADOPT.md` | `AI_CI_DEPLOYMENT.md`, `install/README.md`, `UPDATE_GUIDE.md` |
| `docs/v3/FLOWS.md` | `WORKFLOWS.md` — the 4-job model and every composite action |
| `docs/v3/LOCAL.md` | *(new — the local layer has no doc today)* |
| `docs/v3/SECURITY.md` | `security.md` |
| `docs/v3/RUNNERS.md` | `runners.md` |
| `docs/v3/RULES.md` | `REPO_STANDARDS.md`, re-derived against the v3 surface |
| `docs/MIGRATION_v3.0.0.md` | *(new — required by the release checklist for a MAJOR)* |

### 4.2 Archived, not deleted

v2 docs move to `docs/v2/` with a banner: *"Describes `ci/v2.x`. The current
release is `ci/v3.x` — see `docs/v3/`."* They stay because ten repos remain
pinned to v2 tags until they migrate, and a v2 adopter debugging a v2 pin needs
v2 docs.

### 4.3 Untouchable — append-only

**`CHANGELOG.md`, `DECISIONS.md`, `docs/MIGRATION_v2.0.0.md` are history and are
never rewritten, reordered or scrubbed.** They are the only surviving record of
why the §2 defenses exist. Correct anything wrong in them with a new dated entry.
A rebuild that scrubs them destroys the evidence that makes §2 auditable.

### 4.4 The rulebook is re-derived, not copied

`REPO_STANDARDS.md` is 2,700 lines, much of it incident narrative attached to
rules. `docs/v3/RULES.md` states each **rule** with a one-line cause and a link
into `DECISIONS.md`/`CHANGELOG.md` for the incident. **Every §2 row must appear
as a rule.** That mapping is the acceptance test for §4.4.

## 5. Phases

**P1 — Defense inventory sign-off.** Complete §2: for each row, carried or
dropped-with-reason. **Nothing is built before this is signed off.** It is the
plan's whole safeguard against repeating PLAN-024's four withdrawals.

**P2 — Composite actions.** Build `actions/<name>/action.yml` for each
lightweight check. Each carries its §2 defenses (D5 pinning, D15 `bash -e`,
D3 where it owns concurrency). Unit-test via `tests/`.

**P3 — The four callers.** `quick-gates`, `security`, `ai-review`, `auto-merge`
as templates. D3's allowlist and D4's job-id discipline apply to every one.

**P4 — Local layer.** New hook block, marker bumped (D10), fail-closed
`pre_push_check.sh`, cli2 parity. **Ships before P5** — the local layer must be
in place before CI consolidation changes what adopters rely on.

**P3a — `security` splits in two. It is not a valid single job.** Three
independent conflicts, all found in review:

- **Runner class.** `secret-scan` defaults to `ubuntu-latest`; the other three
  default to the self-hosted pool as *uniform protected* (PLAN-014 §1a). One job
  has one `runs-on`.
- **Fork posture, and this is the disqualifier.** `secret-scan` deliberately runs
  on fork PRs — it MUST see the PR's code. The other three deliberately skip
  them (D27). If a merged `security` job took the pool it would need a fork
  guard, and **a skipped job reports `skipped`, which branch protection treats as
  satisfying a required context** — so `security` would go green on every
  fork PR with gitleaks never having run. That is the "green required check that
  scanned nothing" class D22 exists to prevent, re-created by the consolidation
  meant to be safe.
- **OPS-0049.** Keeping the three on `ubuntu-latest` instead makes private
  consumers pay GitHub-hosted minutes.

**Therefore:** `secret-scan` stays its own job on `ubuntu-latest`, fork-visible,
keeping its `call / gitleaks` context unchanged — no migration, no risk. The
three self-hosted scanners consolidate into `scanners`, fork-guarded at
the job level (§3.2a).

**P5 — Documentation set.** §4, including the §2→RULES mapping.

**P8 — Tooling and distribution. Canon has never shipped a composite action, and
nothing in the toolchain knows about them.** This is a phase the first draft
omitted entirely; without it v3 cannot be installed, updated, drift-checked or
context-mapped.

- **`install/required-context-map.py` — and the failure mode is BACKWARDS from
  what this plan first claimed, in the reassuring direction.** It considers only
  workflows declaring `workflow_call` and matches a caller's **job-level**
  `uses:` (Claim 41). The first draft said a v3 context "resolves to `?` … and
  fails". It does not: the tool classifies any context without `" / "` as
  `?non-call`, and `tests/test_required_contexts.sh` treats `?non-call` as a
  **PASS** — "no canon producer expected" (Claim 45).

  So every bare v3 context resolves **green and unvalidated**, and
  **P7 step 5 — the step whose entire purpose is catching a context armed
  against nothing — catches nothing.** A tool that reports success on the case it
  exists to detect is worse than no tool: P7 would read as verified.

  Teach it that a plain job emits its job name, and that a repo's armed contexts
  must each map to a producer *whatever their shape*.
- **`tests/test_checknames.sh`** builds its emitted-name set the same way, and
  its `case` **`continue`s on every context that is not `call / …`** — so it
  validates zero v3 contexts, not merely the three it hardcodes (`call / verify`,
  `call / Lint / format / security hooks`, `call / gitleaks`). Both the skip and
  the hardcoding need fixing.
- **`manifest.json`** has no schema for an `actions/` surface, and every v3
  caller needs `path`/`template`/`visibility_variants`/`safe_to_replace`/
  `auto_install`. **`quick-gates.yml` is unmanifested today** — the exact defect
  the manifest itself records for audit-trail, which "shipped as a template but
  NOT manifested until 2026-07-16, so manifest-driven tooling skipped it
  entirely."
- **`tests/test_lint.sh`** yamllints and actionlints `.github/workflows/` and
  `install/templates/workflows/` only. P2 moves the majority of canon's shell
  into `actions/*/action.yml`, **where none of the three linters reach it** —
  while §3.4 makes "actionlint becomes enforced" a headline of v3. Extend the
  globs; note actionlint does not validate `action.yml` as a workflow, so the
  embedded-shell delegation needs a different invocation.
- **`scripts/sync-version-refs.sh`** rewrites every `uses: …@ci/vX.Y.Z` in
  `install/templates/workflows/*.yml` to the `VERSION` value, so a v2 patch cut
  while v3 templates sit in-tree rewrites their `@ci/v3.0.0` pins to the v2 tag.
  (`--repin`'s regexes *do* match `…/actions/x@ci/v…`, so re-pinning composites
  works — that half is fine.)
- **`install/deploy-ci-wizard.sh`** is the adoption surface and gets no mention.
- **`auto_install`** currently marks `pre-commit.yml` as the bootstrap tier's
  only gate; folding it into `quick-gates` moves that flag.

**P9 — Rollback.** P7 is irreversible per repo and has no stated undo. Define
one: the v2 tag remains, the v2 callers are deleted only at P7 step 4, and a
documented revert is "restore the v2 callers from the tag, re-add the old
contexts to live protection **and** any ruleset." Ten repos hand-run with no
script is not a plan; P9 ships a dry-run-capable helper or P7 is not started.

**P6 — Release `ci/v3.0.0`.** Migration guide, LiteLLM smoke (MAJOR gate), FT-30
cold-start dry run (🔴 founder). Canon self-adopts first (Wave 0).

**P7 — Per-repo required-context migration.** The only irreversible step:

0. **Update `install/templates/branch-protection-*.json` in the same release.**
   `apply-standards.sh` PUTs the tier file as one whole payload, so any later
   `--apply` after step 3 **restores the old contexts and hangs every PR**
   (Claim 44). The templates must already name the new contexts before any live
   edit happens.
1. Add the new job **alongside** the old
2. Add the new context to **live** protection; observe it reporting green
3. Remove old contexts from live protection **and from any ruleset** (D40) —
   `apply-standards.sh` never touches rulesets, and admins are not ruleset bypass
   actors unless listed, so a ruleset-required context has no `--admin` escape
4. Only then delete the old callers
5. Re-run `install/required-context-map.py` and `tests/test_required_contexts.sh`
   — both must resolve every armed context to a real producer (D39). This is the
   step that catches a context armed against nothing.

Read **both** surfaces at every step (D19, D40):

```bash
gh api repos/<r>/branches/<b>/protection --jq '.required_status_checks.contexts'
gh api repos/<r>/rulesets --jq '.[].id' | while read -r id; do
  gh api "repos/<r>/rulesets/$id" \
    --jq '.rules[]|select(.type=="required_status_checks")
          |.parameters.required_status_checks[].context'; done
```

`enforce_admins: true` on consumer tiers means there is no `--admin` escape if
this is got wrong. P9 owns the undo.

## 6. Non-goals

- **No check is deleted.** Consolidation reduces jobs, not coverage. The three
  scanners get *stronger* (D13, D14).
- **`CHANGELOG.md` / `DECISIONS.md` are not touched** beyond appending.
- **v2 is not deleted** — tags remain, docs are archived, consumers migrate on
  their own schedule.

## 7. Relationship to PLAN-024

PLAN-024 Phases **A** (eliminate `doc-maintainer`), **B** (`docs-sync` reduction)
and **C** (`ci/v3.0.0` release mechanics) **ship first and separately.** Building
v3 around a flow being deleted would waste the work, and A already owns the
`litellm-smoke` circularity and the FT-30 precondition that P6 inherits.

PLAN-024 Phases **D, E, F, G** are **superseded** by this plan: D's `ai-review`
decomposition is moot once job consolidation is the organising idea, E and F are
absorbed into §3.3 and §4, and G was withdrawn outright.

**PLAN-024's status must be updated in the same change that lands this plan** —
its surviving phases re-scoped, its superseded ones marked, per plan-status
governance.

## Claim ledger

| # | Claim | Symbol | Citation |
| --- | --- | --- | --- |
| 1 | The -private variants exist because --update otherwise reverts private repos to ubuntu-latest | `install.sh --update` unsafe on a private consumer | docs/REPO_STANDARDS.md:273 |
| 2 | Canon ships three naming shapes; the bootstrap must name templates literally | `canon ships three naming shapes` | docs/REPO_STANDARDS.md:1475 |
| 3 | The concurrency allowlist exists because a cancelled required check is not success | `CI-0025 / REPO_STANDARDS §23` | install/templates/workflows/markdown-lint.yml:33 |
| 4 | The job name string is the required context; renaming silently un-satisfies protection | `This exact string is the required-status-check context` | ../framework/.github/workflows/acceptance.yml:37 |
| 5 | Hook revs are SHA-pinned because pre-commit executes the upstream build backend at install time | `SHA-pinned, not tag-pinned` | install/templates/pre-commit-hook-block.yaml:47 |
| 6 | The ai-review verdict step fails closed to keep the required check red | `ai-review` IS the required status context | .github/workflows/ai-review.yml:741 |
| 7 | Fork-code-executing lint flows must stay ubuntu-latest on public repos | `NEVER` | CLAUDE.md:215 |
| 8 | secret-scan scans full commit history, not the working tree | `Full-clone scan (fetch-depth: 0)` | .github/workflows/secret-scan.yml:19 |
| 9 | A callee's permissions are an intersection ceiling a caller cannot raise | `pull-requests` MUST be `write` here | .github/workflows/docs-sync.yml:59 |
| 10 | The hook-block marker version is the refresh key | `the REFRESH KEY` | install/templates/pre-commit-hook-block.yaml:3 |
| 11 | A fragment with no commit-stage hook made the required check exit 0 while inspecting nothing | `exited 0 while inspecting nothing` | install/templates/pre-commit-hook-block.yaml:30 |
| 12 | dep-scan fails loud when it finds no manifests | `expect-manifests` | .github/workflows/dep-scan.yml:28 |
| 13 | Own scanners are a founder MUST-HAVE with graduation a founder step | `our own scanners are MUST-HAVE` | plans/PLAN-014_security-scanning-coverage.md:5 |
| 14 | fail-on-findings is a default the flow honours with exit 1, not an incapacity | `fail-on-findings` | .github/workflows/trivy-scan.yml:27 |
| 15 | GitHub runs every run: step under an implicit bash -e | `bash -e` | docs/REPO_STANDARDS.md:2282 |
| 16 | timeout-minutes cannot fire on a job that never starts | `A job with no matching runner queues forever` | CLAUDE.md:161 |
| 17 | Actions Runner 2.327.1 is a hard floor for the node24 reusables | `2.327.1` | CLAUDE.md:257 |
| 18 | The LiteLLM route is the docker bridge; loopback resolves to the container | `172.17.0.1:4001` | CLAUDE.md:194 |
| 19 | markdown-lint is named among the caller templates feeding a required context | `the eight caller templates feeding a` | docs/REPO_STANDARDS.md:2154 |
| 20 | The pre-commit reusable runs every hook against every file | `pre-commit run --all-files --show-diff-on-failure` | .github/workflows/pre-commit.yml:100 |
| 21 | composition fires on pull_request_review and workflow_run, never pull_request | `pull_request_review:` | install/templates/workflows/composition-public.yml:16 |
| 22 | Downloaded tool binaries are SHA-256 verified before execution | `sha256sum --check --strict` | .github/workflows/secret-scan.yml:101 |
| 23 | Canon may only `uses:` actions from an allowlisted set of owners | `actions/*` | .github/workflows/secret-scan.yml:5 |
| 24 | Verified marketplace creators are blocked too, since CI-0011 | `verified_allowed` | install/templates/actions-permissions.json:16 |
| 25 | secret-scan plants a canary because a rule-less config scans nothing and exits 0 | `config canary` | .github/workflows/secret-scan.yml:127 |
| 26 | sast-scan strips PR-supplied semgrep ignore files before scanning | `semgrepignore` | .github/workflows/sast-scan.yml:90 |
| 27 | dep-scan disables osv-scanner call analysis, which compiles source by default | `no-call-analysis` | .github/workflows/dep-scan.yml:20 |
| 28 | trivy is restricted to scanners that cannot fetch PR-controlled remote sources | `cloudformation` | .github/workflows/trivy-scan.yml:15 |
| 29 | semgrep uses an explicit config so a PR cannot inject rules | `--config` | .github/workflows/sast-scan.yml:29 |
| 30 | The scanner fork guard is a job-level condition, not a step-level skip | `head.repo.fork` | .github/workflows/dep-scan.yml:57 |
| 31 | audit-trail derives identity from GitHub metadata, never spoofable commit author | `PR_USER_TYPE` | .github/workflows/audit-trail-check.yml:105 |
| 32 | A silent pass on an unreachable BASE_SHA was the failure this gate exists to prevent | `load-bearing failure mode` | .github/workflows/audit-trail-check.yml:147 |
| 33 | audit-trail refuses pull_request_target because a PR-HEAD checkout there is an RCE | `pull_request_target` | .github/workflows/audit-trail-check.yml:72 |
| 34 | The caller's label types are load-bearing or the escape hatch cannot fire | `labeled` | install/templates/workflows/audit-trail-public.yml:11 |
| 35 | gitleaks output is redacted so the scanner does not leak what it finds | `--redact` | .github/workflows/secret-scan.yml:186 |
| 36 | SARIF upload is best-effort so a GHAS-less private repo does not red the gate | `continue-on-error` | .github/workflows/secret-scan.yml:246 |
| 37 | audit-trail deliberately omits persist-credentials because it fetches the base SHA | `ref: ${{ github.event.pull_request.head.sha }}` | .github/workflows/audit-trail-check.yml:95 |
| 38 | A detector verifies the produced config actually selects a hook at the runner's stage | `check-precommit-hooks` | install/install.sh:1170 |
| 39 | lychee must be the musl static build for older self-hosted runners | `musl` | .github/workflows/links.yml:16 |
| 40 | Rulesets are a second required-check surface apply-standards.sh never touches | `CI-0029` | DECISIONS.md:1877 |
| 41 | The required-context map only understands workflow_call reusables | `workflow_call` | install/required-context-map.py:41 |
| 42 | CI-0021 defines a targeted break-glass so an outage does not normalise --admin | `CI-0021` | docs/REPO_STANDARDS.md:1799 |
| 43 | CI-0023 records that a fail-closed guard fails on faults, not on shapes | `CI-0023` | docs/REPO_STANDARDS.md:2003 |
| 44 | apply-standards PUTs the tier branch-protection file as one whole payload | `branch-protection-` | install/apply-standards.sh:701 |
| 45 | A bare context is classified ?non-call and the suite treats that as a PASS | `?non-call` | tests/test_required_contexts.sh:43 |
| 46 | The v2 links caller splits blocking-internal from scheduled-external | `mode: internal` | install/templates/workflows/links.yml:33 |
| 47 | A caller job that `uses:` a reusable is keyed `call`, which is where the context prefix comes from | `Callers name the job` | tests/test_checknames.sh:14 |
| 48 | A plain job emits its own job name as the context — canon's own `suite` | `suite:` | .github/workflows/tests.yml:29 |
| 49 | sync-version-refs globs every caller template into TARGETS, so a v3 pin reads as stale | `install/templates/workflows` | scripts/sync-version-refs.sh:69 |
| 50 | The exerciser completeness guard derives its surface set from the manifest and reusables | `manifest` | tests/test_exerciser_inventory.sh:8 |
| 51 | markdown-lint is adoptable per repo precisely so existing lint debt does not brick merges | `lint debt` | install/templates/workflows/markdown-lint.yml:12 |
| 52 | The v2 links reusable saves a lychee cache, which the port dropped | `actions/cache/save` | .github/workflows/links.yml:24 |

## Implementation log

### 2026-08-08 — P1 signed off; P2 started (branch `feat/v3-composite-actions`)

**Founder clarification:** "from scratch" means a fresh release without the old
issues — **copying well-established flows forward is expected.** That is what
this plan does: step bodies are ported **verbatim**, only the packaging changes.
It removes the rewrite risk §1 warns about, and §2 becomes a port checklist
rather than a re-derivation exercise.

**Landed:**
- `actions/markdownlint/action.yml` — verbatim port of the v2 reusable's run
  body. Carries D5 (SHA-pinned `uses:`), D15 (`set -euo pipefail`), the
  env-not-interpolation injection defense, `noglob` glob collection, and
  `--ignore-scripts`. Does **not** check out (§3.2).
- `install/templates/workflows/quick-gates.yml` — the consolidating caller.
  Carries D3 (§23 allowlist, not blanket cancel), D4 (job id = context), D7
  (`ubuntu-latest` on public because it executes PR code), D9 (least-privilege
  grant), and the strictest-consumer checkout (`fetch-depth: 0` at the PR head
  for audit-trail's fork-PR guard).
- `tests/test_actions.sh` — 18 assertions, one per §2 defense the composite
  packaging makes newly assertable. Auto-discovered by `tests/run.sh`.

**Mutation-tested, because a suite that only passes proves nothing.** Four
mutations, all killed, baseline restored green afterwards:

| Mutation | Caught by |
| --- | --- |
| unpin `setup-node` SHA → `@v7` | D5 assertion |
| drop `shell: bash` | run/shell count equality |
| `markdownlint-cli2` → `markdownlint-cli` | both tool-parity assertions |
| `cancel-in-progress: true` | both D3 assertions |

**Correction found during implementation, folded into §3.2:** `composition`
fires on `pull_request_review` + `workflow_run`, never `pull_request`
(Claim 21), so it **cannot** share `quick-gates`' job — consolidating a check
into a job whose trigger never fires for it. The count moved 4 → 5 → **6** as
later folds split `audit-trail` (§3.2d) and `secret-scan` (P3a) out as well.

**Remaining in P2 — reduced by the folds.** `actions/pre-commit` and
`actions/links` are **done**. Still to port: the three self-hosted scanners
(osv-scanner, trivy, semgrep) for the `scanners` job.

**Two flows are deliberately NOT ported and stay reusables:** `composition`
(403 lines, different trigger) and `audit-trail`. An earlier version of this
list carried `actions/audit-trail` as pending P2 work, contradicting §3.2d —
porting it to a composite inside its own single-job workflow saves **zero**
provisioning cycles and costs the three defenses §3.2d enumerates. It stays as
it is. `secret-scan` likewise stays its own reusable per P3a.

## Review log

### Pass 1 - 2026-08-08 - author

Drafted against PLAN-024's ledger and the founder's clean-rebuild directive.
Self-review folded the governing risk into §1 (this library's apparent
redundancy is encoded defect history — four PLAN-024 proposals were withdrawn on
exactly that ground) and made §2 the acceptance criterion rather than a
background note. Author's own §2 was assembled from PLAN-024's ledger, which
covered *packaging* defenses only — Pass 2 found that limitation.

**Result:** dispatched independent review.

### Pass 2 - 2026-08-08 - independent

**45 findings. The central one: §2 was ~20 rows short — the plan's declared
acceptance criterion was itself the biggest gap.** Because §4.4 also makes §2 the
acceptance test for `RULES.md`, every missing defense would have been dropped
from both the port checklist and the new rulebook.

Folded:

1. **§2 → §2a, +21 rows (D20–D41).** The scanner and gate *bodies* carry a
   second, larger family of defenses than the packaging: SHA-256 verification of
   downloaded binaries, the allowed-actions policy (which is *why* the checks are
   100-line hand-rolled bodies), the gitleaks config canary, the semgrepignore
   strip (a verified full-SAST-bypass), `--no-call-analysis`, trivy's scanner
   restriction, the job-level fork guard, audit-trail's five-part identity/
   ordering/fail-closed cluster, `--redact`, best-effort SARIF, the
   `persist-credentials` asymmetry, the zero-hook detector, lychee's musl
   requirement, the required-context map, rulesets, CI-0021 and CI-0023.
   **All 21 CARRIED.**
2. **§3.2a — what composite packaging cannot express**, with a disposition per
   constraint. The consequential one: a job-level `if:` becomes a *step-level*
   skip, which runs after the fork's code is already checked out — so the guard
   moves to the **caller**, never to a step.
3. **§3.2b — timeouts.** Four budgets collapse into one, and the branch had
   shipped 15, *below* the 20 `links` alone needs. Rule: sum, never max.
4. **§3.2c — failure sequencing.** A composite step failure aborts the job, so
   one markdownlint error hides every other verdict. Collect-then-fail, with a
   fail-closed verdict step.
5. **§3.2d — the `types:` conflict is unresolvable**, so `audit-trail` splits
   back out. Target moved 4 → 5 → **6 jobs**; each move followed a constraint
   review found, and is recorded rather than smoothed.
6. **P3a — `security` is not a valid single job.** `secret-scan` is
   `ubuntu-latest` and fork-visible; the other three are self-hosted and
   fork-guarded. A skipped job reports *skipped*, which **satisfies** a required
   context — so a merged job would go green on every fork PR with gitleaks never
   having run. It stays separate.
7. **P7 gains steps 0 and 5**, and reads **rulesets** as well as branch
   protection (D40). Without step 0 a later `apply-standards.sh --apply` restores
   the old contexts and hangs every PR.
8. **P8 (new) — tooling and distribution.** Canon has never shipped a composite
   action: `required-context-map.py` understands only `workflow_call`,
   `test_checknames.sh` and `test_required_contexts.sh` hardcode the v2
   contexts, `manifest.json` has no `actions/` schema, and `test_lint.sh` lints
   neither. **P9 (new) — rollback**, which P7 had no undo for.
9. **Five code defects on the branch**, all fixed — see the implementation log.

**Result:** all load-bearing findings folded. §2 is now 41 rows; the plan gained
three phases. **Not ready** — §2a, §3.2a–e, P3a, P8 and P9 are all new since the
last independent pass and are themselves unreviewed.

### Pass 3 - 2026-08-08 - independent (the new material)

**23 findings, 12 load-bearing**, on §2a/§3.2a–e/P3a/P8/P9 and the branch code.
Author verified the two decisive findings at source before folding. All folded.

1. **`call / quick-gates` is not a context this job can emit — and P7 armed it.**
   `call / X` is not a convention; it is `<caller-job-key> / <callee-job-name>`,
   produced only by a job whose body is `uses:` a reusable (Claim 47). A plain
   job emits its own name — canon's live protection carries bare `suite` from
   `tests.yml` (Claim 48) beside `call / markdownlint` from a caller keyed
   `call`. The plan said `call / quick-gates` in five places **including P7 step
   2**, which arms it in live protection: a context nothing emits pins every PR
   forever. **Third required-context near-miss in this project, and the second
   caused by reading a convention instead of the live surface.** Corrected in the
   plan, both templates and the test.
2. **P8's premise was backwards, in the reassuring direction.** A bare context
   classifies as `?non-call`, which `test_required_contexts.sh` treats as a
   **PASS** (Claim 45), and `test_checknames.sh` `continue`s on anything not
   `call / …`. So v3 contexts resolve green and unvalidated, and **P7 step 5 —
   the step whose purpose is catching a context armed against nothing — catches
   nothing.** A tool reporting success on the case it exists to detect is worse
   than no tool.
3. **D42 was missing, and its absence had already produced two code defects.**
   The v2 links split (offline+blocking on PRs, external+report-only weekly) is a
   defense no row named. The ported action defaulted to `external` and to
   `lychee.toml` where canon installs `.lychee.toml` — so the required PR gate
   would have made **live external network calls, blocking, with the consumer's
   whole tolerance profile silently dropped**. Both fixed; `links-external.yml`
   added, since a consumer adopting quick-gates and deleting its v2 `links.yml`
   would otherwise lose external checking entirely.
4. **§3.2c was not implementable and the shipped code did the opposite.** Rewritten
   as caller-side `id:` + `continue-on-error` + `if: always()` verdict — which is
   a job step, where the attribute *is* supported, unlike inside an action.
   Marked NOT yet implemented rather than described as done.
5. **§3.2b's numbers were stale** (55/65 → 45/50) and "a high ceiling costs
   nothing" was false on a serial pool.
6. **§3.2d's stated reason was the weaker one.** The real disqualifier: a job
   that skips an event reports `skipped`, which *satisfies* a required context —
   so a red quick-gates could be laundered green by applying any label. Gate
   bypass, not economy.
7. **The suite still failed open** — a raising extractor gave `assert_eq "" ""`
   → pass, and a scalar `steps:` gave 0/0/0. Now emits an OK/BADSHAPE sentinel
   and validates its own output shape. Verified with two shape mutations.
8. **Three §2a rows were overstated** (D20, D36, D37) — an overstated defense
   becomes a rule canon itself violates. Scoped down.
9. §3.2e gained the `install/templates/` source path it needs to be shippable.

**Result:** all 12 load-bearing findings folded; 52 assertions, 0 failed. **Not
ready.** Three items are explicitly deferred with owners rather than fixed: the
§3.2c verdict step is unimplemented, per-check `timeout` wrappers are
unimplemented, and P8's tooling work is unstarted — so **P7 must not run**, since
its step-5 validation is currently a no-op.

### Pass 4 - 2026-08-08 - independent (FINAL, OPS-0066 cap reached)

**Verdict: NOT-READY — one hard merge blocker plus four load-bearing
corrections.** All folded. This exhausts the three-pass circuit-breaker.

1. **MERGE BLOCKER, and it was red on the branch.** `sync-version-refs --check`
   globs every caller template into TARGETS (Claim 49) and is a **default-stage,
   `always_run` pre-commit hook** — so it gates every commit *and* canon's own
   `call / Lint / format / security hooks` required context. All three v3
   templates pin `@ci/v3.0.0` while `VERSION` is `ci/v2.16.0`, so all three read
   STALE. Verified by running it. **And the failure message's remedy #1 would
   have rewritten the pins to `@ci/v2.16.0`, a tag at which `actions/` does not
   exist** — a `startup_failure` on every consumer. Fixed with the documented
   remedy #2 (`sync-version-refs:ignore` markers), carrying a note to remove them
   at the tag cut. This is the FT-21 chicken-and-egg shape. **D43 added** — the
   row's absence is what let it through.
2. **§3.2's normative checkout paragraph still mandated `fetch-depth: 0` at
   `head.sha`** — the posture the branch had already rejected as *weaker, not
   stricter*, and the paragraph P2 would be implemented from. Rewritten to match
   the shipped caller and §3.2d.
3. **§3.2's job table and the headline count were stale in three places** (4 / 5
   / 6 all live in normative prose). Table rewritten to the current six-job
   model, with the useful consequence made explicit: only **two** contexts are
   new, so P7 touches two names, not five.
4. **`quick-gates` silently dropped markdown-lint's `!node_modules !vendor
   !.git`** — the same silent-default shape as the `links` defect, on the very
   file that states "EVERY input passed explicitly". Now explicit on all three
   steps.
5. **The private variant had three greps and nothing else.** `test_contract.sh`
   skips it (its caller checks key off `runner_labels`; v3 uses a literal
   `runs-on:`), and its CI-0025 evaluator builds from `required-context-map.py`,
   which only sees reusable callers. Added the full assertion set plus a
   public/private drift guard, and fixed the D1 assertions to read the
   **`runs-on` line** rather than the file — the old form was satisfiable by the
   header comment that explains the variant.
6. **§2 was short four more rows** (D43–D46): the VERSION pin discipline, the F1
   completeness guard's blindness to `actions/`, per-check arming granularity
   (fusing three checks removes the documented staged-adoption ladder), and the
   dropped lychee cache.

Minors folded: the stale `§6a` reference, a mis-numbered claim cite, the
implementation log's false "strictest-consumer checkout" claim, and the
contradiction over whether `actions/audit-trail` is still pending P2 work
(§3.2d says it stays a reusable — the port list said otherwise).

**Author note on process:** while reverting a mutation I ran `git checkout` on a
file with *uncommitted fixes*, destroying them — the exact trap recorded in this
project's memory. Caught by the suite going red, restored by re-applying, not by
another checkout.

**Result:** all load-bearing findings folded. 64 assertions, 0 failed; the merge
blocker is cleared and `sync-version-refs --check` passes. **Still NOT READY** —
the three deferrals from Pass 3 stand (§3.2c verdict step, per-check timeouts,
P8), and **P7 must not run**. The branch is now safe to land as an incomplete
foundation: the templates are unmanifested, so `install.sh` cannot ship them and
no consumer can reach them.
