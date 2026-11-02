# [NS-47] External Survey 2026-08-31 (Codex, ai-that-works, OmniRoute) — Full Entry

Moved from `memory-bank/activeContext.md` 2026-10-19 to fund that day's memory-bank update (the
record of PRs #64, #72, #69, #74 and #75) under the startup-context ratchet. The live `[NS-47]`
keeps the headline and points here for findings (a)–(e). Other documents that cite `[NS-47]`(d)
mean (d) below.

The entry below is the whole line exactly as it stood at `9bd619b`. To check it, compare it with
`git show 9bd619b:memory-bank/activeContext.md | grep -F '47. [NS-47] '`, which prints that one line.

47. [NS-47] **External survey 2026-08-31 (OpenAI Codex, ai-that-works, OmniRoute) — doc-level only, nothing installed or reproduced.** Full write-up: **Work-MB Document 16** in `PMB-Findings-for-Work-MB.md` (**OUT OF REPO** — a Downloads export, uncapped and unversioned; treat `progress.md` as the in-repo source); session detail in `progress.md` 2026-08-31. **(a)** Codex runs TWO precedence systems in OPPOSITE directions — prose (`AGENTS.md`) most-local-wins, policy (`config.toml`/`requirements.toml`) managed-wins. PMB has ONE file type carrying both under one asserted rule; **that**, not a missing arbitration sentence, is what `[NS-46]` should be fixed against. **(b)** `model_auto_compact_token_limit_scope: body_after_prefix` — measure the body AFTER a fixed prefix; `CLAUDE.md` + `memory-bank/` IS that prefix here, and PMB reports one blended number. **(c)** Codex's `project_doc_max_bytes` defaults to 32 KiB and BINDS — first external anchor for PMB's 25 KB. Do NOT copy its silent skip: an unloaded guardrail has 0% adherence. **(d)** Decaying-Resolution Memory names what PMB already does by hand; adopt on the READ path only, since DRM's summarise-the-store variant is the ACE/SSGM degradation already hit here. **CAVEATED 2026-09-01 — (d) has a live counter-example:** `[NS-27]`'s archived, live-pointed rule was not retrieved and had to be re-derived; see `progress.md` 2026-08-31. **(e)** OmniRoute REJECTED — second of the gateway class after SwitchYard.
