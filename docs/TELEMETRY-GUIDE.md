# AI Tool Telemetry Configuration Guide

Most AI coding tools send telemetry by default. This guide covers how to opt out
or restrict data collection for each tool in use.

**Why this matters for T-Mobile:** Prompts sent to AI tools may contain code, data schemas,
internal API names, or architectural details. Telemetry logging means this data leaves
your machine and may be stored by the vendor.

## Claude Code

Claude Code does not log prompts for training by default when using the API (Claude Max / API key).
Verify in Settings:

```bash
# Check current settings
cat ~/.claude/settings.json | grep -i "telemetry\|log\|train"
```

If using Anthropic Console, confirm "Improve Claude" is off in Account Settings → Privacy.

## Cursor

Cursor sends usage telemetry by default. To opt out:

1. Open Cursor Settings → General
2. Under **Telemetry**, disable "Send Usage Data"
3. Under **Privacy Mode**, enable to prevent prompts from being used for model training

For enterprise: set `"telemetry.telemetryLevel": "off"` in workspace or user `settings.json`.

## GitHub Copilot

```json
// In VS Code settings.json
{
  "telemetry.telemetryLevel": "off"
}
```

Also: Organization admins can disable Copilot telemetry org-wide in GitHub Organization Settings → Copilot → Policies.

## Gemini CLI

Gemini CLI has telemetry enabled by default. Check:

```bash
# See current config
cat ~/.gemini/settings.json
```

To disable prompt logging:
```json
{
  "telemetry": false
}
```

Or set in your shell (check your installed version's documentation for the exact variable name):
```bash
GEMINI_TELEMETRY=false gemini ...
```

## Verification Checklist

Before using any AI tool on a project with regulated data (PII, PHI, financial):

- [ ] Telemetry/usage data collection is disabled or confirmed as non-logging
- [ ] Prompts are not used for model training (vendor confirmation or contractual)
- [ ] Data residency requirements are met (vendor's data center region)
- [ ] Tool is on the approved tools list for your team

---

**References:**
- [Telemetry and Privacy in Vibe Coding Tools](https://brics-econ.org/telemetry-and-privacy-in-vibe-coding-tools-what-data-leaves-your-repo)
- [Stop secrets from leaking through AI coding tools — GitGuardian](https://www.helpnetsecurity.com/2026/04/15/product-showcase-gitguardian-ggshield-ai-hook/)
