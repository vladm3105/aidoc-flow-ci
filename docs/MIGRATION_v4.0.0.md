# Migration — ci/v3.0.0 → ci/v4.0.0

**Status:** actionable once `ci/v4.0.0` is cut. Adoption is per-consumer —
nothing moves until that consumer repins.

**v4 changes the operating contract, not the packaging.** The v2→v3 composite-
action rework is unchanged and its guide (`docs/MIGRATION_v3.0.0.md`) still
applies to anyone still on v2 — read that one **first**, then this one.

## Why this is a MAJOR bump

Four changes since `ci/v3.0.0` alter an expected consumer surface, which
`CLAUDE.md` "Semver discipline" defines as MAJOR:

| # | Change | Decision | What breaks if you ignore it |
|---|---|---|---|
| 1 | Runner labels renamed `ci-runner`→`ci`, `single-use`→`ephemeral` | CI-0043 | Jobs **queue forever** — no failure, no timeout |
| 2 | `doc-maintainer` reusable **deleted** | CI-0040 | A caller pinned to v4 gets `startup_failure` |
| 3 | LLM credentials unified on `LLM_URL` + `LLM_API_KEY`; the `LITELLM_*` fallbacks **REMOVED** and no longer declared | CI-0051 | A caller still forwarding the old trio gets **`startup_failure` — zero jobs, no logs**. Needs a CALLER EDIT, not just secrets; `--repin` cannot deliver it — see §3 |
| 4 | Caller input renamed `litellm_allow_insecure_http` → `llm_allow_insecure_http` | CI-0051 | An unknown input is rejected; rename it in your caller |

**None of the four is backward compatible.** Items 1 and 2 bite during the
repin; items 3 and 4 bite on the FIRST PR after it. Item 3 is the one with an
ordering requirement — provision the secrets before you repin, not after.

## Before you start

Answer these three questions about **your** repo. Two of them change what you
must do, and one of them changes the ORDER.

1. **Do you call `doc-maintainer.yml`?**

   ```sh
   grep -rl 'doc-maintainer' .github/workflows/ || echo "no — skip §2"
   ```

2. **Do you run any job on the self-hosted pool?** (Every private repo does.)

   ```sh
   grep -rn 'self-hosted' .github/workflows/ || echo "no — skip §1"
   ```

3. **Which labels does your pool actually have registered right now?**

   ```sh
   gh api repos/<owner>/<repo>/actions/runners \
     --jq '.runners[] | {name, labels: [.labels[].name]}'
   ```

   Read this from the API, not from a runbook or a handoff. §1's whole hazard is
   a mismatch between what a workflow selects and what is registered, and the
   only authority on the latter is the API.

## 1. Runner labels — 🔴 ORDER-SENSITIVE, and getting it wrong HANGS

`ci-runner` → **`ci`**, `single-use` → **`ephemeral`**.

> ### ⚠️ A job whose labels match no registered runner QUEUES FOREVER
>
> It does not fail. `timeout-minutes` cannot save it, because the clock starts
> when the job *starts* — a job that never starts never times out. The symptom
> is a required check pinned on **"Expected — Waiting for status to be
> reported"**, with nothing in any log naming the cause, and a PR that is
> `BLOCKED` rather than red. There is no `--admin` escape that makes the check
> report; you have to fix the labels or cancel the run.

**Register the coexistence set FIRST, narrow LAST.** Between those two steps
both old- and new-label jobs find a runner, so nothing hangs while the repin
propagates.

```sh
# STEP 1 — before you repin anything. Both label sets served.
TARGET_REPO=<owner>/<repo> \
  RUNNER_LABELS=self-hosted,ci-runner,single-use,ci,ephemeral \
  bash provision-runner.sh

# STEP 2 — repin (§4), let a real PR run, and CONFIRM a job landed on the new
#          labels before going further:
gh run view <run-id> --json jobs --jq '.jobs[] | {name, runner_name, labels}'

# STEP 3 — only now narrow. Old-label jobs stop finding a runner from here.
TARGET_REPO=<owner>/<repo> \
  RUNNER_LABELS=self-hosted,ci,ephemeral \
  bash provision-runner.sh
```

Do **not** collapse steps 1 and 3. Registering the narrow set before any
new-label job has been observed to land is the FT-9 hang, and it presents as a
CI outage with no error message.

**`ci-runner` survives as a name, and must not be renamed.** The systemd unit
(`ci-runner@.service`), the config directory (`~/.config/ci-runner/`) and the
script path are unchanged — only the **label** moved. Renaming those breaks
provisioning.

**Repos with a pool as of this release:** `operations` (1 runner), `framework`
(2), `iplanic` (1). Each is a separate execution of the three steps above. This
step is 🔴 founder-executed: it writes to another repo's runner registration.

## 2. `doc-maintainer` is deleted — remove the caller BEFORE you repin

CI-0040 retired the flow; #496 executed the removal. `doc-maintainer.yml`, its
caller template, its config and conventions templates, `scripts/doc-maintainer/`
and three `manifest.json` entries are all gone at `ci/v4.0.0`.

**Do not `--repin` a repo that still calls it.** A repin rewrites the `uses:`
tag to a ref where the reusable does not exist, and the next PR gets a
`startup_failure` — which produces **no logs**, so the cause is not visible from
the run page.

```sh
# Order matters. Delete first, then repin.
git rm .github/workflows/doc-maintainer.yml
git rm -f .github/doc-maintainer.json 2>/dev/null || true
git commit -m "chore(ci): drop doc-maintainer ahead of the ci/v4.0.0 repin (CI-0040)"
```

**Known affected as of this release:** `framework` calls
`doc-maintainer.yml@ci/v2.16.0` today. `operations` was the other caller.

**What replaces it:** nothing, deliberately. `docs-sync` is the workspace's sole
doc automation (PLAN-024 A6). If you relied on doc-maintainer's behaviour, adopt
`docs-sync.yml` — note it is **dry-run-first** and its live mode is gated.

## 3. LLM credentials — 🔴 DO THIS BEFORE YOU REPIN

> ### ⚠️ The `LITELLM_*` fallbacks are REMOVED at `ci/v4.0.0` (CI-0051) — and this needs a CALLER EDIT, not just secrets
>
> `LLM_URL` and `LLM_API_KEY` are the **only** names resolved, and the old names
> are **no longer declared** by the reusable. That second half is the one that
> bites.
>
> **Your caller forwards secrets by an explicit map** (FT-42, since `ci/v2.12.0`
> — not `secrets: inherit`). GitHub **rejects a map naming a secret the callee
> does not declare**: the workflow fails to LOAD. You get
> **`startup_failure` — zero jobs, no logs** — on a required check, which is the
> same silent shape as the `doc-maintainer` break in row 2.
>
> **The caller templates shipped at `ci/v2.12.0` … `ci/v3.0.0` forwarded exactly
> those three names and NOT the unified pair.** So if you installed or updated
> anywhere in that range — most of the fleet — you are affected, and:
>
> - **Provisioning the secrets does NOT rescue you.** The map is invalid whatever
>   the repo holds.
> - **`--repin` does NOT rescue you.** It rewrites `uses:` tag strings only and
>   cannot touch a caller body.
>
> **Do all three in the SAME change:** provision the unified pair, delete the
> three `LITELLM_*` lines from your caller's `secrets:` map, and repin.

**Why now.** Two names for one credential is how #350 happened: a run that added
one secret rewrote a working key, and nothing could tell the two paths apart.
The client was never LiteLLM-specific — it POSTs a standard OpenAI-compatible
`{"model","messages"}` body to `<LLM_URL>/v1/chat/completions` — so the split
naming implied a provider coupling that does not exist.

**Provision (recommended — per-repo, revocable, review-scoped):**

```sh
export LLM_URL="https://your-endpoint/v1"     # NOT 127.0.0.1/localhost: that
                                              # resolves to the job CONTAINER (CI-0017)
export LLM_MASTER_KEY="<master key>"          # used to MINT; never stored
bash install/set-llm-secrets.sh --mint --repos "<owner>/<repo>"
```

Or with a key you already hold:

```sh
export LLM_URL="https://your-endpoint/v1"
export LLM_API_KEY="<scoped key>"             # never the master key
bash install/set-llm-secrets.sh --repos "<owner>/<repo>"
```

`--dry-run` prints the per-secret plan and makes no network call. An existing
secret is never replaced without `--overwrite` (#350).

**If you use autofix, widen the minted key's model scope.** `--mint` issues a
key scoped to the **review** alias (`ai-reviewer`) only. Autofix runs the same
`LLM_API_KEY` against the fixer alias (`ai-fixer`, or `vars.LLM_FIXER_MODEL`),
so a `--mint`-provisioned repo that later enables autofix gets **HTTP 403
model-scope**, not 401 — a different symptom with a different cause. Add the
fixer alias to the key's model list at mint time, or provision with a key that
already covers both. Autofix is default-off, so this bites only when you turn
it on, which may be long after the repin.

**Any OpenAI-compatible endpoint works.** Switching provider is these three
values — `LLM_URL`, `LLM_API_KEY`, and the model alias — with no code change.

> ### The unified names are CANON's — your endpoint keeps its own
>
> CI-0051 unified what **this library** calls things: the GitHub Actions secret
> names and the workflow inputs. It has no authority over what your endpoint
> product calls its own configuration, and does not try to rename it. Expect to
> see both, and expect the bridge between them to be the only place they meet.
>
> Worked example — the workspace's own LiteLLM deployment names its admin key
> `LITELLM_MASTER_KEY` (its `docker-compose.yml` and `config/router.*.yaml` read
> that variable), while `set-llm-secrets.sh --mint` expects the unified
> `LLM_MASTER_KEY`. One line bridges them:
>
> ```sh
> # The ( … ) is LOAD-BEARING: it confines the exports to a subshell that exits
> # immediately, so the master key does not linger in your interactive shell's
> # environment for every later process to read.
> ( export LLM_URL="http://172.17.0.1:4001/v1"
>   export LLM_MASTER_KEY="$(grep -m1 '^LITELLM_MASTER_KEY=' /path/to/proxy/.env | cut -d= -f2-)"
>   bash install/set-llm-secrets.sh --mint --repos "<owner>/<repo>" )
> ```
>
> Point `LLM_URL` at OpenAI instead and the source variable becomes
> `OPENAI_API_KEY`; **only that one line changes.** Canon, the reusables and the
> client are untouched — which is the property the rename exists to make
> obvious. Seeing a vendor-specific name on the LEFT of that bridge is expected;
> seeing one inside canon is not.

**Update your caller — this is REQUIRED, not cleanup.** The shipped
`ai-review.yml` template no longer forwards the deprecated trio. If yours still
lists them the workflow will not load at all. Either take the new template with
`install.sh --update` (then re-apply any local `runner_labels_*` / `permissions:`
/ `config-path:` edits — `--update` replaces whole caller bodies), or hand-edit
the three lines out. `--repin` alone is not sufficient.

```yaml
    secrets:
      LLM_URL: ${{ secrets.LLM_URL }}
      LLM_API_KEY: ${{ secrets.LLM_API_KEY }}
      # DELETE: LITELLM_BASE_URL / LITELLM_REVIEW_API_KEY / LITELLM_FIX_API_KEY
```

**Input renamed:** `litellm_allow_insecure_http:` → `llm_allow_insecure_http:`.
Same meaning, same default (`false`). If your caller passes the old name,
rename it — an unknown input is rejected.

`LITELLM_DOC_API_KEY` is **gone** and has no replacement — it existed only for
`doc-maintainer`. Delete it once §2 is done. The other three can be deleted once
you have repinned and one PR has gone green.

## 4. Repin

After §1 step 1 and §2 are done:

<!-- sync-version-refs:ignore-start -->
<!-- CI-0024: in a document NAMED for a tag, that tag is the SUBJECT, not a
     pin to keep current — the repin this document exists to describe. -->
```sh
CI_TAG=ci/v4.0.0 bash <(curl -fsSL \
  https://raw.githubusercontent.com/vladm3105/aidoc-flow-ci/ci/v4.0.0/install/install.sh) \
  <owner>/<repo> --repin
```
<!-- sync-version-refs:ignore-end -->

`--repin` rewrites tag strings only. If you are coming from a release whose
**caller bodies** changed, see `docs/UPDATE_GUIDE.md` on `--update` versus
`--repin` — and note `--update` clobbers local `runner_labels_*`, `permissions:`
and `config-path:` edits, which you then re-apply.

Then complete §1 step 2 (observe a job land on the new labels) before §1 step 3.

## 5. What is NEW in v4 that you may want

None of this is required to adopt v4; it is what you get.

- **`codeql-private.yml`** — codeql was the one generic surface with no private
  variant, so a private adopter running the documented `--add-surface` landed on
  the reusable's `ubuntu-latest` default and queued forever. If you added
  `codeql.yml` to a private repo before v4, re-add it now and you will get the
  labelled variant.
- **`.github/actionlint.yaml` arrives with the caller that needs it.**
  `--add-surface` now pulls it as a dependency whenever the caller it installs
  carries a literal self-hosted `runs-on:`. Previously a private v3 caller
  landed without it and failed the consumer's own `pre_push_check.sh` check 3 on
  every push.
- **Hardened SAST — one input is now restricted, check yours.** The `sast-scan`
  gate was bypassable by committing `.semgrepignore` as a **symlink** (see the
  CHANGELOG). Both sast surfaces now carry the full D23 shape, and `config`
  accepts exactly **`p/default`, `p/security-audit`, `p/python`**.

  **If your caller passes anything else — a local path, a URL, an individual
  `r/…` rule, or another `p/…` pack — the step now REFUSES with a named
  error.** That is deliberate: a narrow or one-rule ruleset exits 0 with a valid
  empty SARIF, so the gate goes green having scanned essentially nothing. Check
  before you repin:

  ```sh
  # No brace expansion — these blocks are `sh`, and dash does not expand {a,b}.
  for f in sast dep trivy; do
    grep -Hn 'config:\|scan-path:' ".github/workflows/${f}-scan.yml" 2>/dev/null
  done
  grep -Hn 'config:\|scan-path:' .github/workflows/scanners.yml 2>/dev/null
  ```

  **`scan-path` is restricted the same way, on all three scanners** — it must be
  `.` (the repo root). A narrower subtree is the same coverage choice by another
  name: an existing directory containing no code scans clean and the gate goes
  green. `.` is the input's default and what every shipped caller passes, so this
  bites only a consumer who set it deliberately.

  Every shipped template already complies. If you need a different pack, ask for
  it in canon rather than setting it in the caller — the gate deciding coverage
  is the whole point of the change.
- **A `dev` → `staging` → `main` branching model, fully OPT-IN (PLAN-028).**
  v4 ships the machinery; **no repo has adopted it, canon included.** With no
  `.github/aidoc-ci.json` in your repo, every surface reproduces its pre-v4
  behaviour, resolved against your repo's API-reported default branch — never a
  hardcoded `main`. You do not have to do anything.

  **The one unconditional effect, and it is cosmetic.** After
  `install.sh --update` — not `--repin`, which rewrites `uses:` strings only —
  caller trigger arms read `branches: ["main"]` where they read
  `branches: [main]`. Same branch; the placeholder has to be quoted because a
  bare `${…}` in a YAML flow sequence is a parse error. `sync/check-drift.sh`
  does not count it as drift. Expect one line of diff per trigger arm, once.

  **`.github/aidoc-ci.json` is now VALIDATED, and `version` is required.** All
  four readers reject unknown keys at either level and any `version` other than
  `1`. This is deliberate: `"promotion_branchs": []` — one transposed letter —
  used to read as "not set", take the model default, and apply
  `enforce_admins: false` to the two branches you were opting out of. If you
  hand-wrote a declaration against a pre-v4 build, add `"version": 1` and check
  your key spellings; `scripts/pre_push_check.sh` will refuse the push and name
  the offending keys.

  **If you want to adopt it, read [`BRANCHING.md`](BRANCHING.md) §8 first — the
  step ORDER is load-bearing.** Create the integration branch and make it the
  repo's GitHub default *before* adding the declaration. Declaring the model
  while `main` is still the default would put `enforce_admins: false` on the
  branch `composition.yml` and `ai-review.yml` anchor their trust to;
  `apply-standards.sh` now refuses both orderings that produce it, rather than
  warning. And understand the cost before you opt in: per CI-0049 a promotion
  branch's protection is **advisory for admins, not enforced** — that is the
  only mechanism on a user-owned account that permits the promotion push at
  all, and there is no CI-side check that a promotion is a fast-forward.

- **ai-review no longer ships the unredacted diff** in its artifact or to the
  autofix model. One consequence worth knowing before you diagnose it as a
  regression: the fixer now sees `[REDACTED_SECRET_SHAPED_CONTENT]` wherever the
  reviewer's patterns matched, and `git apply --3way` refuses a hunk whose
  context is that placeholder. The realistic effect is a slightly higher autofix
  escalation rate on PRs containing secret-**shaped test fixtures** (PEM blocks,
  `AKIA…`, `sk-…`), not only real secrets. Autofix is default-off.

## 6. Rollback

`ci/v3.0.0` is untouched and remains a valid pin — it was **not** re-cut. If v4
misbehaves:

<!-- sync-version-refs:ignore-start -->
<!-- CI-0024: in a document NAMED for a tag, that tag is the SUBJECT, not a
     pin to keep current — the ROLLBACK target — it must stay v3.0.0 forever. -->
```sh
CI_TAG=ci/v3.0.0 bash <(curl -fsSL \
  https://raw.githubusercontent.com/vladm3105/aidoc-flow-ci/ci/v3.0.0/install/install.sh) \
  <owner>/<repo> --repin
```
<!-- sync-version-refs:ignore-end -->

Rolling back the **labels** is the part that needs care: if you have already
narrowed the pool to `self-hosted,ci,ephemeral`, a v3 caller selecting
`ci-runner,single-use` will hang. Re-register the coexistence set before
repinning backwards, for the same reason §1 registers it going forwards.

## Known issues

- §1 step 1 and step 3 are 🔴 founder-executed and cross-repo (the pool default
  lives in `aidoc-flow-operations`), so they are outside what an agent working
  in a consumer repo can complete.
- `self-scanners` exercises canon's scanner actions on `ubuntu-latest` only.
  Canon has no self-hosted pool of its own, so the **runner image** path is still
  verified only by `install/templates/runner/build-image.sh`. A green canon run
  does not prove your image is current — rebuild it per host if you have not
  since 2026-08-09.
