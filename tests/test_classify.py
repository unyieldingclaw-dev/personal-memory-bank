"""Standalone discrimination test for classify.py.

Every expected-DENY row is paired with a matched control that must NOT deny, so a matcher
that simply denies everything cannot pass.
"""
import json
import subprocess
import sys
import os

HERE = os.path.dirname(os.path.abspath(__file__))
# The classifier's committed filename is _review-gate-classify.py. This pointed at 'classify.py',
# which does not exist beside it, so subprocess returned non-zero for every payload and 31 of 32
# rows failed -- while the one expecting UNPARSEABLE 'passed' because the subject was missing, not
# because anything was classified. An override is still accepted for testing a candidate copy.
CLS = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
    os.path.dirname(HERE), 'scripts', '_review-gate-classify.py')
if not os.path.exists(CLS):
    sys.exit('classifier not found: %s' % CLS)

C = 'commit'
P = 'push'
G = 'gh'


def run(payload):
    p = subprocess.run([sys.executable, CLS], input=json.dumps(payload).encode(),
                       capture_output=True)
    if p.returncode != 0:
        return 'UNPARSEABLE'
    return p.stdout.decode().strip()


def cmd(c, **kw):
    d = {'tool_name': 'Bash', 'tool_input': {'command': c}}
    d['tool_input'].update(kw)
    return d


CASES = [
    # --- must classify COMMIT (the four forms that used to slip through, plus controls) ---
    ('COMMIT', cmd('git %s -m x' % C), 'canonical'),
    ('COMMIT', cmd('git -C . %s -m x' % C), 'REGRESSION: -C was allowed'),
    ('COMMIT', cmd('git -C/tmp/x %s -m y' % C), 'attached -C form'),
    ('COMMIT', cmd('git -c user.name=x %s -m x' % C), 'REGRESSION: -c was allowed'),
    ('COMMIT', cmd('git --git-dir=/tmp/g --work-tree=/tmp/w %s -m x' % C), 'global opts'),
    ('COMMIT', cmd('cd /tmp && git %s -m x' % C), 'after &&'),
    ('COMMIT', cmd('VAR=1 git %s -m x' % C), 'assignment prefix'),
    ('COMMIT', cmd('env git %s -m x' % C), 'wrapper'),
    ('COMMIT', cmd('/usr/bin/git %s -m x' % C), 'absolute path'),
    ('COMMIT', cmd('"C:\\Program Files\\Git\\cmd\\git.exe" %s -m x' % C),
     'quoted Windows executable path'),
    ('COMMIT', cmd('echo hi; git %s -m x' % C), 'after semicolon'),
    ('COMMIT', cmd('git --no-pager %s -m x' % C), 'flag then verb'),

    # --- multiple guarded actions must never borrow one marker for the whole chain ---
    ('MULTI', cmd('git %s -m x && gh pr merge 25' % C), 'commit then unconditional merge'),
    ('MULTI', cmd('git %s -m x && git %s origin HEAD' % (C, P)),
     'commit then push needs two independent gates'),

    # --- must classify PUSH ---
    ('PUSH', cmd('git %s origin HEAD' % P), 'canonical'),
    ('PUSH', cmd('git -C . %s origin HEAD' % P), 'REGRESSION: -C was allowed'),
    ('PUSH', cmd('git %s --force origin main' % P), 'force push still gated'),

    # --- must classify MERGE ---
    ('MERGE', cmd('%s pr merge 1' % G), 'canonical'),
    ('MERGE', cmd('%s pr merge 12 --squash' % G), 'with flag'),
    ('MERGE', cmd('%s api -X PUT repos/o/r/pulls/1/merge' % G),
     'REGRESSION: REST form was allowed'),

    # --- must classify NONE: the false-positive half, all previously DENIED ---
    ('NONE', cmd('echo hello', description='explains the git %s gate' % C),
     'REGRESSION: description-only used to deny AND burn the marker'),
    ('NONE', cmd('echo "documenting the git %s gate"' % C),
     'REGRESSION: prose in an echo used to deny'),
    ('NONE', cmd('echo "(git %s)"' % C), 'operators inside quoted prose are not shell syntax'),
    ('NONE', cmd('echo "docs; git %s"' % C), 'semicolon inside quoted prose is inert'),
    ('NONE', cmd('bash -c \'echo "git %s gate"\'' % C),
     'shell launcher executes echo, not git'),
    ('NONE', cmd('npm test -- --name "git %s behavior"' % C),
     'test name is data, not a nested command'),
    ('NONE', cmd('grep -n "git %s" scripts/review-reminders.sh' % C),
     'REGRESSION: grepping the hook source used to deny'),
    ('NONE', cmd('git log --oneline -5'), 'read-only git'),
    ('NONE', cmd('git status --short'), 'read-only git'),
    ('NONE', cmd('git diff HEAD'), 'read-only git'),
    ('NONE', cmd('git-%s --help' % C), 'hyphenated is a different program'),
    ('NONE', cmd('%s pr view 12' % G), 'gh but not a merge'),
    ('NONE', cmd('%s api repos/o/r/pulls/1' % G), 'gh api but not the merge endpoint'),
    ('NONE', cmd('echo hello'), 'plain'),
    ('NONE', cmd('git %s --dry-run' % C.replace(C, 'log')), 'log, not the verb'),
    ('NONE', {'tool_name': 'Bash', 'tool_input': {'command': ''}}, 'empty command'),
    ('NONE', {'tool_name': 'Bash', 'tool_input': {}}, 'no command key'),

    # --- camelCase harness: must still classify, not silently pass ---
    ('COMMIT', {'toolName': 'Bash', 'toolInput': {'command': 'git %s -m x' % C}},
     'REGRESSION: camelCase harness was a silent ALLOW on every tier'),

    # --- unparseable: caller must fall back, NOT allow ---
    ('UNPARSEABLE', None, 'truncated JSON handled by the caller'),
]


def main():
    passed = failed = 0
    for expected, payload, note in CASES:
        if payload is None:
            p = subprocess.run([sys.executable, CLS],
                               input=b'{"tool_input":{"command":"git com',
                               capture_output=True)
            got = 'UNPARSEABLE' if p.returncode != 0 else p.stdout.decode().strip()
        else:
            got = run(payload)
        ok = got == expected
        if ok:
            passed += 1
        else:
            failed += 1
        flag = 'ok  ' if ok else 'FAIL'
        shown = '' if payload is None else payload.get(
            'tool_input', payload.get('toolInput', {})).get('command', '')
        print('%s %-12s got=%-12s %-58s %s' % (flag, expected, got, shown[:58], note))
    print('\nResults: %d passed, %d failed' % (passed, failed))
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
