#!/usr/bin/env python3
"""Minimal dependency-free client for ANY OpenAI-compatible chat endpoint.

Provider-agnostic by construction: it POSTs the standard
`{"model", "messages"}` body to `<LLM_URL>/v1/chat/completions` with a bearer
token. Swapping provider is three values — LLM_URL, LLM_API_KEY, LLM_MODEL.
Nothing here is specific to LiteLLM, and since ci/v4.0.0 the diagnostics do not
name one either (CI-0051)."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import sys
import tempfile
import time
import urllib.parse
import urllib.error
import urllib.request


class ResponseShapeError(ValueError):
    """The proxy responded successfully but without a usable completion."""


MAX_RESPONSE_BYTES = 1_000_000
MODEL_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}$")
# NO REDACTION LIVES HERE, DELIBERATELY. `SECRET_PATTERNS`,
# `redact_secret_shaped()` and `restore_redactions()` were removed with the
# `doc-maintainer` flow (CI-0040 / #496), which was their ONLY caller —
# `completion()` never called them. A 2026-07-18 review proposed deleting them as
# dead and the proposal was correctly dropped at the time BECAUSE doc-maintainer
# used them; deleting that flow voided the reason without voiding the code, and
# what remained was worse than absent: a reader of this module reasonably
# concluded the client redacts, and it never did.
#
# Redaction for ai-review happens in `.github/workflows/ai-review.yml`, on the
# diff, BEFORE the prompt is assembled — `.ai-review/diff-for-review.txt` is the
# only copy that leaves that step. Add patterns THERE. Adding them back here
# would protect nothing and would re-create the same false impression.


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):  # noqa: N802
        return None


def open_no_redirect(request: urllib.request.Request, timeout: float):
    return urllib.request.build_opener(NoRedirect).open(request, timeout=timeout)


def fail(message: str) -> None:
    print(f"::error::llm: {message}", file=sys.stderr)
    raise SystemExit(1)


LOOPBACK_HOSTS = frozenset({"localhost", "127.0.0.1", "::1", "0.0.0.0"})


def in_container() -> bool:
    """Best-effort detection that this process runs inside a container.

    Used only to sharpen an error message, never to gate behaviour, so a false
    negative just restores the previous (vaguer) diagnostics.
    """
    if os.environ.get("LLM_ASSUME_CONTAINER", "").lower() == "true":
        return True
    # Probe the filesystem markers BEFORE reading /proc: on a hardened or Podman
    # runner /proc/self/cgroup can be masked, and an OSError there must not
    # discard the /run/.containerenv signal via short-circuit evaluation.
    if Path("/.dockerenv").exists() or Path("/run/.containerenv").exists():
        return True
    try:
        return "docker" in Path("/proc/self/cgroup").read_text()
    except OSError:
        return False


def loopback_hint(base_url: str) -> str:
    """Name the bridge-vs-loopback mistake instead of surfacing a bare URLError.

    Jobs run inside an ephemeral container, so loopback resolves to
    the container itself, not the host running the proxy. This URL works when
    tested from the host and fails only in CI, which is what makes it expensive
    to diagnose. (CI-0017.)
    """
    host = urllib.parse.urlsplit(base_url).hostname
    if host in LOOPBACK_HOSTS and in_container():
        return (
            f" — LLM_URL points at loopback ({host}) while running INSIDE a"
            " container, so it resolves to the container itself, not the host running"
            " the proxy. Use the Docker bridge gateway instead (default"
            " http://172.17.0.1:4001/v1). This URL works when tested from the host and"
            " fails only in CI. See docs/MIGRATION_v2.0.0.md §1."
        )
    return ""


def auth_hint(code: int) -> str:
    """Name the likely cause of a rejected token instead of a bare status line.

    LLM_API_KEY is populated from the repository secret of the same name — since
    ci/v4.0.0 that is the ONLY name resolved (CI-0051 removed the LITELLM_*
    fallbacks) — so a 401 here is a secret-provisioning problem, not a
    code one. The bare status
    named neither the secret nor a cause, which is what made #350 expensive: a
    set-llm-secrets.sh run adding one optional key silently overwrote a
    working review key, and this message was all CI had to say about it.
    """
    if code == 401:
        return (
            " — the endpoint rejected the bearer token. LLM_API_KEY comes from"
            " the repository secret of the same name, which since ci/v4.0.0 is"
            " the ONLY name resolved: if this repo was never re-provisioned off"
            " the deprecated LITELLM_* secrets, that is the cause (CI-0051). A recent"
            " install/set-llm-secrets.sh run may have overwritten the"
            " value. Re-provision the affected"
            " secret — GitHub secrets are write-only, so the value cannot be read"
            " back or recovered from CI. (#350.)"
        )
    if code == 403:
        # Deliberately NOT the re-provision message. 403 means the token
        # authenticated and is not authorized for this model — which is why
        # set-llm-secrets.sh accepts 403 when probing /models. Telling the
        # operator to re-provision a key the provisioner just certified would
        # send them back into the hand-re-provisioning loop #350 was about.
        return (
            " — the token authenticated but is not authorized for this model."
            " Check the key's model scope on the endpoint; the secret"
            " value itself is fine, so replacing it will not help."
        )
    return ""


def endpoint(base_url: str) -> str:
    parsed = urllib.parse.urlsplit(base_url)
    allow_http = os.environ.get("LLM_ALLOW_INSECURE_HTTP", "").lower() == "true"
    if parsed.scheme not in ({"https", "http"} if allow_http else {"https"}):
        fail(
            "LLM_URL must use HTTPS (or explicitly allow HTTP). If your proxy"
            " is reached over http:// — which is the case for every consumer on the"
            " shared self-hosted pool, since the Docker bridge gateway is plain HTTP on"
            " a private network — set `llm_allow_insecure_http: true` on the"
            " caller. This is determined by the URL SCHEME, not by repo visibility:"
            " public repos need it too. See docs/MIGRATION_v2.0.0.md §1. (CI-0017.)"
        )
    if not parsed.hostname or parsed.username or parsed.password or parsed.query or parsed.fragment:
        fail("LLM_URL contains a forbidden or missing URL component")
    value = base_url.rstrip("/")
    if value.endswith("/chat/completions"):
        return value
    if not value.endswith("/v1"):
        value += "/v1"
    return value + "/chat/completions"


def completion(
    prompt: str, *, model: str, json_mode: bool, timeout: int, verdict_mode: bool = False
) -> str:
    base_url = os.environ.get("LLM_URL", "").strip()
    api_key = os.environ.get("LLM_API_KEY", "").strip()
    if not base_url:
        fail("LLM_URL is not set")
    if not api_key:
        fail("LLM_API_KEY is not set")
    if not model:
        fail("no model alias supplied (--model or LLM_MODEL)")
    if not MODEL_PATTERN.fullmatch(model):
        fail("model alias must match [A-Za-z0-9][A-Za-z0-9._:/-]{0,127}")
    # PLAN-011 T1: a verdict for a large diff (many findings) needs more output
    # headroom than a plain --json call — 4096 truncates the JSON mid-object on
    # big PRs, which surfaces as ResponseShapeError. Verdict mode defaults higher;
    # plain callers keep 4096. The LLM_MAX_TOKENS override wins for both, so an
    # operator can tune per-model without a code edit (model-agnostic).
    # PLAN-011 PC-1 (VERIFIED live 2026-07-17): deepseek-v4-pro (the ai-reviewer
    # alias) accepts max_tokens well past this — 32768 and even 65536 return HTTP
    # 200 — so the practical ceiling is this client's own 1..32768 validator, not
    # the model. A typical complex 45-file verdict USES only ~2.3k completion
    # tokens, but reasoning-token counts are NON-DETERMINISTIC and spike; the
    # reported ResponseShapeError was a reasoning spike truncating at the old 4096
    # default. 24576 (3x the first 8192 pick) covers a heavy-reasoning spike on a
    # near-400KB diff with wide margin. Higher costs nothing extra (billing is per
    # ACTUAL output token; finish_reason is normally `stop`), and LLM_MAX_TOKENS
    # can raise it to the 32768 cap if a residual truncation ever surfaces (the F4
    # infra signal would show it).
    verdict_default_max_tokens = "24576"
    default_max_tokens = verdict_default_max_tokens if verdict_mode else "4096"
    try:
        max_tokens = int(os.environ.get("LLM_MAX_TOKENS", default_max_tokens))
    except ValueError:
        fail("LLM_MAX_TOKENS must be an integer")
    if not 1 <= max_tokens <= 32768:
        fail("LLM_MAX_TOKENS must be between 1 and 32768")

    payload: dict[str, object] = {
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": max_tokens,
    }
    if json_mode:
        payload["response_format"] = {"type": "json_object"}
    request = urllib.request.Request(
        endpoint(base_url),
        data=json.dumps(payload).encode(),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )

    deadline = time.monotonic() + timeout
    for attempt in range(1, 4):
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            fail(f"proxy request timed out after {timeout} seconds")
        attempt_timeout = max(1, min(remaining, timeout / 3))
        try:
            with open_no_redirect(request, timeout=attempt_timeout) as response:
                raw_body = response.read(MAX_RESPONSE_BYTES + 1)
            if len(raw_body) > MAX_RESPONSE_BYTES:
                raise ResponseShapeError("response exceeds 1 MB")
            body = json.loads(raw_body)
            content = body["choices"][0]["message"]["content"]
            if isinstance(content, list):
                content = "".join(
                    part.get("text", "") for part in content if isinstance(part, dict)
                )
            if not isinstance(content, str) or not content.strip():
                raise ResponseShapeError("empty completion")
            if json_mode:
                content = normalize_json_object(content)
            if verdict_mode:
                validate_verdict(json.loads(content))
            return content
        except urllib.error.HTTPError as exc:
            retryable = exc.code == 429 or 500 <= exc.code < 600
            if not retryable or attempt == 3:
                fail(f"proxy returned HTTP {exc.code}{auth_hint(exc.code)}")
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, KeyError, IndexError, TypeError, ResponseShapeError) as exc:
            if attempt == 3:
                hint = loopback_hint(base_url) if isinstance(exc, (urllib.error.URLError, TimeoutError)) else ""
                fail(f"proxy request failed after 3 attempts: {type(exc).__name__}{hint}")
        delay = attempt * 2
        if time.monotonic() + delay >= deadline:
            fail(f"proxy request timed out after {timeout} seconds")
        time.sleep(delay)
    fail("proxy request failed")


def normalize_json_object(content: str) -> str:
    candidate = content.strip()
    fenced = re.fullmatch(r"```(?:json)?\s*\n?(\{.*\})\s*\n?```", candidate, re.S)
    if fenced:
        candidate = fenced.group(1)
    try:
        value = json.loads(candidate)
    except json.JSONDecodeError as exc:
        raise ResponseShapeError("completion is not exactly one JSON value") from exc
    if not isinstance(value, dict):
        raise ResponseShapeError("completion JSON must be an object")
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"))


def validate_verdict(value: object) -> None:
    if not isinstance(value, dict) or set(value) != {"decision", "summary", "findings"}:
        raise ResponseShapeError("verdict has invalid top-level fields")
    if value["decision"] not in {"approve", "request_changes"}:
        raise ResponseShapeError("verdict decision is invalid")
    if not isinstance(value["summary"], str) or not isinstance(value["findings"], list):
        raise ResponseShapeError("verdict summary/findings types are invalid")
    required = {"severity", "path", "line", "body", "fix"}
    severities = {"critical", "medium", "low", "acknowledged"}
    for finding in value["findings"]:
        if not isinstance(finding, dict) or set(finding) != required:
            raise ResponseShapeError("finding has invalid fields")
        if finding["severity"] not in severities:
            raise ResponseShapeError("finding severity is invalid")
        if not all(isinstance(finding[key], str) for key in ("path", "body", "fix")):
            raise ResponseShapeError("finding text field type is invalid")
        if not isinstance(finding["line"], int) or isinstance(finding["line"], bool):
            raise ResponseShapeError("finding line must be an integer")
        if finding["severity"] in {"critical", "medium"} and not finding["fix"].strip():
            raise ResponseShapeError("blocking findings require a concrete fix")
    blocking = any(
        finding["severity"] in {"critical", "medium"} for finding in value["findings"]
    )
    if (value["decision"] == "request_changes") != blocking:
        raise ResponseShapeError("verdict decision contradicts finding severities")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", default=os.environ.get("LLM_MODEL", ""))
    parser.add_argument("--json", action="store_true", dest="json_mode")
    parser.add_argument("--verdict", action="store_true", dest="verdict_mode")
    parser.add_argument("--timeout", type=int, default=600)
    parser.add_argument("--output")
    args = parser.parse_args()
    if not 1 <= args.timeout <= 1800:
        fail("timeout must be between 1 and 1800 seconds")
    result = completion(
        sys.stdin.read(), model=args.model.strip(),
        json_mode=args.json_mode or args.verdict_mode, timeout=args.timeout,
        verdict_mode=args.verdict_mode,
    )
    if args.output:
        destination = Path(args.output)
        destination.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", dir=destination.parent, delete=False
        ) as temporary:
            temporary.write(result.rstrip() + "\n")
            temporary_name = temporary.name
        try:
            os.replace(temporary_name, destination)
        finally:
            try:
                os.unlink(temporary_name)
            except FileNotFoundError:
                pass
    else:
        print(result)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
