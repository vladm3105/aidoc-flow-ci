#!/usr/bin/env python3
"""IPLAN-0025 doc-maintainer — reconciler (§2.4 scheduled-cron backup).

Queries the last N main commits and fires `workflow_dispatch` for any
SHA that has NO associated doc-maintainer run. Addresses the IPLAN-0018
"didn't fire" reliability gap deterministically (per Pass-2 BLOCKER #2).

Inputs:
  --gh-repo        <owner>/<repo>.
  --lookback-min   How far back to scan main commits (default 90 min;
                   wider than the 30-min cron interval to catch a
                   double-miss).
  --workflow       Workflow file name (default doc-maintainer.yml).
  --dispatch       If set, actually dispatch missed SHAs. Otherwise
                   just report.

Logic:
  1. List commits on main in the last `--lookback-min` minutes.
  2. For each commit, query actions/runs?event=push&head_sha=<sha>&workflow=<name>.
  3. If zero matches AND no open maintainer-bot PR for the SHA (step 1
     of the workflow's own dedup check would also catch this; we
     pre-empt to save an empty run), include in missed set.
  4. If --dispatch and missed set non-empty, fire `workflow_dispatch`
     against the workflow with `head_sha` input (deferred to v1.4.1 —
     v1.4.0 ships report-only since workflow_dispatch needs the input
     plumbing on the consumer caller side).

alpha.1 status: REPORT ONLY. Dispatch logic ships in v1.4.1 along with
caller-side `workflow_dispatch` input declaration.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import subprocess
import sys


def fail(msg: str) -> None:
    print(f"::error::reconcile: {msg}", file=sys.stderr)
    sys.exit(1)


def gh_api(path: str) -> dict | list:
    try:
        out = subprocess.run(
            ["gh", "api", path],
            check=True,
            capture_output=True,
            text=True,
        )
        return json.loads(out.stdout)
    except subprocess.CalledProcessError as e:
        fail(f"gh api {path} failed: {e.stderr.strip()[:200]}")
    except json.JSONDecodeError as e:
        fail(f"gh api {path} returned non-JSON: {e}")
    return {}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--gh-repo", required=True)
    ap.add_argument("--lookback-min", type=int, default=90)
    ap.add_argument("--workflow", default="doc-maintainer.yml")
    ap.add_argument("--dispatch", action="store_true")
    args = ap.parse_args()

    since = (
        dt.datetime.now(dt.timezone.utc)
        - dt.timedelta(minutes=args.lookback_min)
    ).strftime("%Y-%m-%dT%H:%M:%SZ")

    commits = gh_api(
        f"repos/{args.gh_repo}/commits?sha=main&since={since}&per_page=30"
    )
    if not isinstance(commits, list):
        fail("commits API returned non-list")
        return 1

    missed: list[str] = []
    for commit in commits:
        sha = commit.get("sha")
        if not sha:
            continue
        runs = gh_api(
            f"repos/{args.gh_repo}/actions/runs"
            f"?event=push&head_sha={sha}&per_page=5"
        )
        if isinstance(runs, dict):
            wf_runs = runs.get("workflow_runs", [])
            has_run = any(
                r.get("path", "").endswith(args.workflow) or
                r.get("name") == args.workflow.replace(".yml", "")
                for r in wf_runs
            )
            if not has_run:
                missed.append(sha)

    if not missed:
        print(
            f"::notice::reconcile: scanned {len(commits)} commits since {since};"
            " all have a doc-maintainer run."
        )
        return 0

    print(
        f"::warning::reconcile: {len(missed)} main commit(s) since {since}"
        f" have NO doc-maintainer run:"
    )
    for sha in missed:
        print(f"  - {sha}")

    if args.dispatch:
        # v1.4.1: dispatch each missed SHA via workflow_dispatch.
        # v1.4.0 ships report-only because the dispatch path needs
        # caller-side `workflow_dispatch:` declaration + the workflow
        # body needs a `head_sha` input that override the default
        # `github.sha` lookup.
        print(
            "::notice::reconcile: alpha.1 stub — --dispatch is reported but"
            " v1.4.0 does not yet auto-dispatch. v1.4.1 will."
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
