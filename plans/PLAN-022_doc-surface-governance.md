# PLAN-022 — doc-surface governance: three surfaces, three edit shapes

> **PRE-`ci/v3` — OPEN WORK REMAINS.** This plan is pre-v3 work, so it is
> **not part of the `ci@v3` line** — but it is **not closed**: its own
> Status reads READY and it was never executed. **Retarget to the v3 line
> before executing**, and check `CHANGELOG.md` for its current state. Scope
> decision of record: `DECISIONS.md` **CI-0041**. Active `ci@v3` work is
> PLAN-023, PLAN-024, PLAN-025 and PLAN-026.

**Status:** **READY** — see the Review log for the basis, and §5 for what was
deliberately cut.
**Scope:** Establish the per-surface edit-model (changelog / handoff / backlog),
record it as canon, and specify the `apply.py` edit-mode taxonomy that PLAN-021
Phase 2 inherits. **Ships no migration and deletes no file.**
**Semver:** none — no canon body, no manifest surface, no workflow change.
**Decision record:** `CI-0028` (new)

> **Gate invocation:**
>
> ```sh
> python3 ~/.claude/skills/verified-planning/check_plan.py \
>   plans/PLAN-022_doc-surface-governance.md \
>   --root /opt/data/aidoc-flow/operations \
>   --root /home/ya/.claude
> ```
>
> ⚠️ **Do not trust this gate's exit code as a readiness signal.** Its
> `ZERO_FINDINGS_RE` matches a `status:` line followed by `ready` **anywhere** in
> the final Pass entry — including a quotation of *another* plan's status — so it
> will green a NOT-READY plan that happens to quote one. Found on this plan's own
> previous revision. Upstream defect in the global `verified-planning` skill; 🟡,
> and the config repo is not one of the ten the OPS-0076 carve-out covers, so a
> human files it.

---

## 1. Three surfaces, three edit shapes

These are **opposite artifacts**, and treating them alike is what produces both
failures below.

| Surface | Lifespan | Correct edit | Never |
|---|---|---|---|
| **CHANGELOG** | permanent, grows monotonically | **anchored insert** under the Unreleased heading | regenerate · reorder · prune · prepend to the file |
| **HANDOFF** | ephemeral, rewritten each wrap | **full regeneration** | append · accrete "previous state" sections |
| **Backlog** | — | the repo's open **GitHub issues** | a parallel markdown queue |

**The changelog is the permanent record of what happened; the handoff is a
disposable briefing about now.** A correction to a changelog entry is a *new
dated entry saying so*, never an edit to the old one. A handoff that needs
skimming has already failed.

### 1.1 "Add at the beginning" means under the anchor, not at the top of the file

This is the precision that decides whether an implementation works. A new entry
goes **beneath the `## [Unreleased]` heading**, below the H1 and the preamble. A
naive file-prepend puts entries above the title. The primitive is **anchored
insert**, never *prepend*.

**Measured across the workspace (2026-07-30)** over the nine covered repos that
have a changelog — `feedback-desk` has none and is not counted:

| Anchor | Repos |
|---|---|
| `## [Unreleased]` | framework, operations, iplanic, engramory, iplan-runner, iplan-standard, interlog (7) |
| `## Unreleased` | **`aidoc-flow-ci` itself** — the outlier, and it is canon |
| *(no changelog)* | `business` — declined by its own governance table, deliberately |

**Consequences for any implementation:** the anchor must be **configurable**,
defaulting to the bracketed form; a repo that declares no changelog must be a
supported state, not an error; and **canon should normalise its own heading**
rather than shipping a tool whose default its own repo violates.

### 1.2 The handoff rule that is missing: volatile claims carry their command

Regeneration alone is not enough, and this repo proves it. `HANDOFF.md` is
**1,393 lines** carrying a "Previous state (2026-07-25)" block and PLAN-018/019
history — against the ~200-line target. But length is the *symptom*.

**The defect is that a carried-forward claim reads as freshly verified.** On
2026-07-30 the handoff's headline stated *"0 open issues, 0 open PRs"*; there
were **eight** open issues and the claim had been stale for three days. Nothing
marked it as a claim rather than a fact.

**Rule:** every volatile claim in a handoff carries the command that re-derives
it. `0 open issues` is unfalsifiable prose; the same line followed by the
`gh issue list --state all --limit 200 | wc -l` that produced it is checkable in
one paste. That converts a stale handoff from *misleading* into *obviously
stale* — the whole difference.

---

## 2. Feedback is a direction of travel, not a class of issue

**A repo's open issues are its backlog — regardless of who filed them.** Filing
on another repo is the *act* of giving feedback; it does not create a distinct
species of issue on the receiving side.

Provenance does not change what the owner does: ci#352 (filed by a framework
session) and a ci-found bug both mean "ci must fix this" — same triage, same
queue, same close-on-merge. **A classifier that drives no action is a second
surface that can only drift**, which is the failure mode this model exists to
avoid. So no `kind:feedback` / `kind:task` label family.

Three places where direction genuinely has teeth — none needing a classifier:

1. **The promotion bar and the five-part body attach to the outbound act.**
   Filing on someone else's repo spends their attention, so it must clear the bar
   (the test is *ownership, not severity*) and carry reproduction at `file:line`,
   blast radius, why it was hard to diagnose, a suggested fix, and what is *not*
   broken. Filing on your own tracker is your own queue — lower bar.
2. **The close permission stays asymmetric.** The owning repo closes its own
   issue when the fix merges; a reporter never closes another repo's. A
   permission rule under OPS-0076, not a taxonomy.
3. **`source:` survives as provenance, not classification** — its job is "who do
   I go back to for more evidence", never a sort key.

**Consequence:** no new label family, so provisioning the
`type:*` / `tier:*` / `source:*` taxonomy is an indexing improvement, not a
prerequisite for anything here. (Measured 2026-07-30: those families are absent
on ci, operations and iplanic; framework has one stray `type:infra`.)

**What this model does NOT settle** — deliberately, see §5: whether an entry that
fails the promotion bar belongs in the tracker anyway once its queue file is
gone. The contract says such a finding *"stays in the worked `plans/` entry"*.
That clause presumes a queue exists, and reconciling it with a retirement is the
migration's problem, not this plan's.

---

## 3. Governance record

**`DECISIONS.md` CI-0028** records §1 and §2: the three-surface model, the
anchored-insert primitive, the handoff verifying-command rule, and
feedback-as-direction.

**`CLAUDE.md`'s governance table is currently false and gets corrected to
describe reality — not the target state.** Its backlog row claims the surface is
*"Not adopted … no separate TODO.md needed for a small canon repo"* while
`plans/FRAMEWORK-TODO.md` holds 1,896 lines. The replacement:

> | TODO / backlog | `plans/` (per-initiative plans + GitHub issues — this repo's open issues **are** its backlog, whoever filed them; a finding below the promotion bar stays in the worked `plans/` entry, not in the tracker. Read the tracker with `gh issue list --state all --limit 200` — the `--limit 30` default truncates silently.) |
> | Legacy FT queue (being retired) | `plans/FRAMEWORK-TODO.md` (still holds open entries; until its retirement lands, both surfaces are live) |

One row, not two, because on this repo **capture and publish coincide**: the
declared backlog is the tracker itself, so there is no separate capture surface
to name. That is the contract's own wording for ci
(`docs/AGENT_FEEDBACK_INTAKE.md:73` in operations), and it is why the row reads
`plans/` **plus** issues rather than splitting them the way a cross-repo filing
does.

**This is the load-bearing detail of the narrowing.** Shipping a row that omits
the legacy queue would assert "GitHub issues are the backlog" while a 1,896-line
queue sits in `plans/` — recreating, inverted, the exact false declaration being
fixed. A governance table describes what **is**.

**The two-row shape is forced by canon's own parser.**
`install/parse-governance-table.py` reads a row's whole path cell as a path.
`extract_path` strips exactly two annotation forms — a trailing `§N`/`#anchor`
(`:172`) and a parenthesized annotation (`:180`) — and nothing else, so an
em-dash annotation stays in the string and is looked up on disk. Measured on
this repo: the prose row this plan carried through Pass 5 took the check from
`errors: []` to `path-not-found` on the entire cell.

The second row also puts the legacy queue under **existence-verification**:
`check_cell` runs on every non-informational row (`:349`) *before* the
required-vs-additional branch (`:361`), so deleting `plans/FRAMEWORK-TODO.md`
without removing its row makes the parser report `path-not-found`.

**That is a property of the parser, not of CI — do not read it as a guardrail.**
Nothing in `.github/workflows/` invokes `install/apply-standards.sh`, and
`standards-drift-self.yml` runs `sync/check-standards-drift.sh`, which never
reaches `governance_check`. The check has no automated reader on canon or on any
consumer; wiring one is filed as
[#355](https://github.com/vladm3105/aidoc-flow-ci/issues/355). Until that lands
the retirement must run the check by hand, and this row is a prose ⚠️ that
*can* be checked — not one that *is*.

**Executing this section:** after editing `CLAUDE.md`, run
`python3 install/parse-governance-table.py CLAUDE.md --repo-root .` from this
repo's root and confirm `errors: []`. That run is the only verification the row
gets.

---

## 4. The edit-mode taxonomy — the contract PLAN-021 inherits

`apply.py` has exactly one edit mode: it demands *"Return the COMPLETE
replacement file"*, and refuses any source over 200 KB. §1 shows that is the
wrong shape for two of the three surfaces.

| Surface | Mode | Guard |
|---|---|---|
| CHANGELOG | anchored insert | assert the diff is a pure insertion — **plus a retained volume ceiling**, see below |
| HANDOFF | whole-file regeneration | stays high-risk / human-reviewed: whole-file is *correct* here, and it is the highest-judgment document |
| README / docs / ROADMAP | targeted edit | unchanged |

**"Pure insertion" is stronger in one direction and WEAKER in the other — do not
state it as a straight upgrade.** `apply.py` computes its changed-line count as a
per-opcode `max` of the deleted and inserted spans, and for an `insert` opcode the
deleted span is 0 while the inserted span is the full inserted-line count — so
**the 400-line ceiling already bounds insertions**. A pure-insertion assert bounds
*deletions* only; a 5,000-line runaway or an injected append satisfies it. **Keep
a volume ceiling alongside the insertion invariant.**

**Two constraints an implementation must not conflate:**

- **The mode change and the guard change are separate.** Removing the 200 KB
  refusal is justified by "nothing reads the whole file" — which holds only if
  what is **sent to the model** also changes. As written, `apply.py` prompts for a
  complete replacement file and writes a `.proposed` sibling; a pure-insertion
  assert over a whole-file regeneration is satisfiable only if the model
  reproduces every other byte exactly, which is *harder* on long files. Specify
  the prompt/IO change, not just the guard.
- **Legitimate heading-touching changelog edits exist**, so the invariant cannot
  be unconditional: `release.sh prep` promotes the Unreleased heading to the
  release version at every cut, and §1.1's own recommendation to normalise
  canon's heading is itself a non-insertion edit. Scope the invariant to the
  **maintainer** path.

**Sequencing:** this is PLAN-021 Phase 2 and lands after PLAN-021. Both touch
`apply.py`, and PLAN-021 currently parks *"section-scoped edits for append-only
docs"* as out of scope — a line to update when Phase 2 opens, not before. Two
plans claiming one scope is its own defect.

---

## 5. Deliberately cut — and why

An earlier revision also carried the **migration**: triaging 57 `FT-NN` entries,
filing ~26 issues across 6 repos, deleting `plans/FRAMEWORK-TODO.md`, and
cleaning 48 inbound references. Three independent review passes returned **12, 9
and 7** load-bearing findings and did not converge. By my tally **22 of the 28
landed in the migration and execution sections**; the model sections above took
six between them, all folded and stable across the two subsequent passes.

The root cause was a routing rule that is **not decidable from the data**: it
asked whether an entry "stays in its plan", which requires knowing which plan
*owns* it. A sweep of `plans/` found **17 files mentioning `FT-NN` across 8
status vocabularies**, 5 with no status line at all, and no mechanical way to
separate ownership from historical mention (`PLAN-018` mentions 27 as history;
one `READY` plan mentions 24).

**That rule only exists because deletion forces every entry to have a
destination.** Cutting the migration does not solve the problem — it removes it.
The retirement is tracked as its own work, with its open decision recorded there:
whether to drop the queue-only clause for the migration and simply file every
open entry.

**Also cut:** the governance row's target-state wording (§3 now describes
reality), and any claim that the tracker becomes the single backlog surface
today — it does not, and will not until the migration lands.

---

## Claim ledger

| # | Claim | Symbol | Citation |
| --- | --- | --- | --- |
| 1 | The governance table declares the backlog not adopted — while the queue file exists | `TODO / backlog \| Not adopted` | CLAUDE.md:73 |
| 2 | The queue file that contradicts it | `# FRAMEWORK-TODO —` | plans/FRAMEWORK-TODO.md:1 |
| 3 | Canon's own changelog uses the UNBRACKETED anchor — the fleet outlier | `## Unreleased` | CHANGELOG.md:6 |
| 4 | `apply.py` has one edit mode: whole-file regeneration | `Return the COMPLETE replacement file` | scripts/doc-maintainer/apply.py:66 |
| 5 | ...and refuses any source over 200 KB | `if len(original.encode()) > 200_000:` | scripts/doc-maintainer/apply.py:59 |
| 6 | The changed-line count already bounds INSERTIONS, so pure-insertion alone is weaker | `max(i2 - i1, j2 - j1)` | scripts/doc-maintainer/apply.py:91 |
| 7 | PLAN-021 parks section-scoped edits — the line Phase 2 updates | `section-scoped edits for append-only docs` | plans/PLAN-021_doc-maintainer-dry-run-cluster.md:479 |
| 8 | The promotion bar's test is ownership, not severity | `ownership, not severity` | docs/AGENT_FEEDBACK_INTAKE.md:47 |
| 9 | The five-part body contract that attaches to the outbound act | `Issue body contract` | docs/AGENT_FEEDBACK_INTAKE.md:159 |
| 10 | Close asymmetry — the reporter never closes another repo's issue | `never close another repo's issue` | docs/AGENT_FEEDBACK_INTAKE.md:204 |
| 11 | `source` vs `target` vocabulary — provenance vs ownership | `Vocabulary` | docs/AGENT_FEEDBACK_INTAKE.md:229 |
| 12 | The below-bar clause this plan defers to the migration | `stays in the worked` | docs/AGENT_FEEDBACK_INTAKE.md:88 |
| 13 | ...and the capture-surface row naming `plans/` as half the surface | `capture and publish coincide here (TODO file declined)` | docs/AGENT_FEEDBACK_INTAKE.md:73 |
| 14 | What the OPS-0076 carve-out permits | `What the autonomy-tier carve-out permits (OPS-0076)` | docs/AGENT_FEEDBACK_INTAKE.md:277 |
| 15 | The decision granting it | `## OPS-0076` | ops/DECISIONS.md:2921 |
| 16 | The skill's scope table declares ci's surface as plans + GitHub issues | `capture and publish coincide` | skills/submit-feedback/SKILL.md:39 |
| 17 | The parser strips a PARENTHESIZED annotation from a path cell — one of the two forms it strips, the other being a trailing `§N`/`#anchor` at `:172`; an em-dash annotation is stripped by neither, which is why §3's row is parenthesized | `paren_idx = cell.find(" (")` | install/parse-governance-table.py:180 |
| 18 | ...and rejects a cell holding two comma-separated backticked paths, which the §3 annotation must therefore avoid | `MULTI_VALUE_RE = re.compile` | install/parse-governance-table.py:83 |
| 19 | Every non-informational row is existence-checked BEFORE the required-vs-additional branch — which is what puts §3's second row under verification | `verified, extracted, err = check_cell` | install/parse-governance-table.py:349 |
| 20 | The governance check's only call site — reached solely by a hand-run of `apply-standards.sh`, never by CI (#355) | `governance_check` | install/apply-standards.sh:433 |

*Rows 1-7 and 17-20 resolve against this repo; 8-15 against
`/opt/data/aidoc-flow/operations`; 16 against `/home/ya/.claude`.*

*Not in the ledger because the path collides with this repo's own file and the
gate would resolve it to the wrong source: the `gh issue list` 30-item default,
recorded in framework's durable traps —*
`grep -n 'defaults to .--limit 30' /opt/data/aidoc-flow/framework/CLAUDE.md` *(:901).*

---

## Review log

### Pass 4 — 2026-07-31 — independent ×3 on the superset (model + migration), summarised

Three independent `verified-planning-reviewer` passes returned **12, 9 and 7**
load-bearing findings, reaching the OPS-0066 cap without converging. Full
per-finding detail is in git history (`7550c1d`, `25912f9`).

**Against the sections retained above, those passes produced six findings, all
folded and all stable across the subsequent passes:**

- §4 (taxonomy): "pure insertion" is weaker than the guard it replaces in the
  addition direction — the changed-line count already bounds insertions (folded);
  and the mode change vs guard change were conflated, with legitimate
  heading-touching edits unnamed (folded).
- §2: the queue-only category does **not** dissolve — the contract routes a
  below-bar finding to the worked plan (folded; now explicitly deferred to the
  migration rather than resolved here).
- §3 (governance row): an earlier row narrowed the contract, dropping `plans/` as
  half the capture surface and the below-bar disposition (folded).
- §1.1: the anchor survey's denominator was unstated (folded — nine repos, with
  `feedback-desk` excluded and said so).
- Header: gated execution on a section that no longer existed (folded).

**No finding against §1's three-surface model or §2's feedback-as-direction
argument survived any pass.**

### Pass 5 — 2026-07-31 — self (the narrowing)

The cut removes the 57-entry triage, the execution/PR sequence and the file
deletion — the sections carrying 22 of the 28 findings — and with them the
undecidable routing rule that was the standing blocker.

Two things are **new in this revision** and therefore carry no independent-review
provenance; both are small and stated conservatively:

1. **§3's governance row now describes reality, not the target state**, with an
   explicit clause naming the queue file as still live. Without it the row would
   assert "GitHub issues are the backlog" over a 1,896-line queue — the same
   false declaration being fixed, inverted. This was the specific trap identified
   before narrowing.
2. **§5 records what was cut and why**, so the migration is deferred *visibly*
   rather than dropped.

**No fourth independent pass was dispatched** — OPS-0066's cap is reached, and
the retained content's review provenance already stands. The narrowing is a
subtraction plus the two additions above; re-reviewing subtracted text would not
be a use of the cap.

**Result:** ready — no findings outstanding against the retained scope.

### Pass 6 — 2026-07-31 — execution pre-flight: §3's row was unexecutable

One finding, found by running the check the row has to pass rather than by
reading it. §3 quoted a prose row; `install/parse-governance-table.py` reads a
row's entire path cell as a path, and strips only a trailing `§N`/`#anchor` or a
parenthesized annotation. Measured against this repo's `CLAUDE.md`: baseline
`errors: []`, with the quoted row `path-not-found` naming the whole cell. The
change that corrects the table for being false would have made canon's own
governance parser report an error on canon's own repo.

Folded: §3 now carries the two-row shape that measures clean, and the ledger
gains rows 17-18 citing the two parser behaviours that constrain it. The
retained model sections (§1, §2, §4, §5) are untouched — the defect was in how
the record is *written*, not in what it says.

**A note for whoever edits this repo's `CLAUDE.md` governance table:** the row
is machine-parsed. Write the path cell as a backticked path followed by a
parenthesized annotation, and run
`python3 install/parse-governance-table.py CLAUDE.md --repo-root .` from this
repo's root before pushing. A prose cell parses as a path and fails. The same
hazard exists in every workspace repo's table, but the command is repo-local —
elsewhere the parser has to be fetched, which is why `apply-standards.sh:356`
curls it.

### Pass 7 — 2026-07-31 — re-verification of the Pass 6 fold

Pass 6's fold is verified the same way the finding was found: §3's replacement
row was spliced into a scratch copy of this repo's `CLAUDE.md` and parsed.
`errors: []`; the required `TODO` row resolves to `plans/` (verified), and the
additional row resolves to `plans/FRAMEWORK-TODO.md` (verified). The annotation
carries no comma-separated backticked pair, so `MULTI_VALUE_RE` does not trip.

No other section was touched by the fold, so nothing else needs re-review.

**Result:** ready — no findings outstanding.

### Pass 8 — 2026-07-31 — independent ×2 on the Pass 6/7 edit

`code-reviewer` returned **FAIL** on four findings, `documentation-specialist`
**PASS** on three. Every one of them landed on text Passes 6 and 7 had *added* —
none on the model sections. All seven are folded. The two structural ones were
re-derived here before folding rather than taken on report:

1. **The self-policing claim asserted a guardrail that does not run.** Pass 6
   wrote that deleting the legacy queue "turns the check red". The *parser*
   reports `path-not-found` — but `governance_check` has one call site
   (`install/apply-standards.sh:433`), nothing in `.github/workflows/` invokes
   `apply-standards.sh`, and `standards-drift-self.yml` runs
   `sync/check-standards-drift.sh`, which never reaches it. Confirmed by grep
   over both trees. This is the workspace's own "an absence is the easiest
   defect to assert" trap, inverted into asserting a *presence*. §3 now
   distinguishes the parser's behaviour from CI's, and the missing wiring is
   filed as [#355](https://github.com/vladm3105/aidoc-flow-ci/issues/355).
2. **"a *required* row's path cell" contradicted the conclusion drawn from it.**
   `check_cell` runs on every non-informational row (`:349`) *before* the
   required-vs-additional branch (`:361`) — which is exactly why the additional
   row is verified at all. Fixed in §3 and Pass 6; ledger row 19 cites it.
3. `extract_path` strips **two** annotation forms, not one — the `§N`/`#anchor`
   strip at `:172` runs before the paren strip at `:180`. Row 17 and both prose
   copies corrected.
4. §3 carried no instruction to run the parser; the command existed only inside
   a review-log entry, which is a record, not a step. §3 now ends with it.
5. The rationale for one row rather than a capture/publish split had been
   dropped from the operative row text, reachable only by following a ledger
   citation into a sibling repo. Restored as prose in §3.
6. Pass 6's note addressed "anywhere in this workspace" while giving a
   repo-local command. Scoped, with the reason the portable form differs.
7. "the stronger form" was an evaluative comparative; replaced by the concrete
   property it was standing in for.

Each fold is verified by the same command that produced the finding —
`errors: []` on the spliced table, and the greps in item 1 re-run against both
trees.

**Result:** ready — no findings outstanding.
