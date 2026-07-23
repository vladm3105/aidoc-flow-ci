# PLAN-014 — security-scanning coverage: own scanners + GitHub-native

**Owner:** `aidoc-flow-ci` maintainer
**Origin:** founder directive (2026-07-18): "we should have own security scanners
AND GitHub native" → refined: **our own scanners are MUST-HAVE; GitHub-native is a
NICE-TO-HAVE only where it is FREE.** GitHub Advanced Security (Code scanning /
native secret scanning) is **free on public repos, a paid tier on private** — which
this account does not license — so the native layer is pursued only on public repos,
and only because it costs nothing extra (best-effort SARIF upload). The canon has
secret-scanning (gitleaks, own + SARIF to Code scanning), SAST (CodeQL, native), and
Dependabot (updates + alerts) — but **no dependency-vulnerability gate (SCA), no
filesystem/IaC/misconfig scanning, and no own SAST**. This plan closes that with new
**own-scanner** reusables (CI `fail-on-findings` gate — the required, fleet-wide
floor, private included) that ALSO surface for free in GitHub Code scanning on public
repos (the bonus). **No paid GHAS feature is ever proposed.**
**Status:** IMPLEMENTED (Phases 1-4, 2026-07-18) — **all three scanners shipped**
report-only: `dep-scan` (`ci/v2.4.0`), `trivy-scan` (`ci/v2.5.0`), `sast-scan`
(`ci/v2.6.0`), + deterministic autofix **preview** (`ci/v2.7.0`, Phase 4 preview
subset). Each shipped with a full OPS-0065 pre-push security review (4 HIGH + 2 MEDIUM

- 1 LOW folded across the four releases). **Remaining:** Phase 5 (graduate
`fail-on-findings` false→true per scanner — a **founder step**) + the deferred Phase 4
push-back subset (batched with the 🔴 PLAN-012 autofix-App enablement). Original
approval: founder 2026-07-18 — **all three scanners in**, **report-only first but
graduation-ready**, **autofix the findings** (§4a).
**Depends on:** [[PLAN-013]] uniform-protected model (new scanner reusables ship as
single self-hosted protected templates, public+private, no visibility split).
**Exit:** each in-scope concern (SCA, filesystem/IaC, SAST) has an **own** canon
reusable (the MUST-HAVE deliverable) that installs its tool with integrity
verification — a SHA-256-verified static binary (osv-scanner, trivy) or a hash-pinned
pip install (semgrep) — **never a third-party action** (REPO_STANDARDS §4.3), runs a
`fail-on-findings`-toggled PR gate on **public AND private** repos via the ai-review
trust-gate (fork → skip → human review; trusted → scan on self-hosted), so **a
public↔private flip changes nothing** (§1a). The
NICE-TO-HAVE, zero-cost layer: the same reusable best-effort **uploads SARIF to
GitHub Code scanning** (`continue-on-error`) — which lands only on public repos
(free GHAS) and silently no-ops on private (no license, no cost, no failure). Only
**free** native settings are touched (public-repo Code scanning / secret-scanning
push protection / dependency-review); no paid GHAS is enabled.

---

## 1. Summary

The canon already proves the exact pattern this plan needs. **`secret-scan.yml`**
installs the gitleaks **binary** (curl + SHA-256 verify + tar — Claims 1, 2), runs
a fail-on-findings gate (Claim 3), AND best-effort **uploads SARIF to GitHub Code
scanning** via `github/codeql-action/upload-sarif` (`continue-on-error`, fork-
guarded — Claim 4). That single shape is **dual-mode by construction**: the
scan+fail step is the real gate (runs everywhere, private included), and the SARIF
upload silently no-ops where GHAS is absent (private repos — Claim 8's N/A). So
"own scanners + GitHub-native" is not two systems — it is **one reusable per tool,
cloned from `secret-scan.yml`.**

**What's missing (the gaps):**

- **SCA / dependency-vulnerability gate** — Dependabot gives *alerts* (out-of-band)
  - update PRs (Claim 6), but nothing **blocks a PR that introduces a known-CVE
  dependency**. No `osv-scanner`/`pip-audit`/`dependency-review` in the pipeline
  (Claim 5).
- **Filesystem / IaC / misconfig scanning** — no `trivy`-class scan (Claim 5).
- **Own SAST** — CodeQL is native-only (Claim 7) + public-only (GHAS, Claim 8);
  there is no own SAST that gates private repos.

**The constraint that shapes everything (REPO_STANDARDS §4.3, Claim 9):** canon
reusables may `uses:` only `actions/*`, `github/*`, `vladm3105/aidoc-flow-ci/*`. So
`aquasecurity/trivy-action`, `google/osv-scanner-action`, `returntocorp/semgrep`
are **forbidden** — each tool is installed **directly** with integrity verification
(a SHA-verified static binary for osv-scanner/trivy, a hash-pinned pip install for
semgrep — §2), like `secret-scan` installs gitleaks. SARIF upload uses
`github/codeql-action/upload-sarif` (github/*, allowed).

## 1a. Uniform protected, ai-review-style (founder requirement, 2026-07-18)

**The scanners MUST use the same approach as `ai-review`: one template that runs the
same scanners on public AND private repos, so a repo can switch public↔private↔public
with NO change** (no `-public`/`-private` split; a visibility flip is a no-op). That
makes the security scanners **AI-flow-class** (uniform self-hosted per [[PLAN-013]]),
**not** generic-lint-class.

The generic lint flows (`markdown-lint`/`links`/`pre-commit`) stay GitHub-hosted on
public *because they run every PR's files including a fork's* (untrusted-code-on-
self-hosted). The security scanners avoid that by **borrowing ai-review's two-job
trust gate**, so they can be uniform self-hosted safely:

- **Job 1 `trust`** (isolated, no PR code — the ai-review trust job's shape): reads
  the trusted allowlist + PR metadata, decides trusted-vs-fork.
- **Job 2 `scan`** (`needs: trust`, self-hosted): runs the scanner ONLY for a
  **trusted, non-fork** author. A fork / non-allowlisted PR is **skipped → human
  review** — the exact same tradeoff `ai-review` already makes. So a fork's files
  never reach the self-hosted scanner, and the same single template is safe on
  public and private alike.

This is the load-bearing safety argument for uniform-self-hosted scanners and the
direct answer to the flip-safety requirement.

**A public↔private flip breaks neither the CI flow nor security compliance:**

- **CI flow unchanged.** One self-hosted template, no visibility branch in
  templates/manifest/installer — the exact same jobs run before and after the flip.
  No re-install, no `-public`/`-private` re-resolution, no queue-forever / no
  `startup_failure` (the failure modes a mis-matched variant would cause).
- **Security compliance unchanged.** The `fail-on-findings` **gate is the
  compliance control**, and it runs on the self-hosted pool regardless of
  visibility — so the security posture is identical on public and private. Only the
  **free native bonus** (SARIF → Code scanning, GHAS-public-only) toggles with
  visibility, and it degrades **gracefully** (`continue-on-error` — Claim 4): on a
  flip to private the upload simply stops landing in the Security tab; it never
  fails the job or weakens the gate. Compliance rides on the own scanner, which is
  why it is the must-have and the native layer is the nice-to-have.

## 2. The two-layer model (per concern)

| Concern | OWN scanner (CI gate, fleet-wide incl. private) | GitHub-NATIVE (public repos, GHAS) |
| --- | --- | --- |
| Secrets | `secret-scan.yml` — gitleaks binary + fail-on-findings ✅ **exists** | native secret scanning + push protection (settings) + gitleaks SARIF → Code scanning ✅ **exists** |
| SAST | **NEW** `sast-scan.yml` — semgrep (hash-pinned **pip**, not a binary — tool-fact T3) + fail-on-findings | CodeQL (`codeql.yml`) ✅ **exists** + semgrep SARIF → Code scanning |
| SCA / deps | **NEW** `dep-scan.yml` — osv-scanner **binary** (tool-fact T1) + fail-on-findings | `dependency-review-action` (github/*, PR dep-diff) + Dependabot alerts ✅ + SARIF → Code scanning |
| Filesystem / IaC | **NEW** `trivy-scan.yml` — trivy **binary** (tool-fact T2; fs + config) + fail-on-findings | trivy SARIF → Code scanning + native settings |

**Install mechanism differs by tool** (Finding folded): osv-scanner + trivy ship
SHA-pinnable static linux tarballs → the exact gitleaks curl+`sha256sum` pattern
(Claims 1, 2; tool-facts T1, T2). **semgrep does NOT ship a static binary** — it is PyPI-distributed,
so it installs via a **hash-pinned `pip install semgrep==X`** (consistent with
`pre-commit.yml`'s existing pip usage), still no third-party action (tool-fact T3). Do
not present all three under one "binary" mechanism.

Every NEW reusable = the `secret-scan.yml` clone: install the SHA/hash-verified tool
→ run with a `fail-on-findings` input (default `false` for a staged rollout, then `true`)
→ emit SARIF → best-effort `upload-sarif` (continue-on-error, fork-guarded). Ships
as a single self-hosted protected template per [[PLAN-013]]. **The OWN column is the
must-have; the NATIVE column is a free bonus** — the same reusable produces both, so
the native layer adds no separate work and no cost (it simply lands on public repos
where GHAS is free and no-ops on private).

## 3. Scanners to add (recommended tools)

- **SCA — `osv-scanner`** (recommended over pip-audit). One language-agnostic tool
  covers pip + npm + GitHub Actions + go from lockfiles/manifests, emits SARIF, is
  OpenSSF-maintained, and ships a static binary (SHA-pinnable). Plus the
  **`dependency-review-action`** (github/*, allowed) as the native PR dep-diff on
  public repos. *(pip-audit is a viable Python-only alternative — §7 D-1.)*
- **Filesystem/IaC — `trivy`** (`fs` mode: vulnerable deps + misconfig + embedded
  secrets; `config` mode: Dockerfile/IaC). Static binary, SARIF. Overlaps
  osv/gitleaks on deps/secrets — run it in **config/misconfig** mode primarily to
  minimize duplication (§7 D-2).
- **SAST — `semgrep`** (own SAST complementing native CodeQL). **PyPI-distributed —
  NOT a static binary** (tool-fact T3): install via a hash-pinned `pip install
  semgrep==X` (the runner image has `python3`; `pre-commit.yml` already pip-installs
  pinned tools), `--sarif` output. *(Optional — §7 D-3; CodeQL already covers native
  SAST on public repos, so semgrep's value is gating **private** repos — where CodeQL
  is N/A — plus a second engine.)*

## 4. GitHub-native enablement — FREE features only (nice-to-have)

Only **free** native features are touched — all public-repo-only (GHAS is free on
public, paid on private). **This plan never enables a paid GHAS feature.** Threaded
through `apply-standards.sh` (Claim 10) + REPO_STANDARDS §3 (Claim 8):

- **Code scanning on public repos (free):** the new SARIF uploads land there
  automatically once `security-events: write` is set on each reusable (like
  secret-scan) — zero extra cost, best-effort.
- **Secret-scanning + push protection on public repos (free):** already the §3 hard
  rule; verify `apply-standards` asserts it.
- **`dependency-review-action` (github/*, free on public):** add to the SCA
  reusable's public path.
- **Private repos:** native Security-tab features are N/A (GHAS unlicensed, Claim 8)
  — **not a gap to close and not a cost to incur**; the own-scanner CI gates are the
  full coverage there. That is exactly the must-have/nice-to-have split.

## 4a. Autofix the findings (founder requirement, 2026-07-18) — where it is SAFE

Security findings are auto-remediated **only where the fix is deterministic AND
data-only** (never executes PR code, never guesses). An independent review
(Pass 5) killed the naive "auto-fix everything" version; the honest, per-class
design:

- **SAST (semgrep) — YES, the one clean auto-fix path.** `semgrep --autofix`
  applies a fix the *rule itself* defines — static, never runs the target code,
  deterministic. It edits in place, so the pipeline runs `git diff` to derive the
  patch. Only the minority of rules carrying a `fix:` key autofix; every other
  finding **escalates** (report + human). No model.
- **SCA (osv-scanner) — NO in-CI autofix; remediation is DEFERRED to Dependabot.**
  A *valid* dependency bump requires re-running the ecosystem resolver
  (`npm install` runs lifecycle scripts; `pip`/sdist runs `setup.py`) — that
  **executes untrusted PR code on the self-hosted runner**, breaking §1a's data-only
  safety, and is *more* dangerous than the model path it would replace (Pass-5 F1).
  So our `dep-scan` is the **gate** (report/block a within-PR introduced vuln);
  **Dependabot security updates** own the actual bump — they run in **GitHub's
  isolated infra**, not ours. Different moments, no arbitration (§7 D-5).
- **Filesystem/IaC (trivy) — NO autofix; escalate-only.** Trivy is a scanner with
  **no fix capability** (Pass-5 F2); in config/misconfig mode it emits prose
  guidance, not an appliable patch. Report + escalate to a human.

**Architecture — a PARALLEL fix pipeline sharing only the push half + one counter,
NOT a trigger tweak (Pass-5 F3/F4/F5).** The shipped [[PLAN-012]] autofix job is
hard-wired to the ai-review verdict artifact + `request_changes` and its generation
step *is* the model call — a scanner finding has neither. So Phase 4 builds a
**separate scanner-autofix codepath** (its own finding source + gate) that:

- **shares** the already-reviewed **two-step pristine-clone App-token push**, the
  governance **deny-floor** (diff-parse + post-apply), **fork-exclusion / trust-gate**,
  and **default-off**;
- shares **ONE round counter** with the ai-review autofix (else combined bot-commits
  reach 2× cap) and **ONE serialized concurrency group** (else two autofix paths race
  two App-token pushes to the same head);
- has **NO LiteLLM dependency** — the model boundary is *structural*, not a
  convention: the scanner-autofix generator never mints `LITELLM_FIX_API_KEY` /
  calls the client (asserted by a test). **Model-based fixing stays exclusive to
  ai-review's code findings** ([[PLAN-012]] D-2a).

Every scanner-autofix commit re-fires the gate and is re-reviewed; anything that
breaks CI fails and escalates, never merges unseen.

## 5. Scope & non-goals

- **In scope:** the three new own-scanner reusables (SCA / filesystem-IaC / SAST) +
  native-settings enablement, all mirroring `secret-scan.yml` + the PLAN-013 model.
- **Not a required-check bump now.** New gates ship `fail-on-findings: false`
  (report-only) first; graduating to blocking + adding to branch protection is a
  later founder step (mirrors the markdown-lint graduation).
- **No third-party actions** (REPO_STANDARDS §4.3) — binaries only.
- **Deferred:** container-*image* scanning (`trivy image`) until a repo ships a
  built image (the runner image lives in operations); DAST; license scanning.

## 6. Phases

- **Phase 0 (this plan + gate).** Draft + independent review + founder go/no-go (§7). ✅ **DONE.**
- **Phase 1 (SCA — the biggest gap).** ✅ **DONE — `ci/v2.4.0`.** `dep-scan.yml`
  (osv-scanner binary, `--no-call-analysis=all` + `expect-manifests`, fail-on-findings +
  SARIF upload) + manifest + caller template (PLAN-013 single) + docs + tests.
  Security-reviewed pre-push (2 HIGH folded + verified).
- **Phase 2 (filesystem/IaC).** ✅ **DONE — `ci/v2.5.0`.** `trivy-scan.yml`
  (`trivy config` only). SSRF-hardened to static scanners (terraform/helm/ansible fetch
  PR-controlled remote sources; `--tf-exclude-downloaded-modules` does NOT stop the
  fetch — verified). 1 HIGH folded.
- **Phase 3 (own SAST).** ✅ **DONE — `ci/v2.6.0`.** `sast-scan.yml` (semgrep,
  version-pinned pip into a venv). `--metrics off` + explicit `--config`; strips
  PR-supplied `.semgrepignore` (a `*`-ignore was a full gate-bypass — verified) +
  fail-loud on broken SARIF. 1 HIGH + 1 MEDIUM folded.
- **Phase 4 (autofix the SAFE findings — §4a).** ✅ **DONE (PREVIEW subset) — `ci/v2.7.0`.**
  Founder chose the **preview-only** shape (2026-07-18): `sast-scan`'s `autofix-preview`
  input runs `semgrep --autofix` in the ephemeral workspace and surfaces the
  deterministic (rule-provided, **no LiteLLM**) patch in the job summary — **nothing is
  pushed**, so it needs no App and ships un-gated / dormant-free. Security-reviewed
  READY (LOW summary-fence-breakout nit folded). **DEFERRED** (originally-scoped
  push-back subset): feeding the patch through the shared two-step App push + deny-floor +
  shared round counter is gated on the same 🔴 founder autofix-App enablement as
  PLAN-012 — batch it there, not as a standalone dormant flow. SCA remediation is
  Dependabot's (deferred); trivy is escalate-only.
- **Phase 5 (graduate + native settings).** ⏳ **FOUNDER STEP.** `fail-on-findings:false
  → true` per scanner after a clean window; assert the free native settings via
  `apply-standards`. Each `fail-on-findings` graduation is a founder step (mirrors
  markdown-lint).

## 7. Founder-decision points — RESOLVED (2026-07-18)

1. **SCA tool → `osv-scanner`** ✅ (+ the free native `dependency-review-action` on
   public).
2. **Filesystem/IaC → `trivy` IN** ✅ (config/misconfig-focused).
3. **Own SAST → `semgrep` IN** ✅ (covers private repos where CodeQL is N/A).
4. **Rollout → report-only first, built graduation-ready** ✅ — ship
   `fail-on-findings: false`, but the toggle + tests exist from day one so flipping to
   blocking is a one-line founder step per scanner after a clean window.
5. **Autofix the findings → YES, where SAFE** ✅ (§4a) — `semgrep --autofix` (the one
   deterministic + data-only path) through PLAN-012's shared push machinery,
   default-off, own security review (Phase 4). SCA remediation → Dependabot (deferred,
   below); trivy → escalate-only.

**D-5 — SCA remediation ownership (resolved):** the `dep-scan` gate reports/blocks a
vulnerable dep **introduced within an open PR**; the actual **bump is Dependabot's**,
which runs in **GitHub's isolated infra** (not our self-hosted runner, avoiding the
execute-untrusted-resolver hole — §4a). They own **different moments** (Dependabot:
base-branch drift PRs; our gate: within-PR introduced vulns), so there is **no
arbitration/deferral logic** — both simply run. We do NOT run a package resolver in
CI to auto-bump.

## 8. Rejected / deferred alternatives

- **Third-party scanner actions** (`aquasecurity/trivy-action`, etc.) — rejected:
  canon authoring allowlist forbids them (Claim 9); install binaries.
- **Rely on Dependabot alerts alone for SCA** — rejected: alerts are out-of-band
  and don't block a PR introducing a vulnerable dep; a CI gate does.
- **Native Code scanning only** — rejected: GHAS is unlicensed on private repos
  (Claim 8), so a native-only posture leaves operations/business/iplanic/interlog
  (where most code lives) with zero coverage. Own CI gates are the fleet-wide floor.
- **Blocking gates from day one** — deferred: report-only first avoids bricking the
  fleet on a backlog of pre-existing findings (markdown-lint-graduation lesson).

---

## Claim ledger

Citations are `file:line` opened and read.

| #   | Claim                                                                                    | Symbol                     | Citation                                        |
| --- | ---------------------------------------------------------------------------------------- | -------------------------- | ----------------------------------------------- |
| 1   | `secret-scan` installs the gitleaks BINARY (curl download), not a third-party action     | `curl -sSfL`               | .github/workflows/secret-scan.yml:91            |
| 2   | the downloaded binary is SHA-256 verified before use                                     | `sha256sum --check`        | .github/workflows/secret-scan.yml:92            |
| 3   | `secret-scan` gates via a `fail-on-findings` input                                       | `fail-on-findings`         | .github/workflows/secret-scan.yml:46            |
| 4   | `secret-scan` best-effort uploads SARIF to Code scanning (continue-on-error, fork-guard) | `upload-sarif`             | .github/workflows/secret-scan.yml:244           |
| 5   | no SCA / trivy / semgrep scanner exists (only prose mentions in pre-commit.yml)          | `pip-audit`                | .github/workflows/pre-commit.yml:53             |
| 6   | Dependabot ships github-actions + pip ecosystems (updates + native alerts)               | `package-ecosystem`        | install/templates/dependabot.yml:15             |
| 7   | CodeQL is the only SAST + it writes to Code scanning (`security-events: write`)           | `security-events: write`   | .github/workflows/codeql.yml:77                 |
| 8   | Code scanning is N/A on private repos (needs GHAS, unlicensed)                            | `Advanced Security`        | docs/REPO_STANDARDS.md:158                       |
| 9   | canon reusables may `uses:` only `actions/*`, `github/*`, `vladm3105/aidoc-flow-ci/*`     | `only`                     | docs/REPO_STANDARDS.md:287                       |
| 10  | server-side security settings (incl. security features) are applied by apply-standards    | `security`                 | install/apply-standards.sh:30                   |
| 11  | `codeql.yml` ships as a caller template (single, no visibility variants)                 | `codeql.yml`               | install/templates/manifest.json:77              |
| 12  | ai-review's trust job hard-excludes forks (IS_FORK → not trusted) — the gate the scanners reuse | `IS_FORK`             | .github/workflows/ai-review.yml:196             |

**Tool facts (external — verified against upstream release pages, not a repo `file:line`):**

- **T1 — `osv-scanner`** ships a static linux binary on its GitHub releases (with
  SHA256SUMS) and emits SARIF (`--format sarif`) → curl+`sha256sum` install like
  gitleaks. Source: <https://github.com/google/osv-scanner/releases>.
- **T2 — `trivy`** ships a static linux tarball on releases (with checksums) and
  emits SARIF (`--format sarif`), supporting `fs` and `config` modes. Source:
  <https://github.com/aquasecurity/trivy/releases>.
- **T3 — `semgrep`** is **PyPI-distributed** (`pip install semgrep`), **NOT** a static
  binary; install via a hash-pinned pip (like `pre-commit.yml`), emits SARIF
  (`--sarif`). Source: <https://pypi.org/project/semgrep/>. *(These are confirmed at
  Phase-1 implementation time by pinning the exact version + SHA/hash — the plan does
  not bake a version now.)*

## Review log

### Pass 0 — 2026-07-18 — author (self)

Drafted from direct reads of `secret-scan.yml` (the binary-install + fail-on-findings

- SARIF-upload pattern the new scanners clone), `codeql.yml` (native SAST →
Code scanning), `dependabot.yml`, REPO_STANDARDS §3 (the GHAS/private N/A matrix that
forces the own-scanner CI gate) + §4.3 (binary-not-third-party-action allowlist),
and `apply-standards.sh`. The design reuses one proven canon shape per tool rather
than inventing anything; the founder gate (§7) is tool-selection + rollout, not
architecture. **Result:** needs independent review.

### Pass 1 — 2026-07-18 — independent (fresh-context Agent) + founder folds

Independent review verified the core premise (one reusable = fleet-wide
fail-on-findings gate + best-effort SARIF that no-ops gracefully on private —
proven in `secret-scan.yml`) and all 11 claims substantively true. **2 load-bearing
findings folded:** (F1) semgrep is NOT a curl-able static binary — it is
PyPI-distributed → §2/§3/Exit corrected to a hash-pinned pip install; osv-scanner +
trivy remain static binaries. (F2) tool binary/SARIF feasibility was uncited → added
tool-facts T1–T3 (external release pages) since they are not repo `file:line`. Plus
3 citation fixes (Claim 3 → `:46`, Claim 6 → `:15`, Claim 10 symbol).

**Founder requirements folded (2026-07-18):** (a) the scanners MUST use the
**same approach as ai-review** — one template, uniform on public+private, flip = a
no-op → added §1a with the ai-review trust-gate design (fork → skip → human review;
trusted → scan on self-hosted; AI-flow-class not lint-class) + Claim 12. (b) a
public↔private flip must break **neither CI nor security compliance** → added the
explicit flip-safety guarantee (CI unchanged: one template, no variant re-resolution;
compliance unchanged: the fail-on-findings gate is the control and runs regardless of
visibility; the native SARIF bonus degrades gracefully). (c) own = must-have, native =
free-only nice-to-have → threaded through Origin/Exit/§2/§4.

**Result:** needs independent re-review (Pass 2) to confirm the fold + the new
uniform-trust-gate design.

### Pass 2 — 2026-07-18 — independent (fresh-context Agent)

Confirmed the fold. F1 (semgrep pip not binary), F2 (tool-facts T1–T3), the 3
citation fixes, and all three founder requirements (a uniform ai-review trust-gate;
b flip-breaks-neither-CI-nor-compliance; c own-must-have/native-free-only) verified
**CLOSED** against source — the trust job's fork-exclusion (`ai-review.yml:196`),
the graceful `continue-on-error` SARIF degradation (`secret-scan.yml:242-243`), and
the no-paid-GHAS framing all check out. **1 residual load-bearing finding:** §2 line
113 still cited "(Claims 12, 13)" — a renumbering artifact (Claim 12 is now IS_FORK;
Claim 13 never existed) → corrected to "(Claims 1, 2; tool-facts T1, T2)"; Claim 12's
line tightened `:192`→`:196`; and a leftover §1 "each tool is a SHA-verified binary"
qualified for semgrep.

### Pass 3 — 2026-07-18 — author (confirm residual fold)

Verified the residual is fully folded: a grep finds no claim reference beyond Claim
12 (no dead `Claim 13`) and no unqualified "SHA-verified binary" framing remains.
§1/§2/§3/Exit are now consistent on the per-tool install mechanism, and §1a's uniform
trust-gate design is internally consistent with §2's table. No other load-bearing
issue open after two independent passes. **Result:** ready for the §7 founder gate.

### Pass 4 — 2026-07-18 — author (founder decisions resolved + autofix-integration)

Founder (2026-07-18) resolved §7 — **all three scanners in** (osv-scanner, trivy,
semgrep); report-only-first, graduation-ready; **and autofix the findings.** Folded:
§7 marked RESOLVED; Status → APPROVED; new **§4a** designs the autofix-integration —
security fixes are **tool-native / deterministic** (osv dep-bump; `semgrep --autofix`;
trivy tool-fix), NOT model-based (a deliberate safety boundary: model-fixing stays for
ai-review's code findings only), routed through PLAN-012's already-reviewed push
machinery (trust-gate + deny-floor + two-step App push + cap + default-off); the
autofix *trigger* broadens from ai-review-verdict to also a fixable scanner finding.
Phase 4 (autofix-integration) added with its own OPS-0065 review; Phase 5 = graduate.
**Result:** needs independent review of the new §4a design (Pass 5).

### Pass 5 — 2026-07-18 — independent (fresh-context Agent) — §4a autofix design

Adversarial review of §4a against the SHIPPED autofix job. **6 load-bearing findings,
all folded by narrowing §4a to only the safe path:**

- **F1 (HIGH)** — an osv dep-bump is NOT data-only: a valid bump re-runs the ecosystem
  resolver (`npm install` lifecycle scripts / `pip` `setup.py`) → executes untrusted
  PR code on the self-hosted runner, worse than the model path. → §4a: **no in-CI
  SCA autofix**; remediation deferred to **Dependabot** (GitHub's isolated infra).
- **F2 (HIGH)** — trivy has no fix capability. → §4a: trivy is **escalate-only**.
- **F3 (MED-HIGH)** — the shipped autofix job is verdict-coupled + its generation IS
  the model call; "broaden the trigger" under-scopes it. → §4a: a **separate parallel
  fix pipeline** sharing only the push half.
- **F4 (MED)** — the round cap lives in the verdict-gated job; a separate path needs
  the **same counter** + one serialized push, else 2× cap / racing pushes. → folded.
- **F5 (MED)** — "model reserved for ai-review" was a convention, not enforced. →
  §4a: **structural** (no LiteLLM dependency on the scanner path) + a test.
- **F6 (MED)** — "defer to Dependabot where it suffices" was incoherent (Dependabot
  fixes base-branch drift, not within-PR vulns). → D-5 reframed as the split, no
  arbitration.

The one genuinely sound autofix path is `semgrep --autofix` (static, rule-deterministic,
never runs target code; most rules escalate). §4a now claims only that.

### Pass 6 — 2026-07-18 — author (confirm §4a narrowing)

Verified the fold: a grep finds no live overclaim (no `osv-autofix`/`trivy-tool-fix`
as a fix path — only as rejected history in the ledger/Pass-4 record); the model
boundary is stated as structural (no-LiteLLM + test), the round counter is shared,
and `semgrep --autofix` is the sole autofix path. §4a / Phase 4 / §7 D-5 are mutually
consistent. **Result:** ready — APPROVED plan; §7 resolved; implementation is the
phased multi-release build in §6 (each phase = ship + full OPS-0065 review). No
workflow ships until Phase 1 is built + reviewed.
