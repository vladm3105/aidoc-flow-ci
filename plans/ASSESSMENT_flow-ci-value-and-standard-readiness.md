# ASSESSMENT — flow-ci real value + company-standard readiness (2026-07-19)

> Pre-deployment evaluation of the `aidoc-flow-ci` pack: (1) its real intrinsic
> value, and (2) whether it is worth mandating as an internal company standard.
> Evidence-based, not aspirational. Decision-input for a founder / operations
> (OPS-NNNN) call — company-standard ratification is a 🔴 operations business
> decision, not settled here.

## Method

Measured, not opined:

- **Deployment reality** — actual `@ci/v*` pins + branch-protection state across
  the 8 sibling consumers.
- **Efficacy** — sampled the AI-review gate's real verdicts on live PRs.
- **Cost** — canon scale (LOC, plans, decisions, tags) + self-maintenance ratio.

## Findings — the value is CONCENTRATED, not uniform

**The AI-review core is the differentiated value, and it is proven.** On
operations PR #244 the gate caught a **critical CI-bricking bug before merge**
(a template re-apply set a nonexistent `runner-self` label → every job would
queue forever, taking down the required-check gate). The verdict cross-referenced
the repo's runner-registration scripts and OPS-0049 (a past outage) and gave a
per-file fix — **something no linter or scanner catches.** Counter-sample: on
routine PRs (#265 version bump, #258 large cutover) it approved correctly with
fair low-severity notes — high-signal, not noise. Owning the model routing
(LiteLLM) + governance integration with no per-seat cost is real strategic value.

**Everything else is commodity or governance-overhead:**

| Flow class | Flows | Intrinsic value | Off-the-shelf? |
| --- | --- | --- | --- |
| **AI-review core** | ai-review, composition, auto-merge-ai-prs | **HIGH — differentiated, proven** (#244) | Partially (CodeRabbit/Copilot), not with your model + governance |
| **Security scanning** | secret-scan, dep-scan, trivy, sast, codeql | **MODERATE — real but commodity** (well-hardened, but table-stakes) | Yes, easily |
| **Quality/lint** | markdown-lint, links, pre-commit | **LOW — commodity, low stakes** | Yes, trivially |
| **Governance/process** | audit-trail-check, standards-drift, labeler, docs-sync, doc-maintainer | **CONDITIONAL — value only if you adopt the workspace model**; overhead otherwise | N/A — bespoke process |

## Cost + reliability caveats (measured)

- **Scale:** ~13,300 LOC (4.5k workflow + 3.4k install/scripts + 5.4k docs),
  47 tags, 15 plans, 11 decisions, 15 open FTs.
- **Self-maintenance:** **31% of 223 commits** are fix/bug/blocker/hardening.
- **Gate reliability:** operations ai-review history = 103 success / 84 failure
  (many failures were the system's OWN infra bugs, since fixed). Improved, but
  the pre-prod review THIS session still found real BLOCKERs about to ship.
- **Deployment gap:** latest canon `ci/v2.8.0`; operations on `v2.0.1` (8 behind),
  the other 7 consumers on `v1.9.5` (~24 behind); **1 of 8** repos has an armed
  (enforcing) gate. The latest v2.x (`v2.8.0`) is deployed to ~0 current consumers.
- **Open trust question — FT-15:** the `workflow_ref`-is-the-caller bug means the
  deployed ai-review may fetch its rubric/client from `main`, not the pinned tag
  — so its behaviour may not be as version-deterministic as claimed. **Confirm
  before trusting the pin story or widening deployment.**

## Verdict 1 — worth deploying? YES, selectively (not as a 16-flow bundle)

Deploy the ~3 flows that carry the value; source the rest where they earn it:

1. **AI-review core** — the reason to adopt any of this. Deploy it.
2. **Scanners à la carte** — only where the surface exists (dep-scan on
   manifest repos, sast on code repos). Commodity; don't deploy as ceremony.
3. **Governance flows** — opt-in, only on repos you will actually govern that way.

## Verdict 2 — worth mandating as a company standard? NOT YET (mandate the CAPABILITY, not this implementation)

A personal-workspace library and a company standard are judged differently. The
pack is strong where the first is judged, weak where the second is:

### Standard-readiness scorecard

| Gate condition for "company standard" | Status | Why |
| --- | --- | --- |
| **Bus factor ≥ 2** (maintainable by non-authors) | 🔴 | ~13k LOC + governance apparatus; a 10-PR session to make it "ready"; realistically one maintainer |
| **Shared infra, not per-team** | 🔴 | AI-review core needs a private LiteLLM proxy + self-hosted runner pools + a reviewer App + per-repo secrets — provisioned per adopter today |
| **Governance decoupled** | 🟡 | de-branding hooks exist (`--codeowner`, `trust_config_repo`) but audit-trail/OPS-NNNN/tier machinery is still coupled |
| **Battle-tested across ≥3 teams over a real window** | 🔴 | 1 armed consumer; recent releases deployed to ~0; not yet proven stable at scale |
| **Support model** (who fixes an adopter's broken gate) | 🔴 | none defined; the one external adopter burned ~7 CI-fix cycles onboarding |

**The trap to avoid: mandating it *to* prove it.** Standards are ratified after
adoption succeeds, not used to force it.

### What would make it standard-worthy

- Cut complexity (drop the tier taxonomy / OPS ceremony / commodity flows) OR add
  a second maintainer → bus factor ≥ 2.
- Provision the LiteLLM proxy + runner pools + reviewer App as **company platform
  services** so adoption is "opt in", not "stand up infrastructure".
- Decouple the review gate from the workspace governance machinery.
- Resolve **FT-15** first — confirm the gate is actually version-pinned.
- Prove stability on ≥3 teams for a real window, THEN ratify.

## Recommendation

1. **Deploy the AI-review core to 2–3 high-value repos** (per
   `ROLLOUT_plan015-arming.md`), arm the gates, and **measure real catch-rate**
   over a month. That is the only "worth it" test that matters.
2. **Feature-freeze the canon** until the fleet is current + gated (no new
   PLAN-NNN capability until adoption ≥ ~50% of active repos).
3. **Resolve FT-15** before trusting/widening.
4. **Offer** the AI-review capability as a supported, opt-in company capability —
   do NOT mandate the pack. Earn "standard" status via proven adoption, then let
   operations ratify it as an OPS-NNNN decision.

## Provenance

Produced during the PLAN-015 close-out session (2026-07-19). Evidence: live `gh`
queries against the 8 consumers + operations ai-review run history; sampled
verdicts (#244 critical catch, #258/#265 approvals); `git`/repo scale metrics.
