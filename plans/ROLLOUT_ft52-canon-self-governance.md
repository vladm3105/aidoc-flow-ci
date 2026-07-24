# ROLLOUT — PLAN-019 FT-52: canon self-governance (branch protection + immutable `ci/v*` tag ruleset)

> ## ✅ EXECUTED 2026-07-24 — both parts are LIVE. Do not re-run.
>
> Run at the founder's explicit in-session direction ("let's do this part: FT-52
> Part A + Part B"), after `ci/v2.12.0` was cut — the ordering §4 asks for.
>
> - **Part A — immutable `ci/v*` tag ruleset:** LIVE. Ruleset id `19687369`,
>   `enforcement: active`, `bypass_actors: []`, rules `deletion` +
>   `non_fast_forward` on `refs/tags/ci/v*`. **Verified by execution:** tag
>   *creation* still ALLOWED (release flow intact), *deletion* REJECTED,
>   *force-move* REJECTED; `ci/v2.12.0` still resolves to `0c743f5`.
> - **Part B — branch protection on `main`:** LIVE with canon's own 5-check set
>   (`suite`, `call / verify`, `call / markdownlint`,
>   `call / Lint / format / security hooks`, `call / gitleaks`),
>   `required_approving_review_count: 0`, `enforce_admins: false`,
>   `required_signatures: false`, force-push + deletion blocked. `ai-review` /
>   `composition` deliberately NOT required (canon does not self-run them —
>   requiring them would hang every PR, F2).
> - **Known residue:** the throwaway verification tag `ci/v0.0.1-ruletest` is still
>   on the remote. It is inert — not a GitHub Release, and it sorts below
>   `ci/v2.12.0` so `tests/test_version_sync.sh`'s `LATEST_TAG` is unaffected
>   (verified green). Removing it requires temporarily setting the ruleset to
>   `enforcement: disabled` (`PUT /repos/.../rulesets/19687369`), deleting the tag,
>   and re-enabling — a deliberate founder action, left undone on purpose.
>
> The original 🔴 framing is preserved below for the record.

> 🔴 **Founder-executed.** Every step writes to `vladm3105/aidoc-flow-ci`'s own
> server-side settings (branch protection + rulesets) — 🔴 per the operations
> autonomy tiers. The AI prepared + verified this **read-only**; it does **not**
> run it in-session (writes-to-repo-settings-inbox-first rule).
>
> **Deliverable of FT-52 is this runbook, not its execution.** A short pointer
> belongs in `operations/ops/inbox/` (the established pattern — cf. the
> FLEET_BRANCH_PROTECTION_ARMING inbox item); adding it there is itself a 🔴
> cross-repo write, so the founder (or an operations-repo session) files it.

## 0. The gap (verified live 2026-07-23)

- `GET repos/vladm3105/aidoc-flow-ci/branches/main/protection` → **404 "Branch not
  protected"** — canon `main` has **no branch protection at all**.
- `GET repos/vladm3105/aidoc-flow-ci/rulesets` → **`[]`** — **no tag ruleset**, so
  a `ci/v*` release tag can be **deleted or moved** by anyone with push.
- Yet canon's own `install/templates/branch-protection-product.json:1` names
  `aidoc-flow-ci` a **product-tier** repo. Canon does not govern itself to the
  standard it ships — the pre-prod review's S1 finding.

**Why the tag ruleset is the higher-value half:** the entire fleet pins canon by
**mutable tag** (`uses: …/aidoc-flow-ci/…@ci/vX.Y.Z`). Nothing today stops a
`ci/vX.Y.Z` tag from being force-moved to a different commit — every consumer
would silently execute the new tree on its next run. An immutable-tag ruleset is
the *actual* mitigation for that trust; it matters more than canon's branch gate.

## 1. ⚠️ Do NOT apply `branch-protection-product.json` verbatim

The product template requires `call / ai-review` and `call / composition`. **Canon
does not self-run those reusables** (it is a library — FT-23; there is no
self-hosted pool and no `ai-review`/`composition` self-caller). If those contexts
are set required, **every canon PR hangs forever** waiting for a check that is
never reported — the exact F2 hang `install/required-context-map.py` exists to
catch. Use **canon's own produced check set** below instead.

Canon's `main`-PR checks (verified live — the set to require):

- `suite`
- `call / verify` (audit-trail)
- `call / markdownlint`
- `call / Lint / format / security hooks` (pre-commit)
- `call / gitleaks`

## 2. Part A — the immutable `ci/v*` tag ruleset (do this first; highest value)

Create a tag ruleset that **blocks deletion and non-fast-forward (move)** of any
`ci/v*` tag, while still allowing **creation** of new release tags:

```bash
gh api -X POST repos/vladm3105/aidoc-flow-ci/rulesets \
  -H "Accept: application/vnd.github+json" \
  --input - <<'JSON'
{
  "name": "immutable ci/v* release tags",
  "target": "tag",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["refs/tags/ci/v*"], "exclude": [] } },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" }
  ]
}
JSON
```

- `deletion` blocks `git push --delete origin ci/vX.Y.Z`.
- `non_fast_forward` blocks force-moving an existing tag to another commit.
- **No `creation` rule** — cutting a *new* `ci/vX.Y.Z` (the release flow) stays
  allowed.
- **No `bypass_actors`** — immutability with an admin bypass is not immutability.
  If a genuine mistake must be undone, the founder can temporarily set
  `enforcement: "disabled"`, fix, and re-enable.

**Verify:**

```bash
gh api repos/vladm3105/aidoc-flow-ci/rulesets --jq '.[] | {name, target, enforcement}'
# expect: immutable ci/v* release tags | tag | active
# then prove it bites (throwaway):
git tag ci/v0.0.1-ruletest && git push origin ci/v0.0.1-ruletest   # creation: allowed
git push --delete origin ci/v0.0.1-ruletest                        # MUST be REJECTED by the ruleset
git tag -d ci/v0.0.1-ruletest
```

(If the create-then-delete test tag can't be deleted remotely because the ruleset
works, delete it locally and leave the remote one — or disable→delete→enable. A
lingering `ci/v0.0.1-ruletest` is harmless; it is not a release tag.)

## 3. Part B — branch protection on canon `main` (canon's own check set)

Apply protection requiring **only the checks canon produces** (§1). Do NOT use
`apply-standards.sh --apply --tier product` here — that would install the
product-tier contexts including `ai-review`/`composition` and hang canon. Set it
directly:

```bash
gh api -X PUT repos/vladm3105/aidoc-flow-ci/branches/main/protection \
  -H "Accept: application/vnd.github+json" \
  --input - <<'JSON'
{
  "required_status_checks": {
    "strict": false,
    "contexts": [
      "suite",
      "call / verify",
      "call / markdownlint",
      "call / Lint / format / security hooks",
      "call / gitleaks"
    ]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 0
  },
  "restrictions": null,
  "required_linear_history": false,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON
```

Notes / compatibility with the AI auto-merge flow:

- `required_approving_review_count: 0` — keeps the AI's `gh pr merge --squash`
  auto-merge working (no human-review gate); the checks above are the real gate.
- `enforce_admins: false` — canon commits are AI-authored and **unsigned**; do NOT
  add a `required_signatures` ruleset here (it would break every AI merge, the
  umbrella's `--admin` problem). Leaving admins un-enforced also lets the release
  flow's known one-red self-pin prep run (FT-21) merge with `--admin` when needed.
- Do **not** require `call / ai-review` / `call / composition` — canon doesn't
  produce them (they would hang). If canon ever gains a self-hosted pool + ai-review
  self-caller, add them then.
- **Expected policy tightening (by design):** making `call / verify` required
  hard-enforces the OPS-0069 audit-trail-phrase gate on every canon PR (today it is
  advisory here), and `call / markdownlint` becomes merge-blocking (canon passes it
  green today, so safe). Both are intended. Neither can permanently stick a PR — the
  `verify`/audit-trail flow honours the `skip-audit-trail` label, and markdownlint is
  fixable in the PR.
- The bare top-level `gitleaks` check (from `secret-scan.yml`'s job, distinct from
  `call / gitleaks`) is intentionally NOT required — it runs advisory-only; requiring
  only `call / gitleaks` is sufficient and never hangs.

**Verify:**

```bash
gh api repos/vladm3105/aidoc-flow-ci/branches/main/protection \
  --jq '{checks: .required_status_checks.contexts, reviews: .required_pull_request_reviews.required_approving_review_count, admins: .enforce_admins.enabled}'
# open a throwaway PR; confirm the 5 checks run + are required, and that a
# green PR still auto-merges (gh pr merge --squash) with 0 required reviews.
```

## 4. Ordering + gating

- **Part A (tag ruleset) is independent** and can be done any time — it is the
  higher-value mitigation; do it first.
- **Part B (branch protection)** should be applied **after** `ci/v2.12.0` is cut,
  or with the knowledge that it interacts with the release flow: the FT-21 prep PR
  is expected-red on its self-pins until the tag exists, and with `main` protected
  that prep would need an `--admin` merge (`enforce_admins: false` above permits
  it). Simplest: apply Part B once the current release cycle is complete.
- Neither part gates the `ci/v2.12.0` tag cut itself. FT-52 is **G4** (before/with
  the fleet rollout), not a tag-cut blocker.
