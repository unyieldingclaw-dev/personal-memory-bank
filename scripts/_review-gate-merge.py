"""Decide whether a payload the classifier already labelled MERGE may be put to the user.

Called by review-reminders.sh only after the classifier returned MERGE. Prints exactly:

    ASK            or    DENY
    <reason>             <reason>
    <audit line>         (nothing)

and exits 0. The hook treats anything other than a first line of exactly ASK -- a crash, a
missing file, no python3 -- as deny, so every failure here fails closed. The specific cause of
a precondition deny goes to stderr only; see GENERIC_DENY for why.

Spec: docs/superpowers/specs/2026-10-20-merge-gate-user-approval-design.md (section 5). The
PowerShell twin is _review-gate-merge.ps1; the two must agree on every fixture in
tests/test-merge-gate.sh.

WHY a whole-command match on the raw string instead of reusing the classifier's segments: the
classifier answers "does this invoke a guarded verb", so it splits on ; & | and newlines,
lifts $(...) and backticks into nested segments, skips VAR= prefixes and wrapper words, and
accepts any path ending in gh. Any of those would let `<canonical merge>; <anything>` pass as
canonical while the prompt describes only the merge.

WHY no \\A / \\z: Python before 3.14 rejects \\z as a bad escape (measured on 3.11.9), and
re.fullmatch already anchors both ends without accepting a trailing newline, which $ would.
"""
import json
import os
import re
import sys

MODES = ('default', 'acceptEdits', 'auto')

# The only description the prompt may show. G0 (2026-10-20) measured that the app's prompt
# displays the agent-written description beside the command, so a free-form one could label a
# merge of #71 as "Merge PR #77 as you asked".
DESCRIPTION = 'Merge pull request (verify the details in the hook reason)'

# WHY generic: naming the settings file that holds a merge-capable allow rule would point the
# agent straight at the silent route this check exists to deny.
GENERIC_DENY = ("Merge gate precondition failed. Ask the user to check this checkout's "
                "Claude settings.")

REPO_SHAPE = re.compile(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', re.ASCII)

# Interpreters whose wildcard one-liner rules can run anything, including a merge.
INTERPRETERS = re.compile(
    r'(?:python3?|py|node|pwsh|powershell|bash|sh|cmd)(?:\.exe)?(?:\s.*)?'
    r'\s(?:-c|-e|--eval|-Command|-EncodedCommand|/c)\b',
    re.ASCII | re.IGNORECASE)


def deny(reason, cause=None):
    if cause:
        print('merge gate: ' + cause, file=sys.stderr)
    sys.stdout.write('DENY\n' + reason + '\n')
    sys.exit(0)


def merge_capable(rule):
    """True when an allow rule could carry a merge past the prompt."""
    m = re.fullmatch(r'(Bash|PowerShell)(?:\((.*)\))?', rule.strip(), re.DOTALL)
    if not m:
        return False
    body = m.group(2)
    if body is None:
        return True  # a bare tool name allows every command
    body = body.strip()
    if body in ('*', ':*'):
        return True
    if re.fullmatch(r'gh(?:\s*\*|:\*)?', body):
        return True
    if re.match(r'gh\s+(?:api\b|-)', body):
        return True
    if re.fullmatch(r'gh\s+pr(?:\s*\*|:\*)', body) or re.match(r'gh\s+pr\s+merge\b', body):
        return True
    return bool('*' in body and INTERPRETERS.match(body))


def settings_files(project):
    config = os.environ.get('CLAUDE_CONFIG_DIR') or os.path.join(os.path.expanduser('~'), '.claude')
    return [
        os.path.join(config, 'settings.json'),
        os.path.join(project, '.claude', 'settings.json'),
        os.path.join(project, '.claude', 'settings.local.json'),
    ]


def check_settings(project):
    for path in settings_files(project):
        if not os.path.exists(path):
            continue
        try:
            with open(path, encoding='utf-8-sig') as f:
                data = json.load(f)
        except Exception:
            deny(GENERIC_DENY, 'unreadable or malformed settings: ' + path)
        if not isinstance(data, dict):
            deny(GENERIC_DENY, 'settings is not a JSON object: ' + path)
        # Wrong-typed blocks deny: this check cannot vouch for a shape it does not understand.
        hooks = data.get('hooks')
        if hooks is not None:
            if not isinstance(hooks, dict):
                deny(GENERIC_DENY, 'hooks is not an object: ' + path)
            if hooks.get('PermissionRequest') not in (None, []):
                deny(GENERIC_DENY, 'PermissionRequest hook configured: ' + path)
        perms = data.get('permissions')
        allow = perms.get('allow') if isinstance(perms, dict) else None
        if allow is not None and not isinstance(allow, list):
            deny(GENERIC_DENY, 'permissions.allow is not a list: ' + path)
        for rule in allow or []:
            if rule is None:
                continue
            if not isinstance(rule, str) or merge_capable(rule):
                deny(GENERIC_DENY, 'merge-capable allow rule in: ' + path)


def allowed_repos(project):
    path = os.path.join(project, '.claude', 'merge-gate.json')
    try:
        with open(path, encoding='utf-8-sig') as f:
            repos = json.load(f)['repos']
    except Exception:
        deny('Merge gate is not configured: .claude/merge-gate.json is missing or malformed, '
             'so no repository is allowed. Merge in the GitHub UI instead.')
    if not isinstance(repos, list) or not repos or not all(
            isinstance(r, str) and REPO_SHAPE.fullmatch(r) for r in repos):
        deny('Merge gate is not configured: .claude/merge-gate.json must list "repos" as '
             'owner/repo strings. Merge in the GitHub UI instead.')
    return repos


def main():
    payload = json.loads(sys.stdin.read())
    if not isinstance(payload, dict):
        deny(GENERIC_DENY, 'payload is not a JSON object')
    # Presence, not truthiness: a subagent's payload carries agent_id whatever its value.
    if 'agent_id' in payload:
        deny('Subagents never merge pull requests. Ask the user, in the main conversation.')
    mode = payload.get('permission_mode')
    if not isinstance(mode, str) or mode not in MODES:
        deny('Merges are only put to the user in default, acceptEdits or auto mode; this '
             'session cannot show a prompt for it. Merge in the GitHub UI instead.')
    if 'GH_HOST' in os.environ or 'GH_REPO' in os.environ:
        deny(GENERIC_DENY, 'GH_HOST or GH_REPO is set in the hook environment')

    project = os.environ.get('CLAUDE_PROJECT_DIR') or os.getcwd()
    check_settings(project)
    repos = allowed_repos(project)

    tool_input = payload.get('tool_input')
    if not isinstance(tool_input, dict):
        deny(GENERIC_DENY, 'payload has no tool_input object')
    command = tool_input.get('command')
    repo_alt = '|'.join(re.escape(r) for r in repos)
    canonical = ('gh pr merge (?P<n>[1-9][0-9]{0,8}) -R (?P<repo>' + repo_alt + ') '
                 '(?P<method>--squash|--merge) --match-head-commit (?P<sha>[0-9a-f]{40})')
    m = re.fullmatch(canonical, command, re.ASCII) if isinstance(command, str) else None
    if not m:
        deny('This agent merges a pull request only in exactly this form, with nothing before '
             'or after it: gh pr merge <N> -R ' + repos[0] + ' --squash --match-head-commit '
             '<full 40-hex head SHA> (or --merge in place of --squash). Use the PR number and '
             'head SHA the user asked for.')
    if 'description' in tool_input and tool_input['description'] != DESCRIPTION:
        deny('Set the tool description to exactly "' + DESCRIPTION + '", or omit it. The '
             'prompt shows it, so it must not describe the merge in the agent\'s own words.')

    method = 'squash' if m.group('method') == '--squash' else 'merge commit'
    sys.stdout.write(
        'ASK\n'
        'Merge PR #{n} in {repo} by {method}, exactly at head {sha}. Approve only if YOU asked '
        'to merge this PR just now. This approval covers this one command.\n'
        '{mode}\t{repo}\t{n}\t{sha}\n'.format(n=m.group('n'), repo=m.group('repo'),
                                            method=method, sha=m.group('sha'), mode=mode))


if __name__ == '__main__':
    try:
        main()
    except SystemExit:
        raise
    except Exception as exc:  # any failure in the check is a deny, never no-decision
        deny(GENERIC_DENY, 'internal error: ' + type(exc).__name__)
