"""Classify a PreToolUse payload as COMMIT / PUSH / MERGE / NONE.

Reads the raw payload on stdin and exits 0. Writes, on stdout:
  * by default, one verdict token;
  * with --git-context, the command's repository path chain, or __UNSUPPORTED_GIT_CONTEXT__;
  * with --tag-push, a TAG-PUSH header line and then the tag names, or nothing (see TAG_PUSH).
Exits non-zero ONLY when the payload cannot be parsed at all, which the caller treats as "fall
back to the conservative raw matcher" rather than as "allow".

WHY a parser and not a substring match. The old gate matched two-word substrings against the
whole raw payload. That produced both failure directions at once, and both were measured:

  * False positives. A benign call whose `description` merely mentioned the verb was denied,
    and -- because the old code consumed the marker before comparing -- the denial destroyed
    an expensively-earned review marker. That is why the repository could not document its
    own gate from a shell.
  * False negatives. `git -C <dir> commit`, `git -c k=v commit`, `git -C <dir> push` and
    `gh api .../pulls/N/merge` each perform the guarded action without containing either
    substring. All four were measured passing the gate against matched controls that were
    correctly denied.

The fix is to ask the question the gate actually means: does this command line invoke git
with the guarded verb? That is a shell-parsing question, so it gets a parser. Splitting on
shell operators is what stops prose from matching -- in `echo "the git commit gate"` the
leading word of the only segment is `echo`, so no segment invokes git.
"""

import json
import re
import sys

# git's own global options. Those taking a separate argument must consume it, or the verb
# scan would mistake the argument for the subcommand.
GLOBAL_WITH_ARG = {'-c', '-C', '--exec-path', '--git-dir', '--work-tree', '--namespace',
                   '--config-env', '--super-prefix'}
GLOBAL_FLAGS = {'--no-pager', '--paginate', '-p', '--bare', '--no-replace-objects',
                '--literal-pathspecs', '--no-optional-locks', '--glob-pathspecs',
                '--noglob-pathspecs', '--icase-pathspecs', '--html-path', '--man-path',
                '--info-path', '--no-lazy-fetch'}

# Wrappers that may precede the real executable without changing what it does.
WRAPPERS = {'env', 'sudo', 'doas', 'command', 'nohup', 'time', 'nice', 'ionice', 'stdbuf',
            'setsid', 'eval', 'exec'}

# Launchers whose syntax explicitly identifies another command line. These are intentionally
# narrow: scanning every argument of npm/make/etc. turns test names and other data into fake
# invocations. Each supported launcher is decoded according to its own command-bearing option.
SHELL_LAUNCHERS = {'bash', 'sh', 'dash', 'zsh', 'ksh', 'fish', 'ash'}
POWERSHELL_LAUNCHERS = {'pwsh', 'powershell'}
XARGS_WITH_ARG = {'-a', '--arg-file', '-E', '--eof', '-I', '--replace', '-L',
                  '--max-lines', '-n', '--max-args', '-P', '--max-procs', '-s',
                  '--max-chars'}
SSH_WITH_ARG = {'-B', '-b', '-c', '-D', '-E', '-e', '-F', '-I', '-i', '-J', '-L',
                '-l', '-m', '-O', '-o', '-P', '-p', '-Q', '-R', '-S', '-W', '-w'}


def basename(tok):
    """Lowercased basename with any .exe suffix removed, quotes stripped."""
    tok = tok.strip('"\'')
    base = tok.replace('\\', '/').rsplit('/', 1)[-1].lower()
    return base[:-4] if base.endswith('.exe') else base


ASSIGNMENT = re.compile(r'^[A-Za-z_][A-Za-z0-9_]*=')
TOKEN = re.compile(r'''"(?:\\.|[^"])*"|'(?:\\.|[^'])*'|\S+''')
CD_PREFIX = re.compile(r'''^cd\s+(?:"([^"]+)"|'([^']+)')\s*&&\s*''')

# The one push the gate lets through without a marker. The WHOLE command must be
# `cd "<absolute path>" && git push <remote>` followed only by `refs/tags/<t>` or `tag <t>` words.
# The hook then checks that every named tag is on a commit already in refs/remotes/origin/main.
# It lives here rather than in a helper of its own, like _review-gate-merge.py, so that it adds no
# file which `mb upgrade` could leave out, as once happened to the lib.
#
# WHY a whole-command match on the raw string, not the parsed segments above (the approach
# _review-gate-merge.py documents at its top):
#   * The parser skips VAR= prefixes, wrappers and -c/-C options, and lifts $(...) out. Any of
#     these can change what the push sends while the refspecs look the same.
#   * A chained command can re-point a tag after this hook has checked it.
#
# WHY [ \t] and not \s: a newline separates commands, so `git push origin<newline>refs/tags/v1`
# is a branch push.
#
# The name classes leave out ':' (src:dst, delete), '+' (force), '*' (pattern), '$' and quotes.
#
# WHY exactly one cd, and an absolute one: the hook checks the repository it resolves from the
# cd, while the shell pushes from wherever its own cd lands. These are the ways found so far for
# the two to part, each with rows in tests/test-review-gate-tag-push.sh:
#   * No cd: the hook would use its own working directory, which can be another repository.
#   * Relative paths, or a second cd: these resolve against two different directories.
#   * A leading '-', '+' or '~': bash and pwsh read these as the previous directory, location
#     history or HOME, which the .ps1 hook would read as a literal folder (a draft that allowed
#     them let `cd "<A>" && cd "-"` through while the shell pushed from another repo, 2026-10-30).
#
# The cd path is otherwise an ALLOWLIST: printable ASCII except its own quote, '$', '`', '\',
# '[', ']', '*' and '?'.
#   * '$' and '`': bash and pwsh expand inside double quotes, so `cd "$(git tag -f v1 <sha>)"`
#     would re-point the tag after the check.
#   * '\': escapes a quote in bash, so the shell could end the string where this pattern does
#     not. Use C:/... paths.
#   * '[ ] * ?': pwsh's cd expands wildcards, while the hook resolves the path literally.
#   * Anything non-ASCII: pwsh also ends a string at the typographic quotes U+2018-U+201E
#     (measured 2026-10-26).
#
# Each hook adds platform checks the shape cannot express. The .ps1 hook refuses a path that is
# not fully qualified (a Windows /...) and enters the resolved root with -LiteralPath. The .sh
# hook refuses a C:/... path off Windows, where it is relative. The .sh hook needs neither of the
# others: it resolves the path with the same bash cd that runs a Bash-tool push.
# The .ps1 twin uses this exact pattern text, which tests/test-review-gate-tag-push.sh compares.
TAG_PUSH = re.compile(r'''cd[ \t]+(?:"(?:[A-Za-z]:)?/[\x20\x21\x23\x25-\x29\x2B-\x3E\x40-\x5A\x5E\x5F\x61-\x7E]*"|'(?:[A-Za-z]:)?/[\x20-\x23\x25\x26\x28\x29\x2B-\x3E\x40-\x5A\x5E\x5F\x61-\x7E]*')[ \t]*&&[ \t]*git[ \t]+push[ \t]+[A-Za-z0-9_][A-Za-z0-9._-]*((?:[ \t]+(?:refs/tags/|tag[ \t]+)[A-Za-z0-9_][A-Za-z0-9._/-]*)+)''')
TAG_PUSH_NAME = re.compile(r'''(?:refs/tags/|tag[ \t]+)([A-Za-z0-9_][A-Za-z0-9._/-]*)''')


def _extract_dollar_paren(text, start):
    """Return (body, closing-index) for a $(...) beginning just after `$(`."""
    depth = 1
    quote = None
    escaped = False
    i = start
    while i < len(text):
        ch = text[i]
        if escaped:
            escaped = False
        elif ch == '\\' and quote != "'":
            escaped = True
        elif quote:
            if ch == quote:
                quote = None
        elif ch in "'\"":
            quote = ch
        elif text.startswith('$(', i):
            depth += 1
            i += 1
        elif ch == ')':
            depth -= 1
            if depth == 0:
                return text[start:i], i
        i += 1
    return text[start:], len(text) - 1


def _extract_backtick(text, start):
    """Return (body, closing-index) for a backtick substitution."""
    escaped = False
    i = start
    while i < len(text):
        ch = text[i]
        if escaped:
            escaped = False
        elif ch == '\\':
            escaped = True
        elif ch == '`':
            return text[start:i], i
        i += 1
    return text[start:], len(text) - 1


def segments(cmd):
    """Split on real shell operators and include executable command substitutions."""
    result = []
    nested = []
    buf = []
    quote = None
    escaped = False
    i = 0

    def flush():
        segment = ''.join(buf).strip()
        if segment:
            result.append(segment)
        buf.clear()

    while i < len(cmd):
        ch = cmd[i]
        if escaped:
            buf.append(ch)
            escaped = False
            i += 1
            continue
        if ch == '\\' and quote != "'":
            buf.append(ch)
            escaped = True
            i += 1
            continue
        if quote == "'":
            buf.append(ch)
            if ch == "'":
                quote = None
            i += 1
            continue
        if ch == '"':
            buf.append(ch)
            quote = None if quote == '"' else '"'
            i += 1
            continue
        # Command substitution executes even inside double quotes, but is inert in single
        # quotes. Scan its body as a separate command without splitting the outer argument.
        if cmd.startswith('$(', i):
            body, end = _extract_dollar_paren(cmd, i + 2)
            nested.extend(segments(body))
            buf.append(' ')
            i = end + 1
            continue
        if ch == '`':
            body, end = _extract_backtick(cmd, i + 1)
            nested.extend(segments(body))
            buf.append(' ')
            i = end + 1
            continue
        if quote == '"':
            buf.append(ch)
            i += 1
            continue
        if cmd.startswith('&&', i) or cmd.startswith('||', i):
            flush()
            i += 2
            continue
        if ch in ';&|\n()':
            flush()
            i += 1
            continue
        if ch in "'\"":
            quote = ch
        buf.append(ch)
        i += 1
    flush()
    return result + nested


def tokens(segment):
    """Tokenize enough shell syntax to keep a quoted executable path intact."""
    return TOKEN.findall(segment)


def unquote_argument(value):
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"":
        return value[1:-1]
    return value


def leading_cd_paths(cmd):
    """Return the quoted leading cd chain, in shell application order."""
    paths = []
    rest = cmd
    while True:
        match = CD_PREFIX.match(rest)
        if not match:
            return paths
        paths.append(match.group(1) if match.group(1) is not None else match.group(2))
        rest = rest[match.end():]


def is_git(tok):
    # PRE-EXISTING HOLE, closed here. These two functions compared a case-SENSITIVE basename and
    # kept the .exe suffix, while basename() above folds case and strips it. So the uppercase and
    # .exe spellings of the executable classified NONE while the lowercase one classified the
    # guarded verb -- measured with matched controls on the working tree.
    #
    # It is genuinely pre-existing rather than introduced by this parser: review-reminders.sh's
    # raw-substring fallback matches lowercase literals too, so BOTH matchers had it, before and
    # after the rewrite. Windows and macOS default filesystems are case-insensitive, so an
    # uppercase spelling really does invoke the same executable there -- and this repo develops on
    # Windows. This is the class the branch fix/block-tier-case-sensitivity is named for.
    return basename(tok) == 'git'


def is_gh(tok):
    return basename(tok) == 'gh'


def leading_executable(tokens):
    """Drop assignments and wrappers, return (exe_token, remaining_tokens)."""
    i = 0
    while i < len(tokens):
        t = tokens[i]
        if ASSIGNMENT.match(t) or t.strip('"\'') in WRAPPERS:
            i += 1
            continue
        break
    if i >= len(tokens):
        return None, []
    return tokens[i], tokens[i + 1:]


def git_verb(rest):
    """First non-option token after git's global options, or None."""
    i = 0
    while i < len(rest):
        t = rest[i]
        if t in GLOBAL_WITH_ARG:
            i += 2
            continue
        if t.startswith('--') and '=' in t and t.split('=', 1)[0] in GLOBAL_WITH_ARG:
            i += 1
            continue
        if t in GLOBAL_FLAGS:
            i += 1
            continue
        if t.startswith('-'):
            # -C<dir> / -cfoo attached forms, and any other leading option: skip it.
            i += 1
            continue
        return t.strip('"\'')
    return None


def git_context_paths(rest):
    """Return git's -C path chain, or None for unsupported explicit work-tree context."""
    paths = []
    i = 0
    while i < len(rest):
        raw = rest[i]
        token = raw.strip('"\'')
        if token == '-C':
            if i + 1 >= len(rest):
                return None
            paths.append(rest[i + 1].strip('"\''))
            i += 2
            continue
        if token.startswith('-C') and len(token) > 2:
            paths.append(token[2:])
            i += 1
            continue
        option = token.split('=', 1)[0]
        if option in ('--git-dir', '--work-tree'):
            return None
        if token in GLOBAL_WITH_ARG:
            i += 2
            continue
        if token.startswith('--') and '=' in token and option in GLOBAL_WITH_ARG:
            i += 1
            continue
        if token in GLOBAL_FLAGS or token.startswith('-'):
            i += 1
            continue
        break
    return paths


def _verdict_from(tok, rest):
    """Verdict if `tok` is git/gh invoked with a guarded verb, else None."""
    if is_git(tok):
        verb = git_verb(rest)
        if verb == 'commit':
            return 'COMMIT'
        if verb == 'push':
            return 'PUSH'
    elif is_gh(tok):
        flat = ' '.join(t.strip('"\'') for t in rest)
        if re.match(r'^pr\s+merge(\s|$)', flat):
            return 'MERGE'
        if re.match(r'^api(\s|$)', flat) and re.search(r'/pulls/\d+/merge', flat):
            return 'MERGE'
    return None


def nested_commands(exe, rest):
    """Return only arguments that the launcher's syntax says are executable commands."""
    base = basename(exe)
    bare = [t.strip('"\'') for t in rest]
    if base in SHELL_LAUNCHERS:
        for i, option in enumerate(bare[:-1]):
            if option.startswith('-') and not option.startswith('--') and 'c' in option[1:]:
                return [unquote_argument(rest[i + 1])]
        return []
    if base in POWERSHELL_LAUNCHERS:
        for i, option in enumerate(bare):
            if option.lower() in ('-c', '-command') and i + 1 < len(rest):
                return [unquote_argument(' '.join(rest[i + 1:]))]
        return []
    if base == 'cmd':
        for i, option in enumerate(bare):
            if option.lower() in ('/c', '/k') and i + 1 < len(rest):
                return [unquote_argument(' '.join(rest[i + 1:]))]
        return []
    if base == 'ssh':
        i = 0
        while i < len(rest):
            option = bare[i]
            if option == '--':
                i += 1
                break
            if not option.startswith('-'):
                break
            i += 2 if option in SSH_WITH_ARG and i + 1 < len(rest) else 1
        # First positional is the host; only what follows is the remote command.
        if i + 1 < len(rest):
            return [unquote_argument(' '.join(rest[i + 1:]))]
        return []
    if base == 'xargs':
        i = 0
        while i < len(rest):
            option = bare[i]
            if option == '--':
                i += 1
                break
            if not option.startswith('-'):
                break
            name = option.split('=', 1)[0]
            i += 2 if name in XARGS_WITH_ARG and '=' not in option and i + 1 < len(rest) else 1
        if i < len(rest):
            return [unquote_argument(' '.join(rest[i:]))]
        return []
    if base == 'busybox' and rest and basename(rest[0]) in SHELL_LAUNCHERS:
        return [unquote_argument(' '.join(rest))]
    return []


def _guarded_invocations(cmd, inherited_paths=None, depth=0):
    """Collect every guarded invocation so one marker cannot authorize a command chain."""
    if depth > 8:
        return []
    prefix_paths = list(inherited_paths or []) + leading_cd_paths(cmd)
    matches = []
    for seg in segments(cmd):
        direct_tokens = tokens(seg)
        exe, rest = leading_executable(direct_tokens)
        if exe is None:
            continue
        v = _verdict_from(exe, rest)
        if v:
            context = git_context_paths(rest) if is_git(exe) else []
            matches.append((v, prefix_paths + (context or []), context is None))
            continue
        for nested in nested_commands(exe, rest):
            matches.extend(_guarded_invocations(nested, prefix_paths, depth + 1))
    return matches


def classify_details(cmd):
    matches = _guarded_invocations(cmd)
    if len(matches) > 1:
        return 'MULTI', [], False
    if matches:
        return matches[0]
    return 'NONE', [], False


def classify(cmd):
    return classify_details(cmd)[0]


def tag_push_names(cmd):
    """Tag names if `cmd` is exactly the tag-only push shape (TAG_PUSH), else []."""
    match = TAG_PUSH.fullmatch(cmd)
    if not match:
        return []
    return TAG_PUSH_NAME.findall(match.group(1))


def main():
    raw = sys.stdin.read()
    if not raw.strip():
        sys.exit(1)
    try:
        data = json.loads(raw)
    except Exception:
        sys.exit(1)
    if not isinstance(data, dict):
        sys.exit(1)
    ti = data.get('tool_input')
    if not isinstance(ti, dict):
        # A harness spelling this camelCase produced a silent ALLOW on every tier,
        # including BLOCK-tier recursive deletion. Read both spellings.
        ti = data.get('toolInput')
    if not isinstance(ti, dict):
        sys.exit(1)
    cmd = ti.get('command')
    if not isinstance(cmd, str) or not cmd.strip():
        # A payload with no command is not a commit. Distinguish this from an unparseable
        # payload: it is a definite NONE, not an unknown.
        sys.stdout.write('NONE')
        return
    if '--tag-push' in sys.argv:
        # WHY a header line: a classifier from before --tag-push ignores the flag and prints its
        # verdict, PUSH, which the hook would otherwise read as a tag name. The hook takes the tag
        # route only when the first line is exactly this header.
        names = tag_push_names(cmd)
        if names:
            sys.stdout.write('\n'.join(['TAG-PUSH'] + names))
        return
    verdict, context_paths, unsupported = classify_details(cmd)
    if '--git-context' in sys.argv:
        if unsupported:
            sys.stdout.write('__UNSUPPORTED_GIT_CONTEXT__')
        else:
            sys.stdout.write('\n'.join(context_paths))
    else:
        sys.stdout.write(verdict)


if __name__ == '__main__':
    main()
