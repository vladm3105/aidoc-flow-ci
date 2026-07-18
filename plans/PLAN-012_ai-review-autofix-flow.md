# PLAN-012 — ai-review autofix flow (build the dormant feature, public+private, default-off)

**Owner:** `aidoc-flow-ci` maintainer
**Origin:** template-gap audit (2026-07-17). The AI-review config surface ships
autofix *scaffolding* — the trust gate emits an `auto_fix_ok` output, the config
template carries `autofix.enabled` + `trust.auto_fix`, the schema reserves an
`autofix` object, and an `ai:autofix-applied` label exists — but **no workflow
consumes any of it**. A consumer who sets `autofix.enabled: true` today gets
nothing, silently. This plan builds the missing fixer flow so the dormant knobs
become real, aligned to the proven security mechanics of the operations
`IPLAN-0014` blueprint and distributed via the current central-reusable-library
canon (not `IPLAN-0014`'s stale vendored model).
**Status:** DRAFT — 🔴 GATED on a founder go/no-go (see §8). This plan is
authored to the point of a decision; **no workflow code ships until the founder
approves the §8 forks (dedicated autofix-App `contents:write` grant +
`pull_request_target` untrusted-PR-head write surface + the D-2a dependency-free
constraint).** Do NOT implement past §7 Phase 0 without that approval. *(Founder
2026-07-17: chose the **dedicated autofix App** over a PAT — folded throughout;
the App both avoids a standing *write* credential and re-fires the gate, GH-1.)*
**Depends on:** (1) a **dedicated autofix GitHub App** (`contents: write`) installed
on each enabled repo, minting ephemeral per-run installation tokens — a 🔴 founder
action; NOT the standing PAT operations retired in OPS-0043, but the App-native
path canon already prefers (Claim 27). (2) **[[PLAN-013]]** — the uniform protected
AI-flow model (single self-hosted template, no visibility split) that lets autofix
ship on **public and private** repos; autofix adopts it rather than a `-private`
variant.
**Exit:** on a **public or private** consumer with `autofix.enabled: true` and the author in
`trust.auto_fix`, a `request_changes` verdict on a non-governance diff produces a
bot commit on the PR head that addresses the findings, re-triggers the gate, and
either converges to `approve` within the round cap or escalates to a human at the
cap — while a fork PR, an untrusted author, or any `framework/**` · `.github/**` ·
`*/governance/**` path receives **no** autofix (review-only), and the whole flow
stays inert when `autofix.enabled` is false (the default).

---

## 1. Summary

The AI-review gate today is **review + label + block/auto-merge**. Autofix (the
"the reviewer proposes a fix and commits it back, then re-reviews until green or
a human is pulled in") was designed twice in operations (`IPLAN-0013` original,
`IPLAN-0014` as-built) but **never shipped to `aidoc-flow-ci` canon and never
enabled anywhere**. The operations build was vendored per-repo; that distribution
model is now stale (canon moved to a central reusable library), and the built
fixer files have since been removed from `operations/templates/ai-review/`
(only `VENDOR.md` + `verdict.schema.json` remain — Claim 14). So this is a
**fresh build in canon**, using `IPLAN-0014`'s security/mechanics as the
blueprint and the current reusable-library model for distribution.

**What this plan is NOT:** it is not a request to enable autofix. The deliverable
is a **default-off** capability (public + private, per [[PLAN-013]]) plus the staged-enablement runbook.
Enabling it on any repo is a separate 🔴 founder action, per the same staged
sequence `IPLAN-0014` defined (review-only → enable auto-merge → enable autofix).

**Roles (the two identities):** the **reviewer** (reviewer App, `contents: read`,
never writes) emits the verdict — `approve` or `request_changes` with per-finding
detail incl. a `fix` guidance string (Claim 7) — and submits the review + label.
The **autofix** (a *dedicated* autofix App, `contents: write`, the sole writer)
runs only on `request_changes` + gates, turns the findings into edits, and pushes.
Its push re-fires the gate → the reviewer re-reviews the fix → converge to
`approve` or hit the round cap → escalate. **judge≠generator holds at the identity
level: the App that reviews (read-only) is never the App that pushes.**

**The two things that make this 🔴, not a routine canon PR:**

1. **It grants a dedicated autofix GitHub App `contents: write`.** The fixer must
   push a commit to the PR head, and that push must **re-fire the gate** so the fix
   is re-reviewed. A base-`GITHUB_TOKEN` push does **not** re-trigger workflows
   (GitHub's loop-prevention, Claim 22) — but a **GitHub App installation-token
   push DOES** (App tokens are a distinct actor, GitHub-documented, fact GH-1). So
   the credential is a **dedicated autofix App** minting an **ephemeral, per-run,
   per-repo installation token** (`create-github-app-token`, the exact pattern the
   reviewer App already uses — Claims 25/26), **not** the standing PAT operations
   retired in OPS-0043. This is the direction canon already took (App-native path
   preferred over PAT — Claim 27); a PAT here would be a regression (see Rejected
   alternatives). Residual: a write-capable token still exists *in the job* — but
   ephemeral + scoped, not standing.
2. **It runs AI-authored code back onto the PR head under `pull_request_target`.**
   Writing under `pull_request_target` is not itself new — the ai-review caller
   already grants `contents: write` and pushes via `GITHUB_TOKEN` (the auto-merge
   fallback, Claim 24). The genuinely-new surface is that the fixer must **check
   out the untrusted PR head** to edit it and then push AI-generated changes back —
   the single point at which the gate stops being diff-only (Claim 21). Every other
   write-back flow in canon (`docs-sync.yml`, `doc-maintainer.yml`) is
   **post-merge** — trusted context, no untrusted PR content in scope
   (Claims 12, 13). Autofix acts on an *open* PR whose content is untrusted. **The
   dedicated App improves fork #1 to an ephemeral credential but does NOT remove
   this surface** — it is inherent to autofix and must be founder-accepted with
   eyes open.

---

## 2. Current state (what exists vs. what's missing)

**Exists (the dormant scaffolding):**

- The ai-review trust job **computes and emits `auto_fix_ok`** from the
  `trust.auto_fix` allowlist (Claims 1, 2). Nothing downstream consumes it
  (Claim 3).
- The config template ships `autofix.enabled: false` and `trust.auto_fix: []`
  (Claim 4); **no workflow reads `autofix.enabled`** (Claim 5).
- The config **schema reserves** an `autofix` object (untyped) (Claim 6).
- The verdict schema already carries a **per-finding `fix` string** (Claim 7) —
  free-text remediation guidance, not a machine-appliable patch.
- An **`ai:autofix-applied` label** exists in the label template, marked optional
  (Claim 8). Note: this label is **not** in the original `IPLAN-0013/0014` design
  (Claim 15) — it is net-new signalling this plan must define or drop.

**Missing (everything that would make it work):**

- No `autofix.yml` reusable workflow (Claim 9).
- No `autofix-*.yml` caller template for consumers (Claim 10).
- No fixer step/job consuming the verdict, `auto_fix_ok`, or the tier flag
  (Claim 3).

## 3. Prior art — what carries forward, what is stale

The operations `IPLAN-0013` (original) + `IPLAN-0014` (as-built) blueprint
(read in full; see the cross-repo Claim ledger rows) gives the security model
essentially for free. **Carries forward (adopt):**

- **judge≠generator, edit-only fixer.** The reviewer model reviews; a *separate*
  fixer produces edits with file tools only — **no shell, no git, no API, no push
  credential in the fixer's hands** (Claim 16). Separation of duties is the safety
  key: only the workflow pushes.
- **The two-step push (the load-bearing safety mechanic).** (a) guard + commit +
  `git format-patch` with **no token**, staging via an explicit allowlist that
  excludes scratch and can never `git add -A` a `.git/**` poison; (b) push from a
  **pristine `git clone`** (autofix-App token only) + `git am`, so the pushed
  `.git` comes from GitHub, never the fixer's workspace (Claim 17 — the operations
  as-built used a PAT here; this plan substitutes the autofix-App token). This
  defeats the "agent poisons `.git/config`|`.git/hooks`" attack that
  `git diff --cached` cannot see.
- **The governance floor as workflow logic, not a tunable.** No autofix on
  `framework/**`, `.github/**`, or `*/governance/**`, enforced at the **push
  boundary** (hard-fail + escalate on any staged deny path), anchored fixed-string
  prefix match, NUL-safe (Claim 18). A copy that drops it is drift.
- **Trust = `auto_fix` allowlist AND not-a-fork** (Claim 1); **default-off**
  kill-switch; **cap→escalate** on a monotonic bot-commit count; ephemeral
  **credential-isolated** runner (never the persistent reviewer box); git hooks
  disabled on checkout (Claim 16, 17).

**Do NOT inherit (stale):**

- The **vendored / no-central-repo distribution model** (`IPLAN-0014` explicitly
  rejected a central library) — superseded by the `aidoc-flow-ci` reusable-library
  canon this repo now is. Distribute as a **reusable + caller template**.
- The `GITHUB_TOKEN`-no-retrigger **inline-loop** prose in `IPLAN-0014`'s header —
  build the **retrigger model** instead (a distinct-actor push that re-fires the
  gate). Operations did that with a PAT; this plan does it with the **autofix
  App** (§4.1) — the retrigger is the mechanic to keep, not the PAT.
- The `IPLAN-0014` **public-repo deferral** (its isolated-runner variant "was
  never built") — **no longer a blocker**: the ephemeral single-use pool now
  provides that isolation, so autofix ships on **public and private** under the
  uniform protected model ([[PLAN-013]], §6).

## 4. Design (the proposed flow)

### 4.0 The load-bearing security departure: the fixer checks out untrusted PR head

The review half of the gate is safe because it is **diff-as-data only** — it reads
the PR diff via `curl` and *never* `actions/checkout`s the PR head into the
write-capable context (Claim 20, and the caller guards this explicitly). **Autofix
cannot preserve that property:** to edit the code it must materialize the PR-head
working tree on the runner. This is the one place the gate stops being diff-only —
`IPLAN-0013` names it exactly (Claim 21). Every mitigation below exists to bound
*that* departure, and it is why the fixer runs on an **ephemeral, credential-
isolated** runner — the `["self-hosted","ci-runner","single-use"]` pool, on
**public and private repos alike** per the uniform protected model ([[PLAN-013]]).
Forks never reach the fixer (they are never trusted, Claim 21's gate), so the
fixer only ever edits a *trusted, non-fork* author's branch — the same posture on
any repo visibility:

- The fixer runs on a throwaway runner that holds **no** persistent creds (never
  the reviewer box), with `persist-credentials: false` and git hooks disabled
  (`core.hooksPath=/dev/null`) so a poisoned checkout cannot execute or read creds.
- The fixer holds **no push credential / no git / no shell** (Claim 16) — it only
  writes files; the two-step push (4.4) is the sole path to `origin`.
- **Residual risk that trust-gating does NOT erase:** a *trusted* author's PR can
  still carry prompt-injection in its diff → the reviewer verdict's `fix` guidance
  (Claim 7) → the fixer's input → a generated patch. The design contains this two
  ways: (i) the fixer produces only files, never actions, and (ii) **every fix
  commit re-fires the full gate** (4.4) — an injected fix is itself re-reviewed
  and cannot auto-merge without passing, and hits the round cap → escalate. This
  containment is a genuine strength; it is stated here so it is not mistaken for an
  unmitigated hole, but it does not remove the untrusted-content surface.

### 4.1 Distribution & shape

- **New reusable `.github/workflows/autofix.yml`** — a third job conceptually
  downstream of `trust` → `ai-review`. Two viable structures (design fork D-1,
  §5): (a) a **new job inside `ai-review.yml`** keyed on the verdict + `auto_fix_ok`
  + tier; or (b) a **standalone `autofix.yml` reusable** the consumer wires as a
  second caller, triggered on the verdict artifact / a label. Recommendation: (a)
  — same-run, reads the verdict from a run-scoped artifact, no cross-workflow
  handoff — matching `IPLAN-0014`'s same-run architecture. (b) is simpler to gate
  behind a separate required-check but adds a cross-workflow verdict handoff.
- **One protected caller template `install/templates/workflows/autofix.yml`** —
  **no `-public`/`-private` split** (it ships uniform per [[PLAN-013]]: single
  template, `["self-hosted","ci-runner","single-use"]`, no visibility branch).
  Ships default-inert (the caller exists but does nothing until
  `autofix.enabled: true` + the autofix-App secrets present).
- **Credential = a dedicated autofix GitHub App.** A *separate* App from the
  reviewer App (which stays `contents: read`). The caller supplies
  `APP_AUTOFIX_ID` + `APP_AUTOFIX_KEY`; the fixer job mints a per-run installation
  token via `actions/create-github-app-token` with `permission-contents: write`,
  `owner`/`repositories` scoped to the PR repo — the same minting pattern the
  reviewer/trust path already uses (Claims 25/26), just with a write permission and
  a distinct App identity. No `AUTOFIX_TOKEN` PAT (Rejected alternatives). The
  App-token push is what re-fires the gate (fact GH-1).

### 4.2 Trigger & gate (when the fixer runs)

Fires only when **all** hold (mirrors `IPLAN-0014`):

1. verdict `decision == request_changes` (Claim 7 — the verdict object),
2. `needs.trust.outputs.auto_fix_ok == 'true'` (Claim 1 — author in `trust.auto_fix`
   AND not a fork),
3. `tier != spec` AND no changed file under the governance deny-paths (Claim 18),
4. `autofix.enabled == true` in the trusted config (Claim 4/5 — **this plan makes
   `autofix.enabled` actually read**),
5. bot-commit count on the PR `< max_fix_rounds` (else escalate).

### 4.3 Fixer mechanics (how the patch is produced)

**Design fork D-2 (§5) — the biggest open decision.** The current canon reviewer
is **dependency-free LiteLLM HTTP** (`litellm_client.py`, Claim 11) — there is no
agent-with-file-tools on the runner. `IPLAN-0014` used a Claude CLI with
`Read/Edit/Write` tools. Two options:

- **D-2a — dependency-free (aligns with current canon):** a LiteLLM chat call
  seeded with the validated findings (each finding already carries a `fix` string,
  Claim 7) returns a **unified diff** (or full-file replacements) which the
  workflow applies with `git apply --3way`. No agent CLI dependency; same
  transport as the reviewer. Risk: model-generated diffs can fail to apply
  cleanly (fuzzy context) → treat an apply failure as "no fix this round" →
  escalate, never force.
- **D-2b — agent CLI (IPLAN-0014 as-built):** reintroduce a file-tool agent
  (Claude Code) on the isolated runner. Richer multi-file edits, but a heavy new
  runtime dependency the canon deliberately removed at `ci/v2.0.0`.

The model-generated diff is **itself untrusted input**: `git apply` must not be
allowed to write outside the intended paths (`.github/**`, path traversal,
`.git/**`). Validate the diff's declared target paths at apply time (not only via
the post-staging deny-scan in 4.4) and reject an apply that touches a deny path.

Recommendation: **D-2a** — it keeps the dependency-free architecture and reuses
the verdict's existing `fix` guidance; escalate-on-apply-failure keeps it safe.
**D-2a is a hard constraint of the founder gate, not a free Phase-1 choice** (§8):
D-2b would reintroduce an agent runtime the canon removed at `ci/v2.0.0` AND run
it against checked-out untrusted PR code — a dependency-policy reversal and a
materially larger attack surface, so adopting D-2b is a **separate founder
decision**, not an implementer's call.

Whichever is chosen, the fixer holds **no push credential** — it only writes
files to the workspace; the workflow's two-step push (4.4) does the rest.

### 4.4 Write-back (the safe push)

Per `IPLAN-0014` as-built (Claim 17), split so the write token never touches the
fixer's `.git`:

1. **Guard + commit + export (no token):** stage via explicit allowlist
   (`git add -A -- ':!.autofix' ':!.git'` style), enumerate staged paths NUL-safe,
   **hard-fail + escalate** if any staged path matches the governance deny-set or
   escapes via symlink, then `git format-patch` (binary-safe). All git ops run
   `-c core.hooksPath=/dev/null --no-verify`.
2. **Push from a pristine clone (autofix-App token only):** mint the autofix App's
   installation token (`create-github-app-token`, `permission-contents: write`,
   scoped to the PR repo), fresh `git clone` of the PR head **with that token**,
   `git am` the exported patch with the `ai-autofix` bot committer identity,
   `git push`. The token appears **only** in this step's env, is **ephemeral**
   (per-run, ~60 min, auto-revoked), and the pushed `.git` comes straight from
   GitHub, never the fixer's workspace.

The autofix-App-token push re-fires the gate (fact GH-1) → the reviewer re-reviews
the fix → converge or cap→escalate. In-canon precedent for a write-back reusable
exists (`docs-sync.yml`, `doc-maintainer.yml`), but both are **post-merge /
trusted** (Claims 12, 13) — autofix's open-PR `pull_request_target` write is the
new risk.

### 4.5 Config knobs (made real)

| Knob | Location | Semantics (this plan) |
| --- | --- | --- |
| `autofix.enabled` | trusted `config.json` | master on/off; **default false**; now actually read by `autofix.yml` |
| `autofix.max_fix_rounds` | trusted `config.json` | bot-commit cap before escalate (default 2, per `IPLAN-0013`) |
| `autofix.max_budget_usd` | trusted `config.json` | per-PR model-spend ceiling (optional) |
| `trust.auto_fix` | trusted `config.json` | author allowlist (existing; now consumed) |
| governance deny-paths | **workflow logic** | NOT a tunable — hardcoded `framework/**` · `.github/**` · `*/governance/**` |
| `APP_AUTOFIX_ID` / `APP_AUTOFIX_KEY` | consumer repo secrets | the **dedicated autofix App** creds; absent → the flow is inert (fail-safe) |

All autofix settings live in the **trusted config source** (operations@main by
default), never the PR branch — a PR cannot enable its own autofix. **This is not
true today and is a hard Phase-1 requirement:** the config's enforced-from-trust
list is currently exactly `trust.ai_review` · `trust.auto_fix` · `litellm.model` ·
`auto_merge.repos` — **`autofix.*` is NOT in it** (Claim 23), and the trust job
resolves only `trust.*` from operations@main. Without explicitly adding
`autofix.enabled` (+ `autofix.max_fix_rounds`) to the enforced set and reading
them from the trusted source, a PR-branch `config.json` could self-enable autofix,
defeating the kill-switch. Phase 1 MUST extend the enforced list + the trust-job
resolution accordingly. The config schema's `autofix` object (Claim 6) also gets a
concrete typed sub-schema.

### 4.6 Labels & signalling

`ai:autofix-applied` exists (Claim 8) but is **not** inherited design (Claim 15).
Decision (D-3, §5): either (a) define it — the fixer step applies it when it
pushes a fix commit, for auditability; or (b) drop it and rely on the bot commit
+ escalation comment. Recommendation: **(a)** — a visible signal that a bot
touched the PR is worth the one label write; wire it mutually-exclusive with an
`ai:autofix-escalated` state at the cap.

## 5. Design forks to resolve at Phase 1 (not now)

- **D-1** — same-run job in `ai-review.yml` (rec) vs. standalone `autofix.yml`
  reusable.
- **D-2** — dependency-free LiteLLM-diff fixer (rec) vs. reintroduced agent CLI.
  **D-2 is NOT decision-free:** the D-2b agent-CLI variant is a founder decision
  (dependency reversal + running an agent on untrusted PR code), pinned to D-2a by
  §8. Only the *shape* of D-2a (unified-diff vs. full-file replacement) is a free
  Phase-1 choice.
- **D-3** — define `ai:autofix-applied` (rec) vs. drop it.

D-1 and D-3 are implementation-shape choices, decision-free for the founder gate.
The founder gate (§8) is about the **dedicated autofix App grant**, the
**untrusted-PR-head write surface**, and the **D-2a constraint**.

## 6. Scope boundaries (right-sizing)

- **Public AND private repos, uniform protected** (per [[PLAN-013]]). Autofix is
  safe on public repos because forks are never trusted → the fixer never runs on a
  fork; only trusted, non-fork authors' branches are edited, on the ephemeral
  isolated pool — the same posture regardless of visibility. (This supersedes the
  earlier draft's "private-only"; the isolated-runner `IPLAN-0014` said was
  "never built" now exists as the ephemeral single-use pool.)
- **Default-off everywhere.** Shipping this flow enables it nowhere. Enablement is
  the staged 🔴 founder sequence, per repo.
- **No new reviewer behavior.** The review half of `ai-review.yml` is unchanged;
  autofix is strictly additive and gated.
- **One consumer pilot first** (a throwaway repo), then a narrow propagation —
  never a fleet-wide enable.

## 7. Phases

- **Phase 0 (this plan + gate).** Draft + independent review + founder go/no-go on
  §8. **Nothing past here without approval.**
- **Phase 1 (build, gated).** Resolve D-1/D-3 (D-2 pinned to D-2a by §8); author
  the single protected `autofix.yml` reusable + `autofix.yml` caller template
  (uniform, per [[PLAN-013]]) + typed `autofix` schema; **extend the
  trust-enforced config list + trust-job resolution to include `autofix.enabled` +
  `autofix.max_fix_rounds`** (Claim 23 — required so a PR cannot self-enable);
  `ci/v2.2.0` semver (MINOR, additive); tests (deny-path guard at apply AND push,
  no-change→escalate, fork→no-autofix, untrusted-author→no-autofix, cap→escalate,
  kill-switch-off inert, PR-branch-config-cannot-self-enable); `docs/` +
  REPO_STANDARDS + CHANGELOG.
- **Phase 2 (pilot, 🔴 founder).** Register the **dedicated autofix App** (install
  on the pilot repo with `contents: write`), set `APP_AUTOFIX_ID`/`APP_AUTOFIX_KEY`
  secrets; enable on one pilot repo (public or private); validate the exit criteria
  live (trusted PR converges; fork/untrusted gets none; governance path forced
  review-only; App-token push re-fires the gate).
- **Phase 3 (narrow propagation, 🔴 founder).** Enable on selected repos (public
  and private) via the staged sequence.

## 8. 🔴 Founder-decision points (the gate)

Autofix does not proceed past Phase 0 until the founder decides:

1. **Provision a dedicated autofix GitHub App with `contents: write`?** The fixer
   push must re-fire the gate; a `GITHUB_TOKEN` push does not (Claim 22) but a
   GitHub App installation-token push does (fact GH-1). The credential is therefore
   a dedicated autofix App minting an **ephemeral per-run installation token**
   (the pattern the reviewer App already uses — Claims 25/26), **not** the standing
   PAT operations retired in OPS-0043 — this is strictly better and the direction
   canon already took (Claim 27). What the founder actually authorizes: registering
   one more App (separate identity from the reviewer, preserving judge≠generator)
   and installing it with `contents: write` on the enabled repos. Residual: a
   write-capable (ephemeral) token exists in the job — far softer than a standing
   PAT, but not zero.
2. **Accept running AI-authored edits on the untrusted PR head?** This is the axis
   that makes autofix different from every existing canon write-back flow: the
   fixer must check out the PR head (Claim 21) — the one point the gate stops being
   diff-only — and a *trusted* author's PR can still carry prompt-injection into
   the fixer (§4.0). The mitigations (edit-only fixer, isolated ephemeral runner,
   two-step pristine-clone push, governance deny-floor at apply + push,
   cap→escalate, every-fix-re-reviewed, default-off, forks-never-trusted) are
   strong but this is honestly a real surface, not "fully mitigated." **Same on
   public and private** — the fixer never runs on a fork, so visibility doesn't
   change this surface ([[PLAN-013]]).
3. **Pin the fixer to D-2a (dependency-free)?** Adopting D-2b (an agent CLI on
   checked-out untrusted PR code) reverses the `ci/v2.0.0` dependency-free policy
   and enlarges the surface — this plan recommends forbidding D-2b; the founder
   confirms.
4. **Confirm public+private (uniform protected, [[PLAN-013]]) + default-off + staged-enable** as the ship shape.

An inbox runbook (`operations/ops/inbox/`) captures these for the founder; per the
workspace autonomy tiers, the autofix-App registration + per-repo install + secret
provisioning + per-repo enablement are founder-executed (writes to other repos /
credential provisioning are 🔴).

## 9. Rejected / deferred alternatives

- **Enable the dormant knobs without building the fixer** — rejected: the knobs
  do nothing; enabling them is the misleading state, not a fix.
- **Apply the verdict `fix` string directly** — rejected: `fix` is free-text
  guidance (Claim 7), not an appliable patch; realizing it still needs a model to
  produce edits (folds into D-2).
- **A standing scoped write PAT (`AUTOFIX_TOKEN`)** — rejected in favour of the
  dedicated autofix App. Both re-fire the gate (a PAT is a distinct actor too), but
  a PAT is a *standing* long-lived secret in repo secrets — exactly what OPS-0043
  retired and what canon already migrated off (App-native path preferred, Claim 27).
  The App gives the same re-trigger with an ephemeral, per-run, per-repo,
  auto-revoked token and a distinct bot identity. A PAT here would be a regression.
- **Reuse the reviewer App (grant it `contents: write`)** — rejected in favour of a
  *separate* autofix App. One App both reviewing and pushing collapses
  judge≠generator at the identity level and broadens the reviewer App's grant;
  the dedicated App keeps the writer distinct and its write scope isolated.
- **Public-repo autofix** — deferred (§6).
- **Author-side "split large PRs"** — N/A (that was PLAN-011's concern).
- **Reintroduce the full agent-CLI runtime** — deferred behind D-2 unless the
  dependency-free path proves insufficient.

---

## Claim ledger

Citations are `file:line` opened and read. Rows marked `[operations]` are
cross-repo — verify the gate with `--root ../operations`.

| #   | Claim                                                                                     | Symbol                          | Citation                                                                    |
| --- | ----------------------------------------------------------------------------------------- | ------------------------------- | --------------------------------------------------------------------------- |
| 1   | trust job emits `auto_fix_ok` from the `trust.auto_fix` allowlist, gated not-a-fork       | `auto_fix_ok`                   | .github/workflows/ai-review.yml:105                                         |
| 2   | `auto_fix_ok` is computed by an in-list check over the `auto_fix` allowlist               | `AUTO_FIX_OK`                   | .github/workflows/ai-review.yml:196                                         |
| 3   | nothing downstream consumes `auto_fix_ok` (only produced at :105/:199, never read)        | `auto_fix_ok`                   | .github/workflows/ai-review.yml:199                                         |
| 4   | config template ships an `autofix` block with `enabled:false` (the master knob)           | `autofix`                       | install/templates/config.json.template:25                                   |
| 5   | `autofix.enabled` is defined but read by NO workflow (grep across `.github/workflows/`)    | `autofix`                       | install/templates/config.json.template:25                                   |
| 6   | the config schema reserves an untyped `autofix` object                                    | `autofix`                       | schemas/ai-review-config-v2.schema.json:31                                  |
| 7   | the verdict schema carries a per-finding `fix` string + `decision` enum                   | `fix`                           | ai-review/verdict.schema.json:19                                            |
| 8   | an `ai:autofix-applied` label exists, marked optional                                     | `ai:autofix-applied`            | install/templates/labels.json:28                                            |
| 9   | the reusable catalog lists 12 reusables; none is an `autofix` workflow                     | `catalog`                       | docs/WORKFLOWS.md:13                                                         |
| 10  | the template manifest enumerates workflow templates; none is an autofix caller             | `template`                      | install/templates/manifest.json:22                                          |
| 11  | the current reviewer is a dependency-free LiteLLM HTTP client (no agent CLI)              | `litellm_client.py`             | .github/workflows/ai-review.yml:577                                         |
| 12  | `docs-sync.yml` is a POST-MERGE write-back fixer (trusted context)                        | `docs-sync.yml`                 | .github/workflows/docs-sync.yml:1                                           |
| 13  | `doc-maintainer.yml` is an AI-driven POST-MERGE write-back maintainer (trusted context)   | `doc-maintainer.yml`            | .github/workflows/doc-maintainer.yml:1                                      |
| 14  | operations RETIRED the vendored fixer (only VENDOR.md + verdict.schema.json remain)        | `Retired`                       | ../operations/templates/ai-review/VENDOR.md:1 `[operations]`                |
| 15  | `ai:autofix-applied` is NOT in the original design (its labels are review-changes/escalated) | `ai:review-escalated`         | ../operations/ops/iplans/IPLAN-0013_ai-review-auto-fixer.md:85 `[operations]` |
| 16  | edit-only fixer (no shell/git/API/push cred); separation of duties is the safety key      | `--allowed-tools`               | ../operations/ops/iplans/IPLAN-0013_ai-review-auto-fixer.md:83 `[operations]` |
| 17  | as-built push = patch-export (no token) → pristine-clone `git am` push (PAT only)         | `AUTOFIX_TOKEN`                 | ../operations/ops/iplans/IPLAN-0014_public-ci-actions-and-autofix.md:256 `[operations]` |
| 18  | governance deny-floor (`framework/**`·`.github/**`·`*/governance/**`) = workflow logic     | `fix_deny_paths`                | ../operations/ops/iplans/IPLAN-0014_public-ci-actions-and-autofix.md:74 `[operations]` |
| 19  | `IPLAN-0014` autofix was BUILT-but-OFF, never cut over / enabled anywhere                  | `AUTOFIX_ENABLED`               | ../operations/ops/iplans/IPLAN-0014_public-ci-actions-and-autofix.md:116 `[operations]` |
| 20  | ai-review is wired under `pull_request_target`, diff-only (caller never checks out PR head)| `pull_request_target`           | install/templates/workflows/ai-review-private.yml:13                        |
| 21  | the fix half checks out the PR branch to edit — the one place the gate is NOT diff-only    | `PR content`                    | ../operations/ops/iplans/IPLAN-0013_ai-review-auto-fixer.md:100 `[operations]` |
| 22  | `GITHUB_TOKEN`-pushed commits do NOT trigger new runs (GitHub-documented) → PAT re-fires   | `GITHUB_TOKEN`                  | ../operations/ops/iplans/IPLAN-0014_public-ci-actions-and-autofix.md:108 `[operations]` |
| 23  | the trust-enforced config list omits `autofix.*` (only `trust.*`/`litellm.model`/`auto_merge.repos`) | `ENFORCED`            | install/templates/config.json.template:4                                    |
| 24  | the ai-review caller already grants `contents: write` + pushes via `GITHUB_TOKEN`          | `contents: write`               | install/templates/workflows/ai-review-private.yml:29                        |
| 25  | canon already mints App installation tokens via `create-github-app-token` (SHA-pinned)    | `create-github-app-token`       | .github/workflows/ai-review.yml:139                                         |
| 26  | the minted App token is per-repo scoped with an explicit `permission-contents`             | `permission-contents`           | .github/workflows/ai-review.yml:145                                         |
| 27  | canon's token precedence prefers the App-native path over the legacy PAT ("no per-repo PAT")| `no per-repo PAT`              | .github/workflows/ai-review.yml:441                                         |

**Platform facts (GitHub-documented; external contract, not a repo `file:line`):**

- **GH-1 — a GitHub App installation-token push re-triggers workflows.** GitHub's
  loop-prevention is specific to the default `GITHUB_TOKEN`; a push authenticated
  with a GitHub App installation access token (a distinct actor) *does* trigger
  subsequent workflow runs. This is what lets the autofix-App push re-fire the gate
  without a PAT. Source:
  <https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow>
  ("Using a personal access token or GitHub App … triggers events that require a
  token" / GITHUB_TOKEN loop-prevention).

## Review log

### Pass 0 — 2026-07-17 — author (self)

Drafted from: (a) direct reads of `ai-review.yml`, `verdict.schema.json`,
`config.json.template`, `schemas/ai-review-config-v2.schema.json`, `labels.json`,
`docs-sync.yml`, `doc-maintainer.yml`; (b) a fresh-context extraction of
operations `IPLAN-0013` + `IPLAN-0014` (the autofix blueprint), which flagged two
stale inheritances (the vendored distribution model; the `GITHUB_TOKEN`-inline-loop
prose) that this plan explicitly rejects (§3). **Result:** needs independent review.

### Pass 1 — 2026-07-17 — independent (fresh-context Agent)

Adversarial review against real source in both repos. All 20 original Claim rows
verified substantively TRUE; four citations imprecise (4, 5, 15, 20) — corrected.
The PAT rationale (`GITHUB_TOKEN` push doesn't re-fire the gate) was confirmed
against operations, not fabricated. **6 load-bearing findings, folded:**

- **F1 (HIGH)** — the plan never surfaced that the fixer must check out the
  untrusted PR head (the one point the gate stops being diff-only). → Added §4.0
  + Claim 21 (IPLAN-0013:100).
- **F2 (HIGH)** — D-2 was mis-scoped as decision-free; D-2b (agent CLI on
  untrusted PR code) is a founder-load-bearing dependency reversal. → Pinned D-2a
  as a hard §8 constraint; §5/§7 updated; new founder fork §8.3.
- **F3 (MED)** — the PAT justification was uncited. → Claim 22 (IPLAN-0014:108);
  §8.1 now rests on it.
- **F4 (MED)** — `autofix.*` is not in the trust-enforced config list, so a PR
  could self-enable autofix. → §4.5 hard Phase-1 requirement + Claim 23 + Phase-1
  task + test.
- **F5 (LOW/MED)** — the model-generated diff's target paths are untrusted and must
  be guarded at apply, not only post-staging. → §4.3 D-2a sentence.
- **F6 (LOW)** — §1.2 overstated the new surface; ai-review already writes under
  `pull_request_target` via `GITHUB_TOKEN`. → §1.2 tightened + Claim 24; the truly-
  new surface is the standing PAT + AI-authored PR-head edits.

**Result:** needs independent re-review (Pass 2) to confirm the fold.

### Pass 2 — 2026-07-17 — independent (fresh-context Agent)

Re-review confirming the Pass-1 fold. All six findings (F1–F6) verified **CLOSED**
against source; all four corrected citations (Claims 4/5 → `config.json.template:25`,
15 → `IPLAN-0013:85`, 20 → `ai-review-private.yml:13`) resolve; the new Claims
21–24 anchor-checked and resolve. No new load-bearing problem introduced by the
fold; internal consistency across §4.0 / §5 / §7 / §8 holds (D-2 pinned to D-2a
everywhere; deny-paths hardcoded consistently). The reviewer scrutinized the
PAT-necessity framing against the inline-loop alternative and confirmed it sound
(every fix commit must re-fire the full gate as a checked run branch-protection
sees — an in-job loop cannot, so the PAT is genuinely required; §3 already
considers-and-rejects the inline loop). Verdict: `zero load-bearing findings`.

**Result:** ready — this is a DRAFT plan whose "ready" means *ready for the founder
go/no-go at §8*, not ready to implement. No workflow code ships until the founder
approves the §8 forks.

### Pass 3 — 2026-07-17 — author (self, post-ready revision)

Founder decision (2026-07-17): use a **dedicated autofix GitHub App** instead of a
standing PAT. Load-bearing security-mechanic change, folded throughout: §1 roles +
fork #1 (App grant, not PAT), §4.1 credential model, §4.4 push (App installation
token, not `AUTOFIX_TOKEN`), §4.5 secrets row (`APP_AUTOFIX_ID`/`_KEY`), §7 Phase 2
(App registration), §8 fork #1 rewritten, §9 two new rejected alternatives (standing
PAT; reuse-reviewer-App). New evidence: Claims 25–27 (canon already mints App
tokens via `create-github-app-token`, per-repo `permission-contents` scoping,
App-native-over-PAT precedence) + platform fact **GH-1** (App installation-token
pushes re-trigger workflows, unlike `GITHUB_TOKEN` — GitHub-documented, verified
against GitHub docs). `check_plan.py` ok (27 citations). Note: fork #2
(untrusted-PR-head write surface) is unchanged by the App — deliberately preserved
as a standing founder-accepted risk. **Result:** needs independent re-review (Pass
4) to confirm the App fold.

### Pass 4 — 2026-07-17 — independent (fresh-context Agent)

Confirmed the App fold. **GH-1 verified CORRECT** (App installation-token pushes
re-trigger workflows; `GITHUB_TOKEN` loop-prevention is token-specific — the whole
design rests on this and it holds). Claims 25/26/27 resolve (`ai-review.yml:139`
mint, `:145` `permission-contents` scoping, `:441` App-native-over-PAT precedence).
Fork #2 correctly kept UNCHANGED by the App (no false claim the App fixes the
untrusted-content surface); dedicated-App-vs-reuse separation-of-duties sound;
two-step push works cleanly with an ephemeral App token. **1 load-bearing finding:**
a leftover §3 bullet still said the "PAT-retrigger model … is the one to build,"
contradicting the App fold → reworded to "build the retrigger model (App-based);
the retrigger is the mechanic to keep, not the PAT." Plus a precision note
(App swaps a standing *write* credential for a private key + ephemeral tokens) →
"standing *write* credential." Both folded. No new hole.

**Result:** ready — DRAFT, still gated on the §8 founder go/no-go (now: dedicated
autofix-App grant + untrusted-PR-head surface + D-2a). No code ships until then.

### Pass 5 — 2026-07-17 — author (scope: public+private per PLAN-013)

Founder decision (2026-07-17): all AI-flows available on public + private, uniformly
protected. Autofix adopts the [[PLAN-013]] uniform model — **dropped "private-only"**
throughout (title, §1 summary, §3 IPLAN-0014-deferral bullet, §4.0/§4.1, §6 scope,
§7 phases, §8 fork 4, Exit). The public-repo safety rests on the property PLAN-013's
two independent passes verified: **forks are never trusted → the fixer never runs on
a fork → only trusted, non-fork branches are edited, on the ephemeral isolated pool —
identical posture on any visibility.** The single `autofix.yml` caller (no
`-private`/`-public` split) replaces the earlier `autofix-private.yml`. The autofix
security mechanics (§4.0/§4.4, dedicated App, deny-floor, cap→escalate) are unchanged
— only the *scope* widened. No new load-bearing surface: PLAN-013 Pass 1/2 already
adversarially validated autofix-on-public under this model. **Result:** ready —
gated on §8 + PLAN-013's §8 (self-hosted-on-public stance + capacity).
