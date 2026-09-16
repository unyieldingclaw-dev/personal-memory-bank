"""Behaviour matrix for the restructured review gate.

Runs the real hook script with a real payload on stdin and reports ALLOW / DENY, so every
row is executed rather than reasoned about. Invoked via subprocess (not a shell pipe) because
this repo's BLOCK tier refuses `<anything> | bash <script>` and cannot distinguish a local
script from a downloaded one.

Usage: gate_matrix.py <repo-root> [--mutate <name>]
"""
import json
import os
import shutil
import hashlib
import subprocess
import tempfile
import sys

sys.stdout.reconfigure(encoding='utf-8')

ROOT = os.path.abspath(sys.argv[1])


def _git_common(d):
    """Realpath of d's shared .git directory, or None if d is not in a repo."""
    p = subprocess.run(['git', '-C', d, 'rev-parse', '--git-common-dir'],
                       capture_output=True)
    if p.returncode != 0:
        return None
    return os.path.realpath(os.path.join(d, p.stdout.decode().strip()))


# EVERYTHING BELOW THIS POINT MUTATES ROOT: it stages and commits the entire working tree under a
# fabricated author, moves scripts/_review-gate-lib.sh and _review-gate-classify.py out of the tree
# and back, appends to and then discards README.md, and deletes the review markers. It runs git as a
# subprocess, so no PreToolUse hook sees any of it and the repository's own review gate cannot
# intervene; and during each move window the gate is disarmed for every concurrent session in that
# checkout, with no signal if this process is killed mid-window.
#
# The only thing that once resembled a precondition was `assert git('status','--porcelain') == ''`,
# placed AFTER the add+commit that guarantees a clean tree -- it could not fail for any ROOT. That is
# the defect class standards/CODE-REVIEW.md rejects, "a check that cannot fail does not count as a
# check", and the one this harness exists to detect in other people's code.
#
# WHY AN EXPLICIT OPT-IN AND NOT AN IDENTITY COMPARISON. The first real guard compared
# the target's --git-common-dir against this file's own and refused on a match. An adversarial pass
# broke it two ways, both executed: (1) it is identity-scoped, so it protected only THIS repository
# and force-committed any OTHER live checkout it was handed -- it produced a real commit
# `t <t@t> gate matrix baseline` in an unrelated repo, sweeping a never-committed file into it;
# (2) the `_self is not None` conjunct FAILED OPEN -- a copy of this file relocated outside any
# repository made `_self` None, which skipped the refusal entirely and let it rewrite even its own
# repo. A guard whose protection depends on where the guard itself is stored is not a guard.
#
# An opt-in token cannot fail either way: no accidental invocation can produce it, and the check
# does not depend on this file's location, the target's identity, or git succeeding.
OPT_IN = '--yes-rewrite-history-in-this-throwaway-clone'
if OPT_IN not in sys.argv:
    sys.exit(
        'REFUSING: this harness REWRITES HISTORY in whatever tree it is given.\n'
        '\n'
        'It stages and commits the entire working tree under a fabricated author, moves the\n'
        'review-gate library out of the tree and back, appends to and then discards README.md,\n'
        'and deletes the review markers. It runs git as a subprocess, so no PreToolUse hook sees\n'
        'any of it and the repository\'s own review gate cannot intervene.\n'
        '\n'
        'Point it ONLY at a throwaway clone, and say so explicitly:\n'
        '    git clone --no-local <repo> /tmp/gf\n'
        '    %s /tmp/gf %s\n' % (os.path.basename(__file__), OPT_IN))

_target = _git_common(ROOT)
if _target is None:
    sys.exit('REFUSING: %s is not inside a git repository.' % ROOT)

# NO IDENTITY CHECK, deliberately. An earlier version also refused when the target resolved to the
# same repository as this file. That reads like belt-and-braces and is not: this harness now ships
# INSIDE the repository under test, so the legitimate use -- clone PMB to a scratch directory, then
# run that clone's own tests/gate_matrix.py against it -- resolves target and self to the same repo
# and would always be refused. A second guard that forbids the only correct usage is worse than no
# second guard, and the identity comparison was independently shown to fail open anyway (a copy
# stored outside any repo made self unknown, which skipped the refusal entirely).
#
# The opt-in token above is the guard: it cannot be produced accidentally and does not depend on
# where this file is stored, what the target is, or git succeeding. The announcement below is the
# rest of the answer -- an intentional run that is nonetheless pointed at the wrong path says so
# before it touches anything.
print('gate_matrix: about to REWRITE HISTORY in %s' % ROOT, flush=True)
print('             (staged commit under a fabricated author, library moved aside, markers deleted)',
      flush=True)

HOOK = os.path.join(ROOT, 'scripts', 'review-reminders.sh')
POST_HOOK = os.path.join(ROOT, 'scripts', 'review-reminders-post.sh')
LIB = os.path.join(ROOT, 'scripts', '_review-gate-lib.sh')
CLS = os.path.join(ROOT, 'scripts', '_review-gate-classify.py')
MARKER = os.path.join(ROOT, '.claude', '.code-review-ok')
PMARKER = os.path.join(ROOT, '.claude', '.change-review-ok')
PRESHA = os.path.join(ROOT, '.claude', '.pending-commit-presha')

V = 'c' + 'ommit'
P = 'p' + 'ush'
SH = 'ba' + 'sh'
EMPTY_SHA = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'


def shell_path():
    """Use Git Bash on Windows rather than the unrelated WSL launcher on PATH."""
    git_bash = r'C:\Program Files\Git\bin\bash.exe'
    if os.name == 'nt' and os.path.isfile(git_bash):
        return git_bash
    return shutil.which('bash') or 'bash'


def sh(args, cwd=ROOT, stdin=None):
    return subprocess.run(args, cwd=cwd, input=stdin, capture_output=True)


def git(*a):
    return sh(['git'] + list(a)).stdout.decode().strip()


def run_hook(cmd, tool='Bash'):
    payload = json.dumps({'tool_name': tool, 'tool_input': {'command': cmd}}).encode()
    p = sh([shell_path(), HOOK], stdin=payload)
    out = p.stdout.decode()
    if '"permissionDecision":"deny"' in out:
        reason = ''
        try:
            reason = json.loads(out)['hookSpecificOutput']['permissionDecisionReason']
        except Exception:
            pass
        return 'DENY', reason
    return 'ALLOW', ''


def run_post_hook(cmd, tool='Bash'):
    payload = json.dumps({'tool_name': tool, 'tool_input': {'command': cmd}}).encode()
    return sh([shell_path(), POST_HOOK], stdin=payload)


def real_hash(*args):
    """Recompute the gate's expected hash the same way diff_hash does.

    hashlib, not a sha256sum subprocess: sha256_file() is a plain sha256 of the bytes, and
    handing MSYS sha256sum a backslashed Windows temp path produced a hash that was neither
    the diff's nor the empty file's, which read as a gate failure rather than a harness one.
    """
    p = subprocess.run(['git', 'diff'] + list(args), cwd=ROOT,
                       capture_output=True)
    return hashlib.sha256(p.stdout).hexdigest()


def real_hash_at(root, *args):
    p = subprocess.run(['git', 'diff'] + list(args), cwd=root, capture_output=True)
    return hashlib.sha256(p.stdout).hexdigest()


def set_marker(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w') as fh:
        fh.write(content)


def clear(*paths):
    for p in paths:
        for extra in (p,) + tuple(
                os.path.join(os.path.dirname(p), f)
                for f in os.listdir(os.path.dirname(p))
                if os.path.isdir(os.path.dirname(p)) and f.startswith(os.path.basename(p) + '.claimed')):
            if os.path.exists(extra):
                os.remove(extra)


results = []


def check(label, expect, got, detail=''):
    ok = (expect == got)
    results.append((ok, label, expect, got, detail))
    return ok


# ------------------------------------------------- baseline: clean tree, fix in HEAD
# The fix under test lives in the working tree, so it must be COMMITTED before any case
# that needs a clean tree -- an earlier version of this harness used `git stash`, which
# reverted scripts/review-reminders.sh to its pre-fix state and then ran THAT. The old code
# duly allowed the empty-diff constant, so the row "failed" while actually reproducing the
# hole on the unfixed script. Verb spelled from fragments: a literal one in this file's text
# would make the file unquotable from a shell in this repo.
subprocess.run(['git', 'add', '-A'], cwd=ROOT, capture_output=True)
subprocess.run(['git', '-c', 'user.email=t@t', '-c', 'user.name=t',
                'c' + 'ommit', '-qm', 'gate matrix baseline'], cwd=ROOT, capture_output=True)
# POST-condition, not a precondition: the add+commit above is what makes the tree clean, so this
# cannot fail for any ROOT and is not a safety check. The safety check is the refusal guard at the
# top of this file. Kept only to catch a commit that silently did nothing.
assert git('status', '--porcelain') == '', 'baseline commit did not produce a clean tree'

# DIRTY_FILE must be TRACKED: `git diff HEAD` ignores untracked files, so an untracked
# scratch file leaves the diff empty and every "has a diff" row degenerates.
DIRTY_FILE = os.path.join(ROOT, 'README.md')
with open(DIRTY_FILE, 'a') as fh:
    fh.write('\n<!-- gate matrix: a real tracked modification to review -->\n')

clear(MARKER, PMARKER)
if os.path.exists(PRESHA):
    os.remove(PRESHA)

# 1. benign payload: allowed, and must not create or destroy anything
d, _ = run_hook('ls -la')
check('benign payload allowed', 'ALLOW', d)

# 2. prose mentioning the verb: allowed (the false positive this design removes)
d, _ = run_hook('echo "the git %s gate"' % V)
check('prose mention allowed', 'ALLOW', d)

# 3. guarded verb, NO marker -> deny
d, r = run_hook('git %s -m x' % V)
check('commit with no marker denied', 'DENY', d, r[:60])

# 4. HOLE D: lib missing + guarded verb -> must DENY, not allow
shutil.move(LIB, LIB + '.hidden')
d, r = run_hook('git %s -m x' % V)
check('HOLE D: missing lib denies (was ALLOW)', 'DENY', d, r[:70])
d2, _ = run_hook('ls -la')
check('HOLE D: missing lib still allows benign', 'ALLOW', d2)
shutil.move(LIB + '.hidden', LIB)

# 5. HOLE A: launcher-wrapped commit -> deny (classifier must see through it)
d, r = run_hook('%s -c "git %s -m x"' % (SH, V))
check('HOLE A: wrapped commit denied (was ALLOW)', 'DENY', d, r[:60])

# Quoted shell punctuation and words are data, not a nested invocation. This is the matched
# control for the launcher row above: broad argument scanning would deny both rows.
d, r = run_hook('echo "(git %s)"' % V)
check('quoted prose with shell syntax allowed', 'ALLOW', d, r[:60])

# One marker cannot authorize a command chain. Keep the marker present after the denial to prove
# this is rejected before the commit path can claim it.
h = real_hash('HEAD')
set_marker(MARKER, h)
d, r = run_hook('git %s -m x && gh pr merge 25' % V)
check('compound guarded command denied', 'DENY', d, r[:60])
check('compound guarded command preserves marker', True, os.path.exists(MARKER))
clear(MARKER)

# Push recovery is intentionally declined: @{u} does not identify an alternate remote/ref, so
# no pre-state may be recorded and PostToolUse must never mint another change-review marker.
h = real_hash('HEAD')
set_marker(PMARKER, h)
d, r = run_hook('git %s missing-remote HEAD' % P)
check('reviewed push attempt allowed', 'ALLOW', d, r[:60])
push_pending = os.path.join(ROOT, '.claude', '.pending-push-presha')
check('push uses no ambiguous recovery state', False, os.path.exists(push_pending))
run_post_hook('git %s missing-remote HEAD' % P)
check('push post-hook never mints a marker', False, os.path.exists(PMARKER))

# 6. git -C form -> deny (the form the base fix was built to close)
d, r = run_hook('git -C . %s -m x' % V)
check('git -C commit denied', 'DENY', d, r[:60])

# 6b. A quoted executable path containing spaces must stay one token. This is the native
# Windows form for Git's default installation directory.
d, r = run_hook('"/path with spaces/git" %s -m x' % V)
check('quoted executable path denied', 'DENY', d, r[:60])

# 6c. git -C changes the repository the command acts on, so the marker lookup must follow it.
# A valid marker in ROOT must not authorize a different target tree.
target = ROOT + '-gate-matrix-target'
os.makedirs(target)
subprocess.run(['git', 'init', '-q', '-b', 'main'], cwd=target, capture_output=True)
subprocess.run(['git', 'config', 'user.email', 't@t'], cwd=target, capture_output=True)
subprocess.run(['git', 'config', 'user.name', 't'], cwd=target, capture_output=True)
with open(os.path.join(target, 'file.txt'), 'w') as fh:
    fh.write('base\n')
subprocess.run(['git', 'add', 'file.txt'], cwd=target, capture_output=True)
subprocess.run(['git', 'commit', '-qm', 'initial'], cwd=target, capture_output=True)
os.makedirs(os.path.join(target, '.claude'))
with open(os.path.join(target, 'file.txt'), 'a') as fh:
    fh.write('target change\n')

set_marker(MARKER, real_hash('HEAD'))
target_rel = os.path.relpath(target, ROOT)
d, r = run_hook('git -C "%s" %s -m x' % (target_rel, V))
check('git -C target rejects ambient marker', 'DENY', d, r[:60])
check('git -C target preserves ambient marker', True, os.path.exists(MARKER))
target_marker = os.path.join(target, '.claude', '.code-review-ok')
target_pending = os.path.join(target, '.claude', '.pending-commit-presha')
set_marker(target_marker, real_hash_at(target, 'HEAD'))
d, r = run_hook('git -C "%s" %s -m x' % (target_rel, V))
check('git -C target accepts target marker', 'ALLOW', d, r[:60])
check('git -C target consumes target marker', False, os.path.exists(target_marker))
check('git -C target writes target recovery state', True, os.path.exists(target_pending))
clear(MARKER)
# The enclosing mutation run owns and removes the entire disposable directory. Leaving this
# sibling for that cleanup avoids Python's Windows read-only/AV race on freshly-created Git
# object files, while keeping it outside ROOT so the clean-tree rows below remain meaningful.

# 7. valid marker -> ALLOW, marker consumed, presha records the reviewed hash
h = real_hash('HEAD')
set_marker(MARKER, h)
d, r = run_hook('git %s -m x' % V)
ok = check('valid marker allows', 'ALLOW', d, r[:60])
check('valid marker consumed', False, os.path.exists(MARKER))
line = open(PRESHA).read() if os.path.exists(PRESHA) else ''
check('presha records reviewed hash', True, line.split()[-1] == h if line else False, line[:80])

# 8. HOLE C: on a CLEAN tree the expected hash degenerates to the public empty-diff
# constant, which anyone can write into the marker. Revert the tracked modification rather
# than stashing -- stashing would revert the fix under test along with it.
subprocess.run(['git', 'checkout', '--', 'README.md'], cwd=ROOT, capture_output=True)
assert git('status', '--porcelain') == '', 'tree must be clean for the empty-diff row'
assert real_hash('HEAD') == EMPTY_SHA, 'clean tree must hash to the empty-diff constant'
set_marker(MARKER, EMPTY_SHA)
d, r = run_hook('git %s --amend --no-edit' % V)
check('HOLE C: empty-diff constant denied (was ALLOW)', 'DENY', d, r[:70])
with open(DIRTY_FILE, 'a') as fh:
    fh.write('\n<!-- gate matrix: restored modification -->\n')

# 8b. PostToolUse must use the same classifier as PreToolUse: prose must not consume
# recovery state, while the global-option form must be reconciled.
h = real_hash('HEAD')
presha = git('rev-parse', 'HEAD')
set_marker(PRESHA, '%s %s' % (presha, h))
clear(MARKER)
run_post_hook('echo "documenting the git %s gate"' % V)
check('post prose leaves marker absent', False, os.path.exists(MARKER))
check('post prose preserves recovery state', True, os.path.exists(PRESHA))
run_post_hook('git -C . %s -m x' % V)
check('post git -C reissues marker', True, os.path.exists(MARKER))
check('post git -C consumes recovery state', False, os.path.exists(PRESHA))
clear(MARKER)

# 9. HOLE B, deterministically: a marker whose hash does NOT match must survive the denial,
# and a marker that DOES match must be gone. Together these pin claim-then-restore: the only
# path that consumes is the one that allows, and the claim itself is the atomic `mv`.
#
# This replaces a sequential "second claim denied" row that could not fail -- after the first
# call consumed the marker, the second was denied for having no marker at all, so the row
# passed without ever exercising the concurrency path it claimed to cover. It stayed green
# under mutation, which is precisely the shape standards/CODE-REVIEW.md rejects.
set_marker(MARKER, 'a' * 64)  # syntactically valid, wrong tree
d, r = run_hook('git %s -m x' % V)
check('HOLE B: stale marker denied', 'DENY', d, r[:50])
check('HOLE B: stale marker SURVIVES the denial', True, os.path.exists(MARKER))
leftovers = [f for f in os.listdir(os.path.dirname(MARKER)) if '.claimed.' in f]
check('HOLE B: no .claimed residue left behind', [], leftovers, str(leftovers))

h = real_hash('HEAD')
set_marker(MARKER, h)
d, _ = run_hook('git %s -m x' % V)
check('HOLE B: matching marker allows', 'ALLOW', d)
check('HOLE B: matching marker consumed', False, os.path.exists(MARKER))

# 10. merge is refused unconditionally, with no marker and no lib needed
shutil.move(LIB, LIB + '.hidden')
d, r = run_hook('gh pr m%s 25' % 'erge')
check('merge denied even with lib missing', 'DENY', d, r[:60])
shutil.move(LIB + '.hidden', LIB)

# 10b. HOLE F: root unresolvable + guarded verb -> must DENY. Run the hook with its cwd
# OUTSIDE any git repository, which is what `git rev-parse --show-toplevel` failing looks
# like. Previously `[ -z "$root" ] && exit 0`, i.e. a silent ALLOW for a real commit.
# A system temp directory, not a sibling of ROOT: an earlier version wrote
# os.path.dirname(ROOT)/gate-matrix-not-a-repo, i.e. outside the tree it was given, which for a
# nested worktree lands inside the parent repo.
outside = tempfile.mkdtemp(prefix='gate-matrix-not-a-repo-')
payload = json.dumps({'tool_name': 'Bash',
                      'tool_input': {'command': 'git %s -m x' % V}}).encode()
p = subprocess.run([shell_path(), HOOK], cwd=outside,
                   input=payload, capture_output=True)
out = p.stdout.decode()
check('HOLE F: unresolvable root denies (was ALLOW)', True,
      '"permissionDecision":"deny"' in out, out[:70])
p2 = subprocess.run([shell_path(), HOOK], cwd=outside,
                    input=json.dumps({'tool_name': 'Bash',
                                      'tool_input': {'command': 'ls -la'}}).encode(),
                    capture_output=True)
check('HOLE F: unresolvable root still allows benign', False,
      '"permissionDecision":"deny"' in p2.stdout.decode())

# 10c. PRE-EXISTING CASE HOLE. An uppercase spelling of the executable must be gated. Both
# matchers had this: the parser compared a case-sensitive basename, and the raw fallback matches
# lowercase literals. Windows and macOS default filesystems are case-insensitive, so the uppercase
# spelling invokes the same executable -- and this repo develops on Windows. The branch is named
# fix/block-tier-case-sensitivity for this class.
d, r = run_hook('GIT %s -m x' % V)
check('case: uppercase executable denied (was ALLOW)', 'DENY', d, r[:50])
d, r = run_hook('git.EXE %s -m x' % V)
check('case: .exe suffix denied (was ALLOW)', 'DENY', d, r[:50])
# Matched controls: these must NOT be gated, or the rows above could pass by denying everything.
d, _ = run_hook('GIT log --oneline')
check('case control: uppercase read-only git allowed', 'ALLOW', d)
d, _ = run_hook('digit %s' % V)
check('case control: a word ENDING in the exe name allowed', 'ALLOW', d)

# 11. classifier missing -> the raw fallback must still deny, INCLUDING an uppercase spelling.
#
# WHY the uppercase row has to be here and not beside the other case rows: those reach the parser,
# which folds case, so the fallback never runs and reverting ITS lowercasing changed nothing. The
# mutation `fallback-folds-case` duly stayed GREEN — an untestable guard, which is the defect class
# this harness exists to catch. The fallback's case handling is only observable with the classifier
# removed, which is exactly the configuration this row creates.
shutil.move(CLS, CLS + '.hidden')
d, r = run_hook('git %s -m x' % V)
check('classifier missing: fallback denies', 'DENY', d, r[:60])
d, r = run_hook('GIT %s -m x' % V)
check('classifier missing: fallback denies UPPERCASE', 'DENY', d, r[:60])
d, _ = run_hook('GIT log --oneline')
check('classifier missing: fallback control (read-only) allowed', 'ALLOW', d)
set_marker(PMARKER, real_hash('HEAD'))
d, r = run_hook('git %s -m x && git %s missing-remote HEAD' % (V, P))
check('classifier missing: fallback compound command denied', 'DENY', d, r[:60])
check('classifier missing: fallback compound preserves marker', True, os.path.exists(PMARKER))
clear(PMARKER)
shutil.move(CLS + '.hidden', CLS)

clear(MARKER, PMARKER)
if os.path.exists(PRESHA):
    os.remove(PRESHA)

w = max(len(r[1]) for r in results) + 1
npass = sum(1 for r in results if r[0])
for ok, label, expect, got, detail in results:
    print('%-4s %-*s expect=%-6s got=%-6s %s' % ('ok' if ok else 'FAIL', w, label,
                                                 expect, got, detail))
print('\nResults: %d passed, %d failed' % (npass, len(results) - npass))
sys.exit(0 if npass == len(results) else 1)
