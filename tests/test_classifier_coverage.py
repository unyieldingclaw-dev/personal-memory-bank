"""Adversarial matrix against the proposed shared classifier.

Every payload is built from fragments so this file never contains the guarded two-word
phrases literally -- writing them would make the file itself unquotable from a shell in
this repo, which is the very false-positive the classifier exists to remove.
"""
import json
import subprocess
import sys

sys.stdout.reconfigure(encoding='utf-8')

CLS = sys.argv[1]
G = 'git'
CM = G + ' ' + 'c' + 'ommit'
PU = G + ' ' + 'p' + 'ush'
PRM = 'gh' + ' pr ' + 'm' + 'erge'

# (label, command, expected verdict, why-it-matters)
CASES = [
    # --- controls: these MUST classify, or the fix is useless ---
    ('plain commit',            CM + ' -m x',                               'COMMIT', 'control'),
    ('plain push',              PU + ' origin main',                        'PUSH',   'control'),
    ('pr merge',                PRM + ' 25',                                'MERGE',  'control'),
    # --- the four forms the fix was BUILT to close ---
    ('git -C dir commit',       G + ' -C /tmp/x ' + CM.split()[1] + ' -m x','COMMIT', 'closed-by-fix'),
    ('git -c k=v commit',       G + ' -c user.name=a ' + CM.split()[1],     'COMMIT', 'closed-by-fix'),
    ('git -C dir push',         G + ' -C /tmp/x ' + PU.split()[1],          'PUSH',   'closed-by-fix'),
    ('gh api pulls merge',      'gh api repos/o/r/pulls/1/merge -X PUT',    'MERGE',  'closed-by-fix'),
    # --- the false positive the fix exists to remove ---
    ('prose mentions verb',     'echo "the ' + CM + ' gate denies this"',   'NONE',   'false-positive-fix'),
    ('grep for the phrase',     "grep -rn '" + CM + "' scripts/",           'NONE',   'false-positive-fix'),
    # --- ATTACK: interpreter wrappers. The OLD substring matcher caught all of these. ---
    ('bash -c commit',          'bash -c "' + CM + ' -m x"',                'COMMIT', 'ATTACK-wrapper'),
    ('sh -c commit',            "sh -c '" + CM + " -m x'",                  'COMMIT', 'ATTACK-wrapper'),
    ('bash -lc push',           'bash -lc "' + PU + '"',                    'PUSH',   'ATTACK-wrapper'),
    ('pwsh -c commit',          'pwsh -c "' + CM + '"',                     'COMMIT', 'ATTACK-wrapper'),
    ('xargs git commit',        'echo . | xargs ' + CM,                     'COMMIT', 'ATTACK-wrapper'),
    ('ssh remote commit',       'ssh host "' + CM + '"',                    'COMMIT', 'ATTACK-wrapper'),
    # --- ATTACK: separators the splitter may not treat as boundaries ---
    ('newline separated',       'cd /tmp\n' + CM,                           'COMMIT', 'ATTACK-separator'),
    ('tab between words',       G + '\t' + CM.split()[1] + ' -m x',         'COMMIT', 'ATTACK-separator'),
    ('leading assignment',      'GIT_DIR=/tmp/x ' + CM,                     'COMMIT', 'ATTACK-separator'),
    ('command wrapper',         'command ' + CM,                            'COMMIT', 'ATTACK-separator'),
    ('absolute path git',       '/usr/bin/' + CM,                           'COMMIT', 'ATTACK-separator'),
    ('git.exe',                 'git.exe ' + CM.split()[1],                 'COMMIT', 'ATTACK-separator'),
    # --- ATTACK: the empty-diff / alias shapes ---
    ('amend no-edit',           CM + ' --amend --no-edit',                  'COMMIT', 'ATTACK-amend'),
    ('allow-empty',             CM + ' --allow-empty -m x',                 'COMMIT', 'ATTACK-amend'),
    ('force push refspec',      PU + ' origin +main:main',                  'PUSH',   'ATTACK-refspec'),
    ('push --mirror',           PU + ' --mirror origin',                    'PUSH',   'ATTACK-refspec'),
]


def run(payload_obj):
    p = subprocess.run([sys.executable, CLS], input=json.dumps(payload_obj).encode(),
                       capture_output=True)
    return p.stdout.decode().strip(), p.returncode


def old_substring(raw):
    """The matcher the fallback reverts to -- what we are being compared against."""
    if CM in raw:
        return 'COMMIT'
    if PU in raw:
        return 'PUSH'
    if PRM in raw:
        return 'MERGE'
    return 'NONE'


rows = []
for label, cmd, expect, kind in CASES:
    obj = {'tool_name': 'Bash', 'tool_input': {'command': cmd}}
    raw = json.dumps(obj)
    got, rc = run(obj)
    old = old_substring(raw)
    # A regression is: the classifier says NONE (so the fallback never fires) on something
    # the old substring matcher WOULD have caught. That is a strict loss of coverage.
    regress = (got == 'NONE' and old != 'NONE')
    miss = (got != expect)
    rows.append((kind, label, expect, got, old, rc, miss, regress))

w = max(len(r[1]) for r in rows) + 1
print('%-20s %-*s %-7s %-7s %-7s %s' % ('KIND', w, 'CASE', 'EXPECT', 'NEW', 'OLD', 'VERDICT'))
print('-' * (44 + w + 24))
nmiss = nregress = 0
for kind, label, expect, got, old, rc, miss, regress in rows:
    flag = ''
    if regress:
        flag = 'REGRESSION vs old matcher'
        nregress += 1
    elif miss:
        flag = 'MISS'
    if miss:
        nmiss += 1
    print('%-20s %-*s %-7s %-7s %-7s %s' % (kind, w, label, expect, got or '(empty)', old, flag))
print()
print('cases=%d  misclassified=%d  strict-regressions-vs-substring-matcher=%d' %
      (len(rows), nmiss, nregress))

# EXIT CODE. Without this the script printed its misclassifications and exited 0, so a CI job or a
# reader running it saw success no matter how many rows were wrong -- a test that cannot fail. The
# two intended de-escalations (prose that merely mentions a guarded verb) are excluded from the
# failure count deliberately: they are the false positives the classifier exists to remove, and
# counting them as regressions is what made `nregress` misleading in the first place.
sys.exit(1 if nmiss else 0)

# Separate probe: does the tool_name reach the classifier at all?
print()
for tn in ('Bash', 'PowerShell', None):
    obj = {'tool_input': {'command': CM + ' -m x'}}
    if tn:
        obj['tool_name'] = tn
    got, rc = run(obj)
    print('  tool_name=%-12s -> %s' % (repr(tn), got))

# Probe: description-only mention (the marker-destroying false positive)
obj = {'tool_name': 'Bash', 'tool_input': {'command': 'ls'},
       'description': 'explain how the ' + CM + ' gate works'}
got, rc = run(obj)
print('  description-only mention -> %s   (old matcher: %s)' % (got, old_substring(json.dumps(obj))))
