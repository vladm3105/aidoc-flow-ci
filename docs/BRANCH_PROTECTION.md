# Branch protection — required checks

`install.sh` drops the workflow callers, but **nothing is enforced until
the checks are marked required** in branch protection. A consumer that
installs the callers and stops there has CI running and green/red — but a
PR can still merge with a red or missing `ai-review`. This doc is how to
close that gap.

## The check names

Consumer callers invoke the reusables via a `jobs.call:` job, so a
reusable's job renders as **`call / <job-name>`** in the checks list:

| Required context | Comes from | Gates |
|---|---|---|
| `call / ai-review` | `ai-review.yml` | the AI review verdict |
| `call / composition` | `composition.yml` | that the App's approval is COUNTED (identity gate) |
| `call / verify` | `audit-trail.yml` → `audit-trail-check.yml` | the OPS-0069 audit-trail phrase |
| `call / Lint / format / security hooks` | `pre-commit.yml` (**bootstrapped**) | mechanical hygiene |
| `call / gitleaks` | `secret-scan.yml` (adopted) | leaked-credential scan |

`ai-review` + `composition` are a **pair** — require both, or neither
(a required `ai-review` with a non-required `composition` lets an
App-approved-but-uncounted PR merge; the reverse blocks every PR since
nothing produces the counted approval).

## Required checks per tier

Two things to hold in mind: `docs/REPO_STANDARDS.md` §2 states the
**target** baseline, and the shipped `branch-protection-<tier>.json`
templates are what `--apply` actually PUTs today. They currently differ
on **`call / verify`** — see the note below the table.

| Tier | What the shipped template requires today | §2 target adds |
|---|---|---|
| **Governance** (public) | `call / ai-review`, `call / composition`, `call / Lint / format / security hooks` | `call / verify` |
| **Product** (public) | above **+** `call / gitleaks` | `call / verify` |
| **Ops** (private) | `call / ai-review`, `call / composition`, `call / Lint / format / security hooks`, `call / gitleaks` | `call / verify` |
| **Umbrella** (private) | **none** — submodule-pointer repo; `required_status_checks: null` by design. `call / verify` runs **advisory** only; do not add it. Merges use `--admin` (OPS-0062). | — |
| **Bootstrap** | `call / Lint / format / security hooks` | `call / verify` deferred until the repo adopts the CI reusable (per §14.3) |

> **`call / verify` reconciliation.** REPO_STANDARDS §2 lists
> `call / verify` in the baseline, but the `branch-protection-{governance,
> product,ops}.json` templates predate that amendment and omit it — so
> `--apply` will NOT add it yet, and a subsequent `--check` reports it as
> drift. This is deliberate-safe: **only require a check the repo's
> workflows actually emit.** Add `call / verify` to a repo's required
> contexts *after* it adopts the `audit-trail` caller (per its §14.3 Wave),
> not before — requiring a check that no workflow emits blocks every PR
> forever. (Reconciling the templates with §2 is tracked in
> `plans/FRAMEWORK-TODO.md`.)

## Applying it

### Preferred — `apply-standards.sh --apply` (canon templates)

The canon branch-protection profile per tier ships as
`install/templates/branch-protection-<tier>.json`
(`governance` / `product` / `ops` / `umbrella` / `bootstrap`).
`apply-standards.sh --apply` PUTs the right profile (backup-before-mutate,
refuses mutable `main` canon without `--allow-main-canon`):

```bash
CI_TAG=ci/v3.0.0 bash <(curl -fsSL https://raw.githubusercontent.com/vladm3105/aidoc-flow-ci/ci/v3.0.0/install/apply-standards.sh) \
  --repo <owner>/<repo> --tier <governance|product|ops|umbrella|bootstrap> --apply --yes
```

- **`CI_TAG=ci/v3.0.0`** pins which canon the script applies. Without it,
  `apply-standards.sh` resolves the tag from the *cwd's* workflow pins and
  falls back to `main` — and `--apply` **refuses `CI_TAG=main`** (mutable
  canon), so a run from a scratch or not-yet-adopted repo would exit 2. The
  URL tag only selects which script is fetched; the env var sets the canon.
- **`--yes`** skips the interactive confirmation — required in a non-TTY
  (CI/piped) shell; drop it to get the interactive prompt.

Run `--check` first (non-mutating) to see the current drift, then
`--apply`. `--apply` is an admin action with F5 blast-radius — founder
runs it.

### Manual — `gh api` (⚠️ full replace)

`PUT …/branches/<branch>/protection` **replaces the entire protection
object** — it is not additive. A partial body silently drops every
setting you omit: posting only `required_status_checks` with
`required_pull_request_reviews: null` would **wipe the CODEOWNERS +
human-approval gate** the canon templates set (governance requires
`require_code_owner_reviews: true` + `required_approving_review_count: 1`).
Prefer `--apply` above. Use manual `gh api` only when you must, and send a
**complete** payload built from the tier's canon template:

```bash
# Read the current protection first (so you know what you'd overwrite):
gh api repos/<owner>/<repo>/branches/<branch>/protection

# Build the full payload from the tier's canon template, then PUT it.
# (The template is the same JSON --apply uses; edit the contexts array if
#  you are adding call/verify after audit-trail adoption.)
curl -fsSL https://raw.githubusercontent.com/vladm3105/aidoc-flow-ci/ci/v3.0.0/install/templates/branch-protection-<tier>.json \
  | gh api -X PUT repos/<owner>/<repo>/branches/<branch>/protection \
      -H "Accept: application/vnd.github+json" --input -
```

Use the repo's **actual default branch** (not hardcoded `main`). The
canon templates set `strict: false` and `enforce_admins: true` — keep
those unless you have a documented reason to diverge (a `--check` will
flag any drift from the template).

> **Two documented exceptions to `enforce_admins: true`, both deliberate.**
> This paragraph used to state the rule without them, so it instructed
> operators to "keep" a value canon itself inverts, and promised a drift check
> that was explicitly taught not to fire.
>
> - **The umbrella tier** ships `enforce_admins: false`
>   (`install/templates/branch-protection-umbrella.json`) because `--admin`
>   merge *is* the intended bypass path there: the umbrella requires signed
>   commits and AI commits are unsigned.
> - **Promotion branches under the three-branch model.** If a repo declares
>   `dev` → `staging` → `main` in `.github/aidoc-ci.json`, `apply-standards.sh`
>   overlays `enforce_admins: false` on each declared promotion branch — per
>   CI-0048 that is the only mechanism on a user-owned account that permits the
>   fast-forward promotion push at all, and `bypass_pull_request_allowances`
>   returns 422. `check-standards-drift.sh` applies the same overlay to the
>   canon side, so this does **not** report as drift. The cost is stated
>   plainly in CI-0049: on those branches the gate is **advisory for admins,
>   not enforced**.
>
> Neither exception applies to a repo that has not adopted the promotion model,
> which as of `ci/v4.0.0` is every repo including canon. Read
> [`BRANCHING.md`](BRANCHING.md) §8 before adopting — §8c's step order is
> load-bearing, and `apply-standards.sh` refuses the wrong order outright.

## Verifying

```bash
# What's currently required:
gh api repos/<owner>/<repo>/branches/<branch>/protection \
  --jq '.required_status_checks.contexts'

# Full drift vs canon for the tier (CI_TAG pins the canon compared against):
CI_TAG=ci/v3.0.0 bash <(curl -fsSL https://raw.githubusercontent.com/vladm3105/aidoc-flow-ci/ci/v3.0.0/install/apply-standards.sh) \
  --repo <owner>/<repo> --tier <tier> --check
```

`check-standards-drift.sh` (or `apply-standards.sh --check`) reports
`branch-protection.contexts: canon=[…] actual=[…]` when they diverge —
warning-only, so it never blocks, but it's the signal that a repo's
required checks drifted from its tier's canon.

## Related

- [`REVIEWER_APP_ONBOARDING.md`](REVIEWER_APP_ONBOARDING.md) — arm the App
  first, or `call / composition` can never resolve SUCCESS on a routine PR.
- `docs/REPO_STANDARDS.md` §2 (required checks) + §14.3 (`call / verify`
  tier coverage).
- `install/templates/branch-protection-*.json` — the per-tier canon
  profiles.
