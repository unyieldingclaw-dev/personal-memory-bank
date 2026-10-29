#!/usr/bin/env bash
# tests/test-review-gate-classify-parity.sh -- the two review-gate classifiers must agree.
#
# WHY this exists: scripts/_review-gate-classify.ps1 (the PowerShell hook, which runs first on every
# platform) compared command tokens with PowerShell's culture-aware operators, which ignore U+00AD
# and equate look-alikes, while scripts/_review-gate-classify.py compares code points. Measured
# 2026-10-19: the ps1 hook allowed `echo x | xargs -I<U+00AD> git commit` and
# `git -c a.b=c<U+207D>x commit`, and both commits ran. This suite pins that the twins give the same
# verdict and git context on such inputs, that the ps1 hook denies the two measured bypasses, and
# that the ps1 file uses no culture-aware comparison (an AST check, with its own self-test).
#
# Needs pwsh and python3. Without them it skips loudly; PMB_REQUIRE_PARITY=1 makes that a failure.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/tests/helpers/assert.sh"
# The scripts under test. Overridable so the suite can be pointed at a candidate (or an old) copy.
S="${PMB_TEST_GATE_SCRIPTS:-$REPO_ROOT/scripts}"

echo "=== review-gate classifier twin parity ==="

require_or_skip() {
    echo "--- SKIPPED: $1 ---"
    echo "!!! WARNING: classifier parity did NOT run. Set PMB_REQUIRE_PARITY=1 to make this a failure."
    if [ "${PMB_REQUIRE_PARITY:-0}" = "1" ]; then
        assert_contains "missing" "present" "PMB_REQUIRE_PARITY=1 but $1"
    fi
    print_summary
    exit $?
}

# Copy match first: it needs neither runtime.
for f in _review-gate-classify.ps1 _review-gate-classify.py; do
    cmp -s "$REPO_ROOT/scripts/$f" "$REPO_ROOT/templates/scripts/$f"
    assert_equals "$?" "0" "templates/scripts/$f is byte-identical to scripts/$f"
done

command -v pwsh >/dev/null 2>&1 || require_or_skip "pwsh is not on PATH"
command -v python3 >/dev/null 2>&1 || require_or_skip "python3 is not on PATH"

T="$(mktemp -d 2>/dev/null || mktemp -d -t pmb-cls-parity)"
trap 'rm -rf "$T"' EXIT
# pnat PATH -- PATH as a native pwsh reads it (Git Bash converts nothing inside -Command strings).
pnat() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }

# ---- sentinel ---------------------------------------------------------------------------------
# Under .NET globalization-invariant mode (no ICU) culture comparison is ordinal, so the rows below
# would pass on the old code too. Say so, and fail under PMB_REQUIRE_PARITY=1: the AST check still
# runs, but the behavioural rows prove nothing in such an environment.
sentinel="$(pwsh -NoProfile -NonInteractive -Command "@('-I') -ccontains ('-I' + [char]0xAD)" </dev/null 2>/dev/null | tr -d '\r')"
if [ "$sentinel" != "True" ]; then
    echo "!!! WARNING: culture comparison is ordinal in this pwsh (sentinel=$sentinel); the parity rows cannot"
    echo "!!! detect a culture regression here. Set PMB_REQUIRE_PARITY=1 to make this a failure."
    if [ "${PMB_REQUIRE_PARITY:-0}" = "1" ]; then
        assert_equals "$sentinel" "True" "PMB_REQUIRE_PARITY=1 but pwsh compares ordinally here (no ICU?)"
    fi
fi

# ---- corpus -----------------------------------------------------------------------------------
# Bytes are spelled with printf octal escapes: Git Bash with LANG unset turns a backslash-u escape into a lone
# 0xAD byte, not UTF-8. NUL cannot live in a bash string, so @NUL@ stands for it.
u() { printf "$1"; }
SHY="$(u '\302\255')"; ZWSP="$(u '\342\200\213')"; BOM="$(u '\357\273\277')"; TAGSP="$(u '\363\240\200\240')"
SUPL="$(u '\342\201\275')"; SUPR="$(u '\342\201\276')"; GRQ="$(u '\315\276')"; SSEMI="$(u '\357\271\224')"
SAMP="$(u '\357\271\240')"; ACUTE="$(u '\314\201')"; CR="$(u '\015')"; FS="$(u '\034')"
C='commit -m x'

# Rows: expected verdict | command. Expected is the Python twin's verdict, which compares code points;
# both twins must give it. The first group are the measured or classifier-level ps1 misses.
ROWS=(
    "COMMIT|echo x | xargs -I${SHY} git $C"
    "COMMIT|echo x | xargs -E${SHY} git $C"
    "COMMIT|echo x | xargs -n${SHY} git $C"
    "COMMIT|echo x | xargs -I${ZWSP} git $C"
    "COMMIT|echo x | xargs -I${BOM} git $C"
    "COMMIT|echo x | xargs -I${TAGSP} git $C"
    "COMMIT|echo x | xargs -I@NUL@ git $C"
    "COMMIT|echo x | xargs -${SHY}- -n 1 git $C"
    "COMMIT|ssh -i${SHY} host git $C"
    "COMMIT|ssh -l${SHY} host git $C"
    "PUSH|ssh -E${SHY} host git push"
    "COMMIT|ssh -${SHY}- -p 22 host git $C"
    "COMMIT|git -c a.b=c${SUPL}x $C"
    "COMMIT|git -c a.b=c${SUPR}x $C"
    "COMMIT|git -c a.b=c${GRQ}x $C"
    "COMMIT|git -c a.b=c${SSEMI}x $C"
    "COMMIT|git -c a.b=c${SAMP}${SAMP}x $C"
    "COMMIT|git -${ACUTE}x $C"
    "COMMIT|git --git-dir${SHY}=x $C"
    "COMMIT|git --GIT-DIR=x $C"
    # Over-triggers before the fix: culture-equal names and options the programs themselves reject.
    "NONE|git -C${SHY} sub $C"
    "NONE|git -c${SHY} a=b $C"
    "NONE|git${SHY} $C"
    "NONE|git${SHY}.exe $C"
    "NONE|git.exe${SHY} $C"
    "NONE|env${SHY} git $C"
    "NONE|git ${SHY}-x $C"
    "NONE|bash${SHY} -c \"git $C\""
    "NONE|bash ${SHY}-c \"git $C\""
    "NONE|pwsh${SHY} -c \"git $C\""
    "NONE|pwsh -command${SHY} \"git $C\""
    "NONE|cmd${SHY} /c git $C"
    "NONE|cmd /c${SHY} git $C"
    "NONE|ssh${SHY} host git $C"
    "NONE|ssh ${SHY}-p 22 host git $C"
    "NONE|echo x | xargs${SHY} git $C"
    "NONE|busybox${SHY} sh -c \"git $C\""
    "NONE|busybox sh${SHY} -c \"git $C\""
    "NONE|gh${SHY} pr merge 1"
    "NONE|git commit${SHY} -m x"
    "NONE|git push${SHY}"
    "NONE|ssh ${SHY}-x host git $C"
    "NONE|echo x | xargs ${SHY}-x git $C"
    # Controls: the ordinary forms every launcher and option arm must still catch.
    "COMMIT|git $C"
    "COMMIT|GIT.EXE $C"
    "COMMIT|git -C sub $C"
    "COMMIT|git -Csub $C"
    "COMMIT|git -c a.b=c $C"
    "COMMIT|echo x | xargs -I{} git $C"
    "COMMIT|echo x | xargs -- git $C"
    "COMMIT|ssh -p 22 host git $C"
    "COMMIT|bash -c \"git $C\""
    "COMMIT|PWSH -Command \"git $C\""
    "COMMIT|cmd /C git $C"
    "COMMIT|busybox sh -c \"git $C\""
    "COMMIT|env FOO=1 git $C"
    "COMMIT|echo \$(git $C)"
    "COMMIT|echo \`git $C\`"
    "PUSH|git push origin HEAD"
    "MERGE|gh pr merge 1"
    "MULTI|git $C && git push"
    "COMMIT|git --git-dir=x $C"
    "NONE|git status --short"
    "NONE|echo \"git $C\""
)
# Known differences, pinned so a later fix flips them on purpose. Each is: py verdict | ps1 verdict | command.
#  - CR: ps1 splits segments on a lone CR (a PowerShell statement separator), py does not, and Git Bash
#    deletes a CR inside a word, so this is a real `xargs -I{} git commit` that ps1 misses. Backlog:
#    docs/backlog/review-gate-classifier-gaps-beyond-culture-compari.md.
#  - U+001C: Python's \s splits on U+001C..U+001F, .NET's does not (nor does bash).
KNOWN=(
    "COMMIT|NONE|echo x | xargs -I${CR}{} git $C"
    "NONE|COMMIT|git -c a.b=c${FS}x $C"
)

# Both runners print one line per command: VERDICT<TAB>UNSUPPORTED<TAB>paths, every character outside
# [A-Za-z0-9 ._/-] written as \uXXXX per UTF-16 code unit, so the two outputs compare as bytes.
cat > "$T/run.py" <<'EOF'
import importlib.util, json, re, sys
spec = importlib.util.spec_from_file_location('cls', sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
def esc(s):
    b = s.encode('utf-16-le', 'surrogatepass')
    units = [int.from_bytes(b[i:i + 2], 'little') for i in range(0, len(b), 2)]
    return ''.join(chr(c) if re.match(r'[A-Za-z0-9 ._/-]', chr(c)) else '\\u%04x' % c for c in units)
out = []
for c in json.load(open(sys.argv[2], encoding='utf-8')):
    v, paths, unsup = m.classify_details(c)
    out.append('%s\t%s\t%s' % (v, 'U' if unsup else '-', ','.join(esc(p) for p in paths)))
sys.stdout.write('\n'.join(out) + '\n')
EOF
cat > "$T/run.ps1" <<'EOF'
param([string]$Classifier, [string]$Cases)
. $Classifier
function Esc([string]$s) {
    -join ($s.ToCharArray() | ForEach-Object {
        $n = [int]$_
        if (($n -ge 65 -and $n -le 90) -or ($n -ge 97 -and $n -le 122) -or ($n -ge 48 -and $n -le 57) -or
            $n -eq 32 -or $n -eq 46 -or $n -eq 95 -or $n -eq 47 -or $n -eq 45) { [string]$_ } else { '\u{0:x4}' -f $n }
    })
}
$lines = foreach ($c in @([System.IO.File]::ReadAllText($Cases) | ConvertFrom-Json)) {
    $ctx = Get-ReviewGateCommandContext $c
    "{0}`t{1}`t{2}" -f $ctx.Verdict, $(if ($ctx.Unsupported) { 'U' } else { '-' }), ((@($ctx.Paths) | ForEach-Object { Esc $_ }) -join ',')
}
[Console]::Out.Write(($lines -join "`n") + "`n")
EOF

all=("${ROWS[@]}" "${KNOWN[@]}")
# ROWS carry one leading verdict field and KNOWN rows two; the command itself may hold '|'.
printf '%s\0' "${all[@]}" | python3 -c '
import json, sys
rows = [r.decode("utf-8") for r in sys.stdin.buffer.read().split(b"\0")[:-1]]
n = int(sys.argv[2])
cmds = [r.split("|", 1)[1].replace("@NUL@", "\0") for r in rows[:n]] + [r.split("|", 2)[2] for r in rows[n:]]
json.dump(cmds, open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=True)
open(sys.argv[3], "w", encoding="ascii").write("".join(ascii(c)[1:-1][:100] + "\n" for c in cmds))
' "$T/cases.json" "${#ROWS[@]}" "$T/labels.txt"
python3 -B "$T/run.py" "$S/_review-gate-classify.py" "$T/cases.json" > "$T/py.out" 2> "$T/py.err"
pwsh -NoProfile -NonInteractive -File "$(pnat "$T/run.ps1")" "$(pnat "$S/_review-gate-classify.ps1")" "$(pnat "$T/cases.json")" </dev/null > "$T/ps1.out" 2> "$T/ps1.err"
assert_equals "$(tr -d '\r' < "$T/py.out" | wc -l | tr -d ' ')" "${#all[@]}" "py classified every corpus row $(head -c 300 "$T/py.err")"
assert_equals "$(tr -d '\r' < "$T/ps1.out" | wc -l | tr -d ' ')" "${#all[@]}" "ps1 classified every corpus row $(head -c 300 "$T/ps1.err")"

# Python on Windows writes CRLF to stdout in text mode.
mapfile -t PY < <(tr -d '\r' < "$T/py.out")
mapfile -t PS < <(tr -d '\r' < "$T/ps1.out")
mapfile -t LABEL < <(tr -d '\r' < "$T/labels.txt")
if [ "${#PY[@]}" -ne "${#all[@]}" ] || [ "${#PS[@]}" -ne "${#all[@]}" ]; then
    print_summary
    exit 1
fi
for k in "${!ROWS[@]}"; do
    want="${ROWS[$k]%%|*}"; label="${LABEL[$k]}"
    assert_equals "${PY[$k]%%$'\t'*}" "$want" "py verdict $want: row $((k + 1)) [$label]"
    assert_equals "${PS[$k]}" "${PY[$k]}" "ps1 verdict and git context equal py's: row $((k + 1)) [$label]"
done
n=${#ROWS[@]}
for k in "${!KNOWN[@]}"; do
    IFS='|' read -r kpy kps _ <<< "${KNOWN[$k]}"
    assert_equals "${PY[$((n + k))]%%$'\t'*}" "$kpy" "known difference $((k + 1)): py gives $kpy"
    assert_equals "${PS[$((n + k))]%%$'\t'*}" "$kps" "known difference $((k + 1)): ps1 gives $kps (flip this row when it is fixed)"
done

# ---- hook level -------------------------------------------------------------------------------
# The ps1 hook itself, with no review marker: the two measured bypasses must be denied, for both
# tool names the settings wire to it; a read-only command must not be.
R="$T/repo"; mkdir -p "$R/.claude"
git -C "$R" init -q -b main && git -C "$R" config user.email t@example.invalid && git -C "$R" config user.name t && git -C "$R" config core.autocrlf false
echo a > "$R/f"; git -C "$R" add f; git -C "$R" -c commit.gpgsign=false commit -qm base; echo b >> "$R/f"; git -C "$R" add f
hook() {
    python3 -c 'import json,sys; print(json.dumps({"tool_name":sys.argv[1],"tool_input":{"command":sys.argv[2]}}))' "$1" "$2" \
        | (cd "$R" && pwsh -NoProfile -NonInteractive -File "$(pnat "$S/review-reminders.ps1")" 2>/dev/null)
}
for tool in Bash PowerShell; do
    assert_contains "$(hook "$tool" "echo x | xargs -I${SHY} git $C")" '"deny"' "ps1 hook ($tool) denies xargs -I<U+00AD> git commit with no marker"
    assert_contains "$(hook "$tool" "git -c a.b=c${SUPL}x $C")" '"deny"' "ps1 hook ($tool) denies git -c a.b=c<U+207D>x commit with no marker"
    assert_not_contains "$(hook "$tool" "git status --short")" '"deny"' "ps1 hook ($tool) does not deny git status (matched control)"
done

# ---- AST guard --------------------------------------------------------------------------------
# Parses the classifier and lists every comparison that could be culture-aware:
#  - -eq/-ne/-lt/-le/-gt/-ge (any case prefix) unless the LEFT operand is provably not a string: a
#    number, $null, an [int] cast, .Count/.Length, arithmetic, or one of the int-only scanner variables.
#    The left operand decides the comparison type in PowerShell, so a number on the right proves nothing.
#  - every -contains/-notcontains/-in/-notin/-like/-notlike, and every switch statement;
#  - StartsWith/EndsWith/IndexOf/LastIndexOf/CompareTo/Compare/Equals calls without an Ordinal argument,
#    and ToLower()/ToUpper() (culture casing);
#  - Sort-Object, Compare-Object, Group-Object, Where-Object, Select-String.
# -match/-replace/-split are regex operators, not collation, and are allowed.
cat > "$T/guard.ps1" <<'EOF'
param([string[]]$Paths)
$intVars = @('c', 'quote', 'depth', 'Depth', 'i')
$eqOps = @('Ieq','Ine','Ceq','Cne','Ilt','Ile','Igt','Ige','Clt','Cle','Cgt','Cge')
$banOps = @('Icontains','Inotcontains','Ccontains','Cnotcontains','Iin','Inotin','Cin','Cnotin','Ilike','Inotlike','Clike','Cnotlike')
$ordMethods = @('startswith','endswith','indexof','lastindexof','compareto','compare','equals')
$banCmds = @('sort-object','compare-object','group-object','where-object','select-string','sort','group','where','?')
function Test-SafeLeft($a) {
    if ($a -is [System.Management.Automation.Language.ConstantExpressionAst] -and $a.Value -is [ValueType]) { return $true }
    if ($a -is [System.Management.Automation.Language.VariableExpressionAst]) {
        $n = $a.VariablePath.UserPath
        if ([string]::Equals($n, 'null', [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
        foreach ($v in $intVars) { if ([string]::Equals($n, $v, [System.StringComparison]::Ordinal)) { return $true } }
        return $false
    }
    if ($a -is [System.Management.Automation.Language.ConvertExpressionAst]) {
        return [string]::Equals($a.Type.TypeName.Name, 'int', [System.StringComparison]::OrdinalIgnoreCase)
    }
    if ($a -is [System.Management.Automation.Language.MemberExpressionAst] -and
        $a.Member -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
        return @('Count', 'Length') -ccontains $a.Member.Value
    }
    if ($a -is [System.Management.Automation.Language.BinaryExpressionAst]) {
        return @('Plus', 'Minus', 'Multiply', 'Divide') -ccontains [string]$a.Operator
    }
    return $false
}
foreach ($p in $Paths) {
    $tok = $null; $err = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$tok, [ref]$err)
    if ($err.Count -gt 0) { "PARSE-ERROR`t$p"; continue }
    foreach ($n in $ast.FindAll({ $true }, $true)) {
        $line = $n.Extent.StartLineNumber; $why = $null
        if ($n -is [System.Management.Automation.Language.BinaryExpressionAst]) {
            $op = [string]$n.Operator
            if ($banOps -ccontains $op) { $why = "operator -$op" }
            elseif ($eqOps -ccontains $op -and -not (Test-SafeLeft $n.Left)) { $why = "operator -$op on a possibly-string left operand" }
        } elseif ($n -is [System.Management.Automation.Language.SwitchStatementAst]) {
            $why = 'switch statement'
        } elseif ($n -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and
                  $n.Member -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
            $m = $n.Member.Value.ToLowerInvariant()
            if ($m -ceq 'tolower' -or $m -ceq 'toupper') { $why = "$m() (culture casing)" }
            elseif ($ordMethods -ccontains $m) {
                $hasOrdinal = $false
                foreach ($arg in @($n.Arguments)) { if ($arg.Extent.Text -cmatch 'StringComparison\]::Ordinal|StringComparer\]::Ordinal') { $hasOrdinal = $true } }
                if (-not $hasOrdinal) { $why = "$m() without Ordinal" }
            }
        } elseif ($n -is [System.Management.Automation.Language.CommandAst]) {
            $name = $n.GetCommandName()
            if ($name -and ($banCmds -ccontains $name.ToLowerInvariant())) { $why = "command $name" }
        }
        if ($why) { "{0}:{1}`t{2}`t{3}" -f [System.IO.Path]::GetFileName($p), $line, $why, ($n.Extent.Text -split "`n")[0] }
    }
}
EOF
# Self-test: one banned form per line (counted), then safe forms that must not be reported.
cat > "$T/selftest.ps1" <<'EOF'
$a -EQ 'x'
$a -ccontains $b
$a -in @('x')
$a -notin @('x')
$a -like 'x*'
switch ($a) { 'x' { 1 } }
$a.startswith('-')
$a.EndsWith('x', 'Ordinal')
[string]::Compare($a, $b)
$a.ToLower()
$a -eq $b
$s -eq 34
$a | Sort-Object
[char]$a -eq [char]$b
$c -eq 92
[int]$x -eq [int]$y
$null -eq $x
$x.Count -gt 1
$i + 1 -lt $n.Length
$a.StartsWith('-', [System.StringComparison]::Ordinal)
[string]::Equals($a, $b, [System.StringComparison]::Ordinal)
$a -match '^x'
EOF
self="$(pwsh -NoProfile -NonInteractive -File "$(pnat "$T/guard.ps1")" "$(pnat "$T/selftest.ps1")" </dev/null 2>&1 | tr -d '\r')"
assert_equals "$(printf '%s\n' "$self" | grep -c . )" "14" "AST guard self-test reports exactly the 14 banned forms"
assert_equals "$(printf '%s\n' "$self" | cut -f1 | sed 's/.*://' | sort -n | tr '\n' ' ')" "1 2 3 4 5 6 7 8 9 10 11 12 13 14 " "AST guard self-test reports lines 1-14 and none of the safe forms"
for f in "$S/_review-gate-classify.ps1" "$REPO_ROOT/templates/scripts/_review-gate-classify.ps1"; do
    hits="$(pwsh -NoProfile -NonInteractive -File "$(pnat "$T/guard.ps1")" "$(pnat "$f")" </dev/null 2>&1 | tr -d '\r')"
    assert_equals "$hits" "" "no culture-aware comparison in ${f#"$REPO_ROOT"/}"
done

print_summary
