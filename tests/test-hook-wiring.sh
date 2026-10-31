#!/usr/bin/env bash
# tests/test-hook-wiring.sh — run the EXACT settings.json hook command strings, not the scripts
#
# WHY this test exists: every other hook suite invokes scripts/X.ps1 or scripts/X.sh directly, so
# none of them sees what Claude Code actually runs -- the command string in .claude/settings.json,
# which chains `pwsh ... || bash ... || true`. Per Claude Code's hooks docs, stdout must be one JSON
# object starting with `{`; anything else is treated as plain text and the JSON is ignored. Two
# wiring defects broke that while every script-level test stayed green:
#   1. No -NoProfile: anything a user's PowerShell profile printed landed on stdout beside the JSON.
#   2. pwsh present, X.ps1 missing: pwsh printed its usage text to stdout (measured: 996 bytes,
#      rc 64) and `||` then ran bash, so stdout was usage text + the deny -- ignored, i.e. allowed.
# The PowerShell-matcher entries had no bash link at all, so a missing .ps1 left them ungated.
#
# Modes, each run against the strings verbatim (bash -c, cwd = a scratch repo, never the real tree):
#   present   -- both twins in place
#   deleted   -- THIS row's .ps1 removed (one script at a time)
#   broken    -- THIS row's .ps1 replaced by a parse error: pwsh exits 1 WITHOUT reading stdin, so
#                bash gets the full payload. This is the reason the `||` chain is kept over an
#                if/else runtime pick (docs/superpowers/plans/2026-08-20-hook-enforcement-integrity.md).
#   shim      -- a `pwsh` first on PATH that prints noise unless -NoProfile precedes -File
#   profile   -- Linux/macOS only: real pwsh with HOME pointed at a temp dir holding a printing profile
# Every mode, the reissue block's mixed case included, has a positive control, so none of them can
# pass by silently not happening.
#
# OUT OF SCOPE, deliberately: the PreCompact string. Whether that gate stays at all is an open
# decision (it can deadlock a session that can no longer take a turn), and that work would edit this
# exact string. Also out of scope: the live file's Stop entry, pre-approval-check (PMB-only, so the
# template has no copy, and on trial under its own design). It already has -NoProfile but no
# [ -f ] guard. Both are exempt from every check here by name, never executed (the Stop entry's last
# link opens a real desktop notification), and counted so the exemptions cannot widen silently.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/tests/helpers/assert.sh"

echo "=== settings.json hook wiring tests ==="

TMP_HW="$(mktemp -d 2>/dev/null || mktemp -d -t pmb-hook-wiring-test)"
# WHY abort: every fixture path below is "$TMP_HW/...", so an empty value would put the fixture repo,
# shim and payloads at the filesystem root.
[ -n "$TMP_HW" ] && [ -d "$TMP_HW" ] || { echo "FAIL: mktemp produced no scratch directory"; exit 1; }
# WHY cygpath: this dir goes on PATH for the shim mode, and a Windows-form entry ("C:/...") splits
# on the drive colon -- measured, the shim was silently skipped.
command -v cygpath >/dev/null 2>&1 && TMP_HW="$(cygpath -u "$TMP_HW")"
trap 'rm -rf "$TMP_HW"' EXIT

HAVE_PWSH=0
REAL_PWSH="$(command -v pwsh 2>/dev/null || true)"
[ -n "$REAL_PWSH" ] && HAVE_PWSH=1
if [ "$HAVE_PWSH" -eq 0 ]; then
    echo "!!! pwsh not on PATH -- every string runs its bash link only; the deleted/broken/shim/profile"
    echo "!!! modes collapse into 'pwsh absent' and are NOT exercised as such."
    if [ "${PMB_REQUIRE_PARITY:-}" = "1" ]; then
        assert_contains "pwsh-missing" "pwsh-present" "PMB_REQUIRE_PARITY=1 but pwsh is not on PATH"
    fi
fi

# ── extraction ──────────────────────────────────────────────────────────────────────────────
# One line per pwsh-invoking hook: event<US>matcher<US>command. WHY \x1f, not a tab: tab is IFS
# whitespace, so `read` would collapse PreCompact's empty matcher field. WHY stdin, not a path
# argument: MSYS path conversion of argv is the classic fixture bug here. WHY tr -d '\r': python's
# stdout on Windows writes CRLF, and a trailing \r inside a command string is a syntax error.
extract() {
    PYTHONIOENCODING=utf-8 python3 -c '
import json, sys
d = json.load(sys.stdin)
for ev, groups in d.get("hooks", {}).items():
    for g in groups:
        for h in g.get("hooks", []):
            c = h.get("command", "")
            if "pwsh" in c:
                sys.stdout.write(ev + "\x1f" + g.get("matcher", "") + "\x1f" + c + "\n")
' < "$1" 2>/dev/null | tr -d '\r'
}

SJ_LIVE="$REPO_ROOT/.claude/settings.json"
SJ_TMPL="$REPO_ROOT/templates/.claude/settings.json"
ROWS_LIVE="$(extract "$SJ_LIVE")"
ROWS_TMPL="$(extract "$SJ_TMPL")"

echo ""
echo "--- extraction: counted, two-way mapped, template identical ---"
# WHY an exact count and not "at least one": an empty extraction (e.g. the Windows Store python3
# alias, which prints nothing) would otherwise select zero strings and pass everything.
# To add a hook: bump this count, add a kind_of row and an ALL_KINDS entry, AND add its oracle to the
# per-mode loop below -- the mapping check only forces the first two. A hook whose command never
# names pwsh is not selected here at all.
# WHY the template comparison too, beside test-mirror-parity.sh's triple check: it also proves the
# template's extraction is non-empty, which that suite does not need. The live file's PMB-only Stop
# entry has no template copy, so it is left out of that comparison.
n_live=$(printf '%s\n' "$ROWS_LIVE" | grep -c .)
assert_equals "$n_live" "12" "live settings.json: exactly 12 pwsh-invoking hook strings (10 in scope + PreCompact + PMB-only Stop)"
ROWS_LIVE_SHARED="$(printf '%s\n' "$ROWS_LIVE" | grep -v '^Stop'$'\x1f')"
assert_equals "$ROWS_TMPL" "$ROWS_LIVE_SHARED" "template settings.json: the same pwsh hook strings as live (minus its PMB-only Stop entry), in the same order"

# kind_of <event> <matcher> <script> -- the case table. Every selected string must map to a row
# here; an unmapped one is a FAIL, so a new pwsh hook cannot be added without a mapping row. (That
# row alone gives it only the static check below -- its behavioural case is written by hand.)
kind_of() {
    case "$1 :: $2 :: $3" in
        "PreToolUse :: Bash :: dangerous-commands")              echo dc_bash ;;
        "PreToolUse :: PowerShell :: dangerous-commands")        echo dc_ps ;;
        "PreToolUse :: Bash :: review-reminders")                echo rr_bash ;;
        "PreToolUse :: PowerShell :: review-reminders")          echo rr_ps ;;
        "PreToolUse :: Write|Edit :: check-contract")            echo contract ;;
        "PreToolUse :: Write|Edit :: warn-stale-review-marker")  echo stale ;;
        "PreToolUse :: Agent :: delegation-depth-check")         echo depth ;;
        "PostToolUse :: Write|Edit :: update-reviewed")          echo reviewed ;;
        "PostToolUse :: Bash :: review-reminders-post")          echo post_bash ;;
        "PostToolUse :: PowerShell :: review-reminders-post")    echo post_ps ;;
        "PreCompact ::  :: pre-compact-check")                   echo exempt ;;
        "Stop ::  :: pre-approval-check")                        echo exempt_stop ;;
        *)                                                       echo UNMAPPED ;;
    esac
}
ALL_KINDS="dc_bash dc_ps rr_bash rr_ps contract stale depth reviewed post_bash post_ps exempt exempt_stop"

SEEN=" "
while IFS=$'\x1f' read -r ev matcher cmd; do
    [ -n "$ev" ] || continue
    script=$(printf '%s' "$cmd" | grep -oE 'scripts/[A-Za-z0-9_-]+\.ps1' | head -1 | sed 's#scripts/##; s#\.ps1$##')
    kind=$(kind_of "$ev" "$matcher" "$script")
    assert_not_contains "$kind" 'UNMAPPED' "mapped: $ev :: $matcher :: $script -> $kind"
    case "$SEEN" in *" $kind "*) assert_equals "$kind" "(unique)" "case row $kind matched by more than one string" ;; esac
    SEEN="$SEEN$kind "
    # Store each string under its kind; printf -v keeps it out of eval.
    printf -v "CMD_$kind" '%s' "$cmd"
    printf -v "SCRIPT_$kind" '%s' "$script"
done <<EOF
$ROWS_LIVE
EOF
for k in $ALL_KINDS; do
    case "$SEEN" in *" $k "*) ;; *) assert_equals "missing" "$k" "case row $k is matched by a settings.json string" ;; esac
done

# ── static: -NoProfile must come BEFORE -File ───────────────────────────────────────────────
# WHY position: after `-File x.ps1`, `-NoProfile` is a script argument and the profile still
# loads (measured: the script received it in $args).
echo ""
echo "--- static: every in-scope pwsh invocation has -NoProfile before -File ---"
for k in $ALL_KINDS; do
    case "$k" in exempt*) continue ;; esac
    v="CMD_$k"; c="${!v:-}"
    [ -n "$c" ] || continue
    pre="${c#*pwsh }"; pre="${pre%%-File*}"
    # Exact-case match: assert_contains greps case-insensitively, and a leading "-" would be read
    # as a grep option.
    case "$pre" in *-NoProfile*) r=0 ;; *) r=1 ;; esac
    assert_exit_zero "$r" "$k: -NoProfile precedes -File"
done

# ── static: every in-scope string is exactly the canonical form for its own script ─────────────
# WHY: the behavioural oracles cannot see a dropped or misnamed bash link on hooks whose twins print
# nothing in the fixture (check-contract, update-reviewed), and a wrong twin on a row whose payload
# another hook also denies. Mutation-tested in review: both survived 104/0 before this check.
echo ""
echo "--- static: each string's guard, -File and bash link name the same script, and both twins exist ---"
for k in $ALL_KINDS; do
    case "$k" in exempt*) continue ;; esac
    v="CMD_$k"; c="${!v:-}"; v="SCRIPT_$k"; s="${!v:-}"
    canon="[ -f scripts/$s.ps1 ] && pwsh -NoProfile -NonInteractive -File scripts/$s.ps1 2>/dev/null || bash scripts/$s.sh 2>/dev/null || true"
    assert_equals "$c" "$canon" "$k: canonical guarded form for scripts/$s"
    [ -f "$REPO_ROOT/scripts/$s.ps1" ] && [ -f "$REPO_ROOT/scripts/$s.sh" ]
    assert_exit_zero "$?" "$k: both scripts/$s.ps1 and scripts/$s.sh exist"
done

# ── fixture ─────────────────────────────────────────────────────────────────────────────────
# A real repo with a commit and a TRACKED modification: with an empty `git diff HEAD` the review gate
# denies through its empty-diff branch and never reaches the marker check (measured). scripts/ and
# .claude/ are excluded from git so deleting or breaking a .ps1 does not change the hashed diff.
FX="$TMP_HW/fx"
PRISTINE="$TMP_HW/pristine"
mkdir -p "$FX/.claude"
cp -R "$REPO_ROOT/scripts" "$FX/scripts"
cp -R "$REPO_ROOT/scripts" "$PRISTINE"
git -C "$FX" init -q
git -C "$FX" config user.email "test@example.com"
git -C "$FX" config user.name "Test"
printf 'scripts/\n.claude/\n.pmb-delegation-depth\n' >> "$FX/.git/info/exclude"
printf 'one\n' > "$FX/tracked.txt"
git -C "$FX" add tracked.txt
git -C "$FX" commit -q -m "initial"
printf 'two\n' >> "$FX/tracked.txt"
# WHY staged: the commit gate refuses while tracked changes are unstaged (review-reminders, the
# "tracked changes are unstaged" deny), which fires before the marker check this suite targets.
git -C "$FX" add tracked.txt

# Payload files, built by python so no quoting reaches a shell.
mkp() { python3 -c 'import json,sys; print(json.dumps({"tool_name":sys.argv[1],"tool_input":{sys.argv[2]:sys.argv[3]}}))' "$1" "$2" "$3" > "$TMP_HW/$4.json"; }
mkp Bash       command "rm -rf /"                          p_dc_bash
mkp PowerShell command "git push --force origin main"      p_dc_ps
mkp PowerShell command "Remove-Item -Recurse -Force .\\build" p_dc_ps_gap
mkp Bash       command "git commit -m x"                   p_commit_bash
mkp PowerShell command "git commit -m x"                   p_commit_ps
mkp Write      file_path "$FX/notes.txt"                   p_write
mkp Agent      prompt "do a thing"                         p_agent

# Shim: prints noise unless -NoProfile appears before -File, then hands off to the real pwsh.
SHIM_DIR="$TMP_HW/shim"
mkdir -p "$SHIM_DIR"
cat > "$SHIM_DIR/pwsh" <<EOF
#!/usr/bin/env bash
np=
for a in "\$@"; do case "\$a" in -NoProfile) np=1 ;; -File) break ;; esac; done
[ -n "\$np" ] || echo "PROFILE-NOISE"
exec "$REAL_PWSH" "\$@"
EOF
chmod +x "$SHIM_DIR/pwsh"

# Linux/macOS real-profile mode: pwsh resolves CurrentUser profiles under $HOME/.config/powershell
# (XDG_CONFIG_HOME when set). Not available on Windows, where the profile path comes from the
# registry and redirecting it would mean touching the user's real profile.
PROF_HOME="$TMP_HW/home"
mkdir -p "$PROF_HOME/.config/powershell"
printf 'Write-Output "REAL-PROFILE-NOISE"\n' > "$PROF_HOME/.config/powershell/Microsoft.PowerShell_profile.ps1"

MODE=present
# run <cmd> <payload-name> -- stdout bytes to $TMP_HW/out (\r stripped), under the current MODE's env.
run() {
    ( cd "$FX" || exit 99
      case "$MODE" in
          shim)    PATH="$SHIM_DIR:$PATH" bash -c "$1" ;;
          profile) HOME="$PROF_HOME" XDG_CONFIG_HOME="$PROF_HOME/.config" bash -c "$1" ;;
          *)       bash -c "$1" ;;
      esac ) < "$TMP_HW/$2.json" 2>/dev/null | tr -d '\r' > "$TMP_HW/out"
}

# shape -- EMPTY (0 bytes), INVALID, or "OBJ <permissionDecision or ->" + newline + reason.
# WHY first byte `{`: json.loads accepts leading whitespace; the documented rule does not.
shape() {
    PYTHONIOENCODING=utf-8 python3 -c '
import json, sys
t = sys.stdin.read()
if t == "":
    print("EMPTY"); sys.exit(0)
if not t.startswith("{") or not t.rstrip().endswith("}"):
    print("INVALID"); sys.exit(0)
try:
    d = json.loads(t)
except Exception:
    print("INVALID"); sys.exit(0)
if not isinstance(d, dict):
    print("INVALID"); sys.exit(0)
h = d.get("hookSpecificOutput") or {}
print("OBJ " + str(h.get("permissionDecision", "-")))
print(str(h.get("permissionDecisionReason", "")))
' < "$TMP_HW/out"
}
verdict() { shape | head -1; }

# set_mode <mode> <script...> -- restore every .ps1, then break the named ones for this mode.
set_mode() {
    MODE="$1"; shift
    cp "$PRISTINE"/*.ps1 "$FX/scripts/"
    local s
    for s in "$@"; do
        case "$MODE" in
            deleted) rm -f "$FX/scripts/$s.ps1" ;;
            broken)  printf 'if (\n' > "$FX/scripts/$s.ps1" ;;
        esac
    done
}

MODES="present"
if [ "$HAVE_PWSH" -eq 1 ]; then
    MODES="present deleted broken shim"
    case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) ;; *) MODES="$MODES profile" ;; esac
fi

# ── positive controls: a mode that does not happen must fail, not pass ─────────────────────
if [ "$HAVE_PWSH" -eq 1 ]; then
    echo ""
    echo "--- positive controls ---"
    CTRL="${CMD_dc_bash:-}"; CTRL="${CTRL//-NoProfile /}"
    set_mode shim
    run "$CTRL" p_dc_bash
    assert_equals "$(head -1 "$TMP_HW/out")" "PROFILE-NOISE" "control: shim is first on PATH -- the string WITHOUT -NoProfile prints its noise"
    set_mode deleted dangerous-commands
    [ -f "$FX/scripts/dangerous-commands.ps1" ]; assert_exit_nonzero "$?" "control: deleted mode really removes the .ps1"
    set_mode broken dangerous-commands
    (cd "$FX" && pwsh -NoProfile -NonInteractive -File scripts/dangerous-commands.ps1 </dev/null >/dev/null 2>&1)
    assert_exit_nonzero "$?" "control: broken mode's .ps1 really fails in pwsh"
    case " $MODES " in *" profile "*)
        set_mode profile
        run "$CTRL" p_dc_bash
        assert_equals "$(head -1 "$TMP_HW/out")" "REAL-PROFILE-NOISE" "control: the planted profile really loads when -NoProfile is absent"
    ;; esac
fi

# ── per-case oracles ────────────────────────────────────────────────────────────────────────
for mode in $MODES; do
    echo ""
    echo "--- mode: $mode ---"

    # Deny cases: EMPTY must never pass these.
    set_mode "$mode" dangerous-commands
    # WHY the reason too: the force-push payload is also denied by the review gate's push check, so a
    # deny alone cannot tell dangerous-commands' fallback from a wrong twin.
    run "${CMD_dc_bash:-}" p_dc_bash
    s=$(shape)
    assert_equals "$(printf '%s\n' "$s" | head -1)" "OBJ deny" "$mode: Bash dangerous-commands, recursive delete -> exactly one deny object"
    assert_contains "$s" "BLOCK:" "$mode: Bash dangerous-commands deny comes from dangerous-commands (BLOCK:)"
    run "${CMD_dc_ps:-}" p_dc_ps
    s=$(shape)
    assert_equals "$(printf '%s\n' "$s" | head -1)" "OBJ deny" "$mode: PowerShell dangerous-commands, force push -> exactly one deny object"
    assert_contains "$s" "BLOCK:" "$mode: PowerShell dangerous-commands deny comes from dangerous-commands (BLOCK:)"
    # KNOWN GAP, pinned: the .sh twin has none of the five PowerShell-native BLOCK rows (Remove-Item,
    # Format-Volume, pipe-to-iex), so when the PowerShell matcher falls back to bash they are not
    # blocked. "No deny" rather than "EMPTY" so the assertion describes the gap, not the bytes. Porting
    # the rows to the .sh turns this red -- then delete this case and the gap's mentions in the docs.
    run "${CMD_dc_ps:-}" p_dc_ps_gap
    gap="$mode"; [ "$HAVE_PWSH" -eq 0 ] && gap=deleted   # no pwsh: the bash link is all there is
    case "$gap" in
        deleted|broken) assert_not_contains "$(verdict)" "deny" "$mode: KNOWN GAP -- PowerShell Remove-Item is not blocked by the bash fallback" ;;
        *)              assert_equals "$(verdict)" "OBJ deny" "$mode: PowerShell Remove-Item -Recurse -Force -> deny (the .ps1 ran)" ;;
    esac

    set_mode "$mode" review-reminders
    rm -f "$FX/.claude/.code-review-ok"
    for k in rr_bash rr_ps; do
        v="CMD_$k"; p=p_commit_bash; [ "$k" = rr_ps ] && p=p_commit_ps
        run "${!v:-}" "$p"
        s=$(shape)
        assert_equals "$(printf '%s\n' "$s" | head -1)" "OBJ deny" "$mode: $k, git commit without a marker -> exactly one deny object"
        assert_contains "$s" "Run /code-review before committing" "$mode: $k deny comes from the marker check, not the empty-diff branch"
    done

    # Advisory cases: exactly one object where the hook has something to say, else EMPTY.
    set_mode "$mode" warn-stale-review-marker
    printf 'x' > "$FX/.claude/.code-review-ok"
    run "${CMD_stale:-}" p_write
    assert_equals "$(verdict)" "OBJ -" "$mode: warn-stale-review-marker with a marker present -> exactly one object"
    rm -f "$FX/.claude/.code-review-ok"

    set_mode "$mode" delegation-depth-check
    printf 'depth=6\ntimestamp=%s' "$(date '+%Y-%m-%d %H:%M')" > "$FX/.pmb-delegation-depth"
    run "${CMD_depth:-}" p_agent
    assert_equals "$(verdict)" "OBJ -" "$mode: delegation-depth-check over budget -> exactly one object"
    rm -f "$FX/.pmb-delegation-depth"

    set_mode "$mode" check-contract
    run "${CMD_contract:-}" p_write
    assert_equals "$(verdict)" "EMPTY" "$mode: check-contract with no contract -> no output"

    set_mode "$mode" update-reviewed
    run "${CMD_reviewed:-}" p_write
    assert_equals "$(verdict)" "EMPTY" "$mode: update-reviewed -> no output"
done

# ── marker reissue: a commit that consumed a valid marker and then failed gets it back ─────
# Both matchers, every mode, plus the mixed case (pre .ps1 present, post .ps1 deleted). The pre
# hook consumes the marker and records HEAD; no commit happens, so the post hook sees HEAD
# unchanged and reissues. Before this change the PowerShell post string had no bash link, so a
# missing review-reminders-post.ps1 lost the marker.
echo ""
echo "--- review-gate marker reissue through the pre/post string pair ---"
# shellcheck disable=SC1091
H=$(cd "$FX" && . scripts/_review-gate-lib.sh && diff_hash HEAD)
assert_contains "$H" '^[0-9a-f]\{64\}$' "fixture: the review-gate diff hash is computable"
REISSUE_MODES="$MODES"
[ "$HAVE_PWSH" -eq 1 ] && REISSUE_MODES="$REISSUE_MODES mixed"
for mode in $REISSUE_MODES; do
    case "$mode" in
        shim|profile) continue ;;   # covered by the stdout oracles above; this block checks state
        mixed)        set_mode present; rm -f "$FX/scripts/review-reminders-post.ps1"
                      [ -f "$FX/scripts/review-reminders-post.ps1" ]
                      assert_exit_nonzero "$?" "control: mixed mode really removes review-reminders-post.ps1"
                      [ -f "$FX/scripts/review-reminders.ps1" ]
                      assert_exit_zero "$?" "control: mixed mode keeps review-reminders.ps1" ;;
        *)            set_mode "$mode" review-reminders review-reminders-post ;;
    esac
    for side in bash ps; do
        pre="CMD_rr_$side"; post="CMD_post_$side"; p=p_commit_bash; [ "$side" = ps ] && p=p_commit_ps
        printf '%s' "$H" > "$FX/.claude/.code-review-ok"
        rm -f "$FX/.claude/.pending-commit-presha"
        run "${!pre:-}" "$p"
        assert_equals "$(verdict)" "EMPTY" "$mode/$side: pre hook allows a commit with a valid marker"
        [ -f "$FX/.claude/.code-review-ok" ]; assert_exit_nonzero "$?" "$mode/$side: pre hook consumed the marker"
        run "${!post:-}" "$p"
        assert_equals "$(verdict)" "EMPTY" "$mode/$side: post hook prints nothing"
        assert_file_exists "$FX/.claude/.code-review-ok" "$mode/$side: post hook reissued the marker after the commit did not land"
    done
done

print_summary
