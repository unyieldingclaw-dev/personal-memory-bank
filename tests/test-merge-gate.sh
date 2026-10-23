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
  print_summary
  exit $?
fi
HAVE_PWSH=0
command -v pwsh >/dev/null 2>&1 && HAVE_PWSH=1

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
run_sh() {
  local dir="${2:-$REPO_ROOT/scripts}"
  (cd "$PROJ" && env -u GH_HOST -u GH_REPO CLAUDE_PROJECT_DIR="$(native "$PROJ")" \
     CLAUDE_CONFIG_DIR="$(native "$CFG")" ${EXTRA_ENV:-} bash "$dir/review-reminders.sh" < "$1" 2>/dev/null)
}
run_ps1() {
  local dir="${2:-$REPO_ROOT/scripts}"
  (cd "$PROJ" && env -u GH_HOST -u GH_REPO CLAUDE_PROJECT_DIR="$(native "$PROJ")" \
     CLAUDE_CONFIG_DIR="$(native "$CFG")" ${EXTRA_ENV:-} \
     pwsh -NoProfile -NonInteractive -File "$(native "$dir/review-reminders.ps1")" < "$1" 2>/dev/null)
}

# expect <ask|deny|none> <label> <payload-file> [scripts-dir] -- runs BOTH twins
expect() {
  local want="$1" label="$2" file="$3" dir="${4:-}" twin out n
  for twin in sh ps1; do
    if [ "$twin" = ps1 ] && [ "$HAVE_PWSH" -eq 0 ]; then continue; fi
    out=$("run_$twin" "$file" $dir)
    case "$want" in
      ask)
        n=$(printf '%s\n' "$out" | grep -c '^{')
        if printf '%s' "$out" | grep -q '"permissionDecision":"ask"' && [ "$n" -eq 1 ]; then
          echo "  PASS: [$twin] ask: $label"; PASS=$((PASS + 1))
        else
          echo "  FAIL: [$twin] ask: $label"; echo "    got: $out"; FAIL=$((FAIL + 1))
        fi ;;
      deny)
        if printf '%s' "$out" | grep -q '"permissionDecision":"deny"' && ! printf '%s' "$out" | grep -q '"ask"'; then
          echo "  PASS: [$twin] deny: $label"; PASS=$((PASS + 1))
        else
          echo "  FAIL: [$twin] deny: $label"; echo "    got: $out"; FAIL=$((FAIL + 1))
        fi ;;
      none)
        if [ -z "$out" ]; then
          echo "  PASS: [$twin] no decision: $label"; PASS=$((PASS + 1))
        else
          echo "  FAIL: [$twin] no decision: $label"; echo "    got: $out"; FAIL=$((FAIL + 1))
        fi ;;
    esac
    LAST_OUT="$out"
  done
}

F="$TMP_MG/payload.json"
case_() {  # case_ <ask|deny|none> <label> <python-expression>
  mkpayload "$F" "$3"
  expect "$1" "$2" "$F"
}

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
case_ deny "-R names another repo"                'p(C.replace("acme/web.app", "acme/other"))'
case_ deny "allowlist value is regex-escaped"     'p(C.replace("acme/web.app", "acme/webXapp"))'
case_ deny "no --match-head-commit"               'p(C.split(" --match-head-commit")[0])'
case_ deny "short SHA"                            'p(C.replace(SHA, SHA[:7]))'
case_ deny "uppercase SHA"                        'p(C.replace(SHA, SHA.upper()))'
case_ deny "PR number with a leading zero"        'p(C.replace(" 12 ", " 012 "))'
case_ deny "PR number of 10 digits"               'p(C.replace(" 12 ", " 1234567890 "))'
case_ deny "--admin appended"                     'p(C + " --admin")'
case_ deny "--auto appended"                      'p(C + " --auto")'
case_ deny "--delete-branch appended"             'p(C + " --delete-branch")'
case_ deny "--rebase method"                      'p(C.replace("--squash", "--rebase"))'
case_ deny "flag order swapped"                   'p(f"gh pr merge 12 --squash -R acme/web.app --match-head-commit {SHA}")'
case_ deny "doubled space"                        'p(C.replace(" -R", "  -R"))'
case_ deny "uppercase flag"                       'p(C.replace("--squash", "--SQUASH"))'
case_ deny "trailing ; x"                         'p(C + "; echo x")'
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
case_ deny "subagent (agent_id set)"              'p(C, agent_id="a1", agent_type="general-purpose")'
case_ deny "subagent (agent_id null)"             'p(C, agent_id=None)'
case_ deny "subagent (agent_id empty)"            'p(C, agent_id="")'
case_ deny "bypassPermissions mode"               'p(C, "bypassPermissions")'
case_ deny "dontAsk mode"                         'p(C, "dontAsk")'
case_ deny "plan mode"                            'p(C, "plan")'
case_ deny "mode missing"                         'p(C, None)'
case_ deny "mode in the wrong case"               'p(C, "Auto")'
case_ deny "mode only inside tool_input (spoof)"  'p(C, None, tool_input_extra={"permission_mode": "default"})'
case_ deny "custom description"                   'p(C, tool_input_extra={"description": "Merge PR #77 as you asked"})'
case_ deny "description near miss"                'p(C, tool_input_extra={"description": DESC + " "})'
case_ deny "description not a string"             'p(C, tool_input_extra={"description": 1})'

echo "--- a command that only mentions a merge is not a merge ---"
case_ none "echo of the canonical command"        'p("echo " + C)'

echo "--- environment and settings preconditions ---"
mkpayload "$F" 'p(C)'
EXTRA_ENV="GH_REPO=acme/web.app" expect deny "GH_REPO set in the hook environment" "$F"
EXTRA_ENV="GH_HOST=github.com"   expect deny "GH_HOST set in the hook environment" "$F"

LOCAL="$PROJ/.claude/settings.local.json"
for rule in 'Bash' 'Bash(*)' 'PowerShell(*)' 'Bash(gh *)' 'Bash(gh:*)' 'Bash(gh api *)' \
            'Bash(gh -R acme/x *)' 'Bash(gh pr *)' 'Bash(gh pr merge:*)' 'PowerShell(gh pr merge *)' \
            "Bash(python3 -c ' *)" 'Bash(node -e *)' "Bash(pwsh -NoProfile -Command ' *)"; do
  python3 -c 'import json,sys; json.dump({"permissions": {"allow": [sys.argv[2]]}}, open(sys.argv[1], "w"))' "$LOCAL" "$rule"
  expect deny "merge-capable allow rule: $rule" "$F"
  assert_not_contains "$LAST_OUT" "settings.local" "deny for '$rule' names no settings file"
  assert_not_contains "$LAST_OUT" "gh api" "deny for '$rule' names no rule"
done
for rule in 'Bash(git *)' 'Bash(gh pr view *)' 'Bash(npm run *)'; do
  python3 -c 'import json,sys; json.dump({"permissions": {"allow": [sys.argv[2]]}}, open(sys.argv[1], "w"))' "$LOCAL" "$rule"
  expect ask "unrelated allow rule leaves the prompt: $rule" "$F"
done
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

echo "--- the repo allowlist ---"
GATE="$PROJ/.claude/merge-gate.json"
mv "$GATE" "$GATE.bak"
expect deny "merge-gate.json missing" "$F"
printf '%s' '{"repos": ' > "$GATE";                  expect deny "merge-gate.json malformed" "$F"
printf '%s' '{"repos": []}' > "$GATE";               expect deny "merge-gate.json with no repos" "$F"
printf '%s' '{"repos": ["acme/web.app", "bad"]}' > "$GATE"; expect deny "a repo value not shaped owner/repo" "$F"
printf '%s' '{"repos": "acme/web.app"}' > "$GATE";   expect deny "repos not a list" "$F"
mv "$GATE.bak" "$GATE"

echo "--- audit record ---"
rm -f "$PROJ/.claude/merge-asks.log"
run_sh "$F" >/dev/null
if grep -q "acme/web.app	12	$SHA" "$PROJ/.claude/merge-asks.log" 2>/dev/null; then
  echo "  PASS: [sh] an ask appends repo, PR and SHA to .claude/merge-asks.log"; PASS=$((PASS + 1))
else
  echo "  FAIL: [sh] an ask appends repo, PR and SHA to .claude/merge-asks.log"; FAIL=$((FAIL + 1))
fi

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
expect deny "merge helper missing" "$F" "$SKEW"
reset_skew
printf '%s\n' 'raise SystemExit(3)' > "$SKEW/_review-gate-merge.py"
printf '%s\n' 'function Get-ReviewGateMergeDecision { throw "boom" }' > "$SKEW/_review-gate-merge.ps1"
expect deny "merge helper crashes" "$F" "$SKEW"
reset_skew
# The .py stub answers --git-context with nothing so the hook resolves the root from PROJ (a git
# repo) and reaches its verdict switch; the .ps1 override is appended to a real copy so the
# classifier's other functions stay defined.
printf '%s\n' 'import sys; sys.stdout.write("" if "--git-context" in sys.argv else "BOGUS")' > "$SKEW/_review-gate-classify.py"
printf '\n%s\n' 'function Get-ReviewGateVerdictFromPayload { "BOGUS" }' >> "$SKEW/_review-gate-classify.ps1"
mkpayload "$TMP_MG/plain.json" 'p("ls")'
expect deny "unrecognised classifier verdict (version skew)" "$TMP_MG/plain.json" "$SKEW"
mkpayload "$F" 'p(C)'

# python3 present but broken: the classifier returns nothing, the raw fallback says MERGE, and a
# fallback verdict is never asked. A stub on PATH works on every OS, unlike removing python3.
STUB="$TMP_MG/stubbin"; mkdir -p "$STUB"
printf '%s\n' '#!/bin/sh' 'exit 1' > "$STUB/python3"; chmod +x "$STUB/python3"
out=$(cd "$PROJ" && env -u GH_HOST -u GH_REPO PATH="$STUB:$PATH" CLAUDE_PROJECT_DIR="$(native "$PROJ")" \
      CLAUDE_CONFIG_DIR="$(native "$CFG")" bash "$REPO_ROOT/scripts/review-reminders.sh" < "$F" 2>/dev/null)
assert_contains "$out" '"permissionDecision":"deny"' "[sh] fallback verdict (classifier unavailable) denies the canonical form"

echo "--- twins and template mirrors ---"
for f in review-reminders.sh review-reminders.ps1 _review-gate-merge.py _review-gate-merge.ps1; do
  diff -q "$REPO_ROOT/scripts/$f" "$REPO_ROOT/templates/scripts/$f" >/dev/null 2>&1
  assert_exit_zero "$?" "templates/scripts/$f is byte-identical to scripts/$f"
done

print_summary
