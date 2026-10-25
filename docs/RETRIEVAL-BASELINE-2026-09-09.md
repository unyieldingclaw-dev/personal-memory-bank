# Retrieval baseline — does a pointer in `activeContext.md` get followed?

**Measured 2026-09-09. Baseline: zero.** Re-measurements go in a new dated file
(`docs/RETRIEVAL-BASELINE-<date>.md`); this file is not appended to.

This file lives in `docs/` rather than `memory-bank/` deliberately. `CLAUDE.md` instructs every session
to read all of `memory-bank/` at start, so a measurement protocol stored there would be read by every
subject it measures. `docs/` is not startup-loaded. `CLAUDE.md` records read-all as an interim
mechanism under an open Tier-1 conflict (`projectbrief.md` wants an index with detail fetched on
demand); if an index mechanism lands, an index entry could carry the probe and the quasi-blind property
below inverts.

## What is being measured

`memory-bank/activeContext.md` has carried a pointer to
`docs/archive/context-2026-08-20-narrative-sections.md` since the 2026-08-20 eviction. That is
externalization with a handle — the same shape three of the eleven surveyed context tools converge on —
running in production here for three weeks. The question is whether the handle is ever followed.

This repo already had one recorded instance of the same shape before this measurement: `[NS-27]`'s
rule that an ACR run's git SHA must be recorded before the run counts as evidence, archived and
live-pointed from `activeContext.md`, was not retrieved and had to be re-derived on 2026-08-31
(`progress.md` 2026-08-31, which quotes it as "pin the version or record the SHA"; `[NS-47]`(d)'s
caveat).

## Method

Search session transcripts for a string that exists **only inside the archive file**, never in
`activeContext.md`. This is the load-bearing detail: searching the *pointer path* cannot distinguish a
session that loaded the pointer from one that opened the target, because the path appears in both. A
content-unique probe can only match if the file's contents actually entered the transcript.

**The probe** is the archive's Fleet Version Drift section heading. It is spelled here as a shell
concatenation so that this file cannot itself match a grep for the joined string (an earlier draft
quoted it verbatim, which made the protocol register as a fetch of the archive it describes):

```
P='ACR Found 2 Versions'' Behind'
```

Uniqueness at measurement time, in the tracked tree: `git grep -l "$P" HEAD -- '*.md'` → the archive file
and nothing else. On disk the reach is wider: registered worktrees under `.claude/worktrees/` hold
one pre-eviction copy of `activeContext.md` and one copy of the archive that also match (`grep -rl "$P"
.claude/worktrees --include='*.md'` returns exactly those two); a Read of either is class 5 below,
not a fetch.

**Scope and unit — read before counting.** Transcripts for main-worktree sessions live under
`~/.claude/projects/C--Users-Mizzo-Claude-Personal-Memory-Bank/`. A session run inside a registered
git worktree gets its **own sibling directory**, `…-Bank--claude-worktrees-<name>/`; eight of those
existed on 2026-09-09 (`ls -d ~/.claude/projects/C--Users-Mizzo-Claude-Personal-Memory-Bank*`). This
measurement scans the main directory only. One session = one top-level
`<uuid>.jsonl`, dated by its first `"timestamp"` (UTC); its `<uuid>/subagents/*.jsonl` and
`<uuid>/tool-results/*` count toward the same session's probe columns (the pointer column reads the
top-level file only). Exclude from the denominator every session that performs a measurement, edits or
reviews this protocol, or inspects hits: each carries the probe from inspecting records, not from
fetching. The command itself prints only counts, so a faithful run leaves no probe in a transcript. At
the time of writing two such sessions exist, first-dated 2026-09-09T23:51Z (measured and drafted) and
2026-09-10T02:53Z (reviewed). Record counts and classifications only — never copy transcript record
text into this repository. Command:

```
cd ~/.claude/projects/C--Users-Mizzo-Claude-Personal-Memory-Bank
P='ACR Found 2 Versions'' Behind'
for f in *.jsonl; do id="${f%.jsonl}"
  first=$(grep -o -m1 '"timestamp":"[^"]*"' "$f" | cut -d'"' -f4)
  pt=$(grep -c "$P" "$f"); ps=$(cat "$id"/subagents/*.jsonl 2>/dev/null | grep -c "$P")
  pr=$(cat "$id"/tool-results/* 2>/dev/null | grep -c "$P")
  ptr=$(grep -c "context-2026-08-20-narrative-sections" "$f")
  echo "${id:0:8} ${first:0:19} $pt $ps $pr $ptr"
done | sort -k2
```

Columns: session, first timestamp, probe hits in the top-level transcript / subagents / tool results,
pointer-path mentions.

**A hit is not automatically a fetch.** Classify each by the tool call that produced the matching
record (resolve it by `tool_use_id`), into one of five classes:
1. **Fetch** — a Read of the archive path, or a `cat` or `sed -n` of it. Only this class counts.
2. **Sweep** — a `grep -rn` over `docs/` or wider that lists the archive's heading line without
   naming the file.
3. **History replay** — `git log -p`, `git show`, `git diff` of `activeContext.md` from before the
   eviction, re-emitting the heading from the text's old home.
4. **Targeted search** — a grep that names the archive path and returns fragments of it. The file was
   partially read, but as a search target, not by following the handle. Record separately.
5. **Pre-archive or eviction activity** — reads, edits and writes of `activeContext.md` while the text
   still lived there, the eviction session's own reads and edits of the archive, and reads of worktree
   copies. Out of scope by construction.
Inspect the matching record before counting it, and record the classification, not the text.

## Result

| | |
|---|---|
| Probe last appeared in any transcript other than the excluded ones | **2026-08-22T00:10Z** (2026-08-21 local) — class 4: a subagent `grep -n -B3 -A3` naming the archive among three files while searching for `ai-code-review-agent`, which is the probe section's own subject (archive line 52) |
| Sessions in the **main-worktree project directory**, first-dated 2026-08-22 → 2026-09-09 UTC, excluding the measuring session | **16** |
| Of those, sessions (incl. subagents and tool results) where the probe appeared | **0** |
| Of those, sessions where the pointer path was loaded | **16** |

The Method command above reproduces these figures.

**The window boundary is a choice, and it flatters one row.** It opens on 2026-08-22 because that is
the first UTC day on which no session carried the probe, not because it is the eviction date. Counted
from the eviction commit (`a687a64`, authored 2026-08-20T14:40Z; the session that made it started
2026-08-20T00:36Z) the denominator is **19** — three sessions first-dated 2026-08-21 join, one of them
holding the class-4 targeted search above — and the fetch count is **0**, with that search recorded
separately as a partial read. That is the superseded pass's denominator with its numerator corrected.
Either window is defensible; report which one you used.

The four hits before the window are not fetches. One (session first-dated 2026-08-10) is a Read of a
worktree copy of `activeContext.md` on 2026-08-17, three days before the archive existed (class 5).
Two (first-dated 2026-08-12 and 2026-08-20) read and edited `activeContext.md` while the text was
still there; only the later of the two performed the eviction. `grep -c
'context-2026-08-20-narrative-sections'` on the two transcripts returns 0 and 48, and the 2026-08-12
session's last record (`2026-08-20T00:41:52Z`) precedes `a687a64`'s author time
(`2026-08-20T14:40:29Z`) by about fourteen hours. Both are class 5. The fourth is the class-4 search
in the table.

**A superseded earlier figure, recorded because the error is instructive:** a first pass searched the
pointer path and reported "1 fetch in 19 sessions." That was wrong in the flattering direction. The one
apparent fetch was a session operating on the eviction itself, and path search cannot separate loaded
from fetched at all.

## The intervention

The pointer was rewritten on 2026-09-09 to carry what a usable handle needs — what the file holds, how
large it is (82 lines, 5,638 bytes; `standards/MEMORY-BANK.md` calls archive files write-once and
`docs/archive/README.md` says never append to one, so the figure holds unless that rule is broken, which has
happened at least once: `f70e84a` corrected a figure in place in a different archive file. That count
is a floor, not a total, because this clone is shallow — `git log origin/main --oneline | wc -l`
returns 1 — so `git log --all -- docs/archive/` cannot see an in-place edit that landed on main
before the graft), and **when to open it** — the last being the piece that a bare path lacks.

## How to re-measure

Re-run the Method command above and count sessions first-dated after 2026-09-10T02:53Z, excluding the session
performing the re-measurement and any that edited or reviewed this file. Baseline is zero, so any hit
is signal once it is classified as a fetch (class 1) rather than classes 2 to 5. Report the
denominator with the unit and window stated here, not just the numerator. Write the result to a new
dated file.

## Limitations — read before drawing a conclusion

1. **Quasi-blind at best, not blind.** Keeping the protocol out of `memory-bank/` prevents a session
   from reading the probe string at startup. It does not make the experiment blind: a session that goes
   looking will find this file. Perfect blindness is unavailable in a system that observes itself, and
   claiming it would be worse than disclosing the limit.
2. **Zero does not mean retrieval failed.** It is equally consistent with the 16 sessions never needing
   the narrative. Separating those requires a task whose correct answer *requires* the archived detail —
   the planted-violation method that found this repo's inert CI check (`1f7a7e7`, authored 2026-09-08
   local; `progress.md` dates the entry 2026-09-09), not observation.
3. **One pointer, n=16, one repo.** Not a general result about externalization.
4. **The intervention is unfalsifiable on a short horizon.** Sessions accumulate slowly; a null result
   at n=5 means nothing.
5. **Confound:** this file's existence, and the enriched pointer, both change the environment. Reading
   this file's final text does not register as a hit (the probe is split); the sessions that drafted
   and reviewed it do, and the exclusion rule above names them. A session that read this file and then
   opens the archive may do so because the trigger text worked or because this file named the target.
   Record which, when it happens. The two bare pointers to the same archive in `[NS-14]` and `[NS-15]`
   are a further confound: a fetch cannot be attributed to the enriched handle over them.
6. **Machine-local evidence, and three of the four cited commits do not resolve from a clone.** The
   transcripts live outside the repository, on one machine, so from any other clone the figures are a
   report rather than a measurement. The commits are only partly better. Of the four cited here, only
   `f70e84a` sits on a live remote branch (`origin/fix/block-tier-case-sensitivity`). `a687a64` is on
   no live remote branch at all: `git ls-remote origin` points at it from `refs/pull/20/head` alone,
   the head of the pull request squash-merged as `ea862e8`, so reaching it needs an explicit
   `git fetch origin refs/pull/20/head`. `1f7a7e7` is unpushed and local to this machine. `605bc969`
   is in `unyieldingclaw-dev/harness-engineering`, not this repository. Prefer a commit that a clone
   can reach, and say so when none exists.
7. **The denominator is partitioned by worktree, and one in-window session sits outside it.** Sessions
   run inside a registered worktree write to their own project directory, so the 16 above counts the
   main directory only. Scanning all nine directories adds `0c222a6f` (first-dated
   2026-08-24T23:43:12Z, worktree `mystifying-meitner-b16cb2`, 2,130 records, probe 0, pointer loaded),
   giving **17 / 0 / 17**, and an alternative from-eviction denominator of 20. The numerator is
   unaffected under every scope tried: no worktree session in or after the window carries the probe.
   Widening the command is possible but needs care, because `a0c56f34` exists in two directories with
   differing contents and a naive cross-directory loop double-counts it.

## Provenance

Source of record: `unyieldingclaw-dev/harness-engineering` **PR #12**, branch
`research/context-efficiency-repos-2026-09-09` at head `605bc969` (committed 2026-09-10T00:56Z; an
open branch can move, so the SHA is the citation) —
`Context Efficiency Repositories — Deep Evidence Pass — 2026-09-09.md` and
`Context Efficiency Repositories — Second Evidence Pass & Ponytail Reassessment — 2026-09-10.md`.

**This measurement answers a question those artifacts raise and do not measure.** The second pass's
experimental matrix lists externalization's primary intervention as "removes raw evidence from active
context" and its main risk as **"retrieval failure"**, and dispositions Context Mode as
**PRIORITY RESEARCH — bounded evidence retrieval**. The corpus names retrieval failure as the risk;
this is a production measurement of it, in the one place where PMB already runs the mechanism.

The handle-design pattern — a described placeholder with a retrieval key — is what the deep pass
records for `magic-compact` (omission IDs plus a `read_omitted_content` tool), dispositioned in the
second pass as **ADOPT DESIGN PRINCIPLE — recoverable structured compaction**. Neither artifact uses the
phrase "omission notice" or lists description and size as fields of it; that is this file's reading of
the mechanism. Neither artifact's account of any surveyed tool mentions a "when to open it" trigger;
whether some tool carries one was not checked at source. "Three of the eleven" is this file's
classification of the deep pass's taxonomy table, not a count the source states.

**Correction, recorded because the error is the point.** An earlier version of this file cited a
different branch — a duplicate evidence pass written on 2026-09-09 without knowing PR #12 existed.
That duplicate was produced after searching only a shallow clone of `main` and concluding no such
artifact existed; the corpus is `main` plus the open research PRs (`gh pr list --repo
unyieldingclaw-dev/harness-engineering --state open` → 7 on 2026-09-09, PR #12 among them), and the
search scope never covered them. It is abandoned, unpushed. The failure class is the one the second
pass's own process correction warns about, and the one this repo's `standards/CODE-REVIEW.md` already
forbids: an absence claim whose search reach was narrower than the assertion built on it. Earlier
drafts of this file repeated the class four more times — "eight" open PRs without having listed
them, the probe quoted verbatim so the protocol matched its own instrument, a byte delta not
re-measured after the text it described was edited, and a transcript session id cited as the eviction
commit. Each was caught by review, not by the author; none carried the command that would have caught
it.
