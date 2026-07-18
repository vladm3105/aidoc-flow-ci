# ops/inbox runbook — report-only security-scanner pilot on `operations`

**Owner:** founder (this is a 🔴 cross-repo write — AI prepared it, does not execute it).
**Goal:** adopt the three PLAN-014 own-security scanners (`dep-scan`, `trivy-scan`,
`sast-scan`) on `aidoc-flow-operations` in **report-only** mode, as the pilot before
any fleet propagation. No gate is made blocking here (Phase 5 is later).
**Canon version:** `ci/v2.7.0`. **Secrets needed:** none.

---

## 0. Why operations is the pilot

- It is the one repo with a live `ci-runner`/`single-use` self-hosted pool (the
  scanners run self-hosted, uniform on public+private — PLAN-013).
- It exercises all three scanners with real targets (surveyed 2026-07-18):
  - `dep-scan` → `pyproject.toml` (real Python deps; **no `expect-manifests` tuning
    needed** — it has a manifest, so no zero-coverage warning).
  - `trivy-scan` → `scripts/ci-runner/Dockerfile` (real Dockerfile misconfig target).
  - `sast-scan` → 12 shell + 13 Python files (semgrep `p/default` covers both).

## 1. Prerequisites — verify BEFORE the PR

1. **Pool online:** `gh api repos/vladm3105/aidoc-flow-operations/actions/runners
   --jq '[.runners[]|select(.status=="online")|[.labels[].name]|join(",")]'` shows a
   `ci-runner`,`single-use` runner. (Ideally ≥2 instances — this adds +3 jobs/PR to a
   SERIAL pool; see §5.)
2. **Runner egress (the one real risk):** the ephemeral runner must reach —
   - `github.com` release assets (osv-scanner + trivy binaries, curl-installed),
   - PyPI (`semgrep==1.170.0`, pip-installed),
   - `semgrep.dev` registry (the `p/default` ruleset).
   If the pool is network-restricted, a scanner fails **loud** (infra error, by design)
   — confirm egress or pre-bake the tools into `aidoc-flow-runner:latest`.
3. **Allowed-actions policy** already permits `actions/*`, `github/*`,
   `vladm3105/aidoc-flow-ci/*` (the scanners use `actions/checkout` +
   `github/codeql-action/upload-sarif` + the reusable) — verify with
   `gh api repos/vladm3105/aidoc-flow-operations/actions/permissions/selected-actions`.
4. SARIF upload no-ops on private-without-GHAS (it's `continue-on-error`); the
   `fail-on-findings` gate is the control, not the upload. Nothing to do.

## 2. Scaffold the three callers (the clean path)

From an `aidoc-flow-ci` checkout at `ci/v2.7.0`:

```bash
# produces 3 caller workflows into <workdir>/.github/workflows/, pinned @ci/v2.7.0,
# report-only, self-hosted labels baked, no secrets.
install/deploy-ci-wizard.sh scaffold vladm3105/aidoc-flow-operations <workdir> \
  dep-scan trivy-scan sast-scan
```

(Or copy `install/templates/workflows/{dep-scan,trivy-scan,sast-scan}.yml` by hand.)
Each caller ships `fail-on-findings: false` and
`runner_labels: '["self-hosted","ci-runner","single-use"]'` — leave both as-is.

## 3. Open the PR (operations repo conventions)

- **Branch-first** (`feat/adopt-plan014-scanners` — never commit to a protected base).
- Add the 3 files; confirm each pins `@ci/v2.7.0`.
- CHANGELOG entry + the **OPS-0069 audit-trail phrase** in a commit body.
- One PR (or one-per-scanner if you prefer smaller review surface).
- Let the existing operations CI (ai-review + audit-trail + composition) gate it.

## 4. Success criteria (what "the pilot works" means)

- All three scanner jobs run on the self-hosted pool and finish (green).
- `dep-scan` scans `pyproject.toml`; `trivy-scan` scans the Dockerfile; `sast-scan`
  scans the shell+Python — each emits a SARIF and a job-summary line.
- Findings (if any) appear as **warnings/annotations only** — no scanner ever blocks a
  PR (report-only). If a scanner *fails*, it is an infra error (egress/tool), not a
  finding — read the `::error::` line; re-run after fixing the cause.
- Optionally flip `sast-scan`'s `autofix-preview: true` on one PR to see a deterministic
  fix patch in the job summary (still nothing pushed).

## 5. Capacity note

operations' PR fan-out grows by 3 jobs. On a single serial `ci-runner` instance these
queue behind the existing ~8 jobs. If PR feedback slows, run **N parallel runner
instances** (`operations/scripts/ci-runner/run-ephemeral.sh`) — do NOT move any job to
`ubuntu-latest` (OPS-0049 / self-hosted-only policy).

## 6. Explicitly NOT in this pilot (later / founder steps)

- **Do NOT flip `fail-on-findings: true`** — that is PLAN-014 **Phase 5**, per-scanner,
  after a clean report-only window (~1–2 weeks or N clean PRs). Track findings first.
- **Do NOT add the scanners to branch protection** (they are not required checks yet).
- **Autofix push-back** (writing a fix back to a PR) is separate — it needs the
  dedicated autofix App (PLAN-012, 🔴), not part of this pilot.

## 7. Rollback

Delete the three caller files (`.github/workflows/{dep-scan,trivy-scan,sast-scan}.yml`)
in a PR. No secrets/App/pool state to unwind — the pilot is stateless.

## 8. After a clean window → propagate

Repeat §2–§4 for the next repos, each gated on its own pool:
`business` / `iplanic` / `interlog` (private — need a pool registered first) and the
public repos (need a pool for the self-hosted scanner jobs). Then Phase 5 graduation
per scanner. (`web-site` + `knowledge-rag` are paused — skip.)
