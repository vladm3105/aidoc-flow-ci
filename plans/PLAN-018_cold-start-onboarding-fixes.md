# PLAN-018 — cold-start onboarding fixes: make a fresh private adopter's bootstrap actually work

> Status: **NOT READY — 3-pass circuit-breaker tripped (OPS-0066).** Pass 3
> folded 2026-07-21 but still returned load-bearing findings, so no fourth
> independent pass was dispatched. Two open items need a founder decision before
> this executes — see §7. Owning repo: `aidoc-flow-ci`.
> Source: pre-prod review of `ci/v2.10.0` against onboarding the new private repo
> `vladm3105/aidoc-flow-feedback-desk` (zero workflows, zero secrets, zero vars,
> zero runners). Scope: **6 fixes + 1 release-note item** — no speculative
> additions. Target release: **`ci/v2.11.0`** (MINOR — see §5).

## 1. Problem

Every consumer in the fleet adopted canon **before `ci/v2.2.0`**. Since then the
cold-start path — `install.sh` on a repo with no prior canon surfaces — has had
no exerciser. Nine releases of drift accumulated in exactly the code path a new
adopter is the first to touch, and three independent defects now make a
by-the-book bootstrap fail without emitting an error a founder could act on.

The defects are not one bug with three symptoms; they are three separate
regressions that happen to share a blind spot:

- **F1 kills the run outright** — the documented one-liner 404s on its first
  template fetch.
- **F2 + F3 survive the run and produce a gate that is structurally incapable of
  gating** — a required context no installed workflow emits, and (if that were
  fixed) a hook config that selects zero hooks and exits 0.

F4/F6/F7 are operator-facing defects that mislead rather than block. F5 is a
release-sequencing item only.

**Explicit non-goals.** The founder-side 🔴 provisioning (runner pool, LiteLLM
secrets, reviewer App) is correctly documented and correctly reported by
`deploy-ci-wizard.sh preflight`; this plan does not automate it, and F4 only
makes `install.sh` *say* what preflight already says. The general
"required check that inspects nothing" guard is **deferred** — see F3.

## 2. The fix contract (what must be true when this is done)

1. `bash install.sh <owner/repo> --visibility private` — the exact command in
   `install/README.md`, **with no `--tier`** — completes end-to-end on a repo
   with no pre-existing canon surfaces, and so does the `--visibility public`
   form.
2. `call / Lint / format / security hooks` — a required context on **every tier
   that has required status checks at all**, i.e. all but umbrella, which has
   none by design (claim 8) — has a producing workflow that `install.sh`
   installs, on every entrypoint including the no-`--tier` default.
3. No **canon-installed** config yields a required check that inspects nothing.
   (Scoped deliberately: a consumer's own pre-existing hook config can still
   produce a vacuous pass, and the general guard for that is deferred — F3.)
4. `install.sh`'s printed next-steps name every prerequisite whose absence
   causes a hang or a hard failure — including the two it currently omits.
5. Template and script defaults match the intent stated in their own header
   comments; no fallback silently pins a stale tag.
6. **No behavioural change for existing consumers** — no already-passing
   required check may start failing *or start passing more weakly* on re-pin or
   `--update`, and no installed surface may diverge from its canon template
   (which `--update` would then revert).

## 3. Per-fix design

### F1 (BLOCKER) — `install.sh` bootstrap loop fetches a template deleted at `ci/v2.2.0`

The loop at `install/install.sh:458` iterates `ai-review composition` and builds
`workflows/${wf}-${VISIBILITY}.yml` for both (claim 1). PLAN-013 unified
`ai-review` into a single protected template with no visibility split — the
manifest records this explicitly (claim 3) — so only `composition` still has
variants (claim 4). Verified live against the tag:
`install/templates/workflows/ai-review-private.yml` → **404**,
`ai-review.yml` → 200.

`fetch_template` returns 1 on a failed `curl` (claim 2) and the call site is
`|| exit 1`, so the script dies **before** config.json, CODEOWNERS, CLAUDE.md,
`pre_push_check.sh`, the pre-commit merge, and all 18 labels.

**Fix — deliberately not manifest-driven.** The obvious sketch ("resolve from
manifest.json, like `update_mode` does") is wrong: `manifest.json` is fetched
**only inside `update_mode`** (claim 5), which returns before the bootstrap loop
is ever reached (claim 6). Wiring it into bootstrap would add a network fetch, a
`python3` parse, and a new hard-failure mode (bootstrap dies on an unfetchable
manifest) that the cold-start path does not have today — new machinery to fix a
hardcoded string.

Instead, name each bootstrapped workflow's template **explicitly**. There are
three naming shapes in play, not two, and the third is what makes an implicit
convention unsafe:

| Workflow | public template | private template |
|---|---|---|
| `ai-review` | `workflows/ai-review.yml` | same (no variants — claim 3) |
| `composition` | `workflows/composition-public.yml` | `workflows/composition-private.yml` (claim 4) |
| `pre-commit` (added by F2) | `workflows/pre-commit.yml` | `workflows/pre-commit-private.yml` (claim 7) |

`pre-commit` is **asymmetric**: the public variant is the bare name, so an
implementer generalising from `composition` writes `pre-commit-public.yml` and
reproduces F1 for every public adopter. The README already flags this shape
("where both exist", claim 9) — the installer must encode it, not infer it.

**Regression cover — respecified.** The obvious test ("every `auto_install: true`
manifest entry's template exists") **would not have caught F1**: the ai-review
entry resolves to `workflows/ai-review.yml`, which exists and always did. The
manifest was never wrong; `install.sh:462` was. The test must:

1. statically extract the template paths `install.sh` passes to
   `fetch_template`, expanding `VISIBILITY` to both values, and assert each
   resolves under `install/templates/`; **and**
2. assert those literals equal the manifest's `visibility_variants` resolution
   for the same consumer paths — closing the drift class this fix *creates* by
   hardcoding names in the installer while leaving the manifest as the
   documentation authority. Without (2) a future edit naming an existing-but-
   wrong variant (`composition-public.yml` on a private install) passes.

**Implementation constraint, load-bearing for the test:** the template path must
remain a **literal at the `fetch_template` call site** (a `case` branch or inline
conditional). The equally natural associative-array form (`TEMPLATES[$wf]`) makes
the argument a variable and renders the static extraction unwritable as
specified. PR-A states this constraint in the test's header comment so a later
refactor does not silently disarm it.

### F2 (BLOCKER) — the required lint context has no producer

`install.sh` auto-installs exactly `ai-review` + `composition` (claim 1); the
manifest's `auto_install: true` set adds config.json, CODEOWNERS,
`pre_push_check.sh`, CLAUDE.md — **`pre-commit.yml` is not in it** (claim 10).
Yet `call / Lint / format / security hooks`, emitted by the `pre-commit` caller,
is a required status check on **every tier that has required checks at all** —
all but umbrella, which deliberately has none (claim 8) — and is the bootstrap
tier's *only* required context (claim 11). Arming
protection after a successful install therefore pins every PR on *"Expected —
Waiting for status to be reported"* forever.

**Fix — narrow and additive.** Add `pre-commit` (its caller per the F1 table +
the `.pre-commit-config.yaml` from F3) to the bootstrap install set,
**unconditionally**, not gated on `--tier`. `TIER` defaults to `""` and the
README's documented one-liner passes none (claim 12), so a tier-gated fix would
leave fix-contract item 1 undefined — the primary documented path. Because the
context is required on every tier that requires anything, unconditional
installation is the minimum that satisfies any of them. The umbrella tier is the
one exception (no required checks at all), where the installed caller is simply
advisory — additive, not harmful.

**What this fix deliberately does NOT do:** it does not make the installer
tier-aware, nor extend the install set to the union each tier's protection
template requires. `manifest.json:42` records the opposite as a design decision
— `auto_install=false` is intended for every non-bootstrap surface, with
adoption via `deploy-ci-wizard` (claim 13). A "union" fix would have a
governance/product/ops bootstrap install five workflows plus their configs. That
is a redesign, not this finding's fix.

**Doc surfaces this falsifies (all corrected in the same PR, per LB-6):**
`manifest.json`'s `auto_install: false` on the pre-commit entry (claim 14);
`install/README.md`'s "the additional caller templates … `pre-commit.yml` … are
**not** bootstrapped automatically" (claim 15); and `install/README.md`'s step 2,
"**Drops the default callers** `ai-review.yml` + `composition.yml`
(per-visibility templates)" (claim 46) — which F2 falsifies on the caller *list*
and F1 falsifies on "per-visibility" (already wrong today for `ai-review`).
Leaving any of these to a later PR would have the installer's own README
documenting the opposite of what it does.

Separately, `verify_standards` should distinguish "required context has no
producing workflow" from generic drift, so this class is caught at install time
rather than at first-PR time. Scoped to a report-string change; no new checks.

### F3 (BLOCKER) — the canon pre-commit fragment yields a green check that lints nothing

On a repo with no `.pre-commit-config.yaml` (true for feedback-desk),
`install.sh` copies `pre-commit-hook-block.yaml` verbatim. That fragment's only
hook is `aidoc-flow-pre-push` with `stages: [pre-push]` (claim 16). The reusable
runs `pre-commit run --all-files` with **no** `--hook-stage` when `run-stage` is
empty (claim 17, the default), which selects the `pre-commit` stage — zero hooks
match, exit 0. So the one check the bootstrap tier makes *required* passes while
inspecting nothing. On `operations` this is masked by a pre-existing rich
config; a fresh adopter gets the vacuous case **by construction**.

**Fix:** ship commit-stage hooks in the canon fragment — `check-yaml`,
`end-of-file-fixer`, `trailing-whitespace` from `pre-commit-hooks`. Meaningful
on a docs/schema repo, and the standard choice.

**Two honest costs, stated rather than glossed:**

- This *is* a new dependency. The fragment today is `repo: local` only (claim
  18) — no network, no third-party `rev` to maintain. After this it has both.
  Accepted because the alternative (a local-only lint hook) means canon
  maintaining its own linters.
- The merge path dedups by whole-entry structural equality (claim 19), so a new
  adopter who *already* uses `pre-commit-hooks` at a different `rev` gets a
  second `repos:` entry for the same repo. PR-B's merge step must dedup by repo
  URL, not whole entry, or explicitly report the collision.

**Contract item 6 — first clause holds, second clause does NOT.** No existing
consumer *receives* the new hooks: `install.sh` no-ops on the `CANON:` marker
(claim 20), `update_mode` excludes `.pre-commit-config.yaml` entirely (claim 21),
and the wizard never writes that file. So no already-passing check starts
failing.

But `apply-standards.sh` subset-checks the consumer's `.pre-commit-config.yaml`
against this very fragment (claim 44), requiring **every** non-comment canon line
to appear verbatim (claim 45). Adding a `repo:`, a `rev:`, and three `- id:`
lines therefore flips **every already-adopted consumer to permanent DRIFT** on
that file — permanent precisely because the two paths above are the ones that
would otherwise repair it, and `--apply` is server-side-settings-only. No
workflow invokes `apply-standards.sh`, so this is a reporting surface, not a
gate. It is nonetheless a real fleet-wide cost that contract item 6's second
clause forbids, and it is **open item OI-1 in §7** — a founder call between
exempting the new entry from `subset_check` and accepting drift plus per-repo
hand-remediation.

**Deferred, with the reason stated:** the first draft also proposed making the
reusable *fail when zero hooks are selected* — the general fix for this class.
Dropped. `pre-commit run` exits 0 and prints nothing when no hook matches the
stage; there is no exit code or flag distinguishing that from "all hooks
passed", so the only implementation is an output-emptiness heuristic. Worse, it
is a behavioural change to a reusable existing consumers already call: any
caller passing `run-stage: manual` (claim 22) whose config has no `manual` hooks
would flip from pass to fail on re-pin — a direct violation of contract item 6.
Filed as a FRAMEWORK-TODO entry carrying the mechanism problem, not smuggled
into a cold-start fix. This is also why contract item 3 is scoped to
canon-*installed* configs.

### F4 (HIGH) — `install.sh` next-steps omit two prerequisites that hang or hard-fail

The next-steps block (claim 23) lists the five secrets, the bot-id var, branch
protection, and cleanup. It never mentions:

- **the runner pool — and the probe must be visibility-INDEPENDENT.** Private
  callers pin `["self-hosted","ci-runner","single-use"]`, but so does the
  visibility-uniform ai-review template that a **public** cold-start adopter now
  also receives (claim 28), so a public repo with no pool gets permanently-queued
  `trust`/`review` jobs too — the wizard already warns for PUBLIC. With no
  registered pool every job sits Queued; GitHub's `timeout-minutes` starts at job
  *start*, so the 10–45 min timeouts never fire — permanently pending checks, no
  error anywhere. `deploy-ci-wizard.sh preflight` catches this; `install.sh`, the
  path the README documents first, does not. **Do not gate the probe on
  `VISIBILITY=private`** — that would reproduce the exact anti-pattern this
  fix's second correction forbids.
- **`litellm_allow_insecure_http`.** `litellm_client.py` hard-fails unless the
  scheme is HTTPS or the flag is set (claims 24, 25), and the flag ships
  commented out in the caller template (claim 26). The workspace's only proxy is
  HTTP on the docker bridge, so adopters of it need the flag.

**Fix — output only.** Add a runner-pool probe (the same
`gh api repos/$REPO/actions/runners` query the wizard uses) as step 0 of the
next-steps list, and name the HTTP flag alongside the LiteLLM secrets.

**Two corrections to the first draft's sketch**, both load-bearing:

- It proposed having `install.sh` *uncomment* the flag post-fetch. That breaks
  contract item 6: `.github/workflows/ai-review.yml` is `safe_to_replace: true`
  (claim 27), so the installed caller would diverge from canon, `--update` would
  report it as drift, and `--update --non-interactive` would silently re-comment
  it — re-breaking ai-review on every private consumer. It is also outside
  install.sh's only sanctioned template-mutation mechanism (the declared-
  placeholder substitution with its fail-closed assertion).
- It gated the flag on `VISIBILITY=private`. The ai-review template is
  visibility-uniform by design and pins the self-hosted pool for public repos
  too (claim 28), so a public adopter reaching the same bridge needs it as well
  — the visibility branch would reproduce exactly the anti-pattern F6 fixes.

Whether canon should instead ship the flag **enabled by default** is a security
default, and belongs in `DECISIONS.md` as its own entry — not a side effect of
this plan.

### F5 (release-note item, not a cold-start fix) — the `docs-sync` permission fix is in no tag

`install/templates/workflows/docs-sync.yml` now grants `pull-requests: write`
with the reasoning inline (claim 29), but that fix sits in `## Unreleased`
(claim 30). At `ci/v2.10.0` the shipped template grants `read`, so the dry-run
path's `gh pr comment` 403s exactly when it has something to report.

**Scope correction:** this does **not** affect the cold-start path this plan
scopes. `docs-sync` is `auto_install: false` (claim 31) and the wizard states it
is legacy and should not be co-installed on new v2 adopters (claim 32). It is a
consumer-facing release note for **already-adopted** repos, which is where the
403 has been silently occurring. No code change; ships with the tag.

### F6 (MEDIUM) — `markdown-lint` report-only is injected for public adopters only

The reusable defaults `fail-on-findings: true` (claim 33). The wizard injects
`fail-on-findings: false` only inside the `if [ ! -f "$TPL/workflows/$wf-$suffix.yml" ]`
branch (claim 34) — so public adopters (no `markdown-lint-public.yml`) get
report-only, private adopters (a `-private.yml` exists) skip the injection and
ship blocking. Note this is **purely a wizard asymmetry**: both templates ship
the flag commented out and both headers carry the same rollout recommendation
(claim 35), so the defect is not "the private template contradicts its header" —
it is that identical templates receive different treatment based on whether a
variant file happens to exist.

**Fix — the wizard conditional, NOT the template.** The first draft proposed
uncommenting `fail-on-findings: false` in `markdown-lint-private.yml`. Pass 2
established that this would cause a **silent fleet-wide gate downgrade**:
`business`, `iplanic`, and `interlog` all deliberately carry
`fail-on-findings: true   # graduated to blocking (PLAN-007 W3)` (claim 36), and
the caller is `safe_to_replace: true` (claim 37), so
`install.sh --update --non-interactive` would replace those callers with a canon
template that now says report-only — turning three graduated blocking gates back
off with no one asking. That is contract item 6's "start passing more weakly"
clause.

The defect is in the wizard's conditional, which is where the fix belongs: move
the report-only injection out of the `[ ! -f … ]` branch so it applies to a new
adopter of either visibility, leaving the shipped template — and therefore the
fleet's `--update` path — untouched. Graduating a repo to blocking stays FT-11's
per-repo, deliberate act.

**Implementation note (not a one-line move).** The report-only injection shares
one `python3` heredoc — and one guard — with the `runner_labels` injection and
the post-check warning (claim 34 spans the block). PR-C must split the
fail-on-findings path from the labels path, or scope the newly-unguarded run to
`wf == markdown-lint`; otherwise every variant template starts flowing through
the injector. For `markdown-lint-private.yml` specifically the labels path is
inert (labels already active) and the flag is commented, so the injection itself
is safe once scoped.

### F7 (MEDIUM) — `deploy-ci-wizard.sh` silently pins 14 releases back

**The first draft got this backwards and it is corrected here.** The claim was
that the `||` fallback is dead code. It is not: `deploy-ci-wizard.sh:16` sets
`set -euo pipefail` (claim 38), and under `pipefail` a missing or unreadable
`VERSION` makes `cat` exit 1, the pipeline exit 1, and the fallback **fire**.
Verified by executing both cases: missing file → fallback fires; empty file →
`CI_TAG=""`.

So the live defect is the reverse of what was reported, and worse than a
`startup_failure`: the reachable literal is `ci/v1.9.5` (claim 39) while
`VERSION` is `ci/v2.10.0` — 14 releases apart — an unreadable VERSION silently scaffolds callers
pinned **14 releases back**, green and wrong. The narrow `CI_TAG=""` case
(empty/whitespace-only VERSION) does produce the unresolvable `@` pin. Nothing
guards either: `tests/test_version_sync.sh` checks `install.sh`'s
`CI_TAG_FALLBACK` but not the wizard's (claim 40).

**Fix — and the guard must survive `set -e`.** The natural replacement
(`CI_TAG="$(tr -d '[:space:]' < "$HERE/../VERSION" 2>/dev/null)"` followed by a
`[ -n "$CI_TAG" ] ||` guard) **dies before reaching its own guard**: under
`set -e` an assignment whose command substitution exits non-zero terminates the
script, and the `< file` redirection failure is reported before `2>/dev/null`
applies to it. Verified by execution — missing file yields a raw
`No such file or directory` and exit 1, and the guard's message never prints.
Ship:

```sh
CI_TAG="$(tr -d '[:space:]' < "$HERE/../VERSION" 2>/dev/null)" || CI_TAG=""
[ -n "$CI_TAG" ] || { echo "cannot resolve VERSION" >&2; exit 2; }
```

Fail loud, carry no literal. Extend `test_version_sync.sh` to cover the wizard
— asserting the shipped behaviour, including the missing-file case — so a stale
literal cannot reappear. (Cosmetic: the redirection error still reaches stderr
before `2>/dev/null` applies, so the operator sees a raw `No such file or
directory` above the guard's message; reorder to `2>/dev/null < "$file"` to
suppress it.)

## 4. Sequencing

Three PRs, sized to keep each reviewable and to respect the ≤3-doc-surface rule
where governance files are touched:

| PR | Contents | Why grouped |
|---|---|---|
| **PR-A** | F1 (explicit template table) + the respecified two-part regression test | The blocker that kills the run; the test is what makes F1 non-recurring. Lands first — F2/F3 are unobservable until the script survives past line 462. |
| **PR-B** | F2 + F3 + the manifest `auto_install` correction + the `install/README.md` bootstrap-set sentence (+ `REPO_STANDARDS.md` amendment) | Both concern "the required check is real". Meaningless apart: F2 installs the producer, F3 makes it inspect something. The doc corrections ship here because PR-B is what falsifies them. |
| **PR-C** | F4 + F6 (wizard) + F7 (+ remaining `install/README.md` operator text) | Operator-facing correctness: what the installer says, what the wizard writes. No file overlap with A/B. |

F5 requires no PR — satisfied by cutting the tag, with a release note.

**Wave-0 self-adoption (F3).** This repo's own `.pre-commit-config.yaml` already
carries the `CANON:` marker, so the merge path no-ops here (claim 20) and the new
hooks will *not* propagate automatically. PR-B hand-adds them, per the
canon-dogfoods-its-own-canon rule in `CLAUDE.md`.

**Verification gate — 🔴 founder-executed.** Canon cannot self-exercise a cold
start (it is already adopted), so the real gate is a live `install.sh` run
against a throwaway repo. The first draft called this "not a 🔴 cross-repo
write"; that is wrong. `install.sh` clones the target and creates 18 labels on
it (claims 41, 42), and "writes to other repos" is 🔴 Never-autonomous / Human
only under the workspace autonomy tiers (claim 43) — creating the throwaway repo
is itself such a write. So this gate is prepared as an `ops/inbox` runbook and
executed by the founder, exactly like PLAN-017's, and **the `ci/v2.11.0` tag cut
is blocked on it**. The runbook asserts all 8 `install/README.md` steps complete
for **both** visibilities and that the lint context reports a real result.

## 5. Release

**`ci/v2.11.0` (MINOR).** Per this repo's semver rule, breaking changes to
expected consumer surfaces are MAJOR and additive changes are MINOR. As narrowed
by Passes 1–2, every change here is additive or corrective:

- F2 **adds** `pre-commit` + its config to the bootstrap set and removes
  nothing. A bootstrap re-run on an existing consumer (documented as a
  supported refresh path) newly adds the caller to a repo that never adopted it
  — additive, and not a required-check regression, since `--update`/`--repin`
  never add absent surfaces.
- F3 **adds** hooks to the canon fragment, reaching only repos with no config or
  no marker (claims 20, 21); the reusable behaviour change that would have
  broken `run-stage: manual` consumers is dropped.
- F6 now changes **the wizard only**, so the fleet's `--update` path is
  untouched and the three graduated blocking gates stay blocking.
- F1/F4/F7 are fixes to paths that are broken or misleading today; F4 is
  output-only. No consumer depends on the current behaviour of any of them.

`docs/RELEASE_CHECKLIST.md` gains one item: the **cold-start dry-run**, which is
the standing defence against this whole finding class.

## 7. Open items — founder decision required (circuit-breaker stop)

Pass 3 returned load-bearing findings, which under OPS-0066 ends the review loop
rather than triggering a fourth pass. Its mechanical corrections are folded
above. Two items are **not** mechanical and are not mine to decide:

- **OI-1 — F3's fleet-wide DRIFT cost.** Adding third-party hooks to the canon
  pre-commit fragment flips every already-adopted consumer to permanent DRIFT in
  `apply-standards.sh` (claims 44, 45). It is a reporting surface, not a gate,
  but the choice between *exempting the new entry from `subset_check`* and
  *accepting the drift plus per-repo hand-remediation* changes what PR-B ships.
  A third option — keep the fragment `repo: local` and write canon's own lint
  hook — avoids both but grows canon's maintenance surface.
- **OI-2 — the verification gate's `CI_TAG`.** §4's runbook must pin
  `CI_TAG=<merge-sha>` explicitly. Run from merged `main` with no override it
  resolves to `ci/v2.10.0` and fetches the **old** fragment — so the gate would
  "pass" against exactly the vacuous config F3 replaces; run inside the
  bump-then-tag window it names a tag that does not exist yet and 404s every
  fetch. The runbook is founder-executed (🔴), so this instruction must be
  explicit in it rather than inferred at the keyboard.

Also filed to `plans/FRAMEWORK-TODO.md` rather than silently dropped:
`docs/AI_CI_DEPLOYMENT.md` tells hand-copy adopters to use the single generic
template for `pre-commit`/`markdown-lint`/`links`/`labeler`, but all but
`doc-maintainer` gained `-private` variants at `ci/v2.1.0` — the same naming-shape
trap F1 encodes into the installer, sitting in the doc a human follows.

## Claim ledger

| # | Claim | Symbol | Citation |
|---|---|---|---|
| 1 | The bootstrap loop builds a per-visibility template name for BOTH ai-review and composition | `wf}-${VISIBILITY}` | install/install.sh:462 |
| 2 | A failed template fetch returns 1 (and the call site is `\|\| exit 1`) | `fetch_template()` | install/install.sh:255 |
| 3 | The manifest records ai-review as a single template with no visibility variants | `no visibility_variants` | install/templates/manifest.json:23 |
| 4 | composition DOES still have per-visibility variants (so the loop is correct for it) | `visibility_variants` | install/templates/manifest.json:31 |
| 5 | `manifest.json` is fetched at exactly one place, inside `update_mode` | `fetch_template "manifest.json"` | install/install.sh:323 |
| 6 | `update_mode` exits before the bootstrap loop is reached | `if update_mode; then` | install/install.sh:451 |
| 7 | pre-commit's PUBLIC variant is the bare name — there is no `pre-commit-public.yml` | `workflows/pre-commit-private.yml` | install/templates/manifest.json:151 |
| 8 | The tier table makes `call / Lint / format / security hooks` required on every tier EXCEPT umbrella, which has no required checks | `Required status checks (baseline)` | docs/REPO_STANDARDS.md:84 |
| 9 | The README already documents that the variant suffix applies only "where both exist" | `where both exist` | install/README.md:141 |
| 10 | `pre-commit.yml` is a manifest entry but is NOT auto-installed | `.github/workflows/pre-commit.yml` | install/templates/manifest.json:149 |
| 11 | The bootstrap tier requires exactly one context, emitted by the pre-commit caller | `call / Lint / format / security hooks` | install/templates/branch-protection-bootstrap.json:7 |
| 12 | `--tier` is optional and defaults to empty, so the documented one-liner passes none | `TIER=""` | install/install.sh:71 |
| 13 | The manifest records opt-in-via-wizard as the intended model for non-bootstrap surfaces | `adoption is via deploy-ci-wizard` | install/templates/manifest.json:42 |
| 14 | The manifest currently marks the pre-commit caller as not auto-installed | `"auto_install": false` | install/templates/manifest.json:154 |
| 15 | The README currently states pre-commit is NOT bootstrapped automatically | `not** bootstrapped automatically` | install/README.md:138 |
| 16 | The canon pre-commit fragment's only hook is pre-push staged | `pre-push` | install/templates/pre-commit-hook-block.yaml:32 |
| 17 | With an empty `run-stage` the reusable runs without `--hook-stage` (⇒ pre-commit stage) | `pre-commit run --all-files --show-diff-on-failure` | .github/workflows/pre-commit.yml:100 |
| 18 | The canon fragment is `repo: local` only — no third-party dependency today | `repo: local` | install/templates/pre-commit-hook-block.yaml:25 |
| 19 | The merge path dedups by whole-entry equality (so a same-repo/different-rev entry duplicates) | `if canon_repo not in consumer_repos:` | install/install.sh:648 |
| 20 | A consumer whose config carries the CANON marker is a no-op (existing consumers untouched) | `CANON: aidoc-flow-ci pre_push_check` | install/install.sh:579 |
| 21 | `update_mode` excludes `.pre-commit-config.yaml` entirely | `.pre-commit-config.yaml` | install/install.sh:301 |
| 22 | `run-stage: manual` is a documented, supported caller configuration | `run-stage` | .github/workflows/pre-commit.yml:52 |
| 23 | The printed next-steps begin here and never mention the runner pool or the HTTP flag | `Next steps (founder)` | install/install.sh:709 |
| 24 | The LiteLLM client permits `http` only when the allow-flag is exactly `true` | `allow_http` | scripts/litellm_client.py:49 |
| 25 | Otherwise it hard-fails on a non-HTTPS base URL | `must use HTTPS` | scripts/litellm_client.py:51 |
| 26 | The shipped ai-review caller leaves the allow-flag commented out | `litellm_allow_insecure_http` | install/templates/workflows/ai-review.yml:60 |
| 27 | The installed ai-review caller is `safe_to_replace`, so `--update` reverts local edits | `safe_to_replace` | install/templates/manifest.json:25 |
| 28 | The ai-review caller pins the self-hosted pool for public repos too (not private-only) | `runner_labels_review` | install/templates/workflows/ai-review.yml:58 |
| 29 | The docs-sync template on `main` now grants `pull-requests: write` | `pull-requests: write` | install/templates/workflows/docs-sync.yml:38 |
| 30 | That fix is recorded under `## Unreleased`, i.e. in no tag | `## Unreleased` | CHANGELOG.md:6 |
| 31 | `docs-sync` is not auto-installed, so it is outside the cold-start path | `.github/workflows/docs-sync.yml` | install/templates/manifest.json:108 |
| 32 | The wizard states docs-sync is legacy and should not be co-installed on new adopters | `legacy` | install/deploy-ci-wizard.sh:104 |
| 33 | The markdown-lint reusable defaults to blocking | `default: true` | .github/workflows/markdown-lint.yml:64 |
| 34 | The wizard injects report-only ONLY when no per-visibility variant exists | `if [ ! -f "$TPL/workflows/$wf-$suffix.yml" ]` | install/deploy-ci-wizard.sh:135 |
| 35 | Both markdown-lint templates carry the same rollout recommendation, so the asymmetry is the wizard's, not the template's | `fail-on-findings` | install/templates/workflows/markdown-lint.yml:12 |
| 36 | Live private consumers deliberately carry blocking markdown-lint (would be downgraded) | `graduated to blocking` | business/.github/workflows/markdown-lint.yml:26 |
| 37 | The markdown-lint caller is `safe_to_replace`, so `--update` would push the downgrade | `safe_to_replace` | install/templates/manifest.json:145 |
| 38 | The wizard sets `pipefail`, so a failing `cat` DOES trigger the `\|\|` fallback | `set -euo pipefail` | install/deploy-ci-wizard.sh:16 |
| 39 | The reachable fallback literal is 11 releases behind `VERSION` | `ci/v1.9.5` | install/deploy-ci-wizard.sh:20 |
| 40 | The version-sync test covers install.sh's fallback only, not the wizard's | `CI_TAG_FALLBACK` | tests/test_version_sync.sh:35 |
| 41 | `install.sh` clones the target repo (a remote operation on another repo) | `gh repo clone` | install/install.sh:248 |
| 42 | `install.sh` creates labels on the target repo | `gh label create` | install/install.sh:697 |
| 43 | "Writes to other repos" is 🔴 Never-autonomous / Human only | `writes to other repos` | operations/CLAUDE.md:183 |
| 44 | `apply-standards.sh` subset-checks the consumer's config against this exact fragment | `subset_check      ".pre-commit-config.yaml"` | install/apply-standards.sh:432 |
| 45 | `subset_check` requires every non-comment canon line to appear verbatim | `missing_lines=` | install/apply-standards.sh:301 |
| 46 | The README's step 2 describes the default callers as per-visibility templates | `(per-visibility templates)` | install/README.md:107 |
| 47 | Re-running bootstrap is a documented refresh path for labels + the pre-commit config | `Re-run install.sh to refresh those.` | install/templates/manifest.json:12 |

> Claims 36 and 43 are cross-repo; verify with
> `check_plan.py --root /opt/data/aidoc-flow plans/PLAN-018_cold-start-onboarding-fixes.md`.

## Review log

### Pass 0 - 2026-07-21 - author

Drafted from a five-lens pre-prod review of `ci/v2.10.0` scoped to onboarding
`feedback-desk`. Every finding folded was re-verified at source before
inclusion; findings that did not survive verification were dropped rather than
carried as caveats.

Two things that verification changed: **F1's blast radius** —
`git log --diff-filter=D` puts the template deletion at the `ci/v2.2.0` release
commit, so the cold-start path has been broken across nine consecutive tags,
which reframes the regression test as the load-bearing deliverable rather than
the one-line fix. **F2's framing** — the installer and the tier model appeared
to disagree, which Pass 2 later showed was a misreading (see below).

Findings deliberately **not** in this plan, each filed to FRAMEWORK-TODO rather
than silently dropped: the ai-review SHA-pin peel gap (needs repo-write to
exploit; shipped template pins tag-only); `secrets: inherit` on privileged
callers and `can_approve_pull_request_reviews: true` (real hardening, neither
blocks nor degrades an onboarding); `codeql.yml`'s tag-object SHA and missing
GHAS guard (opt-in, and feedback-desk is docs-only); the `labeler.yml` config
gap; preflight's raw-409 display.

Gate run before dispatching review.

### Pass 1 - 2026-07-21 - independent

`verified-planning-reviewer`, fresh context, tasked adversarially against the
fix sketches specifically. Returned **9 load-bearing + 5 minor**. All 14 were
re-verified at source before folding — including one settled by *running* the
construct rather than reading it. None were accepted on the reviewer's word;
none were rejected.

Four findings changed the plan's substance:

- **LB-3 inverted F7.** "The `||` fallback is dead code" was false: `set -euo
  pipefail` (claim 38) makes a failing `cat` propagate, so the fallback fires.
  Confirmed by executing both cases. The live defect is the *reachable* stale
  literal pinning 11 releases back — worse than the `startup_failure`
  originally described. This had survived two prior readings (a review lens and
  my own) because both read the `||` and neither ran it.
- **LB-1 + LB-2 gutted F1's fix and its test.** The manifest is fetched only
  inside `update_mode` (claims 5, 6), so "resolve from the already-fetched
  manifest" would have added a network dependency and a new failure mode to the
  cold-start path. And the proposed test could never have caught F1 — the
  manifest entry it would check was always correct. Both respecified.
- **LB-5 + minor-12 gutted F4's fix.** Uncommenting the flag post-fetch would
  make a `safe_to_replace` surface diverge from canon (claim 27), which
  `--update --non-interactive` then silently reverts. Gating on visibility was
  also wrong (claim 28). F4 is now output-only.
- **LB-4 corrected the sequencing.** The verification gate is a 🔴 cross-repo
  write (claims 41-43), so the tag cut is blocked on a founder-executed
  `ops/inbox` runbook.

**LB-7/8/9 all pointed the same way — the plan had grown past its findings.**
F2's "tier-aware installer + union of required contexts" and F3's "fail when
zero hooks are selected" were scope expansions the findings did not license, and
F3's would have broken existing `run-stage: manual` consumers with no mechanism
to implement it correctly. Both narrowed; the general anti-vacuous-gate guard
deferred to FRAMEWORK-TODO with its mechanism problem stated.

### Pass 2 - 2026-07-21 - independent

Fresh `verified-planning-reviewer`, tasked to audit the fold's honesty and to
attack what the fold itself introduced. Returned **7 load-bearing + 6 minor**,
and confirmed all four Pass-1 changes were genuinely reflected in the body with
no superseded reasoning left alive elsewhere — except one, which it caught. All
13 re-verified at source before folding.

Three findings were defects the fold *created*, which is the pass earning its
keep:

- **LB-1 — F1's fix would have reproduced F1.** The replacement gave two naming
  shapes; `pre-commit` (which F2 adds) has a **third** — its public variant is
  the bare name (claim 7). An implementer generalising from `composition` writes
  `pre-commit-public.yml` and 404s every public adopter at the same `|| exit 1`.
  F1 now carries an explicit three-row table.
- **LB-5 — F6's fix would have silently downgraded the live fleet.** Changing
  the *template* to report-only, on a `safe_to_replace` surface (claim 37),
  means the next `--update --non-interactive` turns off three deliberately
  graduated blocking gates in `business`/`iplanic`/`interlog` (claim 36). The
  fix moved to the wizard conditional — which is where the defect actually is.
  Contract item 6 gained the "or start passing more weakly" clause, because the
  original wording did not forbid this.
- **LB-7 — the respecified test did not cover the drift class the new fix
  creates.** Hardcoding template names in the installer while calling the
  manifest the authority is itself a drift risk; the test now cross-checks the
  two, and PR-A records the literal-at-call-site constraint the static
  extraction depends on.

**LB-3 retracted a section outright.** §6 escalated an "irreconcilable
contradiction" between `branch-protection-bootstrap.json` and `manifest.json:42`
to the founder. There is none: "opt-in" in a `required_status_checks` file is a
statement about required *contexts*, not about which workflow files are
installed, and `REPO_STANDARDS.md:84` (claim 8) shows the tiers differ only in
required-check lists. §6 is deleted and F2's second "does NOT do" bullet, which
rested on it, is gone. The same claim strengthened F2's actual justification —
the lint context is required on *every* tier, so unconditional installation is
the minimum that satisfies any of them, not over-reach.

**LB-4** caught that F7's own prescribed replacement dies before its guard under
`set -e` (the `< file` redirection failure precedes `2>/dev/null` and aborts the
assignment) — verified by execution; the fix now ships `|| CI_TAG=""`. **LB-2**
narrowed fix-contract item 3, which the F3 deferral had left unachievable as
written. **LB-6** moved the manifest + README corrections into PR-B, since PR-B
is what falsifies them and the original sequencing left the README documenting
the opposite of the installer's behaviour for a whole PR.

Minors folded: F3's "no new dependency" claim corrected and its merge-dedup
collision surfaced (M-1); Wave-0 self-adoption step added to §4 (M-2); claim 31
re-pointed to the invocation rather than the diagnostic (M-3); the overstated
`auto_install` claim dropped with §6 (M-4); F4 added to §5's enumeration (M-5);
the bootstrap-re-run consequence stated in §5 (M-6).

Gate re-run after the fold.

### Pass 3 - 2026-07-21 - independent

Fresh `verified-planning-reviewer`, tasked to attack the Pass-2 fold — the F1
template table, F6's relocation to the wizard, the narrowed contract item 3, the
§6 deletion, the `set -e`-safe F7 construct, and F3's contract-6 argument — and
to re-check the 14 new/revised claims. Returned **5 load-bearing + 7 minor**. All
verified at source before folding.

It confirmed (a), (c), (d), (e) sound: the F1 table matches the template files
and covers every workflow the bootstrap loop fetches (the other `fetch_template`
call sites are visibility-independent literals); contract item 3 is now
achievable and non-vacuous; §6's deletion was correct and nothing still depends
on it; F7's `|| CI_TAG=""` survives `set -euo pipefail` in all three cases.

The load-bearing findings were:

- **A false universal underneath F2.** Claim 8 asserted the lint context is
  required on *every* tier; the umbrella column reads "(no required checks —
  submodule-pointer only)". Restated in the claim, the fix contract, and F2's
  justification. Notable because this claim had *strengthened* after Pass 2 —
  a correction can introduce an overstatement as easily as an error.
- **F3's contract-6 argument was half right.** No existing consumer *receives*
  the new hooks (that clause holds), but `apply-standards.sh` subset-checks the
  consumer's config against this fragment line-by-line (claims 44, 45), so every
  adopted repo flips to permanent DRIFT. → **OI-1**.
- **The verification gate cannot verify F3.** `TEMPLATE_BASE` derives from
  `CI_TAG`, so a runbook run from merged `main` fetches the pre-fix fragment.
  → **OI-2**.
- **F4's runner-pool bullet was framed private-only**, which would have led an
  implementer to gate the probe on visibility — the exact anti-pattern F4's own
  second correction forbids, since the ai-review template is visibility-uniform
  (claim 28). Corrected to visibility-independent.
- **PR-B's falsified-docs list was incomplete** — `install/README.md`'s step 2
  ("per-visibility templates", claim 46) is falsified by both F1 and F2. Added.

Minors folded: the stale-pin distance is **14** releases, not 11 (counted from
CHANGELOG headings); claim 19's citation re-pointed to the dedup line; claim 35
restated (both templates carry the same recommendation — the asymmetry is purely
the wizard's); F6's fix is not a one-line move (it shares a guard and a heredoc
with the labels injection); F7's construct still leaks a raw redirection error
above its own message; the bootstrap-re-run refresh path added to the ledger
(claim 47). The `AI_CI_DEPLOYMENT.md` naming-trap sibling is filed to
FRAMEWORK-TODO.

**Result: NOT ready — circuit-breaker stop.** Three independent passes are
spent and Pass 3 still found load-bearing defects, so per OPS-0066 no fourth
pass was dispatched. Its corrections are folded; OI-1 and OI-2 in §7 need a
founder decision before PR-A opens.
