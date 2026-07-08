#!/usr/bin/env python3
"""Parse the ## Per-repo governance table from a consumer's CLAUDE.md
and verify each declared path exists on disk.

Implements the PLAN-003 §4.5 parser contract:

- Section anchor: ^## Per-repo governance(\\s+[—-].*)?\\s*$ — accepts
  the em-dash tail form 7 workspace consumers already use.
- Table format: GFM pipe table with first cell starting with "Surface"
  and second cell starting with "Path" (case-insensitive prefix).
- Separator row: both `|---|---|` and `| --- | --- |` forms accepted.
- Row format: `| <surface-label> | <path-or-Not-adopted-cell> |`.
- Required rows matched by canonical-token substring (case-insensitive)
  against: handoff, todo/backlog, decisions, plans/iplan, changelog,
  roadmap. Additional rows below the required 6 are verified for path
  existence but not counted toward required-row completeness.
- "Not adopted [—-]" prefix detected BEFORE any path extraction.
- Multi-value cells NOT accepted (one row per surface).
- Path cells: strip surrounding backticks + parenthesized annotation
  before existence check.

Usage:
  parse-governance-table.py <path-to-CLAUDE.md> [--repo-root <dir>]

Output: JSON on stdout with { clm_path, found_anchor, found_table,
required_rows: {<canonical>: {cell, verified, path}}, additional_rows:
[...], errors: [...] }. Exit 0 iff parse succeeded AND all declared
paths verified (or Not-adopted). Exit 1 if any error.

stdlib only.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

# PLAN-003 §4.5 anchor regex: accepts bare form + em-dash/dash tail form.
ANCHOR_RE = re.compile(r"^## Per-repo governance(\s+[—-].*)?\s*$")

# Header row must start with Surface/Path (case-insensitive prefix per §4.5).
HEADER_CELL_1_RE = re.compile(r"^surface", re.IGNORECASE)
HEADER_CELL_2_RE = re.compile(r"^path", re.IGNORECASE)

# Separator row: accepts N-column tables (2+ cells; GFM tight / loose /
# aligned `:` forms), per §4.5 F#11 + P4 fold.
SEP_ROW_RE = re.compile(r"^\|(\s*:?-+:?\s*\|){2,}\s*$")

# Canonical tokens for the 6 required rows (case-insensitive substring
# match against the surface-label cell per §4.5 F#3).
CANONICAL_TOKENS = {
    "HANDOFF": ("handoff",),
    "TODO": ("todo", "backlog"),
    "Decisions": ("decisions",),
    "Plans": ("plans", "iplan"),
    "Changelog": ("changelog",),
    "Roadmap": ("roadmap",),
}

# "Not adopted [—-]" prefix per §4.5 F#7: detected BEFORE path extraction.
# Uses multi-char alternation (`—|--`) so ASCII "Not adopted --" is matched
# atomically (single-char class `[—-]` would let "Not adopted -" pass).
NOT_ADOPTED_RE = re.compile(r"^\s*not\s+adopted\s+(—|--)\s*", re.IGNORECASE)

# Informational separator row (introducing additional-rows region) —
# matched only when the PATH cell is empty/em-dash. This prevents an
# italicized real row like `| _Live regional HANDOFF_ | regions/eu/HANDOFF.md |`
# from being silently swallowed. Accepts both underscore-italic
# (`_..._`) and asterisk-italic (`*...*`) forms per GFM markdown, which
# consumers may pick either of interchangeably.
INFO_SEPARATOR_RE = re.compile(
    r"^(_.*_|\*.*\*|additional\s+rows\s+below.*|\(.*repo-specific.*\))\s*$",
    re.IGNORECASE,
)

# Multi-value cell detector — comma-separated backticked paths in one
# cell. §4.5 F#6 requires REJECT with explicit error, not fall-through
# to path-not-found (per test-engineer F#3 fold 2026-07-08).
MULTI_VALUE_RE = re.compile(r"`[^`]+`\s*,\s*`[^`]+`")


def parse_table_rows(section_body: str) -> tuple[list[list[str]], list[str]]:
    """Extract GFM pipe-table rows from a section body.

    Returns (rows, errors). Each row is a list of cell strings (stripped).
    Skips header + separator rows; returns only content rows.
    """
    errors: list[str] = []
    rows: list[list[str]] = []
    saw_header = False
    saw_separator = False
    for line in section_body.splitlines():
        stripped = line.strip()
        if not stripped.startswith("|"):
            continue

        # Separator row (either GFM-tight or GFM-loose form).
        if SEP_ROW_RE.match(stripped):
            saw_separator = True
            continue

        # Split cells: strip leading + trailing pipe, split on `|`, strip each.
        cells = [c.strip() for c in stripped.strip("|").split("|")]

        if not saw_header:
            if len(cells) >= 2 and HEADER_CELL_1_RE.match(cells[0]) and HEADER_CELL_2_RE.match(cells[1]):
                saw_header = True
                continue
            # First `|`-row is not a valid header.
            errors.append(
                f"header-mismatch: expected first cell starting with 'Surface' "
                f"and second cell starting with 'Path'; got {cells!r}"
            )
            return [], errors

        # Body row.
        if len(cells) < 2:
            errors.append(f"row-underfull: {stripped!r}")
            continue
        rows.append(cells)

    if not saw_header:
        errors.append("header-mismatch: no `| Surface | Path ... |` header row found")
    if saw_header and not saw_separator:
        errors.append("separator-missing: header row present but no `|---|---|` separator")
    return rows, errors


def is_informational_row(surface_cell: str, path_cell: str) -> bool:
    """A separator/note row inserted for humans that the parser ignores.

    A row is informational ONLY when the label pattern matches an
    INFO_SEPARATOR_RE alternative AND the path cell is empty or an
    em-dash placeholder. This prevents a real row with an italicized
    surface label + a real path from being silently swallowed
    (per code-reviewer F#2 fold 2026-07-08).
    """
    if not INFO_SEPARATOR_RE.match(surface_cell):
        return False
    return path_cell.strip() in ("", "—", "-")


def match_canonical_token(surface_label: str) -> str | None:
    """Return the canonical row name if surface_label contains a canonical token."""
    label_lower = surface_label.lower()
    for canonical, tokens in CANONICAL_TOKENS.items():
        for token in tokens:
            if token in label_lower:
                return canonical
    return None


def extract_path(path_cell: str) -> str:
    """Strip surrounding backticks + trailing annotations from a path cell.

    Per §4.5: consumers may write `` `docs/HANDOFF.md` (protocol in ...) ``,
    `` `docs/STARTUP_STRATEGY.md` §8 ``, or `` `docs/spec.md` #anchor ``;
    strip surrounding backticks, trailing parenthesized annotation, and
    trailing section-anchor suffixes (§N, #anchor) before existence
    check.
    """
    cell = path_cell.strip()

    # Strip trailing section-anchor suffix (§N, e.g. `docs/foo.md §8`) or
    # markdown anchor (#anchor, e.g. `docs/foo.md #section`) — these are
    # display-only pointers into a file; the path itself is what exists.
    # Business's `docs/STARTUP_STRATEGY.md §8` case.
    section_anchor_match = re.search(r"\s+[§#]\S", cell)
    if section_anchor_match:
        cell = cell[: section_anchor_match.start()].strip()

    # Strip parenthesized annotation like `(protocol in ...)` — take
    # everything before the first `(` that follows the primary path.
    # We match on `<path> (`... but only if there's a preceding backticked or
    # bare path.
    paren_idx = cell.find(" (")
    if paren_idx > 0:
        cell = cell[:paren_idx].strip()

    # Strip surrounding backticks.
    if cell.startswith("`") and cell.endswith("`") and len(cell) >= 2:
        cell = cell[1:-1]
    return cell.strip()


def extract_section(text: str) -> tuple[str | None, int]:
    """Find `## Per-repo governance...` section body.

    Returns (body, header_line_number_1_indexed) or (None, -1) if the
    anchor is not present.

    Fenced-code-block state is tracked (test-engineer F#2 fold 2026-07-08):
    lines inside triple-backtick fences are NOT scanned for the anchor
    (a `## Per-repo governance` inside a ```markdown ... ``` block does
    not resolve as the real anchor).
    """
    lines = text.splitlines()
    in_fence = False
    for i, line in enumerate(lines):
        stripped = line.lstrip()
        if stripped.startswith("```") or stripped.startswith("~~~"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        if ANCHOR_RE.match(line):
            # Body = from next line up to (but not including) next `## `
            # H2 heading (or EOF); H2 terminators inside fenced-code
            # blocks are also skipped for the same reason.
            j = i + 1
            body_in_fence = False
            while j < len(lines):
                body_stripped = lines[j].lstrip()
                if body_stripped.startswith("```") or body_stripped.startswith("~~~"):
                    body_in_fence = not body_in_fence
                    j += 1
                    continue
                if not body_in_fence and lines[j].startswith("## "):
                    break
                j += 1
            return "\n".join(lines[i + 1 : j]), i + 1
    return None, -1


def check_cell(cell: str, repo_root: Path) -> tuple[bool, str, str | None]:
    """Verify a path cell — return (verified, extracted_path, error).

    Returns:
        (True, path, None) — path exists (or "Not adopted — <rationale>").
        (False, extracted_path, error_message) — path missing or empty.

    Sandbox: declared paths MUST be repo-relative per §4.5. Absolute
    paths + `..` escapes that resolve outside `repo_root` are rejected
    with `path-escape` to prevent filesystem-existence-oracle leakage
    to CI logs (per security-auditor F#1 fold 2026-07-08).
    """
    if not cell.strip():
        return False, "", "missing-cell: empty"

    if NOT_ADOPTED_RE.match(cell):
        # §4.4: rationale must be present + non-trivial (contain 1+
        # alphanumeric characters). "Not adopted --" alone or with only
        # punctuation fails.
        rest = NOT_ADOPTED_RE.sub("", cell).strip()
        if not re.search(r"\w", rest):
            return False, "", "not-adopted-missing-rationale: cell after 'Not adopted —' has no alphanumeric rationale"
        return True, "", None

    # Multi-value cell rejection per §4.5 F#6 (test-engineer F#3 fold).
    if MULTI_VALUE_RE.search(cell):
        return False, "", "multi-value-cell: use additional-row pattern (one row per surface); comma-separated paths in one cell not accepted per PLAN-003 §4.5"

    path = extract_path(cell)
    if not path:
        return False, "", f"path-extraction-failed: cell = {cell!r}"

    # Absolute paths rejected — declared paths are repo-relative per §4.5.
    if os.path.isabs(path):
        return False, path, f"path-escape: absolute path not allowed: {path}"

    # Resolve + verify inside repo_root. `.resolve(strict=False)` normalizes
    # `..` and symlinks; `relative_to` checks the resolved target is
    # inside the resolved repo_root.
    root_resolved = repo_root.resolve()
    try:
        target = (repo_root / path).resolve(strict=False)
        target.relative_to(root_resolved)
    except ValueError:
        return False, path, f"path-escape: {path} resolves outside repo_root"
    except OSError as e:
        return False, path, f"path-resolve-error: {path}: {e.__class__.__name__}"

    # PermissionError + other OSErrors from .exists() must not crash the
    # parser (security-auditor F#2 fold). Normalize to a single-line err.
    try:
        exists = target.exists()
    except OSError as e:
        return False, path, f"path-check-error: {path}: {e.__class__.__name__}"

    if not exists:
        return False, path, f"path-not-found: {path} (checked {target})"
    return True, path, None


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("clm_path", help="Path to consumer CLAUDE.md")
    parser.add_argument(
        "--repo-root",
        default=None,
        help="Repo root for relative-path resolution (default: parent of CLAUDE.md)",
    )
    args = parser.parse_args(argv)

    clm_path = Path(args.clm_path).resolve()
    if not clm_path.is_file():
        json.dump(
            {"clm_path": str(clm_path), "found_anchor": False, "found_table": False,
             "required_rows": {}, "additional_rows": [], "errors": [f"file-not-found: {clm_path}"]},
            sys.stdout, indent=2,
        )
        print()
        return 1

    repo_root = Path(args.repo_root).resolve() if args.repo_root else clm_path.parent
    text = clm_path.read_text(errors="replace")
    section_body, anchor_line = extract_section(text)

    result = {
        "clm_path": str(clm_path),
        "repo_root": str(repo_root),
        "found_anchor": section_body is not None,
        "anchor_line": anchor_line,
        "found_table": False,
        "required_rows": {},
        "additional_rows": [],
        "errors": [],
    }

    if section_body is None:
        result["errors"].append("anchor-missing: no `## Per-repo governance` H2 heading found")
        json.dump(result, sys.stdout, indent=2)
        print()
        return 1

    rows, parse_errors = parse_table_rows(section_body)
    result["errors"].extend(parse_errors)
    if not rows:
        json.dump(result, sys.stdout, indent=2)
        print()
        return 1

    result["found_table"] = True

    # First pass: filter informational rows and match canonical rows.
    seen_canonical: set[str] = set()
    for cells in rows:
        surface_cell = cells[0]
        path_cell = cells[1]

        if is_informational_row(surface_cell, path_cell):
            continue

        canonical = match_canonical_token(surface_cell)
        verified, extracted, err = check_cell(path_cell, repo_root)

        row_info = {
            "surface_label": surface_cell,
            "cell": path_cell,
            "extracted_path": extracted,
            "verified": verified,
        }
        if err:
            row_info["error"] = err
            result["errors"].append(f"row {surface_cell!r}: {err}")

        if canonical and canonical not in seen_canonical:
            row_info["canonical"] = canonical
            result["required_rows"][canonical] = row_info
            seen_canonical.add(canonical)
        else:
            # Either no canonical token match (repo-specific additional row)
            # OR canonical already seen (an additional-row alternative
            # for the same conceptual kind, e.g., framework's second
            # DECISIONS log).
            if canonical:
                row_info["canonical_shadowed_by"] = canonical
            result["additional_rows"].append(row_info)

    # Check required-row completeness.
    for canonical in CANONICAL_TOKENS.keys():
        if canonical not in result["required_rows"]:
            result["errors"].append(
                f"required-row-missing: no row matches canonical token {canonical!r} "
                f"(tokens: {list(CANONICAL_TOKENS[canonical])})"
            )

    json.dump(result, sys.stdout, indent=2)
    print()
    return 0 if not result["errors"] else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
