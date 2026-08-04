#!/usr/bin/env sh
# PreToolUse hook — blocks git commit/push until the matching review slash command has run,
# and unconditionally blocks `gh pr merge` outright. /code-review writes
# .claude/.code-review-ok on an Approve verdict; /change-review writes .claude/.change-review-ok
# when no finding is Blocking. Each marker authorizes exactly one commit or push attempt for a
# SPECIFIC diff -- see below.
#
# WHY `gh pr merge` gets an unconditional deny instead of a third diff-bound marker: by the
# time a PR is mergeable, its diff already passed the commit gate, the push gate, and (per
# branch protection's required-status-checks with strict:true) CI on the current head -- a
# third hash gate here would mostly re-verify what's already verified, while adding real
# fragility (PR-number/--repo parsing, a `gh pr diff` API call inside a hook). The actual gap
# at merge time isn't diff integrity, it's authorization: merging changes shared history and
# should never happen without the user deciding to do it in that moment, and a hash can't
# encode "the user meant this right now." This hook can only ever see commands *this agent*
# runs -- the user's own terminal is invisible to it -- so an unconditional deny is both
# correct and total: if this hook fires at all, it's the agent trying to merge, never the
# user, so there is no legitimate case to allow through.
#
# WHY the marker holds a SHA-256 hash of the reviewed diff, not an empty file: an empty
# marker is trivially fakeable with `touch` -- anyone (or a rushed agent) can satisfy the
# gate without actually reviewing anything. Binding the marker to a hash of the exact diff
# means it only authorizes committing/pushing that SPECIFIC diff; if the working tree
# changes after the review, the hash no longer matches and the gate re-engages.
#
# WHY the marker is consumed via an atomic rename (mv), not a separate [ -f ] + rm: check-
# then-delete has a TOCTOU window between the two steps. mv's underlying rename is a single
# filesystem operation -- if the source doesn't exist, the move simply fails, collapsing
# "does it exist" and "claim it" into one step.
#
# WHY this also records a pre-state ref once validation succeeds, before the gated command
# itself runs: see the companion PostToolUse hook (review-reminders-post.sh) -- if the gated
# commit/push then fails, that hook detects the relevant git ref didn't move and reissues the
# marker, so a rejected attempt (e.g. a separate pre-commit hook) doesn't force a pointless
# re-review.
#
# WHY match against extract_command()'s parsed tool_input.command, not the raw stdin
# payload: the real Bash tool's PreToolUse payload also carries tool_input.description
# alongside command (e.g. {"tool_input":{"command":"git log --oneline","description":"Show
# git commit history"}}) -- matching raw stdin means that description text alone can trigger
# the gate on a command that never touches git commit/push at all. review-reminders.ps1
# already parses JSON properly (ConvertFrom-Json) and matches on the extracted command value
# only; extract_command() brings this hook to the same behavior using python3, already a
# dependency in this file (resolve_cd_root() below reuses extract_command()'s parsed command
# instead of re-parsing JSON itself), so this carries no new dependency. Falls back to
# matching raw stdin (today's behavior) only when python3 is missing or the
# JSON fails to parse -- the safe failure direction for a security gate is to over-trigger an
# occasional unnecessary re-review, not to silently stop gating commits/pushes altogether.
#
# WHY hookSpecificOutput.permissionDecision, not top-level "continue": top-level
# {"continue": false} only stops the agent's turn *after* the tool call has already run --
# it does not prevent execution. Verified empirically with a real git commit.
#
# WHY sha256sum with a shasum fallback: sha256sum is standard on Linux and in Git for
# Windows' bundled coreutils, but macOS ships shasum instead. If neither is available,
# fail open (skip the gate entirely) rather than deny everything -- matches this repo's
# established "fail open on missing dependency" convention (see check-contract.sh/python3).
#
# WHY hash a file written via redirection, not piped/captured output: this hook is a
# fallback that only runs when pwsh is unavailable (settings.json tries pwsh first), but
# on any machine where BOTH pwsh and bash exist, a marker written by one must validate
# under the other's hook -- whichever runs is a coin flip the writer can't control. Piping
# `git diff | sha256sum` preserves the trailing newline; capturing via `$(git diff ...)`
# strips it. review-reminders.ps1 redirects to a file (`>`), which also preserves it.
# Hashing a redirected file here, instead of piping or capturing, makes this script's hash
# byte-identical to review-reminders.ps1's for the same diff, regardless of which one
# actually enforces the gate on a given machine. Empirically confirmed: command
# substitution and redirect-to-file produced different SHA-256 hashes for the same diff
# (differing by exactly the trailing newline byte) before this fix.

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

# WHY this helper: the commit and push cases below both need "redirect a git diff to a temp
# file, hash it, clean up" -- inlining that 4 times (2 here, 2 more in the companion
# review-reminders-post.sh) risked exactly the kind of copy-paste drift that caused the
# original trailing-newline bug. One helper, one place to get it right.
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
#
# WHY bail out immediately if mktemp fails or returns empty: without this, `git diff "$@" >
# "$tmp"` would redirect to an empty-string filename when `$tmp` is empty (mktemp failed,
# e.g. a full disk or unwritable TMPDIR) -- an ambiguous/invalid redirect whose behavior
# depends on the shell rather than failing predictably. Returning early here means a
# mktemp failure degrades the same way any other diff_hash failure does (empty expected hash,
# fails closed) instead of hitting an undefined redirect error.
diff_hash() {
    tmp=$(mktemp) || return 1
    [ -z "$tmp" ] && return 1
    trap 'rm -f "$tmp"' EXIT
    git diff "$@" > "$tmp" 2>/dev/null
    rc=$?
    sha256_file "$tmp"
    rm -f "$tmp"
    trap - EXIT
    return $rc
}

input=$(cat 2>/dev/null)
[ -z "$input" ] && exit 0

# WHY this exists: `git rev-parse --show-toplevel` below trusts the hook process's own
# ambient cwd. That's correct for a session whose Bash tool cwd persists across calls, but
# empirically false for some dispatched-subagent sessions -- confirmed via direct
# reproduction during the 2026-07-16 review-gate self-attestation fix session (see
# memory-bank/progress.md's 2026-07-16 entry -- that fix's own design spec explicitly scoped
# this hook as untouched): a bare `pwd` with no `cd` kept returning the wrong directory even
# after many prior `cd "<path>" && ...` calls in the same subagent conversation. Every gated
# commit from inside a worktree was denied even with a correct, matching marker present,
# because root resolved to the wrong directory. Deriving root from the gated command's own
# leading `cd` instead of the hook's ambient state fixes this regardless of the underlying
# cause -- see docs/superpowers/specs/2026-07-22-review-hook-worktree-root-fix-design.md.
#
# WHY extract_command() parses the JSON once, and resolve_cd_root() takes the already-
# extracted command as a plain-string argument instead of re-parsing JSON itself: these two
# used to run separate python3 subprocesses each doing their own identical
# `json.loads(...).get("tool_input", {}).get("command", "")` extraction, for two different
# downstream uses (walking a leading cd chain vs. matching the whole command against git
# commit/push/gh pr merge). Parsing once and threading the plain string through removes that
# duplication -- resolve_cd_root()'s own python3 call becomes pure string/path logic with no
# JSON involved at all, while extract_command() remains the single place tool_input.command
# is ever pulled out of the payload.
#
# WHY extract_command() distinguishes "parsing failed" from "tool_input.command legitimately
# parsed to an empty string" via an explicit presence check and exit code, not an empty-
# string default: a default made both cases produce empty output, which the caller could only
# treat identically -- falling back to raw-stdin matching even when the command genuinely
# WAS empty (which should mean "nothing to gate," not "fall back to scanning raw stdin for a
# stray trigger phrase"). Reproduced directly: {"tool_input":{"command":"","description":
# "remember to git commit these staged changes later"}} would otherwise still match the gate
# via the raw-stdin fallback, defeating the point of matching the parsed command at all. The
# exit code (not the printed string) is what the caller branches on, so a genuinely empty
# command is distinguishable from a failed parse even though both print nothing.
extract_command() {
    command -v python3 >/dev/null 2>&1 || return 1
    result=$(python3 - "$input" 2>/dev/null <<'PYEOF'
import sys, json

try:
    data = json.loads(sys.argv[1])
    tool_input = data.get("tool_input", {})
    if "command" not in tool_input:
        sys.exit(1)
    sys.stdout.write(tool_input["command"])
except Exception:
    sys.exit(1)
PYEOF
)
    rc=$?
    [ "$rc" -ne 0 ] && return 1
    printf '%s' "$result" | tr -d '\r'
}

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
# WHY `[^"]+`/`[^']+` (one-or-more), not `*`: must match review-reminders.ps1's regex exactly
# -- a `*` vs `+` mismatch between the two would make bash and PowerShell resolve the SAME
# input differently (e.g. `cd "" && cd "/real/path" && ...`: `*` lets bash match the empty
# segment and continue the chain; `+` would reject it on PowerShell and abandon the chain
# entirely), defeating the point of a hook meant to behave identically on both platforms.
#
# WHY a single-quoted heredoc + argv instead of `python3 -c "..."` + stdin: the regex needs
# to match BOTH `cd "X"` and `cd 'X'` forms, so its source must contain literal double-quote
# AND single-quote characters together -- no shell quoting style for a `-c` argument avoids
# colliding with one or the other. A single-quoted heredoc (<<'PYEOF') isn't interpreted by
# the shell at all (no expansion, no quote handling), so both characters can appear freely;
# the command string moves to argv only because the heredoc already claims stdin.
#
# WHY fail open to the ambient root on any failure: this is a best-effort correction layered
# on top of the existing resolution, not a replacement for it. No python3, no leading cd, or
# an extracted path that isn't a git repo all fall back to exactly today's behavior -- a
# session where ambient cwd is already correct is completely unaffected.
resolve_cd_root() {
    # $1: the already-extracted tool_input.command value (a plain string, not JSON) -- see
    # extract_command() above. This function no longer parses JSON at all.
    command -v python3 >/dev/null 2>&1 || return 1
    cd_path=$(python3 - "$1" <<'PYEOF' 2>/dev/null | tr -d '\r'
import sys, os, re

cmd = sys.argv[1]
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

if match_target=$(extract_command); then
    extracted=1
else
    match_target="$input"
    extracted=0
fi

# WHY match against a quote/backslash-stripped, lowercased copy, not $match_target itself: a
# command like `git c"o"mmit -m "x"` executes, after the real shell's own quote removal, as a
# genuine `git commit -m x` -- but the parsed (or raw-fallback) command TEXT never contains "git
# commit" as a contiguous substring, so every case/esac match below would silently miss it.
# Reproduced directly: that exact payload previously exited 0 with no deny even though bash
# executes it as a real, unreviewed commit -- true even on origin/main, predating this file's
# other fixes. The lowercasing closes a parallel gap: review-reminders.ps1's `-match` is
# case-insensitive by default, but this file's `case`/esac is case-sensitive, so `Git Commit`
# passed through unmatched here while its .ps1 counterpart would have caught it -- on a
# case-insensitive filesystem (default Windows/macOS), `Git`/`GIT` can resolve to the same git
# binary as `git`, so this wasn't just a cosmetic mismatch. Neither transform touches
# $match_target itself, which still needs its real quoting and casing intact for
# resolve_cd_root()'s cd-chain parsing below (a `cd "Path"` argument is case-sensitive on most
# filesystems this hook actually resolves against). Both transforms can only ever make a match
# MORE likely to fire, matching this file's established "over-trigger, never under-gate" safety
# direction -- neither can introduce a new bypass, only new (already-accepted) false-positive
# risk.
match_target_stripped=$(printf '%s' "$match_target" | tr -d "\"'\\\\" | tr 'A-Z' 'a-z')

# classify_targets — an ADDITIONAL commit/push/merge detector, layered on TOP of
# match_target_stripped's substring check below, never a replacement for it: tokenizes $1
# with a real shell-like tokenizer (python3's shlex, POSIX mode: correctly implements quote-
# removal and backslash-escape semantics -- `git c"o"mmit`'s quotes are properly removed
# rather than merely deleted, and punctuation_chars mode recognizes &&/||/;/| as their own
# tokens, splitting compound commands correctly) and walks each resulting simple command's
# tokens, skipping git's/gh's own documented global options (-C <path>, -c <name>=<value>,
# --opt=value forms, etc.) to find the REAL subcommand -- not just whatever text happens to
# follow the literal substring "git " or "gh ". Prints one line per detected trigger
# (commit/push/merge). Returns 1 with no output if python3 is unavailable or the input can't
# be tokenized at all (e.g. genuinely unbalanced quoting); the caller simply doesn't gain the
# extra detection in that case, since the substring check underneath is never bypassed.
#
# WHY this exists, beyond the quote-stripping/lowercasing above: `git -C /path commit -m x`
# and `git -c user.name=z commit -m x` are ordinary, idiomatic git invocations -- not
# adversarial obfuscation, an agent naturally reaches for `-C` when working across
# directories -- whose text never contains "git commit" as a contiguous substring, so
# match_target_stripped's plain substring match missed them entirely. Found via this
# session's opposition-review pass: the same underlying class of gap as the quote-split bug,
# just in git's own argument syntax instead of shell quoting.
#
# WHY additive (OR'd with match_target_stripped), not a primary detector that can suppress
# the substring check: an earlier version of this fix treated "classify_targets ran
# successfully" as authoritative and skipped the substring check whenever it succeeded --
# but "ran successfully" only means the head token was recognized as exactly the string
# "git"/"gh"; it does NOT match `/usr/bin/git commit`, `env git commit`, or any other
# perfectly ordinary indirect invocation. Reproduced directly: that version silently allowed
# `/usr/bin/git commit -m x` through with no deny at all -- a real regression, since the
# substring check alone (still active pre-this-fix) already caught it. Running both checks
# and OR'ing the results means classify_targets() can only ever ADD detection (the -C/-c/
# whitespace-variant forms it understands), never remove coverage the substring check
# already had -- the same "over-trigger, never under-gate" safety direction this file already
# commits to everywhere else, now correctly applied to this fix too.
#
# WHY only the realistic, commonly-used global options are recognized, not a complete
# reimplementation of git's/gh's argument grammar: an unrecognized flag just means
# classify_targets() might miss detecting that specific invocation shape -- harmless given
# the substring check underneath still covers the literal-substring case, and the safe
# direction for an unknown flag is to still treat the next token as a possible subcommand
# (more likely to trigger, never less).
classify_targets() {
    command -v python3 >/dev/null 2>&1 || return 1
    result=$(python3 - "$1" 2>/dev/null <<'PYEOF'
import sys, shlex

GIT_OPTS_WITH_VALUE = ('-c', '-C', '--git-dir', '--work-tree', '--namespace',
                        '--super-prefix', '--exec-path', '--attr-source')
GH_OPTS_WITH_VALUE = ('-R', '--repo', '--hostname')


def next_subcommand(tokens, start, opts_with_value):
    i = start
    n = len(tokens)
    while i < n:
        t = tokens[i]
        if t.startswith('--') and '=' in t:
            i += 1
            continue
        if t in opts_with_value:
            i += 2
            continue
        if t.startswith('-'):
            i += 1
            continue
        return t, i + 1
    return None, i


def split_simple_commands(tokens):
    ops = {'&&', '||', ';', '|', '|&', '&'}
    cur, out = [], []
    for t in tokens:
        if t in ops:
            if cur:
                out.append(cur)
            cur = []
        else:
            cur.append(t)
    if cur:
        out.append(cur)
    return out


try:
    cmd = sys.argv[1]
except IndexError:
    cmd = ""

lex = shlex.shlex(cmd, posix=True, punctuation_chars=True)
lex.whitespace_split = True
try:
    tokens = list(lex)
except ValueError:
    sys.exit(1)

found = set()
for simple in split_simple_commands(tokens):
    if not simple:
        continue
    head = simple[0].lower()
    if head == 'git':
        sub, _ = next_subcommand(simple, 1, GIT_OPTS_WITH_VALUE)
        if sub and sub.lower() == 'commit':
            found.add('commit')
        elif sub and sub.lower() == 'push':
            found.add('push')
    elif head == 'gh':
        sub1, nexti = next_subcommand(simple, 1, GH_OPTS_WITH_VALUE)
        if sub1 and sub1.lower() == 'pr':
            sub2, _ = next_subcommand(simple, nexti, GH_OPTS_WITH_VALUE)
            if sub2 and sub2.lower() == 'merge':
                found.add('merge')

sys.stdout.write('\n'.join(sorted(found)))
PYEOF
)
    rc=$?
    [ "$rc" -ne 0 ] && return 1
    printf '%s' "$result" | tr -d '\r'
}

deny() {
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$1"
}

# tag_only_push — exempts a detected `needs_push` from the diff-bound marker requirement when
# EVERY `git push` invocation in the (possibly compound) command targets only a tag, never a
# branch. Prints "1" on exemption; prints nothing (or fails) otherwise, so the caller's
# default is always "still require the marker" -- exemption is opt-in, never opt-out.
#
# WHY this exists: reported live by the ai-code-review-agent session cutting release v1.8.0 --
# `git tag v1.8.0 origin/main && git push origin v1.8.0` was denied outright, including the
# harmless `git tag` half, because needs_push detection only checks the git SUBCOMMAND (push),
# never WHAT is being pushed. The gate's actual check -- a diff-hash between origin/main and
# HEAD -- is a meaningful "was this code reviewed" proxy for a BRANCH push; a tag carries no
# diff at all, so satisfying the gate for a tag push meant hashing whatever unrelated branch
# happened to be locally checked out. See docs/superpowers/specs/2026-08-03-review-gate-tag-
# push-exemption-design.md for the full writeup and rejected alternatives.
#
# WHY a tag is safe to exempt at all: unlike a branch push, a tag push cannot introduce
# unreviewed code into origin -- it only labels a commit that either already went through its
# own review (an existing merged commit) or is being explicitly, visibly tagged right here in
# the command text (never smuggled in). This hook's job is preventing unreviewed CODE from
# reaching a shared branch; a tag pointer doesn't change any branch's content.
#
# WHY a tag being CREATED in the same compound command counts as exempt too, not just a tag
# that already exists: the reported scenario tags and pushes in one compound command --
# `git tag v1.8.0 origin/main && git push origin v1.8.0` -- and the PreToolUse hook fires
# BEFORE either half has run, so the tag genuinely doesn't exist in the local repo yet when
# this check runs. Requiring `git show-ref` to already find it would mean this exemption could
# never fire for the exact case it exists to fix. Recognizing "this same command's own
# `git tag <name> ...` half declares intent to create <name>" is safe for the same reason
# pushing an existing tag is safe: creating a tag is still just labeling some existing commit,
# never introducing new code, regardless of whether the label already existed.
#
# WHY every other shape (0/1/3+ positional args after `push`, --delete, --tags mixed with an
# explicit refspec, a refspec that isn't a recognized/about-to-be-created tag) falls through to
# "not exempt": each of these is either genuinely ambiguous (could be a branch) or outside what
# this function models -- e.g. `git push origin` (0 args, pushes the current branch via
# upstream tracking) and `git push origin main` (a real branch) MUST keep requiring the marker.
# An unrecognized shape only ever costs an unnecessary re-review, never grants an unearned
# exemption -- the same "over-trigger, never under-gate" direction this file uses everywhere.
tag_only_push() {
    command -v python3 >/dev/null 2>&1 || return 1
    result=$(python3 - "$1" 2>/dev/null <<'PYEOF'
import subprocess
import sys, shlex

GIT_OPTS_WITH_VALUE = ('-c', '-C', '--git-dir', '--work-tree', '--namespace',
                        '--super-prefix', '--exec-path', '--attr-source')
PUSH_OPTS_WITH_VALUE = ('-o',)
TAG_OPTS_WITH_VALUE = ('-m', '-F', '-u', '--local-user', '--cleanup')
TAG_NONCREATE_FLAGS = ('-d', '--delete', '-l', '--list', '-v', '--verify')


def next_token_index(tokens, start, opts_with_value):
    i = start
    n = len(tokens)
    while i < n:
        t = tokens[i]
        if t.startswith('--') and '=' in t:
            i += 1
            continue
        if t in opts_with_value:
            i += 2
            continue
        if t.startswith('-'):
            i += 1
            continue
        return i
    return i


def split_simple_commands(tokens):
    ops = {'&&', '||', ';', '|', '|&', '&'}
    cur, out = [], []
    for t in tokens:
        if t in ops:
            if cur:
                out.append(cur)
            cur = []
        else:
            cur.append(t)
    if cur:
        out.append(cur)
    return out


def is_existing_tag(name):
    if not name or (name.startswith('refs/') and not name.startswith('refs/tags/')):
        return False
    bare = name[len('refs/tags/'):] if name.startswith('refs/tags/') else name
    tag_ok = subprocess.run(['git', 'show-ref', '--verify', '--quiet', 'refs/tags/' + bare],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
    if not tag_ok:
        return False
    head_ok = subprocess.run(['git', 'show-ref', '--verify', '--quiet', 'refs/heads/' + bare],
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
    return not head_ok


def resolve_tag_target(bare):
    # Peels an existing tag to the commit it points at (handles annotated tags via ^{commit}).
    # Returns None if the tag doesn't resolve to a commit at all.
    result = subprocess.run(['git', 'rev-parse', '--verify', '--quiet', 'refs/tags/' + bare + '^{commit}'],
                             stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    if result.returncode != 0:
        return None
    return result.stdout.decode().strip()


def is_ancestor_of_main(ref):
    # WHY this check exists at all: found by a second opposition-review pass, after the
    # src:dst refspec bypass above was already fixed. Tag creation/push was exempted purely
    # on the TAG NAME resolving safely -- with zero check on WHAT COMMIT the tag actually
    # points at. `git tag foo <any-local-commit> && git push origin foo` was exempted
    # regardless of whether <any-local-commit> had ever been reviewed, which doesn't
    # overwrite any branch (confirmed empirically -- a tag push alone never moves a branch
    # ref), but DOES unconditionally upload that commit's objects to the remote's object
    # store with zero review. Requiring the tagged commit to already be an ancestor of
    # origin/main means it was already reviewed and already published via the ordinary
    # commit+push gate before this tag-push exemption ever grants anything -- a tag can only
    # ever re-label content that already passed review, never introduce new unreviewed
    # content to the remote. This still exempts the originally reported bug's exact scenario
    # (`git tag v1.8.0 origin/main && ...` tags origin/main itself, trivially its own
    # ancestor) without reopening the "tag doesn't exist yet when this hook fires" problem
    # that motivated recognizing same-command tag creation in the first place -- this checks
    # the REF BEING TAGGED, not the tag itself, so it works whether or not the tag exists yet.
    #
    # WHY fail closed (not exempt) if origin/main doesn't resolve, rather than falling back to
    # HEAD or some other ref: unlike diff_hash()'s origin/main-then-HEAD fallback (used to
    # compute a hash that still gets independently validated against a marker either way),
    # falling back here would WEAKEN the actual security property this check exists to
    # enforce -- HEAD itself may contain unreviewed local commits. No fallback, just no
    # exemption, consistent with this file's "unable to verify -> don't exempt" pattern.
    if not ref:
        return False
    return subprocess.run(['git', 'merge-base', '--is-ancestor', ref, 'origin/main'],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0


try:
    cmd = sys.argv[1]
except IndexError:
    cmd = ""

lex = shlex.shlex(cmd, posix=True, punctuation_chars=True)
lex.whitespace_split = True
try:
    tokens = list(lex)
except ValueError:
    sys.exit(1)

simples = split_simple_commands(tokens)

# WHY a dict (name -> target ref), not a set of names: see is_ancestor_of_main()'s WHY
# comment above -- trusting a same-command tag creation requires knowing WHAT COMMIT it's
# creating the tag against, not just that a name was declared. `git tag <name> <ref>`'s
# second positional argument (or HEAD, if omitted) is captured here specifically so the
# push-check below can verify that ref is already-reviewed content, not just that a tag
# with this name is being created.
created_tag_names = {}
for simple in simples:
    if not simple or simple[0].lower() != 'git':
        continue
    idx = next_token_index(simple, 1, GIT_OPTS_WITH_VALUE)
    if idx >= len(simple) or simple[idx].lower() != 'tag':
        continue
    args = simple[idx + 1:]
    noncreate = False
    positional = []
    i = 0
    n = len(args)
    while i < n:
        t = args[i]
        if t in TAG_NONCREATE_FLAGS:
            noncreate = True
            i += 1
            continue
        if t.startswith('--') and '=' in t:
            i += 1
            continue
        if t in TAG_OPTS_WITH_VALUE:
            i += 2
            continue
        if t.startswith('-'):
            i += 1
            continue
        positional.append(t)
        i += 1
    if noncreate or not positional:
        continue
    target_ref = positional[1] if len(positional) > 1 else 'HEAD'
    created_tag_names[positional[0]] = target_ref

push_invocations = 0
all_exempt = True

for simple in simples:
    if not simple or simple[0].lower() != 'git':
        continue
    idx = next_token_index(simple, 1, GIT_OPTS_WITH_VALUE)
    if idx >= len(simple) or simple[idx].lower() != 'push':
        continue
    push_invocations += 1
    args = simple[idx + 1:]
    positional = []
    has_tags_flag = False
    has_delete_flag = False
    i = 0
    n = len(args)
    while i < n:
        t = args[i]
        if t == '--tags':
            has_tags_flag = True
            i += 1
            continue
        if t in ('-d', '--delete'):
            has_delete_flag = True
            i += 1
            continue
        if t.startswith('--') and '=' in t:
            i += 1
            continue
        if t in PUSH_OPTS_WITH_VALUE:
            i += 2
            continue
        if t.startswith('-'):
            i += 1
            continue
        positional.append(t)
        i += 1

    if has_delete_flag:
        all_exempt = False
        continue

    if has_tags_flag:
        if len(positional) <= 1:
            continue
        all_exempt = False
        continue

    if len(positional) != 2:
        all_exempt = False
        continue

    refspec = positional[1]
    if ':' in refspec:
        # CRITICAL, found by opposition review: a src:dst refspec pushes the LOCAL ref
        # named src to the REMOTE ref named dst -- the ref that actually gets updated on
        # origin is dst, not src. An earlier version of this check validated src alone, so
        # `git push origin <any-existing-tag>:main` (or :dst = any other branch, optionally
        # with --force) was exempted because the pre-colon tag name checked out, while the
        # actual effect was overwriting the DESTINATION branch with unreviewed content --
        # confirmed empirically: this exact form landed an unreviewed commit on a scratch
        # repo's main with the review-gate marker never checked at all. Correctly resolving
        # dst would require knowing the REMOTE's own ref-name disambiguation (an unqualified
        # dst can resolve differently depending on what already exists there), which this
        # hook has no way to query without a network round-trip inside a PreToolUse hook.
        # Rather than approximate that with a LOCAL heuristic (still fundamentally guessing
        # at remote state), any refspec containing `:` is simply never exempt -- the same
        # "unrecognized shape costs an unnecessary re-review, never grants an unearned
        # exemption" rule this function already applies to every other ambiguous case.
        all_exempt = False
        continue

    src = refspec
    ok = False
    if src in created_tag_names:
        ok = is_ancestor_of_main(created_tag_names[src])
    elif is_existing_tag(src):
        target = resolve_tag_target(src)
        ok = bool(target) and is_ancestor_of_main(target)
    if ok:
        continue
    all_exempt = False

if push_invocations == 0 or not all_exempt:
    sys.exit(1)

sys.stdout.write('1')
PYEOF
)
    rc=$?
    [ "$rc" -ne 0 ] && return 1
    printf '%s' "$result" | tr -d '\r'
}

# WHY classify before resolving root, and WHY gh pr merge is denied here rather than further
# down: this hook has matcher "Bash" in .claude/settings.json, so it fires -- and blocks
# synchronously -- on every single Bash tool call, not just git commit/push/merge attempts.
# resolve_cd_root() (a second python3 fork) and the git rev-parse fallback below are wasted
# latency for the overwhelming majority of calls that need neither: gh pr merge is an
# unconditional deny with no marker/root access at all, and anything else (ls, npm test, ...)
# isn't gated at all. Only git commit/push actually need root.
#
# WHY match_target_stripped's substring check runs unconditionally first, with
# classify_targets()'s result OR'd in afterward: see classify_targets()'s own WHY comment --
# this ordering is what makes classify_targets() strictly additive rather than a replacement
# that could accidentally suppress coverage the substring check already had.
merge_hit=0
needs_commit=0
needs_push=0
case "$match_target_stripped" in *'gh pr merge'*) merge_hit=1 ;; esac
case "$match_target_stripped" in *'git commit'*) needs_commit=1 ;; esac
case "$match_target_stripped" in *'git push'*) needs_push=1 ;; esac

if targets=$(classify_targets "$match_target"); then
    case "$targets" in *merge*) merge_hit=1 ;; esac
    case "$targets" in *commit*) needs_commit=1 ;; esac
    case "$targets" in *push*) needs_push=1 ;; esac
fi

# WHY this check runs against merge_hit regardless of how it was classified, unlike the
# gh-pr-merge-only skip this file used to apply on the raw-stdin fallback: that skip was
# found, on review, to reopen exactly the "no legitimate case to allow through" gap the
# unconditional deny exists to close -- a REAL `gh pr merge` command would fall straight
# through unchecked whenever classification degraded to the fallback path. The false-positive
# risk this used to guard against (an unrelated command whose raw payload merely mentions
# "gh pr merge", e.g. in tool_input.description) is real but is the SAME failure direction
# commit/push already accept on this exact fallback path -- an extra, unnecessary deny, not a
# security hole.
if [ "$merge_hit" = "1" ]; then
    deny "This agent never merges pull requests, even with explicit instruction -- merging shared history requires a human to run the command directly. Run this gh pr merge command yourself."
    exit 0
fi

if [ "$needs_commit" = "0" ] && [ "$needs_push" = "0" ]; then
    exit 0
fi

root=""
[ "$extracted" = "1" ] && root=$(resolve_cd_root "$match_target")
[ -z "$root" ] && root=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$root" ] && exit 0

# WHY cd here, not -C "$root" on every git call below, and WHY this now happens BEFORE the
# tag_only_push() check rather than after: resolving root fixes where the marker is looked
# FOR, but diff_hash(), tag_only_push()'s internal `git show-ref` calls, and the pre-commit/
# pre-push SHA capture further down all run bare git commands with no directory anchor -- the
# exact same ambient-cwd assumption just fixed above, just at different call sites.
# tag_only_push() specifically needs this to have already happened: it resolves refs against
# whatever the CURRENT directory is, so if it ran before this cd, it could answer "is this a
# tag" against the wrong repo entirely. Anchoring the whole rest of this script to $root once,
# here, means every git call downstream -- including tag_only_push()'s -- is correct by
# construction instead of each one needing to remember -C "$root" individually.
cd "$root" 2>/dev/null || exit 0

# WHY tag_only_push() only runs when $extracted = "1": exemption LOOSENS the gate, so it must
# only ever act on high-confidence, JSON-parsed command text -- the same reasoning
# resolve_cd_root() above already applies to root resolution. On the degraded raw-stdin
# fallback path, $match_target may be noise (unparseable JSON, a payload with
# tool_input.description concatenated in) that merely LOOKS like a tag push without "git"
# actually being the invoked program; granting an exemption based on untrustworthy text would
# be the one place in this file where a false read makes the gate LESS safe, not just an
# unnecessary re-review. Requiring $extracted = "1" keeps exemption strictly opt-in.
if [ "$needs_push" = "1" ] && [ "$extracted" = "1" ]; then
    tag_check=$(tag_only_push "$match_target")
    [ "$tag_check" = "1" ] && needs_push=0
fi

# WHY needs_commit/needs_push are re-checked here, after tag_only_push() may have cleared
# needs_push: a compound command that's PURELY a tag creation+push (no commit chained) should
# exit cleanly here with no marker consumed and no further work done -- the exact scenario
# this fix exists for. A compound command that also chains a real commit (needs_commit still
# 1) correctly falls through to have that half's marker checked independently, same as always.
if [ "$needs_commit" = "0" ] && [ "$needs_push" = "0" ]; then
    exit 0
fi

# Attempt an atomic claim: rename the marker to a private name. Fails harmlessly if the
# marker doesn't exist. Prints the claimed marker's content (a hash) on success, empty on
# failure -- caller compares against the expected hash.
consume_marker() {
    marker="$1"
    claimed="$marker.claimed.$$"
    if ! mv "$marker" "$claimed" 2>/dev/null; then
        printf ''
        return 1
    fi
    content=$(cat "$claimed" 2>/dev/null | tr -d '[:space:]')
    rm -f "$claimed"
    printf '%s' "$content"
}

# WHY commit and push were classified and validated INDEPENDENTLY above (needs_commit/
# needs_push), not via one first-match case/esac: a compound Bash tool call chaining both --
# `git commit -m x && git push origin main` -- matches both. A single first-match case/esac
# would only ever validate whichever half matched first, letting an unreviewed push ride
# through on the strength of a valid commit marker alone. Reproduced directly: seeding only a
# valid .code-review-ok marker (no .change-review-ok) let a compound commit+push through
# untouched. Two independent presence checks (see needs_commit/needs_push above) mean a
# compound command must satisfy BOTH markers.
#
# WHY consume_marker() (atomic rename) is still called directly per-branch, not via a peek-
# then-consume-later split: an atomic single-step consume avoids reintroducing the TOCTOU
# window this file already went out of its way to close (see consume_marker()'s own comment).
# The tradeoff: if a compound command needs both markers and only one is valid, the valid one
# still gets consumed even though the whole command is ultimately denied -- forcing an
# unnecessary re-review for that half. That's the same "safe failure direction: occasional
# unnecessary re-review, never silently under-gate" tradeoff this file already makes elsewhere
# (see the unanchored-match WHY comment above), not a new risk.
commit_ok=1
push_ok=1

if [ "$needs_commit" = "1" ]; then
    commit_expected=$(diff_hash HEAD)
    marker="$root/.claude/.code-review-ok"
    actual=$(consume_marker "$marker")
    if [ -z "$commit_expected" ] || [ "$actual" != "$commit_expected" ]; then
        commit_ok=0
    fi
fi

if [ "$needs_push" = "1" ]; then
    push_expected=$(diff_hash origin/main...HEAD)
    rc=$?
    if [ "$rc" -ne 0 ]; then
        push_expected=$(diff_hash HEAD)
    fi
    marker="$root/.claude/.change-review-ok"
    actual=$(consume_marker "$marker")
    if [ -z "$push_expected" ] || [ "$actual" != "$push_expected" ]; then
        push_ok=0
    fi
fi

if [ "$needs_commit" = "1" ] && [ "$commit_ok" = "0" ] && [ "$needs_push" = "1" ] && [ "$push_ok" = "0" ]; then
    deny "Run /code-review before committing and /change-review before pushing -- this is a combined commit+push command and both diff-bound review-ok markers are required. Neither is present/valid."
elif [ "$needs_commit" = "1" ] && [ "$commit_ok" = "0" ]; then
    deny "Run /code-review before committing -- it writes a diff-bound review-ok marker this hook checks. If you already reviewed, the working tree changed since then; re-run /code-review."
elif [ "$needs_push" = "1" ] && [ "$push_ok" = "0" ]; then
    deny "Run /change-review before pushing -- it writes a diff-bound review-ok marker this hook checks. If you already reviewed, the diff changed since then; re-run /change-review."
else
    # WHY also persist the just-validated expected hash (.pending-commit-hash/.pending-push-
    # hash), not just the presha ref: see review-reminders-post.sh's matching comment -- the
    # post-hook used to recompute a fresh diff_hash at reissue time on the (false, in the
    # common case of a mutating downstream pre-commit hook) assumption that a failed commit/
    # push can't have altered the tree. Persisting the ORIGINAL hash here lets the post-hook
    # replay exactly what was actually reviewed, instead of re-deriving a value that may now
    # reflect a tree /code-review or /change-review never saw.
    if [ "$needs_commit" = "1" ]; then
        presha=$(git rev-parse HEAD 2>/dev/null)
        if [ -n "$presha" ]; then
            printf '%s' "$presha" > "$root/.claude/.pending-commit-presha"
            printf '%s' "$commit_expected" > "$root/.claude/.pending-commit-hash"
        fi
    fi
    if [ "$needs_push" = "1" ]; then
        presha=$(git rev-parse '@{u}' 2>/dev/null)
        if [ -n "$presha" ]; then
            printf '%s' "$presha" > "$root/.claude/.pending-push-presha"
            printf '%s' "$push_expected" > "$root/.claude/.pending-push-hash"
        fi
    fi
fi
exit 0
