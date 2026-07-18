# PLAN-013 — uniform protected AI-flow model (visibility-independent)

**Owner:** `aidoc-flow-ci` maintainer
**Origin:** founder directive (2026-07-17): all AI-based flows must be available on
**both public and private** repos and must be **"protected" uniformly regardless
of visibility** — because a repo can flip visibility (private→public, or public→
private→public), and any protection that *depends* on visibility is a latent leak
the flip exposes. Runner-routing decision (founder, 2026-07-17): **uniform
ephemeral self-hosted, one protected template per flow, no `-public`/`-private`
variants.**
**Status:** DRAFT — 🔴 GATED on a founder go/no-go (see §8: the self-hosted-on-
public stance change + the public-repo capacity/DoS acceptance). Foundational for
[[PLAN-012]] (autofix), which adopts this model to reach public repos. Do NOT
implement past Phase 0 without approval.
**Depends on:** sufficient **ephemeral self-hosted runner capacity** to also serve
public repos' trust jobs (a 🔴 founder/ops capacity item — see §8.2).
**Exit:** every AI-based flow (`ai-review`, `autofix`, `doc-maintainer`,
`docs-sync`) runs from a **single protected caller template** using
`["self-hosted","ci-runner","single-use"]`, on public and private repos alike;
there is **no** `-public`/`-private` variant and **no** visibility branch in the
templates, manifest, or installer for these flows; a private↔public flip is a
**no-op** for them (no re-configuration, no leak window); and forks still reach
**no** code-executing / write-credential / secret-bearing job on any repo.

---

## 1. Summary

Today each flow ships a `-private` variant (self-hosted labels) and a `-public`
variant (`ubuntu-latest`); the manifest carries `visibility_variants`; and
`install.sh` resolves which variant to write from the repo's **live** visibility
at update time (Claims 1–5). The **only** functional difference between the two
variants of any flow is the `runner_labels` value — the trust gate, fork
exclusion, and `pull_request_target` posture are already identical (Claims 1, 13,
14). So the visibility split buys nothing but a **flip-mismatch window**: when a
repo changes visibility, the installed variant no longer matches until someone
re-runs `install.sh --update`, and the "private repos have no untrusted forks"
reasoning baked into the reviewer (Claim 5) silently becomes false.

This plan **collapses the `-public`/`-private` split for the AI-based flows** into
one protected template per flow, all on the ephemeral self-hosted single-use pool,
and removes every visibility branch for them from the templates, manifest, and
installer. The five invariants (§3) then hold identically on any repo, so a
visibility flip changes nothing.

**Why uniform self-hosted is *safe* for AI-flows — and why it is correctly scoped
to them.** GitHub recommends against self-hosted runners on public repos because a
fork PR can run untrusted code on your box (`security.md §3`, Claim 10). That
warning is about **untrusted code execution**. In the AI-flows it does not apply,
because **forks never reach a code-executing job:**

- the **trust job** checks out the trusted config repo (`operations@main`) + reads
  PR metadata — it runs **zero PR code** (Claim 6);
- the **review** and **autofix** jobs are gated behind `needs: trust` + the trust
  ok-flags, and **forks are never trusted** (Claims 7, 8) → they never run for a
  fork;
- **doc-maintainer** and **docs-sync** are **post-merge** (`push: main`) → a fork
  PR cannot trigger them at all (Claim 9).

So under uniform self-hosted the **only** job a fork PR triggers is the no-PR-code
trust decision, on an isolated `--rm` ephemeral container. No untrusted code ever
executes on the pool. **This safety rests on the fork-exclusion + trust-gate
property that the AI-flows have and the generic lint flows do NOT** (a
`markdown-lint`/`links`/`pre-commit` job runs the PR's own files, including a
fork's). That is exactly why the scope is the AI-flows: converging a
fork-code-executing lint flow to self-hosted on a public repo would *create* the
leak `security.md §3` warns about. **The generic checks must stay GitHub-hosted
for public forks and are deliberately OUT of scope (§6).**

## 2. Current state (the visibility-conditional surface)

| Surface | What is visibility-conditional today | Citation |
| --- | --- | --- |
| Caller templates | every flow ships `-private` (self-hosted) + `-public` (`ubuntu-latest`); the **only** diff is `runner_labels` | Claims 1, 13, 14 |
| Manifest | `visibility_variants: {public: …, private: …}` per flow | Claim 2 |
| Installer | resolves the variant from the repo's **live** `isPrivate` at update; a flip → mismatch until re-run | Claims 3, 4 |
| Reviewer reasoning | `ai-review.yml` routes the trust job by visibility + bakes in "private repos have no untrusted forks" | Claim 5 |
| Security doc | `security.md §3` frames self-hosted-on-public as "accepted risk / GitHub-recommends-against" | Claim 10 |
| Runner doc | `runners.md` routing rule: private→self-hosted, public→`ubuntu-latest` (`-public.yml` templates) | Claim 11 |

The security posture (trust gate, fork exclusion) is **already visibility-
independent** (Claims 7, 8) — it lives in the reusable, not the variant. Only the
**runner routing** and the **installer/manifest plumbing** branch on visibility.

## 3. The five invariants (the target model)

Every AI-based flow, on every repo, regardless of visibility:

1. **Author trust is allowlist-based and fork-excluding** — a PR-time flow acts
   only when `author ∈ allowlist AND not-a-fork`. No "private is inherently safe"
   shortcut (Claim 5's reasoning is removed).
2. **Forks never reach a job that EXECUTES PR code** — enforced by trust-gating
   (Claims 7, 8) + post-merge triggers (Claim 9). The one fork-reachable job (the
   trust decision) *does* hold secrets + a write token, but it **runs no PR code**
   (Claim 6), so neither is exposed to fork-controlled execution. Corollary
   guardrail: **the trust job takes no fork-controlled string into a `run:` step
   except via `env:` with a charset-safe value** (today only `AUTHOR`, the GitHub
   login) — never a PR title/body/branch-ref interpolated as `${{ … }}` into a
   shell. On self-hosted this is load-bearing: a future such interpolation would be
   RCE-on-our-box, so it is an invariant, not a coincidence.
3. **Every job that runs PR content or holds a write credential runs on the
   ephemeral single-use isolated runner** — `["self-hosted","ci-runner","single-use"]`,
   public and private alike.
4. **No behavior branches on repo visibility** — one template, one runner value,
   one manifest entry per flow; the installer never resolves visibility for these
   flows. A private↔public flip is a no-op.
5. **All AI-flows available on both public and private** — `ai-review`, `autofix`
   ([[PLAN-012]]), `doc-maintainer`, `docs-sync`.

## 4. Design / changes

1. **Collapse the variant pairs.** For each AI-flow, replace `<flow>-private.yml`
   + `<flow>-public.yml` with **one** `<flow>.yml` caller pinning
   `runner_labels…: '["self-hosted","ci-runner","single-use"]'`. (Autofix ships
   single from the start per [[PLAN-012]].) **No deprecation shim needed:** the
   template is *copied into the consumer's fixed path* (`.github/workflows/<flow>.yml`)
   by the installer (Claim 4) and the consumer `uses:` the reusable (whose name does
   not change) — no consumer references the template *filename*, so dropping the
   `-public`/`-private` names is not a consumer-facing break.
2. **Manifest.** Drop `visibility_variants` for the AI-flow entries; point each at
   the single template (Claim 2).
3. **Installer + wizard.** For the AI-flows, stop resolving the variant from
   `isPrivate` (Claims 3, 4) — always write the single protected template. The
   visibility resolution stays only for the still-split generic flows (§6).
4. **Reviewer comment/logic.** Rewrite the `ai-review.yml` visibility-routing
   comment (Claim 5) — the trust job now runs self-hosted on all repos; delete the
   "private repos have no untrusted forks" reasoning; state the fork PR triggers
   only the no-PR-code trust job on the isolated pool.
5. **Docs of record.** Rewrite `security.md §3` (Claim 10) from "self-hosted on
   public = accepted risk" to "**safe for the AI-flows** because forks reach only
   the no-PR-code trust job on the ephemeral isolated pool; all code/write jobs are
   trust-gated (forks excluded) or post-merge — and the generic fork-code-executing
   checks stay GitHub-hosted." Update `runners.md` (Claim 11) routing + REPO_STANDARDS.
6. **Semver: MINOR** (`ci/v2.2.0`). No consumer references a template *filename*
   (Claim 4), so the `-public`/`-private` → single rename is not a consumer-facing
   break — the only behavioral change is `install.sh` writing self-hosted labels
   for public AI-flow callers. Additive/behavioral, not a schema/interface break →
   MINOR, no alias shim.

## 5. The two honest consequences (why this is 🔴)

- **The self-hosted-on-public stance changes.** `security.md §3` currently says
  self-hosted-on-public is accepted-risk-only (Claim 10). This plan asserts it is
  *safe for the AI-flows* on the fork-exclusion argument (§1). That argument is
  sound **only as long as the invariants hold** — if a future edit lets a fork
  reach a code/write job, self-hosted becomes the classic untrusted-code-on-your-box
  hole. The deny-floor + trust-gate are load-bearing and must be treated as such.
- **Public-repo capacity / DoS.** On a public repo, *anyone* can open a fork PR,
  and each now triggers a trust job on **our** self-hosted pool (previously
  GitHub-hosted, i.e. GitHub's capacity). A spray of fork PRs from many accounts
  could queue jobs and saturate the pool. Mitigations: the trust job is fast
  (seconds, no PR code), `concurrency: cancel-in-progress` per PR already collapses
  rapid same-PR pushes, and the ephemeral pool recycles per job — but sizing the
  pool for public-fork volume is a real ops item (§8.2), not a code change.

## 6. Scope boundaries

- **In scope:** the AI-based flows — `ai-review`, `autofix`, `doc-maintainer`,
  `docs-sync`.
- **OUT of scope (deliberately):** the generic checks — `composition`,
  `audit-trail`, `secret-scan`, `links`, `markdown-lint`, `labeler`, `pre-commit`,
  `codeql`, `auto-merge-ai-prs`. The decisive subset — `markdown-lint`, `links`,
  `pre-commit` (all `on: pull_request`) — **run the PR's own files, including a
  fork's**, so on a public repo they must stay **GitHub-hosted**; converging *them*
  to self-hosted would create the untrusted-code-on-self-hosted leak `security.md
  §3` warns about. The rest (`composition`/`audit-trail` read only metadata;
  `auto-merge` merges) are metadata-only and lower-risk, but keeping the whole
  generic set GitHub-hosted on public is the conservative default and is not this
  plan's concern. So their `-public`/`-private` split is *correct*, not a defect.
  **Consequence honestly stated:** a visibility flip is a no-op for the AI-flows,
  but the generic checks still need their variant reconciled on a flip — full-repo
  flip-safety for the generic checks is a separate question with the *opposite*
  runner answer for the fork-code-running lint jobs, out of scope here.

## 7. Phases

- **Phase 0 (this plan + gate).** Draft + independent review + founder go/no-go (§8).
- **Phase 1 (build, gated).** Collapse the 4 AI-flow variant pairs → single
  protected templates; manifest + installer + wizard de-visibility for those flows;
  rewrite `ai-review.yml` routing comment; update `security.md §3` + `runners.md` +
  REPO_STANDARDS; tests (a flip-simulation test: same template resolves for
  `isPrivate=true|false`; a "no visibility_variants on AI-flow manifest entries"
  assertion; fork→trust-job-only isolation test). Cut `ci/v2.2.0` (MINOR, no alias
  shim; per §4.6).
- **Phase 2 (fleet, 🔴 founder).** Ensure pool capacity for public repos; re-pin +
  re-install the AI-flow templates fleet-wide. Coordinate with the PLAN-009 cutover.

## 8. 🔴 Founder-decision points (the gate)

1. **Approve the self-hosted-on-public stance change** — from `security.md §3`
   "accepted-risk-only" to "safe for the AI-flows (forks reach only the no-PR-code
   trust job; all code/write jobs trust-gated or post-merge)." Confirm the
   fork-exclusion argument is accepted as the basis.
2. **Confirm public-repo runner capacity** — the pool must absorb public-fork trust-
   job volume (§5). `concurrency: cancel-in-progress` per PR (Claim 15) collapses
   same-PR pushes but not a many-fork spray; sizing + any rate-guard is an ops item.
   Approve proceeding on the current ephemeral pool, or gate on added capacity.

(Semver is settled — **MINOR**, no consumer-facing break; see §4.6.) Per the
workspace autonomy tiers, the fleet re-pin/re-install + pool sizing are
founder-executed (writes to other repos / infra); an inbox runbook captures them.

## 9. Rejected / deferred alternatives

- **Keep the `-public`/`-private` split, just document the flip risk** — rejected:
  the founder's requirement is that visibility not change behavior; documentation
  does not remove the mismatch window.
- **Uniform self-hosted for ALL flows incl. generic lint** — rejected: lint flows
  run fork PR code, so on public repos they must stay GitHub-hosted; converging
  them would create a real untrusted-code-on-self-hosted leak (§6).
- **Detect visibility at runtime and pick the runner dynamically** — rejected:
  reintroduces a visibility branch (the thing being removed) and adds a
  `gh repo view` per run; uniform self-hosted is simpler and branch-free.

---

## Claim ledger

Citations are `file:line` opened and read. Rows marked `[operations]` are
cross-repo — verify the gate with `--root ../operations`.

| #   | Claim                                                                                       | Symbol                       | Citation                                                             |
| --- | ------------------------------------------------------------------------------------------- | ---------------------------- | ------------------------------------------------------------------- |
| 1   | ai-review `-private` caller sets self-hosted `runner_labels_routine` (public uses ubuntu)   | `runner_labels_routine`      | install/templates/workflows/ai-review-private.yml:39                |
| 2   | the manifest carries `visibility_variants` (public/private template) per flow               | `visibility_variants`        | install/templates/manifest.json:23                                  |
| 3   | `install.sh --update` resolves the variant from the repo's LIVE `isPrivate`                 | `isPrivate`                  | install/install.sh:225                                              |
| 4   | the installer selects the template via `visibility_variants[vis]`                           | `visibility_variants`        | install/install.sh:248                                              |
| 5   | `ai-review.yml` comment bakes in visibility routing + "private has no untrusted forks" (caller-side runner input; comment to rewrite) | `VISIBILITY` | .github/workflows/ai-review.yml:82                                  |
| 6   | the trust job checks out `operations@main` (trusted), never PR code                         | `never PR code`              | .github/workflows/ai-review.yml:108                                 |
| 7   | the review job is gated `needs: trust` + `if ai_review_ok` (forks excluded never run)       | `needs: trust`               | .github/workflows/ai-review.yml:216                                 |
| 8   | forks are NEVER trusted (`IS_FORK` → both ok-flags stay false)                              | `IS_FORK`                    | .github/workflows/ai-review.yml:192                                 |
| 9   | `doc-maintainer` (+ docs-sync) are post-merge; fork PRs do NOT trigger them                 | `Fork PRs do NOT trigger`    | install/templates/workflows/doc-maintainer-public.yml:13            |
| 10  | `security.md §3` frames self-hosted-on-public as accepted-risk / GitHub-recommends-against  | `accepted risk`              | docs/security.md:86                                                  |
| 11  | `runners.md` routing rule: private→self-hosted, public→`ubuntu-latest` (`-public.yml`)      | `Public`                     | docs/runners.md:27                                                  |
| 12  | OPS-0049: this account has no GitHub-hosted minutes for private repos (self-hosted mandate) | `OPS-0049`                   | docs/runners.md:29                                                  |
| 13  | `doc-maintainer` variant pair differs only by `runner_labels` (self-hosted vs ubuntu)       | `runner_labels`              | install/templates/workflows/doc-maintainer-private.yml:69           |
| 14  | `docs-sync` variant pair differs only by `runner_labels` (public omits it → reusable default) | `runner_labels`             | install/templates/workflows/docs-sync-private.yml:41                |
| 15  | `ai-review` sets `concurrency: cancel-in-progress` per PR number (collapses same-PR pushes)   | `cancel-in-progress`         | .github/workflows/ai-review.yml:72                                  |

## Review log

### Pass 0 — 2026-07-17 — author (self)

Drafted from direct reads of the AI-flow caller templates (`ai-review`,
`doc-maintainer`, `docs-sync` private-vs-public diffs — each differs only by
`runner_labels`), `manifest.json` (`visibility_variants`), `install.sh` (live-
visibility variant resolution), `ai-review.yml` (trust-job visibility routing +
fork-exclusion + trust-gated code jobs), and `security.md §3` / `runners.md`. The
load-bearing safety argument — uniform self-hosted is safe for AI-flows *because*
forks never reach a code job (trust-gated or post-merge), which is NOT true of the
generic lint flows — is what scopes the plan to the AI-flows and keeps the generic
checks GitHub-hosted (§6). Founder decisions already folded: uniform self-hosted +
single template (§design), public+private (§3.5). **Result:** needs independent
review.

### Pass 1 — 2026-07-17 — independent (fresh-context Agent)

Adversarial review against real source in both repos. **The security core —
"forks never execute PR code on the self-hosted pool" — verified AIRTIGHT (no
BLOCKER):** the only fork-triggerable in-scope flow is `ai-review`; for a fork only
the `trust` job runs; it checks out `operations@main` (never the PR head, `:168`),
fetches no diff, and interpolates no fork-controlled string into a `run:` step (the
sole PR-derived value, `AUTHOR`, passes via `env:`, charset-constrained); the
review/autofix jobs are `needs: trust`-gated with `ai_review_ok==false` for forks;
doc-maintainer/docs-sync have no `pull_request*` trigger. All 14 Claims verified
true (Claim 14 off-by-one → `:41`, fixed). **2 load-bearing findings, folded:**

- **F1** — Invariant 2 wording was self-contradicting (lumped the secret-bearing
  but no-PR-code trust job with code-executing jobs; forks *do* reach the trust
  job by design). → Reworded to "forks never reach a job that EXECUTES PR code";
  added the trust job's secret/token exposure note + the no-shell-injection
  guardrail (F3).
- **F2** — the MAJOR-semver framing rested on a false premise contradicting the
  plan's own Claim 4 (no consumer references a template *filename*). → §4.6/§8
  now MINOR, no alias shim (also right-sizes the plan).
- Minor folded: Claim 14 line, Claim 5 wording (routing is caller-side), §6 scope
  reason tightened (metadata-only vs fork-code-running lint), + Claim 15
  (`concurrency`) added.

**Result:** needs independent re-review (Pass 2) to confirm the fold.

### Pass 2 — 2026-07-17 — independent (fresh-context Agent)

Confirmed the Pass-1 fold. **F1/F2/F3 + minors all verified CLOSED** against source;
the security core ("uniform self-hosted safe because forks reach only the no-PR-code
trust job") re-confirmed intact and now more precise. Claims 14 (`:41`) + 15 (`:72`
concurrency) resolve. **1 residual load-bearing finding:** §7 Phase 1 still carried
the MAJOR / one-release-alias framing that F2 folded out of §4.6/§8, with a now-wrong
`per §4.6` cross-ref → contradiction an implementer would hit. → §7 reworded to
"Cut `ci/v2.2.0` (MINOR, no alias shim; per §4.6)"; alias mention dropped.

### Pass 3 — 2026-07-17 — author (confirm §7 fold)

Verified the §7 residual is fully folded: a repo-wide grep for `MAJOR|alias|v3.0.0|
one-release` returns only the "**no** alias shim" negations (§4.6, §7) and the
historical F2 record in this log — no live MAJOR/alias decision remains anywhere.
§4.1/§4.6/§7/§8 are now mutually consistent on MINOR-no-shim. No other load-bearing
issue open after two independent passes. **Result:** ready — DRAFT, gated on the §8
founder go/no-go (self-hosted-on-public stance change + public-repo capacity). No
code ships until then; foundational for [[PLAN-012]].
