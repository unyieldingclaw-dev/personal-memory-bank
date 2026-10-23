#!/usr/bin/env bash
# tests/mutate-merge-gate.sh — mutation check for the merge gate (spec §9, "Mutations to prove").
#
# Each mutation is applied to a COPY of scripts/ in a fresh temp directory, never to the
# checkout, and the one fixture that should catch it is run through the mutated hook. KILLED
# means this harness's own fixture changed decision; each fixture mirrors a row of
# tests/test-merge-gate.sh, so that approximates, but does not prove, a red suite row. SURVIVED
# or ERROR means a guard that no fixture here can see fail.
#
# WHY not named test-*.sh: tests/run.sh runs every tests/test-*.sh, and this harness is a
# by-hand check of the suite's power, not part of the suite. Run it after changing the merge gate:
#   bash tests/mutate-merge-gate.sh            (needs python3, perl and pwsh; exits 1 on any survivor)
set -u
REPO="$(cd "${1:-$(dirname "${BASH_SOURCE[0]}")/..}" && pwd)"
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t mb-mg-mutate)"
trap 'rm -rf "$WORK"' EXIT
for tool in python3 perl pwsh; do
  command -v "$tool" >/dev/null 2>&1 || { echo "mutate-merge-gate: $tool not on PATH"; exit 2; }
done
# Canary, as in tests/merge-gate.Tests.ps1: the [ps1] mutations back to -ceq / -ccontains are
# killed only where those operators are culture-aware. Under .NET invariant globalization they are
# ordinal, so those mutations survive there for want of a fixture that can fail, not of a guard.
if [ "$(pwsh -NoProfile -NonInteractive -Command "('a' + [char]0x200b) -ceq 'a'" | tr -d '\r')" != True ]; then
  echo "WARNING: -ceq is ordinal on this host (.NET invariant globalization?). The [ps1] mutations"
  echo "         to -ceq / -ccontains below cannot be killed here, and will report SURVIVED."
fi

mkdir -p "$WORK/proj/.claude" "$WORK/cfg"
git -C "$WORK/proj" init -q 2>/dev/null
printf '%s\n' '{"repos": ["acme/web.app"]}' > "$WORK/proj/.claude/merge-gate.json"
native() { cygpath -m "$1" 2>/dev/null || printf '%s' "$1"; }
SHA=0123456789abcdef0123456789abcdef01234567
C="gh pr merge 12 -R acme/web.app --squash --match-head-commit $SHA"
mk() { MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' python3 -c 'import json,sys; json.dump(json.loads(sys.argv[2]), open(sys.argv[1],"w"))' "$(native "$1")" "$2"; }
mk "$WORK/canon.json"   "{\"permission_mode\":\"default\",\"tool_input\":{\"command\":\"$C\"}}"
mk "$WORK/sub.json"     "{\"permission_mode\":\"default\",\"agent_id\":\"a\",\"tool_input\":{\"command\":\"$C\"}}"
mk "$WORK/bypass.json"  "{\"permission_mode\":\"bypassPermissions\",\"tool_input\":{\"command\":\"$C\"}}"
mk "$WORK/trail.json"   "{\"permission_mode\":\"default\",\"tool_input\":{\"command\":\"$C; echo x\"}}"
mk "$WORK/upper.json"   "{\"permission_mode\":\"default\",\"tool_input\":{\"command\":\"${C/--squash/--SQUASH}\"}}"
mk "$WORK/esc.json"     "{\"permission_mode\":\"default\",\"tool_input\":{\"command\":\"${C/web.app/webXapp}\"}}"
mk "$WORK/other.json"   "{\"permission_mode\":\"default\",\"tool_input\":{\"command\":\"${C/acme\/web.app/acme\/other}\"}}"
mk "$WORK/desc.json"    "{\"permission_mode\":\"default\",\"tool_input\":{\"command\":\"$C\",\"description\":\"Merge PR 77 as you asked\"}}"
mk "$WORK/nl.json"      "{\"permission_mode\":\"default\",\"tool_input\":{\"command\":\"$C\\n\"}}"
mk "$WORK/plain.json"   "{\"permission_mode\":\"default\",\"tool_input\":{\"command\":\"ls\"}}"
mk "$WORK/array.json"   "[{\"permission_mode\":\"default\",\"tool_input\":{\"command\":\"$C\"}}]"
# Like mk, but built from a Python expression, for payloads holding U+200B (ZW).
mkpy() { MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' C="$C" python3 -c 'import json,os,sys; C = os.environ["C"]; ZW = chr(0x200b); json.dump(eval(sys.argv[2]), open(sys.argv[1], "w"))' "$(native "$1")" "$2"; }
mkpy "$WORK/zwmode.json" '{"permission_mode": "default" + ZW, "tool_input": {"command": C}}'
mkpy "$WORK/zwdesc.json" '{"permission_mode": "default", "tool_input": {"command": C, "description": "Merge pull request (verify the details in the hook reason)" + ZW}}'

# Per-mutation fixture state, set before a call to mutate and reset after it:
#   M_SETTINGS  content for the settings file M_TARGET (relative to the project; default local)
#   M_ENV       extra VAR=value words for the hook's environment
#   M_PREP      a function run on the scripts copy before both runs (stubs)
#   M_GATE      content for .claude/merge-gate.json (default: the one-repo allowlist)
GATE_DEFAULT='{"repos": ["acme/web.app"]}'
M_SETTINGS=""; M_TARGET=".claude/settings.local.json"; M_ENV=""; M_PREP=""; M_GATE="$GATE_DEFAULT"
reset_fixture() { M_SETTINGS=""; M_TARGET=".claude/settings.local.json"; M_ENV=""; M_PREP=""; M_GATE="$GATE_DEFAULT"; }

run() {  # run <twin> <scripts-dir> <payload>
  local twin="$1" dir="$2" payload="$3"
  rm -f "$WORK/proj/.claude/settings.local.json" "$WORK/proj/.claude/settings.json" "$WORK/cfg/settings.json"
  [ -n "$M_SETTINGS" ] && printf '%s' "$M_SETTINGS" > "$WORK/proj/$M_TARGET"
  printf '%s' "$M_GATE" > "$WORK/proj/.claude/merge-gate.json"
  if [ "$twin" = sh ]; then
    (cd "$WORK/proj" && env -u GH_HOST -u GH_REPO -u GH_CONFIG_DIR CLAUDE_PROJECT_DIR="$(native "$WORK/proj")" \
       CLAUDE_CONFIG_DIR="$(native "$WORK/cfg")" $M_ENV bash "$dir/review-reminders.sh" < "$payload" 2>/dev/null)
  else
    (cd "$WORK/proj" && env -u GH_HOST -u GH_REPO -u GH_CONFIG_DIR CLAUDE_PROJECT_DIR="$(native "$WORK/proj")" \
       CLAUDE_CONFIG_DIR="$(native "$WORK/cfg")" $M_ENV \
       pwsh -NoProfile -NonInteractive -File "$(native "$dir/review-reminders.ps1")" < "$payload" 2>/dev/null)
  fi
}
decision() { case "$1" in *'"permissionDecision":"ask"'*) echo ask;; *'"permissionDecision":"deny"'*) echo deny;; '') echo none;; *) echo other;; esac; }
fresh_copy() {
  rm -rf "$1"; mkdir -p "$1"
  cp "$REPO"/scripts/review-reminders.sh "$REPO"/scripts/review-reminders.ps1 "$REPO"/scripts/_review-gate-*.py \
     "$REPO"/scripts/_review-gate-*.ps1 "$REPO"/scripts/_review-gate-lib.sh "$1"/
}
# The classifier gives no verdict, so the hook's raw fallback says MERGE with the helper in place.
stub_no_verdict() {
  printf '%s\n' 'pass' > "$1/_review-gate-classify.py"
  printf '%s\n' 'throw "classifier unavailable"' > "$1/_review-gate-classify.ps1"
}

KILLED=0; SURVIVED=0
mutate() {  # mutate <name> <twin> <file> <perl-subst> <payload> <expected-unmutated>
  local name="$1" twin="$2" file="$3" subst="$4" payload="$WORK/$5" want="$6"
  local d="$WORK/scripts"; fresh_copy "$d"
  [ -n "$M_PREP" ] && "$M_PREP" "$d"
  local before; before=$(decision "$(run "$twin" "$d" "$payload")")
  cp "$d/$file" "$d/$file.orig"
  perl -0pi -e "$subst" "$d/$file"
  if cmp -s "$d/$file" "$d/$file.orig"; then
    echo "  ERROR  [$twin] $name: substitution did not apply"; SURVIVED=$((SURVIVED+1)); reset_fixture; return
  fi
  local after; after=$(decision "$(run "$twin" "$d" "$payload")")
  if [ "$before" != "$want" ]; then echo "  ERROR  [$twin] $name: unmutated gave $before, expected $want"; SURVIVED=$((SURVIVED+1))
  elif [ "$after" != "$want" ]; then echo "  KILLED [$twin] $name ($want -> $after)"; KILLED=$((KILLED+1))
  else echo "  SURVIVED [$twin] $name (still $after)"; SURVIVED=$((SURVIVED+1)); fi
  reset_fixture
}

RULE='{"permissions":{"allow":["Bash(gh api *)"]}}'
# Caught by a probe (PR 1) and by nothing else: the asked-command pass reruns the shape checks, so
# with the first check removed it would still deny RULE, but it does not match this rule.
PROBE_ONLY_RULE='{"permissions":{"allow":["Bash(gh pr m* 1 *)"]}}'
GLOB_RULE='{"permissions":{"allow":["Bash(gh pr m*)"]}}'
COLON_RULE='{"permissions":{"allow":["Bash(g*:*)"]}}'
TSTAR_RULE='{"permissions":{"allow":["Bash(gh pr m*e 1 --squash*)"]}}'
MERGE_PROBE_RULE='{"permissions":{"allow":["Bash(* --merge --match-head-commit*)"]}}'
PAD_RULE='{"permissions":{"allow":["Bash( * )"]}}'
TRAIL_RULE='{"permissions":{"allow":["Bash(*) "]}}'
BUDGET_RULES=$(python3 -c 'import json; print(json.dumps({"permissions": {"allow": ["Bash(*" + "0" * 39 + "x)"] * 600}}))')
# Misses every probe (PR 1) and matches only the asked command (#12).
CMD_RULE='{"permissions":{"allow":["Bash(gh pr m* 12*)"]}}'
# Within the budget for the probes alone, over it with the asked-command pass.
SHARED_RULES=$(python3 -c 'import json; print(json.dumps({"permissions": {"allow": ["Bash(*" + "0" * 39 + "x)"] * 460}}))')
LONG_RULE=$(python3 -c 'import json; print(json.dumps({"permissions": {"allow": ["Bash(" + "x" * 4100 + ")"]}}))')
MANY_REPOS=$(python3 -c 'import json; print(json.dumps({"repos": ["acme/web.app"] + ["acme/r%d" % i for i in range(10)]}))')
CASE_RULE='{"permissions":{"allow":["Bash(Python3 -c *)"]}}'
SPACE_RULE='{"permissions":{"allow":["\u001cBash(*)"]}}'
PRH='{"hooks":{"PermissionRequest":[{"matcher":"Bash","hooks":[]}]}}'
NAN='{"permissions":{"allow":[]},"x":NaN}'
COMMENT='{"permissions":{"allow":[]}} // c'
ARRAY='[{"permissions":{"allow":["Bash(git *)"]}}]'
ZW_KEY=$(python3 -c 'import json; print(json.dumps({"permissions" + chr(0x200b): {"allow": []}, "permissions": {"allow": ["Bash(*)"]}}))')
ZW_STAR=$(python3 -c 'import json; print(json.dumps({"permissions": {"allow": ["Bash(*" + chr(0x200b) + ")"]}}))')
ZW_COLON=$(python3 -c 'import json; print(json.dumps({"permissions": {"allow": ["Bash(:*" + chr(0x200b) + ")"]}}))')

echo "=== bash twin: review-reminders.sh + _review-gate-merge.py ==="
mutate "ask emitted as allow"        sh review-reminders.sh   's/"permissionDecision":"ask"/"permissionDecision":"allow"/' canon.json ask
M_PREP=stub_no_verdict
mutate "fallback-verdict guard removed" sh review-reminders.sh 's/if \[ "\$verdict_source" = classifier \] && \[ -f/if [ -f/' canon.json deny
mutate "agent_id check removed"      sh _review-gate-merge.py "s/if 'agent_id' in payload:/if False:/"                       sub.json deny
mutate "mode check removed"          sh _review-gate-merge.py 's/if not isinstance\(mode, str\) or mode not in MODES:/if False:/' bypass.json deny
mutate "fullmatch -> match"          sh _review-gate-merge.py 's/re\.fullmatch\(canonical/re.match(canonical/'            trail.json deny
mutate "match made case-insensitive" sh _review-gate-merge.py 's/command, re\.ASCII\)/command, re.ASCII | re.IGNORECASE)/' upper.json deny
mutate "re.escape removed"           sh _review-gate-merge.py 's/re\.escape\(r\) for r in repos/r for r in repos/'       esc.json deny
mutate "repo allowlist removed"      sh _review-gate-merge.py "s/\(\?P<repo>' \+ repo_alt \+ '\)/(?P<repo>[^ ]+)/"        other.json deny
mutate "full match relaxed with .*"  sh _review-gate-merge.py "s/\(\?P<sha>\[0-9a-f\]\{40\}\)'/(?P<sha>[0-9a-f]{40}).*'/" trail.json deny
mutate "description check removed"   sh _review-gate-merge.py "s/if 'description' in tool_input and/if False and/"        desc.json deny
M_ENV="GH_REPO=acme/web.app"
mutate "GH env check removed"        sh _review-gate-merge.py 's/if any\(name in os\.environ for name in GH_ENV\):/if False:/' canon.json deny
M_ENV="GH_CONFIG_DIR=$WORK/ghcfg"
mutate "GH_CONFIG_DIR dropped"       sh _review-gate-merge.py "s/, 'GH_CONFIG_DIR'\)/)/"                                  canon.json deny
M_SETTINGS="$PROBE_ONLY_RULE"
mutate "allow-rule check removed"    sh _review-gate-merge.py 's/or merge_capable\(rule, probes, budget\):/or False:/'     canon.json deny
M_SETTINGS="$RULE"; M_TARGET=".claude/settings.json"
mutate "project settings.json not read" sh _review-gate-merge.py "s/        os\.path\.join\(project, '\.claude', 'settings\.json'\),\n//" canon.json deny
M_SETTINGS="$GLOB_RULE"
mutate "wildcard probe removed"      sh _review-gate-merge.py 's/if any\(glob_matches\(body, p, budget\) for p in probes\):/if False:/' canon.json deny
M_SETTINGS="$COLON_RULE"
mutate "trailing :* reading removed" sh _review-gate-merge.py 's/if body\.endswith\(/if False and body.endswith(/'      canon.json deny
M_SETTINGS="$TSTAR_RULE"
mutate "trailing-star loop removed"  sh _review-gate-merge.py 's/    while i < len\(body\) and body\[i\] == /    while False and body[i] == /' canon.json deny
M_SETTINGS="$MERGE_PROBE_RULE"
mutate "--merge probe removed"       sh _review-gate-merge.py 's/ --merge --match-head-commit %s/ --squash --match-head-commit %s/' canon.json deny
M_SETTINGS="$BUDGET_RULES"
mutate "step budget not enforced"    sh _review-gate-merge.py 's/        if budget\[0\] < 0:\n            return True\n//' canon.json deny
M_SETTINGS="$CMD_RULE"
mutate "asked-command pass removed"  sh _review-gate-merge.py 's/if merge_capable\(rule, \[command\], budget\):/if False:/' canon.json deny
M_SETTINGS="$SHARED_RULES"
mutate "asked-command pass given its own budget" sh _review-gate-merge.py 's/merge_capable\(rule, \[command\], budget\)/merge_capable(rule, [command])/' canon.json deny
M_SETTINGS="$LONG_RULE"
mutate "rule length cap removed"     sh _review-gate-merge.py 's/    if len\(rule\) > MAX_RULE_LENGTH:\n        return True\n//' canon.json deny
M_GATE="$MANY_REPOS"
mutate "repo count cap removed"      sh _review-gate-merge.py 's/not 1 <= len\(repos\) <= MAX_REPOS/not repos/'        canon.json deny
M_SETTINGS="$CASE_RULE"
mutate "ASCII lowercasing removed"   sh _review-gate-merge.py 's/INTERPRETERS\.match\(body\.translate\(ASCII_LOWER\)\)/INTERPRETERS.match(body)/' canon.json deny
M_SETTINGS="$SPACE_RULE"
mutate "edge whitespace not stripped" sh _review-gate-merge.py 's/strip_ws\(rule\), re\.DOTALL/rule, re.DOTALL/'        canon.json deny
M_SETTINGS="$PAD_RULE"
mutate "body whitespace not stripped" sh _review-gate-merge.py 's/    body = strip_ws\(body\)\n//'                        canon.json deny
M_SETTINGS="$TRAIL_RULE"
mutate "trailing whitespace not stripped" sh _review-gate-merge.py 's/return text\.strip\(WS_CHARS\)/return text.lstrip(WS_CHARS)/' canon.json deny
M_SETTINGS="$PRH"
mutate "PermissionRequest check removed" sh _review-gate-merge.py "s/if hooks.get\('PermissionRequest'\) not in \(None, \[\]\):/if False:/" canon.json deny
M_SETTINGS="$NAN"
mutate "NaN accepted"                sh _review-gate-merge.py 's/json\.load\(f, parse_constant=no_constant\)/json.load(f)/' canon.json deny

echo "=== PowerShell twin: review-reminders.ps1 + _review-gate-merge.ps1 ==="
mutate "ask emitted as allow"        ps1 review-reminders.ps1   "s/permissionDecision       = 'ask'/permissionDecision       = 'allow'/" canon.json ask
M_PREP=stub_no_verdict
mutate "fallback-verdict guard removed" ps1 review-reminders.ps1 's/if \(-not \$verdictFromFallback\) \{/if (\$true) {/' canon.json deny
mutate "agent_id check removed"      ps1 _review-gate-merge.ps1 "s/if \(\(Get-MergeGateProperty \\\$payload 'agent_id'\)\.Present\)/if (\\\$false)/" sub.json deny
mutate "mode check removed"          ps1 _review-gate-merge.ps1 's/if \(\$mode -isnot \[string\] -or -not \(\$script:MergeGateModes \| Where-Object \{ \[string\]::Equals\(\$_, \$mode, \[System\.StringComparison\]::Ordinal\) \}\)\)/if (\$false)/' bypass.json deny
# Ordinal comparisons reverted to the culture-aware -ceq / -ccontains, which treat U+200B as absent.
mutate "mode compared with -ccontains" ps1 _review-gate-merge.ps1 's/\(\$script:MergeGateModes \| Where-Object \{ \[string\]::Equals\(\$_, \$mode, \[System\.StringComparison\]::Ordinal\) \}\)/(\$script:MergeGateModes -ccontains \$mode)/' zwmode.json deny
mutate "description compared with -ceq" ps1 _review-gate-merge.ps1 's/\[string\]::Equals\(\$desc\.Value, \$script:MergeGateDescription, \[System\.StringComparison\]::Ordinal\)/\$desc.Value -ceq \$script:MergeGateDescription/' zwdesc.json deny
M_SETTINGS="$ZW_KEY"
mutate "keys compared with -ceq"     ps1 _review-gate-merge.ps1 's/\[string\]::Equals\(\$_\.Name, \$Name, \[System\.StringComparison\]::Ordinal\)/\$_.Name -ceq \$Name/' canon.json deny
M_SETTINGS="$ZW_STAR"
mutate "bare-star body compared with -ceq" ps1 _review-gate-merge.ps1 "s/\[string\]::Equals\(\\\$body, '\*', \[System\.StringComparison\]::Ordinal\)/\\\$body -ceq '*'/" canon.json ask
M_SETTINGS="$ZW_COLON"
mutate "bare :* body compared with -ceq" ps1 _review-gate-merge.ps1 "s/\[string\]::Equals\(\\\$body, ':\*', \[System\.StringComparison\]::Ordinal\)/\\\$body -ceq ':*'/" canon.json ask
mutate "-cmatch -> -match"           ps1 _review-gate-merge.ps1 's/\$command -cnotmatch \$canonical/\$command -notmatch \$canonical/' upper.json deny
mutate "[regex]::Escape removed"     ps1 _review-gate-merge.ps1 's/\$repos \| ForEach-Object \{ \[regex\]::Escape\(\$_\) \}/\$repos | ForEach-Object { \$_ }/' esc.json deny
mutate "repo allowlist removed"      ps1 _review-gate-merge.ps1 's/\(\?<repo>\$alt\)/(?<repo>[^ ]+)/'                       other.json deny
mutate "\\z -> \$"                   ps1 _review-gate-merge.ps1 's/\{40\}\)\\z"/{40})\$"/'                                  nl.json deny
mutate "full match relaxed with .*"  ps1 _review-gate-merge.ps1 's/\{40\}\)\\z"/{40}).*\\z"/'                               trail.json deny
mutate "description check removed"   ps1 _review-gate-merge.ps1 's/if \(\$desc\.Present -and/if (\$false -and/'               desc.json deny
M_ENV="GH_REPO=acme/web.app"
mutate "GH env check removed"        ps1 _review-gate-merge.ps1 's/if \(Test-Path "Env:\$name"\)/if (\$false)/'               canon.json deny
M_ENV="GH_CONFIG_DIR=$WORK/ghcfg"
mutate "GH_CONFIG_DIR dropped"       ps1 _review-gate-merge.ps1 "s/, 'GH_CONFIG_DIR'\)/)/"                                  canon.json deny
M_SETTINGS="$PROBE_ONLY_RULE"
mutate "allow-rule check removed"    ps1 _review-gate-merge.ps1 's/-or \(Test-MergeGateCapableRule \$rule \$probes \$budget\)/-or \$false/' canon.json deny
M_SETTINGS="$RULE"; M_TARGET=".claude/settings.json"
mutate "project settings.json not read" ps1 _review-gate-merge.ps1 "s/        \(Join-Path \(Join-Path \\\$ProjectDir '\.claude'\) 'settings\.json'\),\n//" canon.json deny
M_SETTINGS="$GLOB_RULE"
mutate "wildcard probe removed"      ps1 _review-gate-merge.ps1 's/foreach \(\$p in \$Probes\) \{ if \(Test-MergeGateGlob \$body \$p \$Budget\) \{ return \$true \} \}//' canon.json deny
M_SETTINGS="$COLON_RULE"
mutate "trailing :* reading removed" ps1 _review-gate-merge.ps1 's/if \(\$Body\.EndsWith\(/if (\$false -and \$Body.EndsWith(/' canon.json deny
M_SETTINGS="$TSTAR_RULE"
mutate "trailing-star loop removed"  ps1 _review-gate-merge.ps1 's/while \(\$i -lt \$Body\.Length -and \[int\]\$Body\[\$i\] -eq 42\)/while (\$false)/' canon.json deny
M_SETTINGS="$MERGE_PROBE_RULE"
mutate "--merge probe removed"       ps1 _review-gate-merge.ps1 's/-R \$r --merge --match/-R \$r --squash --match/'          canon.json deny
M_SETTINGS="$BUDGET_RULES"
mutate "step budget not enforced"    ps1 _review-gate-merge.ps1 's/        if \(\$Budget\.Steps -lt 0\) \{ return \$true \}\n//' canon.json deny
M_SETTINGS="$CMD_RULE"
mutate "asked-command pass removed"  ps1 _review-gate-merge.ps1 's/if \(Test-MergeGateCapableRule \$k\.Rule @\(\$command\) \$budget\)/if (\$false)/' canon.json deny
M_SETTINGS="$SHARED_RULES"
mutate "asked-command pass given its own budget" ps1 _review-gate-merge.ps1 's/Test-MergeGateCapableRule \$k\.Rule @\(\$command\) \$budget/Test-MergeGateCapableRule \$k.Rule @(\$command)/' canon.json deny
M_SETTINGS="$LONG_RULE"
mutate "rule length cap removed"     ps1 _review-gate-merge.ps1 's/    if \(\$Rule\.Length -gt \$script:MergeGateMaxRuleLength\) \{ return \$true \}\n//' canon.json deny
M_GATE="$MANY_REPOS"
mutate "repo count cap removed"      ps1 _review-gate-merge.ps1 's/ -or \$repos\.Count -gt \$script:MergeGateMaxRepos//' canon.json deny
M_SETTINGS="$CASE_RULE"
mutate "ASCII lowercasing removed"   ps1 _review-gate-merge.ps1 's/\$lower -cmatch \$interp/\$body -cmatch \$interp/'        canon.json deny
M_SETTINGS="$SPACE_RULE"
mutate "edge whitespace not stripped" ps1 _review-gate-merge.ps1 's/\$r = Get-MergeGateTrimmedText \$Rule/\$r = \$Rule/'   canon.json deny
M_SETTINGS="$PAD_RULE"
mutate "body whitespace not stripped" ps1 _review-gate-merge.ps1 's/\$body = Get-MergeGateTrimmedText \$Matches\[2\]/\$body = \$Matches[2]/' canon.json deny
M_SETTINGS="$TRAIL_RULE"
mutate "trailing whitespace not stripped" ps1 _review-gate-merge.ps1 's/\$Text\.Trim\(\$script:MergeGateWsChars\)/\$Text.TrimStart(\$script:MergeGateWsChars)/' canon.json deny
M_SETTINGS="$PRH"
mutate "PermissionRequest check removed" ps1 _review-gate-merge.ps1 's/if \(\$null -ne \$pr -and/if (\$false -and/'         canon.json deny
M_SETTINGS="$COMMENT"
mutate "strict JSON validation removed" ps1 _review-gate-merge.ps1 's/\[System\.Text\.Json\.JsonDocument\]::Parse\(\$Text, \$options\)\.Dispose\(\)//' canon.json deny
M_SETTINGS="$ARRAY"
mutate "-NoEnumerate removed"        ps1 _review-gate-merge.ps1 's/ConvertFrom-Json -NoEnumerate -ErrorAction Stop/ConvertFrom-Json -ErrorAction Stop/' canon.json deny
mutate "payload -NoEnumerate removed" ps1 _review-gate-merge.ps1 's/\$Raw \| ConvertFrom-Json -NoEnumerate -ErrorAction Stop/\$Raw | ConvertFrom-Json -ErrorAction Stop/' array.json deny

echo "=== default-deny for unknown verdicts (both hooks) ==="
stub_verdict() { printf '%s\n' 'import sys; sys.stdout.write("" if "--git-context" in sys.argv else "BOGUS")' > "$1/_review-gate-classify.py"; printf '\n%s\n' 'function Get-ReviewGateVerdictFromPayload { "BOGUS" }' >> "$1/_review-gate-classify.ps1"; }
M_PREP=stub_verdict
mutate "default-deny verdict branch removed" sh  review-reminders.sh  's/    \*\)\n.*?\n        ;;\n(esac)/$1/s' plain.json deny
M_PREP=stub_verdict
mutate "default-deny verdict branch removed" ps1 review-reminders.ps1 's/    default \{.*?\n    \}\n\}/}/s'           plain.json deny

echo "=== audit line ending (PowerShell hook) ==="
# Not a decision change, so checked by the log's bytes: the LF fix removed must make the line
# end without 0x0a, which tests/test-merge-gate.sh's audit row rejects.
d="$WORK/scripts"; fresh_copy "$d"
audit_last() { rm -f "$WORK/proj/.claude/merge-asks.log"; run ps1 "$d" "$WORK/canon.json" >/dev/null; tail -c 1 "$WORK/proj/.claude/merge-asks.log" 2>/dev/null | od -An -tx1 | tr -d ' \n'; }
before=$(audit_last)
perl -0pi -e 's/\{1\}`n" -f/{1}" -f/' "$d/review-reminders.ps1"
after=$(audit_last)
if [ "$before" = 0a ] && [ "$after" != 0a ]; then echo "  KILLED [ps1] audit LF removed (last byte 0a -> ${after:-none})"; KILLED=$((KILLED+1))
else echo "  SURVIVED/ERROR [ps1] audit LF removed (before=$before after=$after)"; SURVIVED=$((SURVIVED+1)); fi

echo "killed=$KILLED survived=$SURVIVED"
[ "$SURVIVED" -eq 0 ]
