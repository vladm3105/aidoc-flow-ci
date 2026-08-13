# HANDOFF — aidoc-flow-ci

Briefing for a fresh session with zero context. Two questions, in order: what the
last session did, and what to do next. **Regenerated wholesale at every wrap per
CI-0028** — nothing here is history, and every volatile claim carries the command
that re-derives it. Durable facts live in `CLAUDE.md` § "Durable traps"; the
decision record is `DECISIONS.md`, which is authoritative — this file never
summarises it.

**State:** **`ci/v3.0.0` is RELEASED** (2026-08-12) and published as Latest. The
deployable artifact is the **tag**, at `6d68b26` — canon ships by tag, so that
identifier is the one that survives; `main`'s tip moves and is not it. At this
wrap `main` was one commit above the tag, tree clean, **41** open issues, **0**
open PRs. That commit is **#457**, merged 22 minutes after the tag, so **a
consumer on `ci/v3.0.0` does not have it** — re-derive what is above the tag with
`git log --oneline ci/v3.0.0..origin/main`.

| Claim | Command | Value at wrap |
|---|---|---|
| Released version | `git describe --tags --abbrev=0` | `ci/v3.0.0` |
| Tag points at | `git ls-remote --tags origin 'refs/tags/ci/v3.0.0^{}'` | `6d68b26` |
| Release is real | `gh release view ci/v3.0.0 --json isDraft,isPrerelease` | both `false` |
| Release is Latest | `gh api repos/vladm3105/aidoc-flow-ci/releases/latest --jq .tag_name` — **not** `--json isLatest`, which is not a field | `ci/v3.0.0` |
| Reachable by consumers | `curl -o /dev/null -w '%{http_code}' https://raw.githubusercontent.com/vladm3105/aidoc-flow-ci/ci/v3.0.0/install/install.sh` | `200` |
| Suite | `bash tests/run.sh \| sed 's/\x1b\[[0-9;]*m//g' \| grep -oE '[0-9]+ passed, [0-9]+ failed' \| awk '{p+=$1;f+=$3} END{print NR" suites, "p" passed, "f" failed"}'` | **17 suites, 1542 passed, 0 failed** |
| pre-commit / pre-push | `pre-commit run --all-files` · `bash scripts/pre_push_check.sh` | both exit 0 |
| Governance table | `python3 install/parse-governance-table.py CLAUDE.md --repo-root .` | PASS |
| Standards drift | `bash sync/check-standards-drift.sh --tier product` | 4/4 families, 2 drift = the deliberate FT-52 profile |
| Open issues | `gh issue list --state open --limit 200 --json number --jq 'length'` | **41** |
| Open PRs | `gh pr list --state open --json number --jq 'length'` | **0** |

**The FT-21 red is gone.** `suite` failed on `VERSION != latest published tag`
on every PR from prep until the cut; it cleared the moment the tag existed. A red
`suite` from here on is a real red. Likewise the four self-pinned required
contexts now resolve. **#457 was the first PR after the prep boundary with all
five required contexts green, and the first to merge without `--admin`** —
`gh pr checks 452` and `gh pr checks 453` each return exactly one check,
`suite: fail`, because the other four never reported at all.

## What this session did

**Cut `ci/v3.0.0`** — 57 merged PRs that no consumer could reach are now
reachable. Merged #449 (wrap), #452 (prep), #453 (#450's fix), **then tagged**.
PR #457 (post-release doc truth) merged 22 minutes *after* the tag and is the
one commit above it.

**The ordering in the previous handoff was wrong, and following it would have
produced a green run about the wrong tree.** It said run FT-30 → prep → tag.
`docs/RELEASE_CHECKLIST.md:89-96` and `scripts/release.sh:16-18` both say
prep → merge → **dry-run** → tag, because `prep` edits the cold-start surface
(it retires the forward-pin markers in five templates). Corrected before running.

**FT-30 passed** — `FT-30 DRY-RUN PASSED` against `vladm3105/ci-coldstart-scratch`
(public) at `CI_TAG=f9c9c73`, the prep-merge SHA. It installed exactly the
manifest's `auto_install: true` set — `ai-review`, `composition`, `quick-gates` —
with `quick-gates` on `ubuntu-latest`, correct for a public target. That verifies
both #441's bootstrap change and the D7 public-quadrant fix on a real cold start
rather than in a unit test. **This is recorded nowhere durable — #454.**

**Four review passes found real defects, and the last two found defects in the
fixes for the first two.** Most consequential: the promoted CHANGELOG section —
which `release.sh tag` publishes *verbatim* as the release body — still said the
v3 layer was "NOT released" and pinned to "a tag that does not exist". It would
have shipped as the release notes of the release that falsified it.

Filed: [#450](https://github.com/vladm3105/aidoc-flow-ci/issues/450) (fixed),
[#451](https://github.com/vladm3105/aidoc-flow-ci/issues/451),
[#454](https://github.com/vladm3105/aidoc-flow-ci/issues/454),
[#455](https://github.com/vladm3105/aidoc-flow-ci/issues/455),
[#456](https://github.com/vladm3105/aidoc-flow-ci/issues/456).

## What to do next

Open issues are the backlog — do not restate them here:

```sh
gh issue list --state open --limit 200      # the --limit 30 default truncates silently
```

1. **[#454](https://github.com/vladm3105/aidoc-flow-ci/issues/454) — record the
   release where its gates were declared.** `plans/PLAN-025_v3-clean-rebuild.md:586`
   still reads `P6 — Release ci/v3.0.0. ⬜ NOT STARTED`, and FT-30's pass exists
   only in `ROADMAP.md` prose and this file. `DECISIONS.md` is the carrier a wrap
   cannot erase; `litellm-smoke`'s only non-plan citation is a handoff line and
   evaporates at the next regeneration. Top item because it rots fastest.
2. **[#455](https://github.com/vladm3105/aidoc-flow-ci/issues/455) — the rulebook
   half of #441.** `install/templates/manifest.json:185` asserts
   `auto_install=true` on the line above `"auto_install": false`, shipped verbatim
   to consumers; `docs/REPO_STANDARDS.md` §16 still names `pre-commit` as the
   bootstrap-tier producer. Behaviour is correct; only the canonical descriptions
   are wrong.
3. **Consumer adoption.** No consumer has repinned — measured: `operations`
   `@ci/v2.0.1`, `framework` `@ci/v2.16.0`, the rest `v1.5.1`–`v1.9.5`.
   **Wave 0 self-adoption is PARTIAL, not absent:** canon's own callers *are*
   repinned at `ci/v3.0.0` (`bash sync/check-standards-drift.sh --tier product`
   → `pin-currency: all pins current`), but the new v3 surfaces are not
   installed — `ls .github/workflows/ | grep -E 'quick-gates|scanners'` is empty.
   That gap is Wave 0, and canon dogfoods before Wave 1 pulls. The two
   easy-to-get-wrong PLAN-021 edits are in `CLAUDE.md` § "The PLAN-021 consumer
   resume", not here.
4. [#451](https://github.com/vladm3105/aidoc-flow-ci/issues/451) and
   [#456](https://github.com/vladm3105/aidoc-flow-ci/issues/456) — the
   promoted-prose scan that would have caught this session's worst defect, and
   three docs still framed around the pre-tag state.

## Blockers

| Blocker | Why | What would clear it |
| --- | --- | --- |
| **Runner image is stale on every host but this one** | Until each rebuilds, `scanners` is red on arrival there. State and inventory now tracked in [#458](https://github.com/vladm3105/aidoc-flow-ci/issues/458) rather than here, because this row had survived two regenerations — the tell that it is not volatile | #458; the `gh`-pin half is [#435](https://github.com/vladm3105/aidoc-flow-ci/issues/435) |
| **PLAN-025 P7 must not run** | Still the only irreversible phase; P9 (rollback) must exist first. **P4** (local layer — rewrites `pre_push_check.sh`, ships before P5) and **P5** (the `docs/v3/` documentation set) are also not started | P9 landing. `docs/MIGRATION_v3.0.0.md` is the migration path, not the documentation set |

No founder-gated blocker remains for the release itself. The three, with the
evidence rather than a pointer to it: **FT-30** — passed 2026-08-12, above;
**`litellm-smoke`** — run `31348751529`, 2026-08-10, both aliases; **OPS-0066** —
waived, `DECISIONS.md` CI-0036. #454 is the missing durable record, and this
line is why it is the top task: the previous regeneration already dropped the
`litellm-smoke` run id, which now survives only inside #454's body.

## What did NOT change

No consumer repo, no branch protection, no ruleset, no required context, no
`doc-maintainer` / `docs-sync` / `ai-review` / `secret-scan` behaviour. The
throwaway `vladm3105/ci-coldstart-scratch` was left **public** with the canonical
labels, for the next release's FT-30; nothing was pushed to it beyond labels.

`doc-maintainer` remains **live on `operations`** and **paused on `framework`** —
not re-verified this session; re-derive with
`python3 -c "import json;[print(r, json.load(open(f'../{r}/.github/doc-maintainer.json'))['dry_run'], json.load(open(f'../{r}/.github/doc-maintainer.json'))['kill_switch']) for r in ('operations','framework')]"`.
