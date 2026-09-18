# Archived: `progress.md` 2026-09-09 — one section, moved verbatim 2026-09-17

**Relocated from `memory-bank/progress.md` on 2026-09-17**, unchanged. **Verbatim, not summarised** —
the same precedent as every relocation above it in `progress.md`.

**Why:** the Codex-authored PreCompact recovery-only policy correction added two new dated entries
(`## 2026-09-17`, `## 2026-09-16`), pushing `progress.md` to 512 of its 500-line CI cap and the
aggregate startup-context ratchet 3,057 bytes over `origin/main` — both a required, admin-enforced
`File Size` CI check. This was the oldest full-detail section not yet relocated.

**Citation survival was grep-verified before the move**: `grep -n "2026-09-09" memory-bank/activeContext.md`
found one reference (`[NS-44]`, citing `docs/RETRIEVAL-BASELINE-2026-09-09.md`, not this section by
line), which resolves against the stub heading left in `progress.md`, unchanged from the original.

---

## 2026-09-09 — a CI check that had never been able to fail, and what found it

**It was found by planting a violation, not by reading.** The invisible-Unicode guard over
`standards/`, `CLAUDE.md` and `templates/CLAUDE.md` had never once been able to fail since the day
it was written, so every green CI run was evidence of nothing. Mechanism and fix: `1f7a7e7`. The
durable part is what found it — **a check never given something to catch is indistinguishable from
one that cannot catch anything.** Five of the seven extracted checks still have no
detection-efficacy coverage; closing them is what changes the cost of the *next* inert check.

**The mutant space has axes, and hunting one mutant at a time never enumerates them.** The fixture
took four attempts, each defeated one axis over — one "fix" was a regression described as an
improvement. It ended by splitting the space into code-point coverage (unbounded, so closed by
argument) and everything else (finite: scope roots, plant position, status branch) — an open-ended
hunt became three cells that could be closed, and were.

**Several of my own verification commands did not verify what they claimed** — a pipe to `head`
(always exits 0), `&&`-chained greps (a no-match aborts the rest), a non-matching `sed`, a grep
whose escaping printed nothing, and a CR-counting grep that matched every line and produced a false
CRLF finding I asserted aloud before catching it. Four failed silently; the one that failed loudly
did so because mutations ran through a Python `assert` on the substitution count. **The fix is not
more care, it is making the check unable to pass without doing its work** — the same principle as
the bug being repaired, applied to the tooling that verifies the repair.

**The commit gate denies on a bare substring, and the denial destroys the marker — REPRODUCED.**
`review-reminders.sh:87` matches `*'git<SP>commit'*` against raw stdin (spelled with `<SP>` here
deliberately — the literal form denies the very tool call that writes it). `consume_marker()`
(`:74-84`) renames and `rm -f`s the marker *before* comparing hashes, with no restore on denial. So
any tool call whose payload merely contains the substring destroys a valid, expensively-earned
review marker. Matched control pair, no git invoked either time: an `echo` containing the substring
was denied, the same `echo` with it broken passed. Three natural instances in one session — a grep
of the hook's own source, a contract file, and this entry. The comment at `:39` asserts the false
premise that the substring "only plausibly" appears inside a command field. Sharper than `[NS-45]`
(filed INFERRED-not-reproduced, and at least an attempted commit); `[NS-25]`'s bug on the commit
side. **Self-suppressing: it blocks its own documentation.**

**Archived detail entered zero sessions while its pointer was loaded by all of them.** `activeContext.md`
has pointed at `docs/archive/context-2026-08-20-narrative-sections.md` since the 2026-08-20 eviction —
externalization with a handle, already shipped. Measured 2026-09-09 by transcript search for content
unique to that file, so a hit means the content entered a session rather than the pointer merely being
loaded: across the **16 main-worktree-directory sessions first-dated 2026-08-22 → 2026-09-09 (UTC) it
entered zero**, while the pointer was loaded in every one. Worktree sessions write to their own
project directory; widening to all nine gives 17/0/17, so the zero is scope-invariant and only the
denominator moves. Protocol, unit, command and limits:
`docs/RETRIEVAL-BASELINE-2026-09-09.md` — kept outside `memory-bank/` so the sessions it measures do not
read it at start.

**What zero does and does not settle.** It is undiagnostic between "never needed" and "needed, never
fetched"; only a task whose correct answer requires the archived detail separates them. It is the same
shape `[NS-27]`'s rule showed on 2026-08-31 (`[NS-47]`(d)'s caveat): archived, pointed at, on-topic, not
retrieved. The pointer was rewritten (the commit landing this entry) because a bare path gives a session no
reason to open it; whether a described handle changes the rate is what the doc's re-measure section exists to find out.

**Correction — the review-gate defect recorded above has been fixed THREE times and merged ZERO
times, and all three fix only half of it.** The reproduction this session was real; the discovery was
not. Three distinct patches to `scripts/review-reminders.sh` (`git patch-id --stable` differs for
each; none has landed, per `git show origin/main:scripts/review-reminders.sh | grep -c
extract_command` returning 0 — do **not** use `git merge-base --is-ancestor` here, because this clone
is shallow and that check answers NO even for commits that are on main, `ea862e8` being the control):
`2fa55b8` (2026-07-27,
PR #10's branch `claude/keen-carson-b30c44`, pushed — the only one of the three that also patches
`review-reminders-post.sh` and its mirror; all three add a description-field case to
`tests/test-review-reminders.sh` — `--stat` for the file list, `git show <sha> --
tests/test-review-reminders.sh` for the case itself, since `--stat` shows counts and never content),
`656a4d2` (2026-07-27, 75 minutes
later, branch `claude/strange-bun-9a0ffc`, **never pushed** — verifiable only on the machine holding
that branch), and `fe73e13` (2026-08-08, twelve days later, branch `fix/review-reminders-raw-stdin`,
pushed as PR #11). The last two share an identical subject line — "fix: extract tool_input.command in
review-reminders.sh instead of matching raw stdin" — but not a body, and neither branch contains the
other: independent rediscovery, not a cherry-pick.
`git show origin/main:scripts/review-reminders.sh | grep -c extract_command` returns **0**: none has
landed.

**What they fix, and what they do not — this sharpens `[NS-24]` Task #33 and `[NS-45]`, and
strengthens `[NS-26]`'s `peek_marker()` case.** All three match on the extracted `tool_input.command`
on the success path, falling back to raw stdin when extraction fails — the description-field half of
the entry above, minus the parse-failure path. `.pmb-hook-errors.log`'s 160 entries are all
`dangerous-commands.ps1` JSON-parse failures on hook stdin, so malformed payloads demonstrably reach
hooks here; that review-reminders' own fallback fires is **INFERRED**, since neither review-reminders
hook writes that log. None changes
the `*'git<SP>commit'*` substring match on the command text itself, and none moves `consume_marker()`'s
rename-and-delete after the hash compare (`git show 2fa55b8:scripts/review-reminders.sh`, lines
229-249: the rename at 232, the delete at 237, the compare at 249), so a command whose text merely
mentions the verb is still denied, and still destroys the marker, after any of them lands. On this
machine `pwsh` 7.6.5 is on PATH and `settings.json` runs `review-reminders.ps1` first, which already
extracts the command (`:56`), regex-matches the verb in it (`:111`), and moves-then-deletes the marker
before the compare (`:90-108`). **INFERRED, not measured:** that the trips recorded above came through
that path follows from hook order plus `pwsh` being present, and neither hook writes
`.pmb-hook-errors.log`, so no artifact records which interpreter denied. What IS measured, by running
both directly: description-only payload → ps1 allow, sh deny; verb in command → both deny. So the
description-field defect is live here only when `pwsh` fails to launch, and every one of the three
fixes leaves the command-text half untouched on both interpreters.

**The durable lesson is not the defect, it is the merge rate.** Three independent fixes to one half of
the defect and no landing means the cost is paid repeatedly in rediscovery while the whole defect stays
live. Cite commits, not session dates: commits are verifiable in-repo and session dates are not. The
re-measurement in `docs/RETRIEVAL-BASELINE-2026-09-09.md` is pointed at from `[NS-44]`, not scheduled —
`activeContext.md` has no headroom for an entry.

**The Next Steps drain is unblocked, and deliberately not done here.** `cbd988c` gave this file the
room that completed items drain into — the stated dependency when this morning's contract deferred
it. Still deferred: 33+ completeness judgements, each needing a citation-survival check, and
`[NS-4]`/`[NS-24]`/`[NS-37]` all have live inbound citations. For whoever takes it — that contract
lists `[NS-30]` among the resolved; it reads "Shipped… but NOT closed in the field."
