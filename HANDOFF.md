# HANDOFF — aidoc-flow-ci

Briefing for a fresh session with zero context. Two questions, in order: what the
last session did, and what to do next. **Regenerated wholesale at every wrap per
CI-0028** — nothing here is history, and every volatile claim carries the command
that re-derives it. Durable facts live in `CLAUDE.md` § "Durable traps"; the
decision record is `DECISIONS.md`, which is authoritative — this file never
summarises it.

**Scope: `aidoc-flow-ci` ONLY** (founder, 2026-08-16). Do not edit, adopt into,
or file on sibling repos this session. Sibling checkouts may be read as evidence.

**State:** **`ci/v3.0.0` is RELEASED** (2026-08-12) and published as Latest. The
deployable artifact is the **tag**, at `6d68b269` — canon ships by tag, so that is
the identifier that survives; `main`'s tip moves and is not it. At this wrap
`main` is **15 commits above the tag**, tree clean, **44** open issues, **0** open
PRs. **None of the fifteen reaches a consumer on `ci/v3.0.0`** — which now matters
more than usual: see the first "next" item.

| Claim | Command | Value at wrap |
|---|---|---|
| Released version | `git describe --tags --abbrev=0` | `ci/v3.0.0` |
| Tag points at | `git ls-remote --tags origin 'refs/tags/ci/v3.0.0^{}'` | `6d68b269` |
| Release is Latest | `gh api repos/vladm3105/aidoc-flow-ci/releases/latest --jq .tag_name` — **not** `--json isLatest`, which is not a field | `ci/v3.0.0` |
| Suite | `bash tests/run.sh \| sed 's/\x1b\[[0-9;]*m//g' \| grep -oE '[0-9]+ passed, [0-9]+ failed' \| awk '{p+=$1;f+=$3} END{print NR" suites, "p" passed, "f" failed"}'` | **19 suites, 1719 passed, 0 failed** |
| pre-commit | `pre-commit run --all-files` | exit 0 |
| Governance table | `python3 install/parse-governance-table.py CLAUDE.md --repo-root .` | PASS |
| markdownlint | `git ls-files '*.md' \| xargs npx markdownlint-cli2` — use `git ls-files`, **never** a `**/*.md` glob, which reaches the gitignored bootstrap scratch trees | 0 errors |
| Ledger gate baseline | `bash scripts/pre_push_check_ci.sh --ledger-only` | **79 failing rows, 14 of 15 gated plans** |
| Open issues | `gh issue list --state open --limit 200 --json number --jq 'length'` | **44** |
| Open PRs | `gh pr list --state open --json number --jq 'length'` | **0** |
| Stale in-progress markers — **`--label` reads a LAGGING index**; confirm any single issue with `gh issue view <N> --json labels`, which is immediately consistent | `gh issue list --state closed --label status:in-progress --json number --jq 'length'` | **0** |
| In progress | same, `--state open` | **#432 only** |
| Commits above the tag | `git rev-list --count ci/v3.0.0..origin/main` — count from `origin/main`, not `HEAD`; on a wrap branch `HEAD` is already one higher | **15** |

## What this session did

**Merged [#485](https://github.com/vladm3105/aidoc-flow-ci/pull/485) at
`56a2605`, closing [#481](https://github.com/vladm3105/aidoc-flow-ci/issues/481)
and [#455](https://github.com/vladm3105/aidoc-flow-ci/issues/455).**

`#441` had shipped one half of a two-half change: it moved `auto_install` from
`pre-commit.yml` to `quick-gates.yml` on the condition, stated in its own PR body,
that it land *"next to PLAN-026 C0's template substitution"*. §C0 never followed.
So a post-v3 **cold start** installed `quick-gates.yml` while all four tier
templates still required `call / Lint / format / security hooks` — armed by
`--apply` as one whole payload, with no `--admin` escape on consumer tiers.

**The flags are reverted, not the decision** — recorded as **`DECISIONS.md`
CI-0038**, which is authoritative and not summarised here. §C0 and the flag flip
now land **together, after PLAN-026 C1–C5**. Read CI-0038 before touching either.

**Two findings worth knowing before you touch the map** — both now routed to
durable carriers (`CLAUDE.md` § Durable traps gained the format-change entry this
wrap; the reasoning is CI-0038's):

- `install/required-context-map.py` now prefixes `!` on a producer canon ships at
  `auto_install: false`. That format change **silently broke
  `install/deploy-ci-wizard.sh` §6**, its other reader, while the whole suite
  stayed green — nothing drives the wizard. Fixed, and
  `tests/test_required_contexts.sh` **§8** now pins the symbol vocabulary next to
  the map and asserts every reader handles it.
- **The §C0 coverage is PARTIAL, and the halves matter.** §C0 landing **alone**
  reds the suite. §C0 **plus** the flag flip, before the C1–C5 rollout, does
  **not** — `auto_install` describes a cold start and canon cannot read consumer
  repos, so CI-0038 item 2 is enforced by review only. Do not re-derive this as
  either "the suite will catch it" or "the detector does nothing".

## What to do next

### Startable now, no decision needed

**[#478](https://github.com/vladm3105/aidoc-flow-ci/issues/478) — the pre-commit
fragment's marker was not bumped for #474's body change.** Self-contained, in
scope, and the only named item that needs no founder input. **Read its
ledger-impact section first**, and note its body cites `PLAN-023:1200` for the
Claim 37 symbol — #485 shifted that to **`:1203`**, so the issue body needs
correcting as part of the fix.

### Decisions owed to the founder — neither is startable without them

**1. Whether to cut a release.** The #481 fix is on `main` and reaches **no consumer** until a tag. A repo that
cold-started at `ci/v3.0.0` and ran `apply-standards.sh --apply` is bricked
*today*; `docs/troubleshooting.md` **§20** carries the one-line interim recovery
(`--add-surface .github/workflows/pre-commit.yml`) and
`docs/MIGRATION_v3.0.0.md` "Known issues" carries the same.

**Verified: none of the eight consumers that carry required contexts is
exposed** — every one has `pre-commit.yml` on `origin/main`, and exposure needs a
**cold start** at `ci/v3.0.0`, not a particular pin (canon itself pins
`ci/v3.0.0` on 8 of its 9 self-callers and is not exposed). **None of the eight
has `quick-gates.yml`** — the fact that governs §C0. Re-derive against the
REMOTE, since four consumers sit on feature branches right now:

```sh
for d in operations framework business iplanic iplan-runner iplan-standard engramory interlog; do
  printf '%-16s %s\n' "$d" "$(git -C /opt/data/aidoc-flow/$d cat-file -e origin/main:.github/workflows/quick-gates.yml 2>/dev/null && echo HAS || echo none)"
done
```

**Not verified, and not checkable from here: any repo onboarded outside the
workspace.** So the exposure is latent for the fleet and unknown beyond it; the
release is a judgement call, not an emergency. **What is 🔴 founder is the FT-30
cold-start dry run**, not releasing as such — and this release owes one, because
`docs/RELEASE_CHECKLIST.md` requires a **bootstrap-path** change to be dry-run
against the **prep-merge SHA**, and #485 is exactly that.

**2. PLAN-026 C1–C5 is now the gating work for §C0** — a fleet rollout putting
`quick-gates.yml` on the consumers, and **out of this session's declared scope**.
It needs a scope decision before it can start.

**The scope line at the top of this file is dated 2026-08-16 and was a
per-session directive.** Re-establish it before touching a sibling repo; do not
read it as standing.

Everything else is the backlog; do not restate it here:

```sh
gh issue list --state open --limit 200      # the --limit 30 default truncates silently
gh issue list --state open --label status:in-progress
```

**There is a SECOND live backlog surface**, per this repo's governance table:
`plans/FRAMEWORK-TODO.md`, the legacy FT queue, still holds open entries until
its retirement lands (FT-58, 🔴 founder). The tracker alone is not the backlog.

Other named items, all **inherited, not re-verified this session** (#478 is
above):
[#432](https://github.com/vladm3105/aidoc-flow-ci/issues/432) (still In Progress —
advanced by #482, not closed; read its comment on why the empty-range fix was
withdrawn before re-attempting), the
79-row ledger backlog (`bash scripts/pre_push_check_ci.sh --ledger-only`; re-pin
LAST, after code freeze, #393), and Wave 0 self-adoption (canon runs the **v2**
architecture at a v3 pin — `ls .github/workflows/ | grep -E 'quick-gates|scanners'`
is empty, confirmed 0 this wrap).

## Blockers

| Blocker | Why | What would clear it |
| --- | --- | --- |
| **§C0 cannot land until the fleet has `quick-gates.yml`** | Arms a required context no installed consumer produces; consumer tiers have no `--admin` escape. **Coverage is partial — know which half:** §C0 landing ALONE reds the suite (`!` on the bootstrap producer, `tests/test_required_contexts.sh` §5). §C0 **plus** the flag flip does **not**, because `auto_install` describes a cold start and canon cannot read consumer repos — that ordering is review-enforced only | PLAN-026 C1–C5 (a rollout, out of scope), then §C0 + the flag as ONE change. Reasoning: `DECISIONS.md` CI-0038 |
| **The #481 fix reaches no consumer until a tag** | Canon ships by tag; `main` is 15 commits ahead and none of it is delivered | A release (🔴 founder). Interim recovery is documented at `docs/troubleshooting.md` §20 |
| **Runner image is stale on every host but this one** | Until each rebuilds, `scanners` is red on arrival there | [#458](https://github.com/vladm3105/aidoc-flow-ci/issues/458); the `gh`-pin half is [#435](https://github.com/vladm3105/aidoc-flow-ci/issues/435). **Inherited, not re-verified this session** |
| **PLAN-025 P7 must not run** | Still the only irreversible phase; P9 (rollback) must exist first. **P4** and **P5** are also not started | P9 landing. `docs/MIGRATION_v3.0.0.md` is the migration path, not the P5 documentation set. **Inherited** |

## What did NOT change

**No consumer repo, no branch protection, no ruleset, no required context.** The
four tier templates still require `call / Lint / format / security hooks`, which
every consumer produces — #485 deliberately touched no
`install/templates/branch-protection-*.json`. No `docs-sync` / `ai-review` /
`secret-scan` behaviour.

The Claim-ledger baseline is **unchanged at 79 rows, verified as an identical row
set** rather than an identical count (`PLAN-023`'s Claim 64 was re-authored in the
same change, because #485 removed the wizard arm it pinned).

**`doc-maintainer` is RETIRED** — `DECISIONS.md` CI-0040, executed in the same
change that carries this line. Canon no longer ships the reusable, the caller or
config templates, `scripts/doc-maintainer/`, the three `manifest.json` entries,
the `ai-doc-maintainer` alias or `LITELLM_DOC_API_KEY`.

**Consumers are NOT broken and must NOT `--repin`.** `operations` (live,
`kill_switch=false`) and `framework` (inert, `kill_switch=true`) both pin
immutable tags — `ci/v2.0.1` and `ci/v2.16.0` — so their callers still resolve.
A re-pin would move them to a tag where the workflow does not exist. **They
delete the caller instead.** Re-derive both the pin and the state:

```sh
for d in operations framework; do
  git -C /opt/data/aidoc-flow/$d show origin/main:.github/workflows/doc-maintainer.yml \
    | grep -m1 'uses:.*aidoc-flow-ci'
done
```

Lessons went to auto-memory, which is **gitignored and machine-local**
(`~/.claude/.gitignore:5`) — safe on this host only, not backed up. Read them
there; they are not restated here.
