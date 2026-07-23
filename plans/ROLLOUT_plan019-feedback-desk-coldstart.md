# ROLLOUT — PLAN-019 §6: cold-start dry-run + onboarding for `aidoc-flow-feedback-desk`

> 🔴 **Founder-executed.** Every step here writes to another repo (clones it,
> creates 18 labels, opens a PR) or changes server-side settings/secrets — 🔴 per
> the operations autonomy tiers. The AI prepared + verified this read-only; it
> does **not** run it in-session.
>
> **Gating role:** Part A is the PLAN-018 **FT-30 cold-start dry-run** that
> `docs/RELEASE_CHECKLIST.md` requires before the `ci/v2.12.0` tag is cut. Part B
> completes feedback-desk's onboarding but does **not** gate the tag.
>
> ✅ **READY TO RUN — G1 is complete (2026-07-23).** All four Workstream-A blockers
> merged to `main`: FT-39 (#269), FT-40 (#270), FT-41 (#271), FT-42 (#272). The
> **G1-merge-SHA is `d70782e7fc21c3a35bad287097d74cd99fd9241e`** (tip of `main`,
> FT-42 squash) and is filled in below — verified it resolves on
> raw.githubusercontent (`VERSION` → HTTP 200). `export CI_TAG=` that SHA.

| Field | Value |
| --- | --- |
| Target repo | `vladm3105/aidoc-flow-feedback-desk` (PRIVATE; default branch `main`) |
| Current state | No `.github/workflows/`, no `.pre-commit-config.yaml`, canon not referenced, `APP_REVIEWER_1_BOT_ID` UNSET — a genuine cold start |
| Blocked on | ✅ CLEARED — Workstream A (G1) merged to `main` (FT-39/40/41/42, PRs #269–#272; SHA `d70782e`). The dry-run now runs the *fixed* `install.sh`. |
| Tier | product (private) → `composition-private.yml`, self-hosted runners |

---

## The single most important line

```bash
export CI_TAG=d70782e7fc21c3a35bad287097d74cd99fd9241e        # the merge commit of the Workstream-A PR(s)
```

Without it, `install.sh` resolves `CI_TAG` from `VERSION`/`CI_TAG_FALLBACK` (both
still `ci/v2.11.0`) and fetches the **previous** release's templates — validating
the pre-fix files, not the ones about to ship. This is the exact trap
`docs/RELEASE_CHECKLIST.md` "🔴 COLD-START DRY-RUN" calls out. Use the merge SHA
until the tag exists; after tagging, `CI_TAG=ci/v2.12.0` is equivalent.

---

## Part A — the installer cold-start (THIS is the tag gate)

Run from a clean checkout of `aidoc-flow-ci` at the G1 merge SHA.

```bash
export CI_TAG=d70782e7fc21c3a35bad287097d74cd99fd9241e
bash install/install.sh vladm3105/aidoc-flow-feedback-desk --visibility private
```

**Expected — GREEN:**

- `==> using CI_TAG=d70782e7fc21c3a35bad287097d74cd99fd9241e (source: env)` — confirms the pin, not the fallback.
- Every template fetch returns 200 — **no `404`, no `FAIL`**. (F1: the pre-`ci/v2.2.0`
  `ai-review-${VISIBILITY}.yml` 404 must not recur.)
- `composition-private.yml` and `pre-commit.yml` are written and resolve (F2).
- `.pre-commit-config.yaml` is created from the canon fragment carrying the
  `# CANON: aidoc-flow-ci pre_push_check v2` marker (F3), and
  `install/check-precommit-hooks.sh` on it reports ≥1 pre-commit-stage hook.
- The run reaches **"creating canonical labels"** and creates all 18 without a
  masked 409.
- The final next-steps block prints, including the runner-pool probe and the
  `litellm_allow_insecure_http` HTTP note — **printed, not aborting** the script.
- **NEW this release (FT-39):** an empty/HTML template fetch now fails loud
  instead of writing a 0-byte file. A clean run must show no such failure; if one
  fires, the fetch source is wrong (check `CI_TAG` and network), not the installer.

**On Part-A green:** the FT-30 gate is satisfied. Proceed to tag:

```bash
# from aidoc-flow-ci main, after the prep PR merged and VERSION reads ci/v2.12.0
bash scripts/release.sh tag ci/v2.12.0 --dry-run-verified
```

**If Part A is red:** capture the failing line; do **not** tag. The installer
fixes are Workstream A — a red here means a G1 fix regressed or `CI_TAG` was wrong.

---

## Part B — arm feedback-desk's gates GREEN (onboarding; NOT a tag gate)

feedback-desk is private, so its CI cannot go green until the fleet Phase-0 infra
exists for it. These are the same 🔴 prereqs tracked in PLAN-009 Phase 0; none
exist for this repo yet. **Never substitute `ubuntu-latest` on a private repo to
avoid them** — that is an OPS-0049 billing-exposure + policy violation; the fix is
to register the pool.

1. **Self-hosted runner pool.** Register a
   `["self-hosted","ci-runner","single-use"]` pool for feedback-desk
   (`../operations/scripts/ci-runner/run-ephemeral.sh`; run N≈6-8 parallel
   instances so an ~8-job PR fan-out doesn't serialize). Without it every job
   queues forever.
2. **Per-repo LiteLLM secrets.** Set `LITELLM_BASE_URL`
   (`http://172.17.0.1:4001`), `LITELLM_REVIEW_API_KEY`, `LITELLM_FIX_API_KEY`
   (mint per `install/set-litellm-secrets.sh` / the LiteLLM proxy runbook). There
   is no org inheritance — `vladm3105` is a personal account, so this is per-repo.
3. **Arm the reviewer App.** Set `vars.APP_REVIEWER_1_BOT_ID` (numeric bot id) +
   the App secrets (`APP_REVIEWER_1_ID/KEY`, `APP_AUTOFIX_ID/KEY`,
   `AI_REVIEW_TOKEN`). **Until this is set, `composition` is INERT and — per
   PLAN-019 FT-43 — a label/draft event on a `request_changes` PR can flip
   `ai-review` green.** Arm this before relying on feedback-desk's gate, or before
   opening real PRs against it.
4. **Branch protection** (product tier): apply
   `install/templates/branch-protection-product.json` once the required contexts
   have producers (use `install/required-context-map.py` to confirm every required
   context has an installed caller — the FT-45 wizard-preflight §6 check).
5. **Merge the onboarding PR** that Part A's `install.sh` opened.

---

## Teardown / note

Part A is real onboarding, not a throwaway — feedback-desk keeps the installed
files. If instead you want a pure throwaway FT-30 validation (no real repo
touched), point `install.sh` at a scratch repo with the same
`export CI_TAG=d70782e7fc21c3a35bad287097d74cd99fd9241e` and delete it after; Part A's GREEN criteria are
identical. Either satisfies the tag gate; only the feedback-desk run also advances
its onboarding.

## Provenance

PLAN-019 §6 (READY 2026-07-23, verified-planning 3 passes / 2 independent). The
underlying installer fixes (FT-39) are Workstream A / G1. FT-30 origin:
PLAN-018 RELEASE_CHECKLIST cold-start gate.
