"""
Push the memory-bank project description + topics to GitLab.

Reads GITLAB_TOKEN from the environment (never prints it).
Targets https://gitlab.com/tmobile/ere/memory-bank.

Usage (bash):
    export GITLAB_TOKEN=glpat-xxxxxxxxxx
    python scripts/update_gitlab_description.py

Usage (PowerShell):
    $env:GITLAB_TOKEN = "glpat-xxxxxxxxxx"
    python scripts/update_gitlab_description.py
"""
from __future__ import annotations

import json
import os
import sys
from urllib import request, error

PROJECT_PATH = "tmobile/ere/memory-bank"
API_BASE = "https://gitlab.com/api/v4"

SHORT_DESCRIPTION = (
    "Enterprise-ready AI coding standard for Cursor and Claude Code. "
    "Persistent memory-bank, 3-tier security guardrails, code quality and "
    "logging standards, feature workflow, multi-agent /code-review, and "
    "on-demand /accessibility-review (WCAG 2.1 AA)."
)

LONG_DESCRIPTION = """Enterprise AI coding standards for Cursor and Claude Code. Drop into any repo; productive in under 15 minutes.

Core standards:
• Persistent memory-bank — five files the AI reads at every session start.
• 3-tier security guardrails — BLOCK / CONFIRM / WARN (secrets, force-push, slopsquat packages, MCP creds, long-lived creds in agent env).
• Code quality — verification before done, WHY-only comments, explicit error handling.
• Structured logging — JSON-in-prod, correlation IDs, auto-PII redaction.
• Feature workflow — Brainstorm → Spec → Plan → Implement (TDD) → Simplify → Security Review → Commit.

Conditional + on-demand:
• Accessibility (WCAG 2.1 Level AA) — glob-scoped Cursor rule for UI files; on-demand /accessibility-review audit.
• Multi-agent /code-review — three parallel role subagents (security, performance, style) with uncorrelated contexts, a test-coverage reviewer that generates missing tests, and an opponent auditor that confirms / downgrades / rejects findings.

Enterprise hygiene (v1.5):
• Rules-file integrity — anti-prompt-injection for .cursorrules / CLAUDE.md / AGENTS.md / .mdc / slash commands.
• Data classification — Public / Internal / Confidential / Restricted tiers.
• Ephemeral secrets — Vault / AWS SM / Azure KV; rotate after agent sessions.
• OWASP LLM Top 10 (2025) coverage mapping with residual-gap tracker.
• Model governance — approved model list + version pinning + canary change management.
• Incident response runbook template with AI-involvement checklist.
• Agent resource controls — token budgets, loop detection, 429 handling.

Ships rule files for Cursor (.mdc), Claude Code (CLAUDE.md + slash commands), AGENTS.md for Codex / Gemini CLI. Install scripts for Windows / macOS / Linux. MIT licensed. See README for install one-liners."""

TOPICS = [
    "ai-coding",
    "cursor",
    "claude-code",
    "developer-tools",
    "memory-bank",
    "security-guardrails",
    "code-review",
    "accessibility",
    "wcag",
    "structured-logging",
    "enterprise-ai",
    "slash-commands",
    "tmobile-aero",
]


def api_put(path: str, token: str, payload: dict) -> dict:
    body = json.dumps(payload).encode("utf-8")
    req = request.Request(
        f"{API_BASE}/{path}",
        data=body,
        method="PUT",
        headers={
            "PRIVATE-TOKEN": token,
            "Content-Type": "application/json",
        },
    )
    try:
        with request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except error.HTTPError as e:
        body_text = e.read().decode("utf-8", errors="replace")
        raise SystemExit(f"HTTP {e.code} {e.reason}: {body_text}") from e
    except error.URLError as e:
        raise SystemExit(f"Network error: {e.reason}") from e


def main() -> int:
    token = os.environ.get("GITLAB_TOKEN")
    if not token:
        print(
            "ERROR: GITLAB_TOKEN is not set.\n"
            "  bash:       export GITLAB_TOKEN=glpat-xxxxxxxxxx\n"
            "  powershell: $env:GITLAB_TOKEN = 'glpat-xxxxxxxxxx'\n"
            "Then re-run this script.",
            file=sys.stderr,
        )
        return 2

    # GitLab's 'description' field on projects accepts the long form.
    # Topics are a separate top-level field on the same PUT.
    encoded_path = PROJECT_PATH.replace("/", "%2F")
    print(f"Target project: {PROJECT_PATH}")
    print(f"Endpoint:       {API_BASE}/projects/{encoded_path}")
    print(f"Description:    {len(LONG_DESCRIPTION)} chars")
    print(f"Topics:         {', '.join(TOPICS)}")
    print()

    # 1) Update description + topics
    result = api_put(
        f"projects/{encoded_path}",
        token,
        {"description": LONG_DESCRIPTION, "topics": TOPICS},
    )

    print("✓ Update succeeded.")
    print(f"  id:              {result.get('id')}")
    print(f"  name:            {result.get('name')}")
    print(f"  path_with_ns:    {result.get('path_with_namespace')}")
    print(f"  visibility:      {result.get('visibility')}")
    print(f"  web_url:         {result.get('web_url')}")
    desc = (result.get("description") or "")[:100].replace("\n", " ")
    print(f"  description[0:100]: {desc}…")
    tags = result.get("topics") or result.get("tag_list") or []
    print(f"  topics returned: {tags}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
