# Multi-Session Memory — known differences between the journal twins

Companion to [`2026-09-26-multi-session-memory-design.md`](2026-09-26-multi-session-memory-design.md)
§4.1. The spec states the rule: the two twins of `scripts/pmb-journal.{sh,ps1}` make the same decisions,
and both refuse to open a FIFO or a device. This file lists where they are known to differ, and how
each one tests for a non-regular file. References such as §4.3, F18 or S3 point to the spec.

The two sections below were moved verbatim from the spec's §4.1 at `c2a5d1c`, including their inline
amendment tags. Later amendments edit this text in place, and the commit message records the date and
the review (see the spec's header).

**Twin parity (amended 2026-10-14, Task 6 review; 2026-10-16 and 2026-10-17, FIFO-hardening
reviews; 2026-10-18 and 2026-10-19, argument-alteration reviews).** The two twins are built to make
the same decisions, return the same exit codes and write the same bytes to `pmb/`. The parity tests
check this for the cases they cover; it is not proven in general. These are the differences known today:
- **Text arguments under pwsh.** Under `-File` and `-CommandWithArgs` pwsh parses every argument
  before the PowerShell twin sees it: a dash-led one (`-`, U+2013-U+2015) can be split at a colon,
  dropped, or turned into a flag such as `--file:<path>`; `--%` is dropped; on Linux invalid UTF-8
  becomes U+FFFD; `-Command` re-parses them. The twin reads arguments for a record, `show` or
  `import-handoff` only when it finds its own file name on the process command line and the words
  after it equal them, compared ordinally; it refuses U+FFFD and lone surrogates. Elsewhere (a
  wrapper, `-CommandWithArgs`, an in-process call such as Claude Code's PowerShell tool makes) it
  refuses every such call unless the caller plants decoy words, pointing at the sh twin from Bash
  and at `pwsh -File` with `--file` from PowerShell; `gate`, `mode`, `start` and `help` still run,
  so `--% start` runs there where the sh twin prints usage, as `--% gate` does everywhere. So it
  refuses some text the sh twin records; where the parity tests reach, it records no other text. Out
  of reach: pwsh exits 1 on an argument such as `-:x` before any script runs; a pwsh script
  relaunching the twin with altered arguments; a PowerShell caller, whose native call drops even a
  quoted `--%` and the quoting after it; a Git Bash caller on Windows, which rewrites them before
  pwsh starts, so a path or invalid UTF-8 is stored in another form. Measured: pwsh 7.4.7, 7.6.6.
- **Windows, with a Git Bash FIFO** (Regular files, below).
- **A Linux or macOS host with neither `/usr/bin/test` nor `/bin/test`**, or whose binary cannot
  be run (Regular files, below).
- **Message text only.**
  - Paths in messages take each shell's form: `C:/...` from .NET and git, `/c/...` or `/tmp/...`
    from Git Bash.
  - An OS error inside a message is the platform's own text, .NET's or the shell tool's. So is the
    error for a secret pattern that cannot be applied: a .NET regex error, not a grep exit code.
  - The first usage line names `pmb-journal.ps1`.

**Regular files (amended 2026-10-16, Plan A and FIFO-hardening reviews; 2026-10-18 and -19, reviews
of #63 and #65).** Both twins refuse to open a FIFO or a device, since opening a FIFO blocks the hook.
Before reading a file, the sh twin uses its built-in `[ -f ]`. .NET reports a FIFO as an existing
file, so on Linux and macOS the PowerShell twin runs the first of `/usr/bin/test` and `/bin/test`
that exists, found once per process. Alpine ships only `/usr/bin/test`. Windows needs no binary. If
neither exists, or the one found cannot be run, the twin throws rather than refusing every file.
It throws the first time it checks a file that exists and is not a link; a missing file still
reads as not regular, with no throw. Its behaviour then differs from the sh twin's (a known
difference listed under Twin parity, above):
- `show` of a session with at least one record prints its header, then the error, and exits 1;
- `note --file` and `import-handoff` print the error and exit 1;
- the claim report is skipped without a message, and the claim itself still exits 0;
- the gate fails open on every compaction that reads a record or `gate-blocked`. Run as the hook,
  it prints `[HOOK ERROR]` on stdout and logs the error to `.pmb-hook-errors.log`. Run as
  `pmb-journal.ps1 gate`, it warns on stderr.

When a FIFO or other non-regular file sits at `gate-blocked`, it is neither read nor written, so the
block cannot be recorded and the gate fails open (§4.3). The first write creates `started` only when
nothing is at that name (an entry of any type means the session started; sh's `noclobber` alone
would open a FIFO), and the gate's probe creates its file in `tmp/` under a fresh random name. On
Linux, a FIFO at `started` or at the probe's old name `.probe.<pid>` hangs neither twin (tested).
Names are tested before they are opened (e.g. records, `gate-blocked`, and in the sh twin
`started`), so a FIFO swapped in between can still block; S3 puts such same-user writes out of
scope. On Windows, pwsh sees a Git Bash FIFO only as a `<name>.lnk` file. macOS is not in CI.
