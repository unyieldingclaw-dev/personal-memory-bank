#!/usr/bin/env bash
# tests/test-pre-compact-check.sh — tests for the PreCompact hook
#
# Outside journal mode the hook is a no-op: it allows every compaction and prints nothing
# (docs/superpowers/specs/2026-11-01-derived-work-rules-and-compaction-recovery-design.md, D1').
# Recovery happens after compaction, in the SessionStart(compact) hook (tests/test-hook-wiring.sh).
#
# The discriminating fixtures are the ones the former gate BLOCKED -- a thin bank, a stale
# handoff.md, no memory-bank/ at all -- so a regression back to blocking turns an expected 0 into 2.
# Journal mode still has its own gate; those cases pin that delegation is unchanged.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="${PMB_TEST_HOOK:-$REPO_ROOT/scripts/pre-compact-check.sh}"   # overridable for mutation checks
source "$REPO_ROOT/tests/helpers/assert.sh"

echo "=== pre-compact-check tests ==="

TMPDIR_PC="$(mktemp -d 2>/dev/null || mktemp -d -t mb-precompact-test)"
trap 'rm -rf "$TMPDIR_PC"' EXIT

TODAY="$(date +%Y-%m-%d)"

# Builds a memory bank in $1. "fresh" satisfies the former gate's checks; "thin" fails both
# (no substantive activeContext lines, no dated progress entry).
make_bank() {
    local dir="$1" kind="$2"
    mkdir -p "$dir/memory-bank"
    if [ "$kind" = "fresh" ]; then
        {
            echo "# Active Context"
            echo "This is a substantive line of session state that is comfortably over twenty characters."
            echo "This is a second substantive line of session state, also well over the threshold length."
            echo "This is a third substantive line of session state, likewise over the threshold length."
        } > "$dir/memory-bank/activeContext.md"
        printf '# Progress\n\n## %s — did some work\n\n- an entry\n' "$TODAY" > "$dir/memory-bank/progress.md"
    else
        printf '# Active Context\n' > "$dir/memory-bank/activeContext.md"
        printf '# Progress\n\n## 2020-01-01 — ancient\n' > "$dir/memory-bank/progress.md"
    fi
}

run_hook() { ( cd "$1" && bash "$HOOK" 2>/dev/null ); }
hook_code() { ( cd "$1" && bash "$HOOK" >/dev/null 2>&1; echo $? ); }
backdate() { touch -d "2 days ago" "$1" 2>/dev/null || touch -t "$(date -d '2 days ago' +%Y%m%d%H%M 2>/dev/null || echo 202001010000)" "$1"; }

# ── legacy path: a no-op, allows every state the former gate blocked ──────────────────
echo ""
echo "--- legacy path (no journal mode): allows compaction, prints nothing ---"
D="$TMPDIR_PC/fresh"; make_bank "$D" fresh
assert_contains "code=$(hook_code "$D")" "code=0" "fresh memory bank: allowed"
D="$TMPDIR_PC/thin"; make_bank "$D" thin
assert_contains "code=$(hook_code "$D")" "code=0" "thin memory bank (the former gate blocked this): allowed"
assert_equals "$(run_hook "$D")" "" "thin memory bank: no stdout (nothing for the user to act on)"
D="$TMPDIR_PC/handoff-stale"; make_bank "$D" thin
printf '# Handoff\n\nspent state\n' > "$D/handoff.md"; backdate "$D/handoff.md"
assert_contains "code=$(hook_code "$D")" "code=0" "stale handoff.md with a thin bank (the former gate blocked this): allowed"
assert_equals "$(run_hook "$D")" "" "stale handoff.md: no stale-handoff note"
D="$TMPDIR_PC/no-bank"; mkdir -p "$D"
assert_contains "code=$(hook_code "$D")" "code=0" "no memory-bank/ at all (the former gate blocked this): allowed"

# ── journal mode (docs/superpowers/specs/2026-09-26-multi-session-memory-design.md §4.3) ─────
# WHY: the delegation branch is the only code in this hook that can block. These cases pin both directions --
# it takes over when the repository has opted in AND the script exists, and it changes nothing
# otherwise (every case above runs with neither). Each "not opted in" fixture is one the journal
# gate BLOCKS (no journal record), so a delegation that fires where it must not turns the expected 0
# into 2.
echo ""
echo "--- journal mode: delegates only when opted in and the script exists ---"
# Global constraints: no inherited MB_HOME, and no session of this suite in the real pmb/.
export MB_HOME="/nonexistent/pmb-test-mb-home"
# WHY --path-format=absolute and a hard stop: in a main checkout --git-common-dir prints a RELATIVE
# `.git`, and a failed resolution would make the isolation check below pass without checking.
JM_REAL_GIT="$(git -C "$REPO_ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
if [ -z "$JM_REAL_GIT" ] || [ ! -d "$JM_REAL_GIT" ]; then
    echo "FAIL: cannot locate the real repository's git directory from $REPO_ROOT; the isolation check would pass vacuously"
    exit 1
fi
JM_REAL_PMB="$(cd "$JM_REAL_GIT" && pwd -P)/pmb"
jm_real_state() { ls -1 "$JM_REAL_PMB/sessions" 2>/dev/null | grep -c '^sessJM_'; }
JM_REAL_BEFORE="$(jm_real_state)"
# Overridable for mutation checks, like HOOK and HOOK_PS1 (see tests/test-pmb-journal.sh).
JM_SH="${PMB_TEST_JOURNAL_SH:-$REPO_ROOT/scripts/pmb-journal.sh}"
JM_PS1="${PMB_TEST_JOURNAL_PS1:-$REPO_ROOT/scripts/pmb-journal.ps1}"
# jm_repo DIR FLAG SCRIPT BANK — FLAG on|off|none (none: the ref exists, the flag file does not --
# this repository's own state from Plan A's merge until Plan C); SCRIPT yes|no copies both journal
# twins; BANK fresh (plus today's handoff.md) or thin.
jm_repo() {
    local dir="$1" flag="$2" with_script="$3" bank="$4"
    git init -q "$dir"
    ( cd "$dir" && git config user.email t@example.invalid && git config user.name pmb-test && git config core.autocrlf false
      mkdir -p scripts
      if [ "$with_script" = yes ]; then
          cp "$JM_SH" "$REPO_ROOT/scripts/secret-patterns.txt" scripts/
          [ -f "$JM_PS1" ] && cp "$JM_PS1" scripts/
      fi
      [ "$flag" = none ] || printf 'journal=%s\n' "$flag" > .pmb-features
      git add -A && git commit -qm init --allow-empty && git update-ref refs/remotes/origin/main HEAD )
    make_bank "$dir" "$bank"
    [ "$bank" = fresh ] && printf '# Handoff\n\ntoday\n' > "$dir/handoff.md"
    return 0
}
# jm_payload TRIGGER SID. WHY a SID parameter: a manual block arms the once-only escape hatch for
# that session, so a second twin run against the same fixture needs an id of its own.
jm_payload() { printf '{"session_id":"%s","trigger":"%s"}' "${2:-sessJM_0001}" "${1:-manual}"; }
jm_code() { ( cd "$1" && jm_payload "${2:-manual}" sessJM_0001 | CLAUDE_CODE_SESSION_ID=sessJM_0001 bash "$HOOK" >/dev/null 2>&1; echo $? ); }
jm_repo "$TMPDIR_PC/jm-on" on yes fresh
assert_contains "code=$(jm_code "$TMPDIR_PC/jm-on")" "code=2" "[NS-22] opted in with the script: a fresh bank and today's handoff.md do NOT pass a manual /compact (the journal gate decides)"
assert_contains "code=$(jm_code "$TMPDIR_PC/jm-on" auto)" "code=0" "opted in, trigger=auto: allowed"
# WHY stdout is asserted through the real hook: the hook wiring discards stderr, so the JSON decision
# is what reaches the user, and the exit code alone would not show it. WHY sessJM_0002: the manual
# block above armed the once-only escape hatch for sessJM_0001.
jm_out="$(cd "$TMPDIR_PC/jm-on" && jm_payload manual sessJM_0002 | CLAUDE_CODE_SESSION_ID=sessJM_0002 bash "$HOOK" 2>/dev/null)"
assert_contains "$jm_out" '^{"decision":"block","reason":".*"}$' "opted in, manual: the real hook prints the JSON block decision on stdout"
jm_repo "$TMPDIR_PC/jm-off" off yes fresh
assert_contains "code=$(jm_code "$TMPDIR_PC/jm-off")" "code=0" "flag off: legacy path allows (no delegation)"
jm_repo "$TMPDIR_PC/jm-noscript" on no fresh
assert_contains "code=$(jm_code "$TMPDIR_PC/jm-noscript")" "code=0" "flag on but no script (adopter / old branch): legacy path allows"
jm_repo "$TMPDIR_PC/jm-noflag" none yes fresh
assert_contains "code=$(jm_code "$TMPDIR_PC/jm-noflag")" "code=0" "script present, no flag file: legacy path allows (no delegation)"
jm_repo "$TMPDIR_PC/jm-noflag-thin" none yes thin
assert_contains "code=$(jm_code "$TMPDIR_PC/jm-noflag-thin")" "code=0" "script present, no flag file, thin bank: legacy path allows (no delegation)"
assert_equals "$(jm_real_state)" "$JM_REAL_BEFORE" "no journal-mode case writes a session into the real pmb/"

# ── sh/ps1 parity ──────────────────────────────────────────────────────────────────────────
# WHY: every assertion above runs the .sh hook only, but Claude Code invokes the .ps1 twin first
# on any machine where pwsh is present -- so a twin that still blocked would go unseen without
# these cases ([NS-37] was exactly such a sh/ps1 divergence).
#
# WHY skipped rather than failed when pwsh is missing: CI runs on Linux where pwsh is not
# guaranteed. The skip is loud so it is not mistaken for a pass; PMB_REQUIRE_PARITY=1 makes it fatal.
HOOK_PS1="${PMB_TEST_HOOK_PS1:-$REPO_ROOT/scripts/pre-compact-check.ps1}"   # overridable for mutation checks
if command -v pwsh >/dev/null 2>&1; then
    echo ""
    echo "--- sh/ps1 parity: the .ps1 twin must agree with the .sh hook ---"
    ps1_code() { ( cd "$1" && pwsh -NoProfile -NonInteractive -File "$HOOK_PS1" >/dev/null 2>&1; echo $? ); }

    assert_contains "code=$(ps1_code "$TMPDIR_PC/fresh")"         "code=0" "ps1: fresh bank: allowed"
    assert_contains "code=$(ps1_code "$TMPDIR_PC/thin")"          "code=0" "ps1: thin bank (the former gate blocked this): allowed"
    assert_contains "code=$(ps1_code "$TMPDIR_PC/handoff-stale")" "code=0" "ps1: stale handoff.md with a thin bank: allowed"
    assert_contains "code=$(ps1_code "$TMPDIR_PC/no-bank")"       "code=0" "ps1: no memory-bank/ at all: allowed"
    assert_equals "$( (cd "$TMPDIR_PC/thin" && pwsh -NoProfile -NonInteractive -File "$HOOK_PS1" 2>/dev/null) )" "" "ps1: thin bank: no stdout"

    # Journal mode in the ps1 hook -- the twin that runs first wherever pwsh exists. WHY sessJM_0003 and
    # up: a manual block arms the once-only escape hatch for its session, and the sh cases above used
    # sessJM_0001 and sessJM_0002 on these fixtures, so each ps1 scenario takes an id of its own (C6.8).
    ps1_jm() { ( cd "$1" && jm_payload "$2" "$3" | CLAUDE_CODE_SESSION_ID="$3" pwsh -NoProfile -NonInteractive -File "$HOOK_PS1" >/dev/null 2>&1; echo $? ); }
    assert_contains "code=$(ps1_jm "$TMPDIR_PC/jm-on" manual sessJM_0003)" "code=2" "ps1: [NS-22] opted in with the script: a fresh bank and today's handoff.md do NOT pass a manual /compact (the journal gate decides)"
    assert_contains "code=$(ps1_jm "$TMPDIR_PC/jm-on" auto sessJM_0004)" "code=0" "ps1: opted in, trigger=auto: allowed"
    jm_out="$(cd "$TMPDIR_PC/jm-on" && jm_payload manual sessJM_0005 | CLAUDE_CODE_SESSION_ID=sessJM_0005 pwsh -NoProfile -NonInteractive -File "$HOOK_PS1" 2>/dev/null)"
    assert_contains "$jm_out" '^{"decision":"block","reason":".*"}$' "ps1: opted in, manual: the real hook prints the JSON block decision on stdout"
    assert_contains "code=$(ps1_jm "$TMPDIR_PC/jm-on" manual sessJM_0005)" "code=0" "ps1: opted in, a repeated manual /compact with nothing new passes (escape hatch)"
    # The payload path: no CLAUDE_CODE_SESSION_ID (Cursor, Codex, hook-less clients), so the id can come
    # only from the payload. WHY a case of its own: with the env id set to the same value, the env path
    # alone produces the same block.
    jm_out="$(cd "$TMPDIR_PC/jm-on" && jm_payload manual sessJM_0012 | env -u CLAUDE_CODE_SESSION_ID pwsh -NoProfile -NonInteractive -File "$HOOK_PS1" 2>/dev/null)"
    assert_contains "$jm_out" 'Checked session: sessJM_0012' "ps1: without CLAUDE_CODE_SESSION_ID the hook's block names the session it read from the payload"
    assert_contains "$jm_out" 'note \\"<text>\\" --session sessJM_0012' "ps1: the payload-path block's command carries --session <id>"
    # Inert when not opted in: each fixture is one the legacy gate passes and the journal gate blocks
    # (or, for the thin bank, the reverse), so a delegation that fires, or swallows the legacy gate, shows.
    assert_contains "code=$(ps1_jm "$TMPDIR_PC/jm-off" manual sessJM_0006)" "code=0" "ps1: flag off: legacy path allows (no delegation)"
    assert_contains "code=$(ps1_jm "$TMPDIR_PC/jm-noscript" manual sessJM_0007)" "code=0" "ps1: flag on but no script: legacy path allows"
    assert_contains "code=$(ps1_jm "$TMPDIR_PC/jm-noflag" manual sessJM_0008)" "code=0" "ps1: script present, no flag file: legacy path allows (no delegation)"
    assert_contains "code=$(ps1_jm "$TMPDIR_PC/jm-noflag-thin" manual sessJM_0009)" "code=0" "ps1: script present, no flag file, thin bank: legacy path allows (no delegation)"
    # Detection must never read the flag as ON while it is off -- with a profile's strict error
    # preferences, and with no git at all. A misdetection runs the journal gate, which blocks here (2). WHY cygpath: the hook path sits inside a -Command
    # string, where Git Bash does not convert /c/... to C:/...
    hook_native="$HOOK_PS1"; command -v cygpath >/dev/null 2>&1 && hook_native="$(cygpath -m "$HOOK_PS1")"
    strict_code="$( (cd "$TMPDIR_PC/jm-noflag-thin" && jm_payload manual sessJM_0010 | pwsh -NoProfile -NonInteractive -Command "\$ErrorActionPreference='Stop'; \$PSNativeCommandUseErrorActionPreference=\$true; & '$hook_native'; exit \$LASTEXITCODE" >/dev/null 2>&1; echo $?) )"
    assert_contains "code=$strict_code" "code=0" "ps1: strict error preferences during detection: flag read as off, legacy path allows"
    # WHY a PATH holding only pwsh's own directory: git cannot be started, so the detection's git call
    # throws -- the case where both of the hook's guards (Test-PmbFlagOn's catch and the hook's own try)
    # are needed. pwsh itself is started by its full path.
    pwsh_bin="$(command -v pwsh)"; pwsh_dir="$(dirname "$pwsh_bin")"
    if PATH="$pwsh_dir" command -v git >/dev/null 2>&1; then
        echo "  SKIP: git sits beside pwsh, so a PATH without git cannot be built here"
    else
        nogit_code="$( (cd "$TMPDIR_PC/jm-noflag-thin" && jm_payload manual sessJM_0011 | PATH="$pwsh_dir" "$pwsh_bin" -NoProfile -NonInteractive -File "$HOOK_PS1" >/dev/null 2>&1; echo $?) )"
        assert_contains "code=$nogit_code" "code=0" "ps1: with git missing, detection reads the flag as off and the legacy path allows"
    fi
    assert_equals "$(jm_real_state)" "$JM_REAL_BEFORE" "no ps1 journal-mode case writes a session into the real pmb/"
else
    echo ""
    echo "--- sh/ps1 parity: SKIPPED (pwsh not on PATH) ---"
    echo "!!! WARNING: cross-shell parity assertions did NOT run. A sh/ps1 divergence cannot be"
    echo "!!! detected by this run. Set PMB_REQUIRE_PARITY=1 to make this a failure."
    if [ "${PMB_REQUIRE_PARITY:-0}" = "1" ]; then
        assert_contains "pwsh-missing" "pwsh-present" "PMB_REQUIRE_PARITY=1 but pwsh is not on PATH -- parity block could not run"
    fi
fi

# ── mirror parity: scripts/ and templates/scripts/ must not drift ───────────────────────────
# WHY: templates/ is what `mb upgrade` ships to adopters, so a fix landing in scripts/ alone is
# invisible here and broken there. This repo has already shipped that exact mistake once with
# dangerous-commands, and templates/scripts/pre-compact-check.sh has itself fallen behind before
# (7de75e6, syncing a bash optimization it missed). A byte comparison is the cheapest guard.
echo ""
echo "--- mirror parity: scripts/ vs templates/scripts/ ---"
diff -q "$REPO_ROOT/scripts/pre-compact-check.sh" "$REPO_ROOT/templates/scripts/pre-compact-check.sh" >/dev/null 2>&1
assert_exit_zero "$?" "scripts/pre-compact-check.sh and its templates/ mirror are byte-identical"
diff -q "$REPO_ROOT/scripts/pre-compact-check.ps1" "$REPO_ROOT/templates/scripts/pre-compact-check.ps1" >/dev/null 2>&1
assert_exit_zero "$?" "scripts/pre-compact-check.ps1 and its templates/ mirror are byte-identical"

print_summary
