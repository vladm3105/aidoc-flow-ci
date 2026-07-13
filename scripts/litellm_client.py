#!/usr/bin/env python3
"""Minimal dependency-free client for a LiteLLM OpenAI-compatible proxy."""

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
SECRET_PATTERNS = (
    re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----.*?-----END (?:RSA |EC |OPENSSH )?PRIVATE KEY-----", re.S),
    re.compile(r"\bAKIA[0-9A-Z]{16}\b"),
    re.compile(r"\bgh[pousr]_[A-Za-z0-9]{30,}\b"),
    re.compile(r"\bsk-[A-Za-z0-9_-]{20,}\b"),
)


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):  # noqa: N802
        return None


def open_no_redirect(request: urllib.request.Request, timeout: float):
    return urllib.request.build_opener(NoRedirect).open(request, timeout=timeout)


def fail(message: str) -> None:
    print(f"::error::litellm: {message}", file=sys.stderr)
    raise SystemExit(1)


def endpoint(base_url: str) -> str:
    parsed = urllib.parse.urlsplit(base_url)
    allow_http = os.environ.get("LITELLM_ALLOW_INSECURE_HTTP", "").lower() == "true"
    if parsed.scheme not in ({"https", "http"} if allow_http else {"https"}):
        fail("LITELLM_BASE_URL must use HTTPS (or explicitly allow HTTP)")
    if not parsed.hostname or parsed.username or parsed.password or parsed.query or parsed.fragment:
        fail("LITELLM_BASE_URL contains a forbidden or missing URL component")
    value = base_url.rstrip("/")
    if value.endswith("/chat/completions"):
        return value
    if not value.endswith("/v1"):
        value += "/v1"
    return value + "/chat/completions"


def completion(
    prompt: str, *, model: str, json_mode: bool, timeout: int, verdict_mode: bool = False
) -> str:
    base_url = os.environ.get("LITELLM_BASE_URL", "").strip()
    api_key = os.environ.get("LITELLM_API_KEY", "").strip()
    if not base_url:
        fail("LITELLM_BASE_URL is not set")
    if not api_key:
        fail("LITELLM_API_KEY is not set")
    if not model:
        fail("no model alias supplied (--model or LITELLM_MODEL)")
    if not MODEL_PATTERN.fullmatch(model):
        fail("model alias must match [A-Za-z0-9][A-Za-z0-9._:/-]{0,127}")
    try:
        max_tokens = int(os.environ.get("LITELLM_MAX_TOKENS", "4096"))
    except ValueError:
        fail("LITELLM_MAX_TOKENS must be an integer")
    if not 1 <= max_tokens <= 32768:
        fail("LITELLM_MAX_TOKENS must be between 1 and 32768")

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
                fail(f"proxy returned HTTP {exc.code}")
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, KeyError, IndexError, TypeError, ResponseShapeError) as exc:
            if attempt == 3:
                fail(f"proxy request failed after 3 attempts: {type(exc).__name__}")
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


def redact_secret_shaped(text: str) -> tuple[str, dict[str, str]]:
    redactions: dict[str, str] = {}
    for pattern in SECRET_PATTERNS:
        def replace(match: re.Match[str]) -> str:
            token = f"[REDACTED_SECRET_{len(redactions)}]"
            redactions[token] = match.group(0)
            return token
        text = pattern.sub(replace, text)
    return text, redactions


def restore_redactions(text: str, redactions: dict[str, str]) -> str:
    for token, original in redactions.items():
        if text.count(token) != 1:
            raise ResponseShapeError(f"model did not preserve redaction token {token}")
        text = text.replace(token, original)
    return text


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
    parser.add_argument("--model", default=os.environ.get("LITELLM_MODEL", ""))
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
