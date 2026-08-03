#!/usr/bin/env sh
# scripts/_review-gate-lib.sh — shared helpers for review-reminders.sh / review-reminders-post.sh
# (PreToolUse / PostToolUse review-gate hook pair). Dot-sourced, not executed directly.
#
# WHY this file exists: sha256_file(), diff_hash(), and resolve_cd_root() used to be defined
# verbatim in both review-reminders.sh and review-reminders-post.sh -- a fix to one (e.g. the
# 2026-07-09 trailing-newline hash bug) had to be manually ported to the other, and a missed
# port silently reintroduced whatever the other file already fixed. See
# docs/superpowers/specs/2026-07-29-review-gate-hook-lib-dedup-design.md for the full design.
#
# WHY sha256sum with a shasum fallback: sha256sum is standard on Linux and in Git for
# Windows' bundled coreutils, but macOS ships shasum instead. If neither is available,
# fail open (skip the gate entirely) rather than deny everything -- matches this repo's
# established "fail open on missing dependency" convention (see check-contract.sh/python3).
sha256_file() {
    file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | cut -d' ' -f1
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | cut -d' ' -f1
    else
        printf ''
    fi
}

# WHY this helper: the commit and push cases in both hook files need "redirect a git diff to
# a temp file, hash it, clean up" -- inlining that repeatedly risked exactly the kind of
# copy-paste drift that caused the original trailing-newline bug. One helper, one place to
# get it right.
#
# WHY hash a file written via redirection, not piped/captured output: on any machine where
# BOTH pwsh and bash exist, a marker written by one must validate under the other's hook --
# whichever runs is a coin flip the writer can't control. Piping `git diff | sha256sum`
# preserves the trailing newline; capturing via `$(git diff ...)` strips it.
# _review-gate-lib.ps1 redirects to a file (`>`), which also preserves it. Hashing a
# redirected file here, instead of piping or capturing, makes this file's hash byte-identical
# to the PowerShell lib's for the same diff, regardless of which one actually enforces the
# gate on a given machine. Empirically confirmed: command substitution and redirect-to-file
# produced different SHA-256 hashes for the same diff (differing by exactly the trailing
# newline byte) before this fix.
#
# WHY return git diff's exit code, not the hash computation's: the push case needs to try
# `origin/main...HEAD` and fall back to `HEAD` if that ref doesn't exist (no upstream). The
# caller decides whether to fall back based on whether the underlying `git diff` succeeded,
# not whether hashing succeeded (sha256_file degrades gracefully to an empty string on its
# own, unrelated failure mode) -- so this returns git diff's own exit code via `$rc`,
# captured before sha256_file has a chance to run and overwrite `$?`.
#
# WHY the trap: without it, a script exit between `mktemp` and the final `rm -f` (e.g. an
# unexpected signal) leaks a temp file. `trap - EXIT` clears it again once this function
# returns normally, since sh traps are shell-global, not function-scoped -- otherwise this
# trap would still be armed (harmlessly, but confusingly) for the rest of the script.
diff_hash() {
    tmp=$(mktemp)
    trap 'rm -f "$tmp"' EXIT
    git diff "$@" > "$tmp" 2>/dev/null
    rc=$?
    sha256_file "$tmp"
    rm -f "$tmp"
    trap - EXIT
    return $rc
}

# WHY parameterless, relying on the caller's global $input: the caller (review-reminders.sh /
# review-reminders-post.sh) reads raw stdin into $input and does its own raw-stdin case-match
# BEFORE calling this function -- $input is already a shell global by the time this runs, and
# adding a parameter here would just duplicate what's already in scope. This is an implicit
# contract: any caller of resolve_cd_root() must set $input first.
#
# WHY this exists: `git rev-parse --show-toplevel` (the caller's fallback) trusts the hook
# process's own ambient cwd. That's correct for a session whose Bash tool cwd persists across
# calls, but empirically false for some dispatched-subagent sessions -- confirmed via direct
# reproduction during the 2026-07-16 review-gate self-attestation fix session (see
# memory-bank/progress.md's 2026-07-16 entry -- that fix's own design spec explicitly scoped
# this hook as untouched): a bare `pwd` with no `cd` kept returning the wrong directory even
# after many prior `cd "<path>" && ...` calls in the same subagent conversation. Every gated
# commit from inside a worktree was denied even with a correct, matching marker present,
# because root resolved to the wrong directory. Deriving root from the gated command's own
# leading `cd` instead of the hook's ambient state fixes this regardless of the underlying
# cause -- see docs/superpowers/specs/2026-07-22-review-hook-worktree-root-fix-design.md.
#
# WHY python3, not a regex on raw stdin: the raw-text matching in the caller's case statement
# only needs to detect presence ("git commit" appears somewhere"). This needs the actual
# VALUE of tool_input.command to check its prefix. Matches check-contract.sh's existing
# precedent in this repo for the same class of need (extracting an actual field value, not
# just detecting presence).
#
# WHY resolve the FULL leading cd chain, not just the first cd: a chained command like
# `cd "A" && cd "B" && git commit ...` must resolve to B's root, not A's -- reproduced
# directly against the OLD implementation (a sed pattern that only ever matched the first
# `cd "X" &&` prefix): it extracted "A" from that exact string, so a chained command could
# reuse a marker earned reviewing A to authorize a commit that actually runs in B. python3
# walks every leading `cd "<path>" && ` / `cd '<path>' && ` segment in order, applying each
# cd's relative-path semantics against the previously resolved directory (matching what a
# real shell does with the same chain), so the git-root check below runs against the FINAL
# directory, not the first one.
#
# WHY `[^"]+`/`[^']+` (one-or-more), not `*`: must match _review-gate-lib.ps1's
# Resolve-CdRoot regex exactly -- a `*` vs `+` mismatch between the two would make bash and
# PowerShell resolve the SAME input differently (e.g. `cd "" && cd "/real/path" && ...`: `*`
# lets bash match the empty segment and continue the chain; `+` would reject it on PowerShell
# and abandon the chain entirely), defeating the point of a hook meant to behave identically
# on both platforms.
#
# WHY a single-quoted heredoc + argv instead of `python3 -c "..."` + stdin: the regex needs
# to match BOTH `cd "X"` and `cd 'X'` forms, so its source must contain literal double-quote
# AND single-quote characters together -- no shell quoting style for a `-c` argument avoids
# colliding with one or the other. A single-quoted heredoc (<<'PYEOF') isn't interpreted by
# the shell at all (no expansion, no quote handling), so both characters can appear freely;
# $input moves to argv only because the heredoc already claims stdin.
#
# WHY fail open to the ambient root on any failure: this is a best-effort correction layered
# on top of the existing resolution, not a replacement for it. No python3, malformed JSON, no
# leading cd, or an extracted path that isn't a git repo all fall back to exactly today's
# behavior -- a session where ambient cwd is already correct is completely unaffected.
resolve_cd_root() {
    command -v python3 >/dev/null 2>&1 || return 1
    cd_path=$(python3 - "$input" <<'PYEOF' 2>/dev/null | tr -d '\r'
import sys, json, os, re

try:
    data = json.loads(sys.argv[1])
    cmd = data.get("tool_input", {}).get("command", "")
except Exception:
    cmd = ""

dq = re.compile(r'^cd\s+"([^"]+)"\s*&&\s*')
sq = re.compile(r"^cd\s+'([^']+)'\s*&&\s*")
rest = cmd
cur = os.getcwd()
matched = False
while True:
    m = dq.match(rest) or sq.match(rest)
    if not m:
        break
    matched = True
    p = m.group(1)
    cur = p if os.path.isabs(p) else os.path.normpath(os.path.join(cur, p))
    rest = rest[m.end():]

print(cur if matched else "")
PYEOF
)
    [ -z "$cd_path" ] && return 1
    cd_root_result=$(git -C "$cd_path" rev-parse --show-toplevel 2>/dev/null)
    [ -z "$cd_root_result" ] && return 1
    printf '%s' "$cd_root_result"
}
