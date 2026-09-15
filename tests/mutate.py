"""Mutation proof for the review-gate fixes.

For each fix, remove exactly that fix and assert the matrix row which covers it flips to
FAIL. A guard whose removal leaves the suite green is not a guard -- this repo's
standards/CODE-REVIEW.md calls that "a check that cannot fail does not count as a check",
and the previous round of this work shipped two such: a push-gate comparison and a reissue
binding, both of which left the suite fully green when deleted.
"""
import io
import os
import shutil
import subprocess
import tempfile
import sys

sys.stdout.reconfigure(encoding='utf-8')

SRC = os.path.abspath(sys.argv[1])
HERE = os.path.dirname(os.path.abspath(__file__))
# A system temp directory, NOT a subdirectory of this file's own. WORK under HERE meant that when
# SRC contained HERE -- i.e. whenever this harness was run from inside the tree it was mutating --
# copytree recursed into its own earlier copies and crashed, and it wrote seven full repo copies
# into a tracked directory.
WORK = tempfile.mkdtemp(prefix='pmb-gate-mutate-')


def rd(p):
    return io.open(p, encoding='utf-8', newline='').read()


def wr(p, s):
    io.open(p, 'w', encoding='utf-8', newline='').write(s)


def sandbox_copy(destination):
    """Copy source files without inheriting a linked-worktree .git pointer."""
    shutil.copytree(SRC, destination, ignore=shutil.ignore_patterns('.git'))
    subprocess.run(['git', 'init', '-q', '-b', 'main'], cwd=destination, check=True)


# (name, file, find, replace, row that must flip to FAIL)
MUTATIONS = [
    ('classifier-preserves-quoted-exe', 'scripts/_review-gate-classify.py',
     '        direct_tokens = tokens(seg)',
     '        direct_tokens = seg.split()',
     'quoted executable path denied'),

    ('classifier-launcher-scan', 'scripts/_review-gate-classify.py',
     '        for nested in nested_commands(exe, rest):',
     '        for nested in []:',
     'HOLE A: wrapped commit denied (was ALLOW)'),

    ('classifier-quote-aware-segments', 'scripts/_review-gate-classify.py',
     "            quote = None if quote == '\"' else '\"'",
     '            quote = None',
     'quoted prose with shell syntax allowed'),

    ('compound-actions-denied', 'scripts/_review-gate-classify.py',
     '    if len(matches) > 1:',
     '    if False:',
     'compound guarded command denied'),

    ('push-recovery-declined', 'scripts/review-reminders.sh',
     '                rm -f "$root/.claude/.pending-push-presha"',
     '                printf \'%s\' "$expected" > "$root/.claude/.pending-push-presha"',
     'push uses no ambiguous recovery state'),

    ('lib-missing-fails-closed', 'scripts/review-reminders.sh',
     'if ! . "$(dirname "$0")/_review-gate-lib.sh" 2>/dev/null; then\n    deny "Review gate cannot run: scripts/_review-gate-lib.sh is missing or unreadable, so the marker check is unavailable. This is a broken installation, not a passed review -- restore the file (or run mb upgrade from the MAIN worktree) before committing or pushing."\n    exit 0\nfi',
     '. "$(dirname "$0")/_review-gate-lib.sh" 2>/dev/null || exit 0',
     'HOLE D: missing lib denies (was ALLOW)'),

    ('empty-diff-rejected', 'scripts/review-reminders.sh',
     'if [ -z "$expected" ] || [ "$expected" = "$EMPTY_DIFF_SHA" ]; then\n            deny "Review gate: there is no diff to review (git diff HEAD is empty, or git diff failed). The hash of an empty diff is a public constant, so it cannot serve as proof of review. If you are amending or committing an empty change, run the command yourself."\n        elif',
     'if [ -z "$expected" ]; then\n            deny "no diff"\n        elif',
     'HOLE C: empty-diff constant denied (was ALLOW)'),

    # Consume on the mismatch path instead of restoring -- i.e. the original burn-on-denial
    # behaviour. The stale-marker row must notice the marker is gone.
    ('mismatch-restores-marker', 'scripts/review-reminders.sh',
     '                release_marker "$marker"\n                deny "Run /code-review before committing',
     '                drop_marker "$marker"\n                deny "Run /code-review before committing',
     'HOLE B: stale marker SURVIVES the denial'),

    # Leave the claim in place instead of consuming it on the allow path -- a marker that
    # survives a successful commit is no longer single-use.
    ('success-consumes-marker', 'scripts/review-reminders.sh',
     '                drop_marker "$marker"\n                presha=$(git rev-parse HEAD 2>/dev/null)',
     '                release_marker "$marker"\n                presha=$(git rev-parse HEAD 2>/dev/null)',
     'HOLE B: matching marker consumed'),
    # Reopen the pre-existing case hole in the PARSER: make is_git() compare a case-sensitive,
    # .exe-retaining basename again, which is what it did before this branch.
    ('classifier-folds-case', 'scripts/_review-gate-classify.py',
     "    return basename(tok) == 'git'",
     "    return tok.rsplit('/', 1)[-1] in ('git', 'git.exe')",
     'case: uppercase executable denied (was ALLOW)'),

    # Reopen the OTHER half of the same hole -- the raw fallback's lowercasing. Built by string
    # concatenation so this file does not contain the guarded two-word phrase, which would make it
    # unquotable from a shell in this repo.
    ('fallback-folds-case', 'scripts/review-reminders.sh',
     'lower=$(printf ' + "'%s'" + ' "$input" | tr ' + "'[:upper:]' '[:lower:]'" + ')',
     'lower=$(printf ' + "'%s'" + ' "$input")',
     'classifier missing: fallback denies UPPERCASE'),

    ('fallback-compound-denied', 'scripts/review-reminders.sh',
     'if [ "$fallback_count" -gt 1 ]; then verdict=MULTI; else verdict=$fallback_verdict; fi',
     'if false; then verdict=MULTI; else verdict=$fallback_verdict; fi',
     'classifier missing: fallback compound preserves marker'),

    # Restore the silent allow when the repo root cannot be resolved.
    ('root-unresolvable-fails-closed', 'scripts/review-reminders.sh',
     'if [ -z "$root" ]; then\n    deny "Review gate cannot run: the repository root could not be resolved',
     'if [ -z "$root" ]; then\n    exit 0\nfi\nif false; then\n    deny "Review gate cannot run: the repository root could not be resolved',
     'HOLE F: unresolvable root denies (was ALLOW)'),

    ('git-c-root-bound', 'scripts/review-reminders.sh',
     '    if [ -n "$context" ]; then',
     '    if false; then',
     'git -C target rejects ambient marker'),

    ('post-uses-classifier', 'scripts/review-reminders-post.sh',
     'verdict=$(printf ' + "'%s'" + ' "$input" | python3 "$classifier" 2>/dev/null) || exit 0',
     'verdict=COMMIT',
     'post prose leaves marker absent'),
]


def run_matrix(root):
    # The opt-in token gate_matrix.py now requires. Passing it is safe here and only here:
    # every `root` this function is given is a copytree copy this process made under WORK, a
    # system temp directory -- never SRC, and never a checkout anyone is working in.
    p = subprocess.run([sys.executable, os.path.join(HERE, 'gate_matrix.py'), root,
                        '--yes-rewrite-history-in-this-throwaway-clone'],
                       capture_output=True)
    out = p.stdout.decode() + p.stderr.decode()
    failed = set()
    for line in out.splitlines():
        if line.startswith('FAIL'):
            # 'FAIL <label padded> expect=...'
            failed.add(line[5:].split('expect=')[0].strip())
    return failed, out, p.returncode


print('=== baseline (all fixes present) ===')
if os.path.isdir(WORK):
    shutil.rmtree(WORK, ignore_errors=True)
base = os.path.join(WORK, 'base')
sandbox_copy(base)
failed, out, rc = run_matrix(base)
print(out.strip().splitlines()[-1])
if rc != 0 or failed:
    print('BASELINE NOT GREEN -- mutation results would be meaningless. Failing rows:')
    for f in sorted(failed):
        print('   ', f)
    if not failed:
        print('    harness exited %d without a parsed FAIL row' % rc)
    sys.exit(1)

print()
rows = []
for name, relpath, find, repl, expect_row in MUTATIONS:
    d = os.path.join(WORK, name)
    sandbox_copy(d)
    p = os.path.join(d, relpath)
    s = rd(p)
    if find not in s:
        rows.append((name, 'ANCHOR-NOT-FOUND', False, ''))
        continue
    wr(p, s.replace(find, repl, 1))
    failed, out, rc = run_matrix(d)
    caught = expect_row in failed
    others = sorted(failed - {expect_row})
    if rc != 0 and not failed:
        others.append('HARNESS-ERROR: exited %d without a parsed FAIL row' % rc)
    rows.append((name, expect_row, caught, ', '.join(others)))

w = max(len(r[0]) for r in rows) + 1
allgood = True
for name, expect_row, caught, others in rows:
    status = 'RED (good)' if caught else 'STILL GREEN -- NOT A REAL CHECK'
    if not caught:
        allgood = False
    print('%-*s %-31s %s' % (w, name, status, ('| also flipped: ' + others) if others else ''))

print()
print('mutations=%d  detected=%d' % (len(rows), sum(1 for r in rows if r[2])))
sys.exit(0 if allgood else 1)
