#!/usr/bin/env bash
# tests/test-merge-gate.sh — the merge branch of review-reminders.sh/.ps1 end to end
#
# WHY this suite exists: the gate used to deny every `gh pr merge` unconditionally. It now
# returns "ask" -- a permission prompt the user answers -- for exactly one canonical,
# repo-pinned form, and denies everything else (spec:
# docs/superpowers/specs/2026-10-20-merge-gate-user-approval-design.md). A regression in either
# direction matters: an ask that turns into allow merges with no human, and a deny that turns
# into "no decision" hands the call to auto mode's classifier. So every case asserts the exact
# decision, and both twins run the SAME fixture table, because production runs pwsh first and
# bash only as its fallback.
#
# WHY a separate suite rather than more rows in test-review-reminders.sh: that file is being
# edited by an open PR (#79), and the merge gate is self-contained enough to stand alone.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/tests/helpers/assert.sh"

echo "=== merge gate (review-reminders MERGE branch) tests ==="

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIPPED (python3 not installed: the fixtures are built with it, and without it the bash"
  echo "         hook denies every merge through its raw fallback, covered below on machines that have it)"
  if [ "${PMB_REQUIRE_PARITY:-0}" = "1" ]; then
    assert_contains "python3-missing" "python3-present" "PMB_REQUIRE_PARITY=1 but python3 is not on PATH -- the merge gate suite could not run"
  fi
  print_summary
  exit $?
fi
HAVE_PWSH=0
command -v pwsh >/dev/null 2>&1 && HAVE_PWSH=1
if [ "$HAVE_PWSH" -eq 0 ] && [ "${PMB_REQUIRE_PARITY:-0}" = "1" ]; then
  assert_contains "pwsh-missing" "pwsh-present" "PMB_REQUIRE_PARITY=1 but pwsh is not on PATH -- the PowerShell twin could not run"
fi

TMP_MG="$(mktemp -d 2>/dev/null || mktemp -d -t mb-mg-test)"
trap 'rm -rf "$TMP_MG"' EXIT

# Native path for pwsh on Windows; unchanged elsewhere.
native() { cygpath -m "$1" 2>/dev/null || printf '%s' "$1"; }

PROJ="$TMP_MG/proj"
CFG="$TMP_MG/cfg"
mkdir -p "$PROJ/.claude" "$CFG"
# A git repo so the unknown-verdict case below reaches the hook's verdict switch instead of
# being denied earlier for an unresolvable root.
git -C "$PROJ" init -q 2>/dev/null
# A repo name with a dot proves the allowlist value is regex-escaped (acme/webXapp must not match).
printf '%s\n' '{"repos": ["acme/web.app"]}' > "$PROJ/.claude/merge-gate.json"

SHA=0123456789abcdef0123456789abcdef01234567
CANON="gh pr merge 12 -R acme/web.app --squash --match-head-commit $SHA"
DESC='Merge pull request (verify the details in the hook reason)'

# mkpayload <file> <python-dict-expression>  -- the payload is built by json.dumps, so commands
# carrying quotes, newlines, CR or non-ASCII reach the hook exactly as Claude Code would send them.
# MSYS_NO_PATHCONV: on Git Bash, an argument containing "/usr/bin/" is rewritten to a Windows path
# before native python sees it, which silently turned the path-qualified-gh case into a different
# command (measured 2026-10-20). With conversion off, the output file's own path must be passed
# native, or Windows python writes it somewhere else.
mkpayload() {
  MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' CANON="$CANON" SHA="$SHA" DESC="$DESC" python3 -c '
import json, os, sys
C, SHA, DESC = os.environ["CANON"], os.environ["SHA"], os.environ["DESC"]
def p(cmd, mode="default", **extra):
    d = {"session_id": "s", "hook_event_name": "PreToolUse", "tool_name": "Bash",
         "tool_input": {"command": cmd}}
    if mode is not None:
        d["permission_mode"] = mode
    ti = extra.pop("tool_input_extra", {})
    d["tool_input"].update(ti)
    d.update(extra)
    return d
with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump(eval(sys.argv[2]), f)
' "$(native "$1")" "$2"
}

# run_sh / run_ps1 <payload-file> [scripts-dir]  -> hook stdout (stderr dropped, as in production)
# LIMIT, when a row sets it, prefixes the hook with `timeout N`, so a hang fails that row (exit 124)
# instead of stalling the suite. Empty where timeout(1) is missing (stock macOS).
run_sh() {
  local dir="${2:-$REPO_ROOT/scripts}"
  (cd "$PROJ" && env -u GH_HOST -u GH_REPO -u GH_CONFIG_DIR CLAUDE_PROJECT_DIR="$(native "$PROJ")" \
     CLAUDE_CONFIG_DIR="$(native "$CFG")" ${EXTRA_ENV:-} ${LIMIT:-} bash "$dir/review-reminders.sh" < "$1" 2>/dev/null)
}
run_ps1() {
  local dir="${2:-$REPO_ROOT/scripts}"
  (cd "$PROJ" && env -u GH_HOST -u GH_REPO -u GH_CONFIG_DIR CLAUDE_PROJECT_DIR="$(native "$PROJ")" \
     CLAUDE_CONFIG_DIR="$(native "$CFG")" ${EXTRA_ENV:-} ${LIMIT:-} \
     pwsh -NoProfile -NonInteractive -File "$(native "$dir/review-reminders.ps1")" < "$1" 2>/dev/null)
}
TIMEOUT=""
command -v timeout >/dev/null 2>&1 && TIMEOUT="timeout"

# expect <ask|deny|none> <label> <payload-file> [scripts-dir] [reason-substring] -- runs BOTH twins.
# Every outcome must also exit 0: a non-zero exit after a printed decision would run the wiring's
# `|| bash` fallback as well. The reason substring pins WHICH check denied, so a deny from an
# earlier, unrelated check cannot pass for the one a row is about. Substrings avoid quotes and
# apostrophes, which the two twins' JSON encoders escape differently.
expect() {
  local want="$1" label="$2" file="$3" dir="${4:-}" reason="${5:-}" twin out rc n ok
  LAST_OUT_SH=""; LAST_OUT_PS1=""
  for twin in sh ps1; do
    if [ "$twin" = ps1 ] && [ "$HAVE_PWSH" -eq 0 ]; then continue; fi
    out=$("run_$twin" "$file" $dir); rc=$?
    ok=0
    case "$want" in
      ask)
        n=$(printf '%s\n' "$out" | grep -c '^{')
        printf '%s' "$out" | grep -q '"permissionDecision":"ask"' && [ "$n" -eq 1 ] && ok=1 ;;
      deny)
        printf '%s' "$out" | grep -q '"permissionDecision":"deny"' && ! printf '%s' "$out" | grep -q '"ask"' && ok=1 ;;
      none)
        [ -z "$out" ] && ok=1 ;;
    esac
    [ "$rc" -eq 0 ] || ok=0
    if [ -n "$reason" ]; then
      case "$out" in *"$reason"*) ;; *) ok=0 ;; esac
    fi
    if [ "$ok" -eq 1 ]; then
      echo "  PASS: [$twin] $want: $label"; PASS=$((PASS + 1))
    else
      echo "  FAIL: [$twin] $want: $label (exit $rc${reason:+, reason should contain: $reason})"
      echo "    got: $out"; FAIL=$((FAIL + 1))
    fi
    if [ "$twin" = sh ]; then LAST_OUT_SH="$out"; else LAST_OUT_PS1="$out"; fi
  done
}

F="$TMP_MG/payload.json"
case_() {  # case_ <ask|deny|none> <label> <python-expression> [reason-substring]
  mkpayload "$F" "$3"
  expect "$1" "$2" "$F" "" "${4:-}"
}

# Reason substrings, one per deny path that matters for security.
R_FORM="only in exactly this form"
R_SUB="Subagents never merge"
R_MODE="only put to the user in default, acceptEdits or auto mode"
R_DESC="Set the tool description to exactly"
R_GENERIC="Merge gate precondition failed"
R_NOCHECK="the check could not run here"

[ "$HAVE_PWSH" -eq 0 ] && echo "  NOTE: pwsh not installed -- only the bash twin runs"

echo "--- the canonical form is asked ---"
case_ ask  "squash, default mode"                 'p(C)'
case_ ask  "--merge, acceptEdits mode"            'p(C.replace("--squash", "--merge"), "acceptEdits")'
case_ ask  "auto mode"                            'p(C, "auto")'
case_ ask  "the exact fixed description"          'p(C, tool_input_extra={"description": DESC})'
mkpayload "$F" 'p(C)'
out=$(run_sh "$F")
assert_contains "$out" "Merge PR #12 in acme/web.app by squash, exactly at head $SHA" \
  "reason names the PR, the repo, the method and the full SHA"
assert_contains "$out" "Approve only if YOU asked" "reason tells the user when to approve"

echo "--- every other command shape is denied ---"
case_ deny "-R missing"                           'p(C.replace(" -R acme/web.app", ""))'
case_ deny "-R names another repo"                'p(C.replace("acme/web.app", "acme/other"))' "$R_FORM"
case_ deny "allowlist value is regex-escaped"     'p(C.replace("acme/web.app", "acme/webXapp"))' "$R_FORM"
case_ deny "no --match-head-commit"               'p(C.split(" --match-head-commit")[0])'
case_ deny "short SHA"                            'p(C.replace(SHA, SHA[:7]))'
case_ deny "uppercase SHA"                        'p(C.replace(SHA, SHA.upper()))'
case_ deny "PR number with a leading zero"        'p(C.replace(" 12 ", " 012 "))'
case_ deny "PR number of 10 digits"               'p(C.replace(" 12 ", " 1234567890 "))'
case_ deny "--admin appended"                     'p(C + " --admin")' "$R_FORM"
case_ deny "--auto appended"                      'p(C + " --auto")'
case_ deny "--delete-branch appended"             'p(C + " --delete-branch")'
case_ deny "--rebase method"                      'p(C.replace("--squash", "--rebase"))'
case_ deny "flag order swapped"                   'p(f"gh pr merge 12 --squash -R acme/web.app --match-head-commit {SHA}")'
case_ deny "doubled space"                        'p(C.replace(" -R", "  -R"))'
case_ deny "uppercase flag"                       'p(C.replace("--squash", "--SQUASH"))'
case_ deny "trailing ; x"                         'p(C + "; echo x")' "$R_FORM"
case_ deny "trailing && x"                        'p(C + " && echo x")'
case_ deny "trailing & x"                         'p(C + " & echo x")'
case_ deny "trailing | x"                         'p(C + " | cat")'
case_ deny "trailing newline"                     'p(C + "\n")'
case_ deny "newline then a second command"        'p(C + "\necho x")'
case_ deny "trailing CR"                          'p(C + "\r")'
case_ deny "trailing # comment"                   'p(C + " # c")'
case_ deny "trailing redirection"                 'p(C + " > f")'
case_ deny "command substitution appended"        'p(C + " $(echo x)")'
case_ deny "PowerShell backtick escape appended"  'p(C + " `--admin`")'
case_ deny "VAR= prefix"                          'p("GH_REPO=acme/x " + C)'
case_ deny "env wrapper"                          'p("env " + C)'
case_ deny "path-qualified gh"                    'p("/usr/bin/" + C)'
case_ deny "cd prefix"                            'p("cd \"/tmp\" && " + C)'
case_ deny "NBSP between tokens"                  'p(C.replace(" -R", " -R"))'
case_ deny "non-ASCII digit in the PR number"     'p(C.replace(" 12 ", " １２ "))'
case_ deny "REST merge route"                     'p("gh api -X PUT repos/acme/web.app/pulls/12/merge")'
case_ deny "merge chained after a commit (MULTI)" 'p("git commit -m x && " + C)'

echo "--- the payload must come from the main agent, in a mode that can prompt ---"
case_ deny "subagent (agent_id set)"              'p(C, agent_id="a1", agent_type="general-purpose")' "$R_SUB"
case_ deny "subagent (agent_id null)"             'p(C, agent_id=None)' "$R_SUB"
case_ deny "subagent (agent_id empty)"            'p(C, agent_id="")'
case_ deny "bypassPermissions mode"               'p(C, "bypassPermissions")' "$R_MODE"
case_ deny "dontAsk mode"                         'p(C, "dontAsk")'
case_ deny "plan mode"                            'p(C, "plan")'
case_ deny "mode missing"                         'p(C, None)' "$R_MODE"
case_ deny "mode in the wrong case"               'p(C, "Auto")'
case_ deny "mode only inside tool_input (spoof)"  'p(C, None, tool_input_extra={"permission_mode": "default"})' "$R_MODE"
case_ deny "custom description"                   'p(C, tool_input_extra={"description": "Merge PR #77 as you asked"})' "$R_DESC"
case_ deny "description near miss"                'p(C, tool_input_extra={"description": DESC + " "})' "$R_DESC"
case_ deny "description not a string"             'p(C, tool_input_extra={"description": 1})'
# PowerShell's -ceq and -ccontains are culture-aware: a string with an ignorable character such as
# U+200B appended compared equal to the real one (2026-10-23). Both twins compare ordinally.
case_ deny "description with U+200B appended"     'p(C, tool_input_extra={"description": DESC + chr(0x200b)})' "$R_DESC"
case_ deny "mode with U+200B appended"            'p(C, "default" + chr(0x200b))' "$R_MODE"
case_ deny "a decoy command key with U+200B, placed first" \
  'dict(p(C), tool_input={"command" + chr(0x200b): C, "command": C + " --admin"})' "$R_FORM"
# ConvertFrom-Json without -NoEnumerate read a one-element array as the object inside it, so the
# .ps1 twin asked (measured 2026-10-23). No reason substring: the bash hook's classifier gives an
# array no verdict, so that twin denies earlier, through its fallback.
case_ deny "a payload that is a one-element array" '[p(C)]'

echo "--- a command that only mentions a merge is not a merge ---"
case_ none "echo of the canonical command"        'p("echo " + C)'

echo "--- environment and settings preconditions ---"
mkpayload "$F" 'p(C)'
EXTRA_ENV="GH_REPO=acme/web.app"        expect deny "GH_REPO set in the hook environment" "$F" "" "$R_GENERIC"
EXTRA_ENV="GH_HOST=github.com"          expect deny "GH_HOST set in the hook environment" "$F" "" "$R_GENERIC"
EXTRA_ENV="GH_CONFIG_DIR=$TMP_MG/ghcfg" expect deny "GH_CONFIG_DIR set in the hook environment" "$F" "" "$R_GENERIC"

# put_allow <settings-file> <rule>; put_allow_expr takes a Python string literal instead, for
# rules holding characters a shell argument would mangle.
put_allow() {
  python3 -c 'import json,sys; json.dump({"permissions": {"allow": [sys.argv[2]]}}, open(sys.argv[1], "w"))' "$1" "$2"
}
put_allow_expr() {
  python3 -c 'import json,sys; json.dump({"permissions": {"allow": [eval(sys.argv[2])]}}, open(sys.argv[1], "w"))' "$1" "$2"
}

# Each of the three files the helper reads, so dropping one from its list is caught.
LOCAL="$PROJ/.claude/settings.local.json"
for target in "$CFG/settings.json" "$PROJ/.claude/settings.json" "$LOCAL"; do
  put_allow "$target" 'Bash(gh api *)'
  expect deny "merge-capable allow rule in ${target#"$TMP_MG"/}" "$F" "" "$R_GENERIC"
  rm -f "$target"
done

# The first rows are rule shapes; from 'Bash(gh pr m*)' on they are caught by matching each rule
# as a wildcard pattern against the merge spellings, as Claude Code would. The last three need,
# in turn, the matcher's trailing :* reading, its trailing-star loop, and the --merge probe.
for rule in 'Bash' 'Bash(*)' 'PowerShell(*)' 'Bash(gh *)' 'Bash(gh:*)' 'Bash(gh api *)' \
            'Bash(gh -R acme/x *)' 'Bash(gh pr *)' 'Bash(gh pr merge:*)' 'PowerShell(gh pr merge *)' \
            "Bash(python3 -c ' *)" 'Bash(node -e *)' "Bash(pwsh -NoProfile -Command ' *)" \
            'Bash(Python3 -c *)' 'Bash(gh pr m*)' 'Bash(g*)' 'Bash(gh a*)' 'Bash(*merge*)' \
            'Bash(gh * pr merge *)' 'Bash(gh pr * -R acme/web.app *)' \
            'Bash(g*:*)' 'Bash(gh pr m*e 1 --squash*)' 'Bash(* --merge --match-head-commit*)'; do
  put_allow "$LOCAL" "$rule"
  expect deny "merge-capable allow rule: $rule" "$F" "" "$R_GENERIC"
  assert_not_contains "$LAST_OUT_SH$LAST_OUT_PS1" "settings.local" "deny for '$rule' names no settings file (both twins)"
  assert_not_contains "$LAST_OUT_SH$LAST_OUT_PS1" "gh api" "deny for '$rule' names no rule (both twins)"
done
# Whitespace the two regex engines' \s disagree on (\x1c-\x1f), and Unicode whitespace that
# Python's old re.ASCII interpreter check missed: both twins now read them alike.
for expr in '"Bash(python3" + chr(0x2003) + "-c *)"' '"Bash(python3\x1c-c *)"' '"\x1cBash(*)"' \
            '"Bash( * )"' '"Bash(*) "' '"Bash(\x1c*)"' '"Bash(*)\x1c"'; do
  put_allow_expr "$LOCAL" "$expr"
  expect deny "merge-capable allow rule with unusual whitespace: $expr" "$F" "" "$R_GENERIC"
done
for rule in 'Bash(git *)' 'Bash(gh pr view *)' 'Bash(npm run *)' 'Bash(gh apix *)' 'Bash(python -m pytest *)' \
            'Bash(gh pr .*)'; do
  put_allow "$LOCAL" "$rule"
  expect ask "unrelated allow rule leaves the prompt: $rule" "$F"
done
# The probes use PR 1 and a zero SHA, so each of these misses all of them. They match only the
# asked command, #12 at a SHA ending in 7, which every rule is matched against after the full match.
for rule in 'Bash(gh pr m* 12*)' 'Bash(*pr merge 12*)' 'Bash(* 12 -R *)' 'Bash(*--match-head-commit 0123*)' \
            'Bash(gh p*7)' 'PowerShell(gh p*7)'; do
  put_allow "$LOCAL" "$rule"
  expect deny "allow rule that matches only the asked command: $rule" "$F" "" "$R_GENERIC"
  assert_not_contains "$LAST_OUT_SH$LAST_OUT_PS1" "settings.local" "deny for '$rule' names no settings file (both twins)"
done
for rule in 'Bash(gh pr m* 77*)' 'Bash(gh p*8)'; do
  put_allow "$LOCAL" "$rule"
  expect ask "the same shape for another PR or SHA leaves the prompt: $rule" "$F"
done
# The long s case-folds to s in Python's Unicode IGNORECASE but not in .NET's, so the interpreter
# check folds ASCII letters only, in both twins.
put_allow_expr "$LOCAL" '"Bash(ba" + chr(0x17f) + "h -c *)"'
expect ask "a non-ASCII look-alike letter is not folded into an interpreter name" "$F"

echo "--- the settings check stays fast on hostile settings, and fails closed at its caps ---"
# A regex glob took 23 s on a 10-star rule (2026-10-21); a hook past its timeout gives no
# decision. This rule has 15. Each twin runs under timeout(1), so a regression fails the row
# (exit 124) rather than hanging the suite.
put_allow_expr "$LOCAL" '"Bash(" + "*0" * 14 + "*x)"'
started=$SECONDS
LIMIT="${TIMEOUT:+$TIMEOUT 60}" expect ask "a many-star rule that matches no merge is answered, not stalled on" "$F"
assert_equals "$(( SECONDS - started < 30 ))" 1 "both twins answer the many-star rule in under 30 s (took $(( SECONDS - started )) s)"
# A regex whitespace strip was quadratic in rule length, under a 4,096-character cap but with no
# cap on the number of rules: 33 ms per 4,092-character rule in the .py twin, 6.4 ms in the .ps1
# one (2026-10-23), so 3,000 such rules would take about 99 s and 19 s. Each twin is timed on its
# own, so a regression in either one fails its row.
python3 -c 'import json,sys; json.dump({"permissions": {"allow": ["Read(" + " " * 4085 + "x)"] * 3000}}, open(sys.argv[1], "w"))' "$LOCAL"
LIMIT="${TIMEOUT:+$TIMEOUT 60}" expect ask "3,000 long whitespace-padded non-Bash rules are answered, not stalled on" "$F"
for twin in sh ps1; do
  if [ "$twin" = ps1 ] && [ "$HAVE_PWSH" -eq 0 ]; then continue; fi
  started=$SECONDS
  LIMIT="${TIMEOUT:+$TIMEOUT 60}" "run_$twin" "$F" >/dev/null
  assert_equals "$(( SECONDS - started < 8 ))" 1 "[$twin] answers the long-rule file in under 8 s (took $(( SECONDS - started )) s)"
done
# The strip's character set and the matching regex class are two spellings of one set.
ws_ok=$(python3 -I -B -c '
import importlib.util, re, sys
s = importlib.util.spec_from_file_location("m", sys.argv[1]); m = importlib.util.module_from_spec(s)
s.loader.exec_module(m)
print(set(m.WS_CHARS) == {chr(c) for c in range(0x3100) if re.fullmatch(m.WS, chr(c))})
' "$(native "$REPO_ROOT/scripts/_review-gate-merge.py")")
assert_equals "$ws_ok" "True" "[py] WS_CHARS holds exactly the characters the WS class matches"
put_allow_expr "$LOCAL" '"Bash(" + "x" * 4100 + ")"'
expect deny "a rule longer than the length cap counts as merge-capable" "$F" "" "$R_GENERIC"
# 600 near-miss rules spend more than the shared step budget, which then counts as merge-capable.
python3 -c 'import json,sys; json.dump({"permissions": {"allow": ["Bash(*" + "0" * 39 + "x)"] * 600}}, open(sys.argv[1], "w"))' "$LOCAL"
expect deny "rules that exhaust the wildcard step budget deny" "$F" "" "$R_GENERIC"
python3 -c 'import json,sys; json.dump({"permissions": {"allow": ["Bash(*" + "0" * 39 + "x)"] * 50}}, open(sys.argv[1], "w"))' "$LOCAL"
expect ask "the same rules within the budget still ask" "$F"
# 460 fit the budget for the probes alone (177,560 steps) but not with the asked-command pass
# (225,400), so they deny only while that pass spends the same budget.
python3 -c 'import json,sys; json.dump({"permissions": {"allow": ["Bash(*" + "0" * 39 + "x)"] * 460}}, open(sys.argv[1], "w"))' "$LOCAL"
expect deny "the asked-command pass spends the same step budget" "$F" "" "$R_GENERIC"

echo "--- settings and allowlist are read as strict JSON, alike in both twins ---"
# ConvertFrom-Json alone accepted each of these, and Python accepted NaN; a one-element array
# read as the object inside it in the PowerShell twin.
for body in '{"permissions": {"allow": []}} // c' '{"permissions": {"allow": [],},}' \
            '{"permissions": {"allow": []}, "x": NaN}' "{'permissions': {'allow': []}}" \
            '[{"permissions": {"allow": ["Bash(git *)"]}}]'; do
  printf '%s' "$body" > "$LOCAL"
  expect deny "settings.local.json that is not a strict JSON object: $body" "$F" "" "$R_GENERIC"
done
printf '%s' '{"permissions": {"allow": []}, "permissions": {"allow": ["Bash(gh api *)"]}}' > "$LOCAL"
expect deny "duplicate key: the last value counts, in both twins" "$F" "" "$R_GENERIC"
printf '%s' '{"permissions": {"allow": ["Bash(gh api *)"]}, "permissions": {"allow": []}}' > "$LOCAL"
expect ask "duplicate key: an earlier value is overridden, in both twins" "$F"
printf '%s' '{"permissions": {"allow": "Bash(gh *)"}}' > "$LOCAL"
expect deny "permissions.allow that is not a list" "$F"
printf '%s' '{"hooks": []}' > "$LOCAL"
expect deny "hooks block that is not an object" "$F"
printf '%s' '{"permissions": ' > "$LOCAL"
expect deny "malformed settings.local.json" "$F"
rm -f "$LOCAL"; mkdir "$LOCAL"
expect deny "unreadable settings.local.json (a directory)" "$F"
rmdir "$LOCAL"
printf '%s' '{"hooks": {"PermissionRequest": [{"matcher": "Bash", "hooks": []}]}}' > "$CFG/settings.json"
expect deny "PermissionRequest hook in user settings" "$F"
printf '%s' '{"hooks": {"PermissionRequest": []}}' > "$CFG/settings.json"
expect ask "empty PermissionRequest list" "$F"
rm -f "$CFG/settings.json"
# A key with U+200B appended is a different key, as it is to Claude Code: a decoy placed first
# must not hide the real one. -ceq matched the decoy in the .ps1 twin (2026-10-23).
for expr in '{"permissions" + ZW: {"allow": []}, "permissions": {"allow": ["Bash(*)"]}}' \
            '{"permissions": {"allow" + ZW: [], "allow": ["Bash(*)"]}}' \
            '{"hooks" + ZW: {}, "hooks": {"PermissionRequest": [{"matcher": "Bash", "hooks": []}]}}' \
            '{"hooks": {"PermissionRequest" + ZW: [], "PermissionRequest": [{"matcher": "Bash", "hooks": []}]}}'; do
  python3 -c 'import json,sys; ZW = chr(0x200b); json.dump(eval(sys.argv[2]), open(sys.argv[1], "w"))' "$LOCAL" "$expr"
  expect deny "a decoy key with U+200B does not hide the real one: $expr" "$F" "" "$R_GENERIC"
done
put_allow_expr "$LOCAL" '"Bash(*" + chr(0x200b) + ")"'
expect ask "a rule body of a star and U+200B is not a bare star, in both twins" "$F"
put_allow_expr "$LOCAL" '"Bash(:*" + chr(0x200b) + ")"'
expect ask "a rule body of :* and U+200B is not a bare :*, in both twins" "$F"
rm -f "$LOCAL"

echo "--- the repo allowlist ---"
GATE="$PROJ/.claude/merge-gate.json"
R_UNREAD="missing or malformed"; R_UNSET="must list"
mv "$GATE" "$GATE.bak"
expect deny "merge-gate.json missing" "$F" "" "$R_UNREAD"
printf '%s' '{"repos": ' > "$GATE";                  expect deny "merge-gate.json malformed" "$F" "" "$R_UNREAD"
printf '%s' '{"repos": ["acme/web.app"]} // c' > "$GATE"; expect deny "merge-gate.json with a comment" "$F" "" "$R_UNREAD"
printf '%s' '{"repos": []}' > "$GATE";               expect deny "merge-gate.json with no repos" "$F" "" "$R_UNSET"
printf '%s' '{"other": 1}' > "$GATE";                expect deny "merge-gate.json without a repos key (same text in both twins)" "$F" "" "$R_UNSET"
printf '%s' '[{"repos": ["acme/web.app"]}]' > "$GATE"; expect deny "merge-gate.json that is an array" "$F" "" "$R_UNSET"
printf '%s' '{"repos": ["acme/web.app", "bad"]}' > "$GATE"; expect deny "a repo value not shaped owner/repo" "$F" "" "$R_UNSET"
printf '%s' '{"repos": "acme/web.app"}' > "$GATE";   expect deny "repos not a list" "$F" "" "$R_UNSET"
python3 -c 'import json,sys; json.dump({"repos": ["acme/web.app"] + ["acme/r%d" % i for i in range(10)]}, open(sys.argv[1], "w"))' "$GATE"
expect deny "more than 10 repos (each one multiplies the probes)" "$F" "" "$R_UNSET"
python3 -c 'import json,sys; json.dump({"repos": ["acme/web.app", "a" * 101 + "/r"]}, open(sys.argv[1], "w"))' "$GATE"
expect deny "an owner longer than 100 characters" "$F" "" "$R_UNSET"
python3 -c 'import json,sys; json.dump({"repos" + chr(0x200b): ["acme/other"], "repos": ["acme/web.app"]}, open(sys.argv[1], "w"))' "$GATE"
expect ask "a decoy repos key with U+200B does not replace the allowlist" "$F"
mv "$GATE.bak" "$GATE"

echo "--- audit record ---"
# Both twins append to the same file, so each must write one LF-terminated line with every field
# in place: ts, permission_mode, repo, N, sha. The line ending is checked as bytes: Git Bash's
# grep drops a CR before matching, and counts an unterminated last line as a line.
LOG="$PROJ/.claude/merge-asks.log"
TAB=$(printf '\t')
AUDIT_RE="^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z${TAB}default${TAB}acme/web\.app${TAB}12${TAB}${SHA}\$"
for twin in sh ps1; do
  if [ "$twin" = ps1 ] && [ "$HAVE_PWSH" -eq 0 ]; then continue; fi
  rm -f "$LOG"
  "run_$twin" "$F" >/dev/null
  last=$(tail -c 1 "$LOG" 2>/dev/null | od -An -tx1 | tr -d ' \n')
  crs=$(od -An -tx1 -v "$LOG" 2>/dev/null | tr -s ' ' '\n' | grep -c '^0d$')
  if [ "$(grep -c '' "$LOG" 2>/dev/null)" = 1 ] && grep -qE "$AUDIT_RE" "$LOG" \
     && [ "$last" = 0a ] && [ "$crs" = 0 ]; then
    echo "  PASS: [$twin] an ask appends one anchored LF line to .claude/merge-asks.log"; PASS=$((PASS + 1))
  else
    echo "  FAIL: [$twin] an ask appends one anchored LF line to .claude/merge-asks.log"
    echo "    got: $(od -c "$LOG" 2>/dev/null | head -5)"; FAIL=$((FAIL + 1))
  fi
done

echo "--- PMB's own settings keep the crash-path ask rules and the merge-tool deny rules ---"
missing=$(python3 -I -c '
import json, sys
perms = json.load(open(sys.argv[1], encoding="utf-8")).get("permissions", {})
want = {"ask": ["Bash(gh pr merge:*)", "PowerShell(gh pr merge:*)"],
        "deny": ["mcp__ccd_pr__set_auto_merge", "mcp__plugin_engineering_github__merge_pull_request"]}
print(" ".join(r for key, rules in want.items() for r in rules if r not in perms.get(key, [])))
' "$(native "$REPO_ROOT/.claude/settings.json")")
assert_equals "$missing" "" ".claude/settings.json holds both ask rules and both deny rules"

echo "--- install skew and broken pieces fail closed ---"
SKEW="$TMP_MG/scripts"
reset_skew() {
  rm -rf "$SKEW"; mkdir -p "$SKEW"
  cp "$REPO_ROOT"/scripts/review-reminders.sh "$REPO_ROOT"/scripts/review-reminders.ps1 \
     "$REPO_ROOT"/scripts/_review-gate-*.py "$REPO_ROOT"/scripts/_review-gate-*.ps1 \
     "$REPO_ROOT"/scripts/_review-gate-lib.sh "$SKEW"/
}
reset_skew
expect ask "control: the copied scripts ask" "$F" "$SKEW"
rm -f "$SKEW/_review-gate-merge.py" "$SKEW/_review-gate-merge.ps1"
expect deny "merge helper missing" "$F" "$SKEW" "$R_NOCHECK"
reset_skew
printf '%s\n' 'raise SystemExit(3)' > "$SKEW/_review-gate-merge.py"
printf '%s\n' 'function Get-ReviewGateMergeDecision { throw "boom" }' > "$SKEW/_review-gate-merge.ps1"
expect deny "merge helper crashes" "$F" "$SKEW" "$R_NOCHECK"
reset_skew
# The classifier gives no verdict while the real merge helper stays in place, so the raw fallback
# says MERGE and only the hooks' fallback guard (verdict_source / $verdictFromFallback) stands
# between it and an ask. The "control" row above is the same copy without the stubs.
printf '%s\n' 'pass' > "$SKEW/_review-gate-classify.py"
printf '%s\n' 'throw "classifier unavailable"' > "$SKEW/_review-gate-classify.ps1"
expect deny "fallback verdict with the helper present is never asked" "$F" "$SKEW" "$R_NOCHECK"
reset_skew
# The .py stub answers --git-context with nothing so the hook resolves the root from PROJ (a git
# repo) and reaches its verdict switch; the .ps1 override is appended to a real copy so the
# classifier's other functions stay defined.
printf '%s\n' 'import sys; sys.stdout.write("" if "--git-context" in sys.argv else "BOGUS")' > "$SKEW/_review-gate-classify.py"
printf '\n%s\n' 'function Get-ReviewGateVerdictFromPayload { "BOGUS" }' >> "$SKEW/_review-gate-classify.ps1"
mkpayload "$TMP_MG/plain.json" 'p("ls")'
expect deny "unrecognised classifier verdict (version skew)" "$TMP_MG/plain.json" "$SKEW" "unrecognised classifier verdict"
mkpayload "$F" 'p(C)'

# python3 present but broken: the classifier returns nothing, the raw fallback says MERGE, and a
# fallback verdict is never asked. A stub on PATH works on every OS, unlike removing python3.
STUB="$TMP_MG/stubbin"; mkdir -p "$STUB"
printf '%s\n' '#!/bin/sh' 'exit 1' > "$STUB/python3"; chmod +x "$STUB/python3"
out=$(cd "$PROJ" && env -u GH_HOST -u GH_REPO -u GH_CONFIG_DIR PATH="$STUB:$PATH" CLAUDE_PROJECT_DIR="$(native "$PROJ")" \
      CLAUDE_CONFIG_DIR="$(native "$CFG")" bash "$REPO_ROOT/scripts/review-reminders.sh" < "$F" 2>/dev/null)
assert_contains "$out" '"permissionDecision":"deny"' "[sh] fallback verdict (classifier unavailable) denies the canonical form"

echo "--- twins and template mirrors ---"
for f in review-reminders.sh review-reminders.ps1 _review-gate-merge.py _review-gate-merge.ps1; do
  diff -q "$REPO_ROOT/scripts/$f" "$REPO_ROOT/templates/scripts/$f" >/dev/null 2>&1
  assert_exit_zero "$?" "templates/scripts/$f is byte-identical to scripts/$f"
done

print_summary
