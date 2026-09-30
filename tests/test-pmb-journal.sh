#!/usr/bin/env bash
# tests/test-pmb-journal.sh — tests for scripts/pmb-journal.{sh,ps1}
# (docs/superpowers/specs/2026-09-26-multi-session-memory-design.md §4.1-§4.3).
#
# WHY collisions are INJECTED rather than raced: a race test passes whenever the scheduler is kind,
# and the random suffix makes real collisions vanishingly rare -- so a test that only runs two
# writers at once stays green even with the no-overwrite guard deleted. These tests pre-create the
# exact colliding name / sequence number, so removing `ln` (or the exclusive seq create) turns them
# red. See the review record of tests/test-mb-version-notifier.sh for the same preference.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# WHY overridable: mutation checks point these at a mutated copy in a scratch directory, so the
# tracked script is never edited in place (a copy-aside-and-restore can revert a peer session's
# concurrent edit -- progress.md, 2026-08-29..31 carried-forward item 2). The copy's directory must
# also hold secret-patterns.txt, because each twin reads the list from its own directory.
J="${PMB_TEST_JOURNAL_SH:-$REPO_ROOT/scripts/pmb-journal.sh}"
J_PS1="${PMB_TEST_JOURNAL_PS1:-$REPO_ROOT/scripts/pmb-journal.ps1}"
PATTERNS="$REPO_ROOT/scripts/secret-patterns.txt"
source "$REPO_ROOT/tests/helpers/assert.sh"

# WHY: mb.sh/mb.ps1 take REPO_ROOT from MB_HOME (spec F18). The journal must not depend on it, and
# a fixture that inherited the real MB_HOME could reach the real repository.
export MB_HOME="/nonexistent/pmb-test-mb-home"
unset CLAUDE_CODE_SESSION_ID PMB_TEST_RAND PMB_TEST_SEQ_START PMB_TEST_TS

# WHY count this suite's own session ids rather than checksum the whole directory: other sessions
# in other worktrees legitimately write the real pmb/ while this suite runs (heartbeats, notes), so
# a whole-directory checksum would fail for reasons unrelated to the suite. Every id this suite uses
# starts with "sess" and a capital letter; real Claude Code ids are lower-case UUIDs.
REAL_PMB="$(cd "$(git -C "$REPO_ROOT" rev-parse --git-common-dir)" && pwd -P)/pmb"
real_pmb_state() { ls -1 "$REAL_PMB/sessions" 2>/dev/null | grep -c '^sess[A-Z]'; }
REAL_BEFORE="$(real_pmb_state)"

echo "=== pmb-journal tests ==="
T="$(mktemp -d 2>/dev/null || mktemp -d -t pmb-journal-test)"
trap 'rm -rf "$T"' EXIT

# make_repo DIR FLAG — FLAG is on | off | none. Commits the journal scripts and (unless none) a
# .pmb-features file, then points refs/remotes/origin/main at that commit.
make_repo() {
    local dir="$1" flag="$2"
    git init -q "$dir"
    (
        cd "$dir" || exit 1
        git config user.email t@example.invalid && git config user.name pmb-test
        git config core.autocrlf false   # the fixture's LF files, committed without CRLF warnings
        mkdir -p scripts
        cp "$J" "$PATTERNS" scripts/
        [ -f "$J_PS1" ] && cp "$J_PS1" scripts/
        [ "$flag" = none ] || printf 'journal=%s\n' "$flag" > .pmb-features
        git add -A && git commit -qm init && git update-ref refs/remotes/origin/main HEAD
    )
}
pmbdir() { printf '%s/pmb' "$(cd "$1" && cd "$(git rev-parse --git-common-dir)" && pwd -P)"; }
jr() { local d="$1"; shift; ( cd "$d" && bash "$J" "$@" ); }                  # run, keep output
jcode() { local d="$1"; shift; ( cd "$d" && bash "$J" "$@" >/dev/null 2>&1; echo $? ); }

# ── mode: the flag is read only through refs/remotes/origin/main's SHA ─────────────────────────
echo ""; echo "--- mode ---"
make_repo "$T/on" on;     assert_equals "$(jcode "$T/on" mode)"   "0" "flag on at origin/main: mode exits 0"
make_repo "$T/off" off;   assert_equals "$(jcode "$T/off" mode)"  "1" "flag off: mode exits 1"
make_repo "$T/none" none; assert_equals "$(jcode "$T/none" mode)" "1" "no .pmb-features: mode exits 1"
make_repo "$T/noref" on;  git -C "$T/noref" update-ref -d refs/remotes/origin/main
assert_equals "$(jcode "$T/noref" mode)" "1" "missing origin/main ref: flag reads as off"
# F17: an empty revision reads the INDEX. A staged .pmb-features must not turn the flag on.
make_repo "$T/staged" none; git -C "$T/staged" update-ref -d refs/remotes/origin/main
printf 'journal=on\n' > "$T/staged/.pmb-features"; git -C "$T/staged" add .pmb-features
assert_equals "$(jcode "$T/staged" mode)" "1" "staged .pmb-features with no ref: still off (no index fallback)"
# F16: a local branch named origin/main must not shadow the remote-tracking ref.
make_repo "$T/shadow" off
( cd "$T/shadow" && printf 'journal=on\n' > .pmb-features && git add .pmb-features && git commit -qm on \
  && git branch origin/main HEAD 2>/dev/null )
assert_equals "$(jcode "$T/shadow" mode)" "1" "local branch origin/main with flag on does not shadow remote ref (off)"
# F16, second half: a TAG named origin/main resolves before refs/remotes too (gitrevisions order).
make_repo "$T/shadowtag" off
( cd "$T/shadowtag" && printf 'journal=on\n' > .pmb-features && git add .pmb-features && git commit -qm on \
  && git tag origin/main HEAD 2>/dev/null )
assert_equals "$(jcode "$T/shadowtag" mode)" "1" "tag origin/main with flag on does not shadow remote ref (off)"
# Review Focus 1: a path containing a space -- the flag read AND a write.
make_repo "$T/a b" on
assert_equals "$(jcode "$T/a b" mode)" "0" "repository path with a space: mode works"
( cd "$T/a b" && CLAUDE_CODE_SESSION_ID=sessSPACE01 bash "$J" note 'written in a repository whose path contains a space' ) >/dev/null
assert_equals "$(ls -1 "$(pmbdir "$T/a b")/sessions/sessSPACE01/r" 2>/dev/null | grep -c -- '-note-')" "1" "repository path with a space: the record lands under pmb/"

# ── identity ──────────────────────────────────────────────────────────────────────────────────
echo ""; echo "--- identity ---"
assert_equals "$(jcode "$T/on" note 'no session id available here at all, forty bytes plus')" "1" "no CLAUDE_CODE_SESSION_ID and no --session: refused"
out="$(cd "$T/on" && CLAUDE_CODE_SESSION_ID=sessAAAA01 bash "$J" note --session sessBBBB02 'a note that is long enough to be a record' 2>&1)"
assert_contains "$out" "differs from CLAUDE_CODE_SESSION_ID" "--session that differs from the env id is refused"
# WHY ids of 10 and 11 characters: both pass the 8-64 length rule, so only the CHARSET rule can
# refuse them. A shorter id such as '../x' is refused by length alone and would not detect a charset
# rule that had been loosened (review 2026-09-29, T-5).
assert_equals "$(cd "$T/on" && CLAUDE_CODE_SESSION_ID='../../evil' bash "$J" note 'a note that is long enough to be a record' >/dev/null 2>&1; echo $?)" "1" "a session id with dot-dot path characters is refused (length is fine, charset is not)"
assert_equals "$(cd "$T/on" && CLAUDE_CODE_SESSION_ID='a/b/c/d/e/f' bash "$J" note 'a note that is long enough to be a record' >/dev/null 2>&1; echo $?)" "1" "a session id with slashes is refused (length is fine, charset is not)"
sid="$(jr "$T/on" start)"
assert_equals "$(printf '%s' "$sid" | grep -cE '^[0-9a-f]{32}$')" "1" "start prints a 32-hex session id"

# ── writing records ───────────────────────────────────────────────────────────────────────────
echo ""; echo "--- writing ---"
export CLAUDE_CODE_SESSION_ID=sessWRITE01
out="$(jr "$T/on" note 'first real note: finished the writer, next the gate tests')"
assert_contains "$out" "recorded " "note prints the record name"
assert_contains "$out" "in session sessWRITE01" "note names the session it wrote to"
P="$(pmbdir "$T/on")/sessions/sessWRITE01"
assert_file_exists "$P/meta" "first write creates meta"
assert_file_exists "$P/heartbeat" "first write touches heartbeat"
names="$(ls -1 "$P/r" | sort -t- -k2,2n)"
assert_equals "$(printf '%s\n' "$names" | sed -n 1p | cut -d- -f3)" "start" "first record of a session is the start marker"
assert_equals "$(printf '%s\n' "$names" | sed -n 2p | cut -d- -f3)" "note" "second record is the note"
assert_equals "$(printf '%s\n' "$names" | grep -cvE '^[0-9]{8}T[0-9]{6}Z-[0-9]{6}-[a-z]+(-NS-[0-9]{1,5})?-[0-9a-f]{6}\.md$')" "0" "every record name matches the grammar"
assert_equals "$(cat "$P/r/$(printf '%s\n' "$names" | sed -n 2p)")" "first real note: finished the writer, next the gate tests" "record body is the text, verbatim"
assert_contains "$(cat "$P/meta")" "worktree=$(git -C "$T/on" rev-parse --show-toplevel)" "meta names the worktree top level"
out="$(jr "$T/on" note NS-26 'progress on the item, recorded with its NS id attached')"
# WHY no leading dash in these patterns: assert_contains runs `grep -qi "$pattern"`, and grep reads
# a pattern that starts with '-' as an option (exit 2), which would fail the assertion every time.
assert_contains "$out" "note-NS-26-" "an NS id is carried in the record name"
# Review Focus 4: from a subdirectory.
mkdir -p "$T/on/sub/dir"
( cd "$T/on/sub/dir" && bash "$J" note 'written from a subdirectory of the worktree, still recorded' ) >/dev/null
assert_equals "$(ls -1 "$P/r" | grep -c -- '-note-')" "3" "a write from a subdirectory lands in the same session"

# ── validation ────────────────────────────────────────────────────────────────────────────────
echo ""; echo "--- validation ---"
assert_equals "$(jcode "$T/on" claim)" "1" "claim without an NS id is refused"
assert_equals "$(jcode "$T/on" claim NS-123456)" "1" "a malformed NS id (6 digits) is refused"
assert_equals "$(jcode "$T/on" claim NS-x1)" "1" "a malformed NS id (non-digit) is refused"
assert_equals "$(jcode "$T/on" bogus 'x')" "1" "an unknown kind is refused"
body1024="$(head -c 1024 /dev/zero | tr '\0' 'a')"
body1025="${body1024}a"
assert_equals "$(jcode "$T/on" note "$body1024")" "0" "a 1,024-byte body is accepted"
assert_equals "$(jcode "$T/on" note "$body1025")" "1" "a 1,025-byte body is refused"
# Review Focus 2: the limit counts UTF-8 bytes. 'é' is 2 bytes: 511 of them + 'x' = 1,023 bytes.
eacute="$(printf '\303\251')"
utf1023="$(for i in $(seq 511); do printf '%s' "$eacute"; done)x"
utf1025="${utf1023}${eacute}"
assert_equals "$(jcode "$T/on" note "$utf1023")" "0" "1,023 bytes of multi-byte text is accepted"
assert_equals "$(jcode "$T/on" note "$utf1025")" "1" "1,025 bytes of multi-byte text is refused (bytes, not characters)"
printf 'line one of a note\n---\nline three\n' > "$T/fm.txt"
assert_equals "$(jcode "$T/on" note --file "$T/fm.txt")" "1" "a body with a --- line is refused"
printf 'carriage\r\nreturns and a bell\007 stripped from this body text\r\n' > "$T/crlf.txt"
# WHY the exit code AND the exact body: with the normaliser gone the write is REFUSED (the CR is a
# control character), so `last` would be the previous record and a grep for controls would pass on it
# (review 2026-09-29, T-1).
assert_equals "$(jcode "$T/on" note --file "$T/crlf.txt")" "0" "a body with CR and a bell is accepted once normalised"
last="$(ls -1 "$P/r" | sort -t- -k2,2n | tail -1)"
assert_equals "$(cat "$P/r/$last")" "$(printf 'carriage\nreturns and a bell stripped from this body text')" "the stored body is exactly the stripped text"
# WHY tr + [[:cntrl:]] rather than od: `od -c` prints BEL as `\a`, not `007`, so grepping od's
# output for 007 passes even when the bell survives.
assert_equals "$(LC_ALL=C tr -d '\n\t' < "$P/r/$last" | LC_ALL=C grep -c '[[:cntrl:]]')" "0" "CR and control characters are stripped"
# WHY these secret-shaped inputs are assembled at run time: CI's gitleaks scan and the pre-push
# scan both read the SOURCE lines, so no line may hold the literal shape. The writer receives the
# same bytes as the assembled literal (a quoted 16-character password assignment).
q='"'; hp=hunter2hunter2
assert_equals "$(jcode "$T/on" note "config: password = ${q}${hp}${q}")" "1" "a body matching a secret pattern is refused"
assert_equals "$(jcode "$T/on" note "config: PASSWORD = ${q}${hp}${q}")" "1" "secret matching is case-insensitive"
assert_equals "$(jcode "$T/on" note '')" "1" "an empty body is refused"
assert_equals "$(jcode "$T/on" note '    ')" "1" "a whitespace-only body is refused"
# Hardening (adversarial review 2026-09-29).
assert_equals "$(jcode "$T/on" claim NS-05)" "1" "a non-canonical NS id (leading zero) is refused, so NS-05 cannot alias NS-5"
assert_equals "$(jcode "$T/on" note "hidden $(printf '\342\200\256')reversed text inside a note")" "1" "a bidi override character is refused"
assert_equals "$(jcode "$T/on" note "tagged $(printf '\363\240\200\201')invisible instruction carrier")" "1" "a Unicode tag character is refused"
assert_equals "$(jcode "$T/on" note "hidden $(printf '\330\234')Arabic letter mark inside a note")" "1" "U+061C (a bidi mark) is refused"
assert_equals "$(jcode "$T/on" note "hidden $(printf '\363\240\204\200')variation selector supplement in a note")" "1" "U+E0100 (variation selector supplement) is refused"
printf 'bad byte \377 in the middle of a note long enough\n' > "$T/badutf8.txt"
assert_equals "$(jcode "$T/on" note --file "$T/badutf8.txt")" "1" "invalid UTF-8 is refused"
printf '\357\273\277---\nfrontmatter behind a byte-order mark\n---\n' > "$T/bomfm.txt"
assert_equals "$(jcode "$T/on" note --file "$T/bomfm.txt")" "1" "a --- line behind a leading BOM is refused"
printf 'text\n--- \nmore text after a rule with a trailing space\n' > "$T/fmsp.txt"
assert_equals "$(jcode "$T/on" note --file "$T/fmsp.txt")" "1" "a --- line with trailing whitespace is refused"
assert_equals "$(jcode "$T/on" note 'key sk-ant-api03-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA leaked')" "1" "an Anthropic key shape is refused"
assert_equals "$(jcode "$T/on" note 'config: password: hunter2hunter2 without quotes')" "1" "an unquoted password assignment is refused"
# SEC-1: the credential shapes a plain password= pattern misses. Best effort, not a scanner.
assert_equals "$(jcode "$T/on" note '{"password": "hunter2hunter2"}')" "1" "a JSON-quoted password is refused"
ca=abcd1234; cb=efgh5678
assert_equals "$(jcode "$T/on" note "${q}client_secret${q}: ${q}${ca}${cb}${q}")" "1" "a JSON-quoted client_secret is refused"
assert_equals "$(jcode "$T/on" note 'aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY')" "1" "an aws_secret_access_key assignment is refused"
# WHY the value is built at run time: CI's credential grep flags `<key>=<8+ alphanumerics>` in any
# tracked line, and these two inputs would trip it. The bytes sent to the writer are unchanged.
v=abcd1234
assert_equals "$(jcode "$T/on" note "API_KEY=$v$v$v")" "1" "an API_KEY assignment is refused"
assert_equals "$(jcode "$T/on" note "token=$v$v$v")" "1" "a token assignment is refused"
assert_equals "$(jcode "$T/on" note 'Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.abcdefghijk')" "1" "a bearer token is refused"
sl=sk_live_
assert_equals "$(jcode "$T/on" note "${sl}51H8abcdefghijklmnopqrstuv")" "1" "a sk_live_ key is refused"
assert_equals "$(jcode "$T/on" note 'postgres://user:S3cretPassw0rd@db.example.com/x')" "1" "a URL with embedded credentials is refused"
# The secret list fails CLOSED when it cannot be applied: a copy of the script whose list holds an
# invalid regex must refuse, not store.
mkdir -p "$T/badpat" && cp "$J" "$T/badpat/" && printf 'AKIA[0-9A-Z]{16}\n[unclosed\n' > "$T/badpat/secret-patterns.txt"
assert_equals "$(cd "$T/on" && bash "$T/badpat/pmb-journal.sh" note 'an ordinary note while the pattern list is broken' >/dev/null 2>&1; echo $?)" "1" "an invalid secret-pattern list fails closed"
printf '# comments only\n' > "$T/badpat/secret-patterns.txt"
assert_equals "$(cd "$T/on" && bash "$T/badpat/pmb-journal.sh" note 'an ordinary note while the pattern list is empty' >/dev/null 2>&1; echo $?)" "1" "an empty secret-pattern list fails closed"

# SEC-6: --file is read only when it is a regular file, not a link, and at most 64 KB. WHY the
# assertions read the MESSAGE: a body over 1,024 bytes is refused anyway, so the exit code alone
# cannot tell the size guard from the body limit. 65,536 bytes must pass the size guard (and then meet
# the body limit); 65,537 must be stopped by it before the file is read into a variable.
head -c 65536 /dev/zero | tr '\0' 'a' > "$T/big64k.txt"
head -c 65537 /dev/zero | tr '\0' 'a' > "$T/big64k1.txt"
out="$(cd "$T/on" && bash "$J" note --file "$T/big64k.txt" 2>&1)"
assert_contains "$out" "body is 65536 bytes" "a 65,536-byte --file passes the size guard (the body limit refuses it)"
out="$(cd "$T/on" && bash "$J" note --file "$T/big64k1.txt" 2>&1)"
assert_contains "$out" "larger than 65536 bytes" "a --file over 64 KB is refused before it is read"
out="$(cd "$T/on" && bash "$J" note --file "$T" 2>&1)"
assert_contains "$out" "not a regular file" "a --file that is a directory is refused as not a regular file"
ln -s "$T/fm.txt" "$T/link.txt" 2>/dev/null
if [ -L "$T/link.txt" ]; then
    out="$(cd "$T/on" && bash "$J" note --file "$T/link.txt" 2>&1)"
    assert_contains "$out" "not a regular file" "a --file that is a symbolic link is refused"
else
    echo "  SKIP: symbolic links cannot be created here, so the --file link refusal is not exercised"
fi

# ── sequence numbers ──────────────────────────────────────────────────────────────────────────
echo ""; echo "--- sequence numbers ---"
export CLAUDE_CODE_SESSION_ID=sessSEQ0001
jr "$T/on" note 'establishes the session for the sequence-number cases here' >/dev/null
PS="$(pmbdir "$T/on")/sessions/sessSEQ0001"
: > "$PS/seq/999999"
assert_equals "$(jcode "$T/on" note 'no sequence number is left, so this must be refused')" "1" "past seq 999999 a write is refused, never given a 7-digit name"
assert_equals "$(ls -1 "$PS/r" | grep -c -- '-[0-9]\{7\}-')" "0" "no record carries a 7-digit seq"
rm -f "$PS/seq/999999"
# A lost seq/ must not restart numbering below the records already in r/.
hi=$(ls -1 "$PS/seq" | sort -n | tail -1)
mv "$PS/seq" "$PS/seq.lost"
jr "$T/on" note 'written after seq/ was lost, numbered above the existing records' >/dev/null
assert_equals "$(ls -1 "$PS/seq" | sort -n | tail -1)" "$((hi + 1))" "after seq/ is lost, numbering continues above the records in r/"
# A seq/ that cannot hold files must fail fast, not retry up to the cap (~4.7 h under Git Bash).
rm -rf "$PS/seq" && printf 'not a directory\n' > "$PS/seq"
start_s=$(date +%s)
assert_equals "$(jcode "$T/on" note 'seq/ is a plain file here, so allocation must fail fast')" "1" "an unusable seq/ refuses the write"
assert_equals "$(( $(date +%s) - start_s < 20 ))" "1" "an unusable seq/ fails within seconds"
unset CLAUDE_CODE_SESSION_ID
# Two first writes at once must not both publish a start marker: the `started` sentinel decides.
SS="$(pmbdir "$T/on")/sessions/sessSTART01"
mkdir -p "$SS/r" "$SS/seq" && : > "$SS/started"
( cd "$T/on" && CLAUDE_CODE_SESSION_ID=sessSTART01 bash "$J" note 'the sentinel already exists, so no start marker is written' ) >/dev/null
assert_equals "$(ls -1 "$SS/r" | grep -c -- '-start-')" "0" "an existing started sentinel suppresses a second start marker"

# ── injected collisions (spec §7, Journal) ────────────────────────────────────────────────────
echo ""; echo "--- injected collisions ---"
export CLAUDE_CODE_SESSION_ID=sessCOLL001
jr "$T/on" note 'establishes the session so the next seq is predictable, forty+' >/dev/null
P2="$(pmbdir "$T/on")/sessions/sessCOLL001"
# WHY PMB_TEST_SEQ_START: the allocator counts the record names in r/ as well as seq/, so a
# planted record raises the next seq past itself. Forcing the seq to the planted record's number
# (still free in seq/) makes the publish step meet the exact colliding name.
next=$(( $(ls -1 "$P2/seq" | sort -n | tail -1) + 5 ))
target="$P2/r/20260101T000000Z-$(printf '%06d' "$next")-note-abcdef.md"
printf 'ORIGINAL\n' > "$target"
( cd "$T/on" && PMB_TEST_SEQ_START=$next PMB_TEST_TS=20260101T000000Z PMB_TEST_RAND=abcdef bash "$J" note 'collides on purpose with the pre-created record name' ) >/dev/null
assert_equals "$(cat "$target")" "ORIGINAL" "a pre-existing record at the target name is never overwritten"
assert_equals "$(ls -1 "$P2/r" | grep -c "^20260101T000000Z-$(printf '%06d' "$next")-note-")" "2" "the new record is published beside it under a fresh suffix"
: > "$P2/seq/70"
( cd "$T/on" && PMB_TEST_SEQ_START=70 bash "$J" note 'seq 70 is taken, so this record must get seq 71' ) >/dev/null
assert_equals "$(ls -1 "$P2/r" | grep -c -- '-000071-note-')" "1" "a pre-existing seq/<n> is skipped (exclusive create)"
# Review Focus 5: same-second writes are ordered by seq, not by timestamp.
( cd "$T/on" && PMB_TEST_TS=20260101T000001Z bash "$J" note 'same second A, must sort before B by seq' \
  && PMB_TEST_TS=20260101T000001Z bash "$J" note 'same second B, must sort after A by seq' ) >/dev/null
a_seq="$(ls -1 "$P2/r" | grep '^20260101T000001Z' | sort -t- -k2,2n | head -1 | cut -d- -f2)"
b_seq="$(ls -1 "$P2/r" | grep '^20260101T000001Z' | sort -t- -k2,2n | tail -1 | cut -d- -f2)"
assert_equals "$([ "$((10#$a_seq))" -lt "$((10#$b_seq))" ] && echo ordered)" "ordered" "same-second records get strictly increasing seq"
# SEC-3: the test seams are read in the SHIPPED writer, so a value that is not the documented shape
# is ignored. WHY the traversal probe uses a name inside sessions/: with the check gone the record
# is hard-linked at sessions/escape-<seq>-note-<rand>.md, outside r/.
seam_before=$(ls -1 "$P2/r" | wc -l)
( cd "$T/on" && PMB_TEST_TS='../../escape' bash "$J" note 'a traversal value in PMB_TEST_TS must be ignored, not used' ) >/dev/null
assert_equals "$(ls -1 "$(pmbdir "$T/on")/sessions" | grep -c '^escape-')" "0" "a traversal PMB_TEST_TS puts nothing outside r/"
assert_equals "$(( $(ls -1 "$P2/r" | wc -l) - seam_before ))" "1" "a traversal PMB_TEST_TS is ignored: the record lands in r/ under a real timestamp"
( cd "$T/on" && PMB_TEST_RAND=zzzzzz bash "$J" note 'a non-hex PMB_TEST_RAND must be ignored, not used in the name' ) >/dev/null
assert_equals "$(ls -1 "$P2/r" | grep -c 'zzzzzz')" "0" "a PMB_TEST_RAND that is not 6 hex digits is ignored"
assert_equals "$(cd "$T/on" && PMB_TEST_SEQ_START=1234567 bash "$J" note 'a 7-digit PMB_TEST_SEQ_START must be ignored, not used' >/dev/null 2>&1; echo $?)" "0" "a PMB_TEST_SEQ_START longer than 6 digits is ignored"
unset CLAUDE_CODE_SESSION_ID

# ── the real repository is untouched ──────────────────────────────────────────────────────────
echo ""; echo "--- isolation ---"
assert_equals "$(real_pmb_state)" "$REAL_BEFORE" "no session of this suite appears in the real repository's pmb/"

print_summary
