# PostToolUse hook — companion to review-reminders.ps1 (PreToolUse). If a git commit/push
# that consumed a review-ok marker then failed, reissues the marker so a rejected attempt
# (e.g. a separate pre-commit hook, nothing staged, a merge conflict) doesn't force a
# pointless re-review -- the diff hasn't changed, so the same review still applies.
#
# WHY compare git ref state instead of parsing tool_response: the exact PostToolUse
# response schema (success/exitCode field names) isn't worth depending on when the
# question can be answered from ground truth instead -- if HEAD (for commit) or the
# upstream ref (for push) didn't move, the command failed, full stop, regardless of what
# any response field says.
try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $cmd = ($raw | ConvertFrom-Json).tool_input.command
} catch { exit 0 }

if (-not $cmd) { exit 0 }

# WHY this exists: see the matching comment in review-reminders.ps1.
#
# WHY resolve the FULL leading cd chain: see the matching comment in review-reminders.ps1 --
# both hooks share this exact logic.
$cdRoot = $null
$chainPatternText = @'
^cd\s+(?:"([^"]+)"|'([^']+)')\s*&&\s*
'@
$chainPattern = [regex]$chainPatternText
$restCmd = $cmd
$curDir = (Get-Location).Path
$matchedAny = $false
while ($true) {
    $m = $chainPattern.Match($restCmd)
    if (-not $m.Success) { break }
    $matchedAny = $true
    $p = if ($m.Groups[1].Success) { $m.Groups[1].Value } else { $m.Groups[2].Value }
    $curDir = if ([System.IO.Path]::IsPathRooted($p)) { $p } else { [System.IO.Path]::GetFullPath((Join-Path $curDir $p)) }
    $restCmd = $restCmd.Substring($m.Length)
}
if ($matchedAny) {
    $candidate = git -C $curDir rev-parse --show-toplevel 2>$null
    if ($candidate) { $cdRoot = $candidate }
}

$root = if ($cdRoot) { $cdRoot } else { git rev-parse --show-toplevel 2>$null }
if (-not $root) { exit 0 }

# WHY Set-Location here: see the matching comment in review-reminders.ps1.
try { Set-Location $root } catch { exit 0 }

# WHY hash a file written via redirection: see the matching comment in review-reminders.ps1
# -- PowerShell's pipeline re-tokenizes piped/captured external-command output, which does
# not reproduce the exact byte stream `git diff | sha256sum` (bash) produces. Redirecting
# to a file preserves raw bytes identically on both platforms.
function Get-FileHashHex {
    param([string]$Path)
    return (Get-FileHash -Path $Path -Algorithm SHA256).Hash.ToLower()
}

if ($cmd -match 'git\s+commit\b') {
    $preShaFile = Join-Path $root '.claude/.pending-commit-presha'
    if (Test-Path $preShaFile) {
        $preSha = (Get-Content $preShaFile -Raw -ErrorAction SilentlyContinue)
        Remove-Item $preShaFile -Force -ErrorAction SilentlyContinue
        $preSha = if ($preSha) { $preSha.Trim() } else { $null }
        $postSha = git rev-parse HEAD 2>$null
        if ($preSha -and $postSha -and $postSha -eq $preSha) {
            # HEAD didn't move — commit failed. A failed commit can't have altered the
            # working tree, so recomputing the hash fresh reproduces the same value.
            $tmp = [System.IO.Path]::GetTempFileName()
            try {
                git diff HEAD > $tmp 2>$null
                Get-FileHashHex $tmp | Set-Content (Join-Path $root '.claude/.code-review-ok')
            } finally {
                Remove-Item $tmp -Force -ErrorAction SilentlyContinue
            }
        }
    }
} elseif ($cmd -match 'git\s+push\b') {
    $preShaFile = Join-Path $root '.claude/.pending-push-presha'
    if (Test-Path $preShaFile) {
        $preSha = (Get-Content $preShaFile -Raw -ErrorAction SilentlyContinue)
        Remove-Item $preShaFile -Force -ErrorAction SilentlyContinue
        $preSha = if ($preSha) { $preSha.Trim() } else { $null }
        $postSha = git rev-parse '@{u}' 2>$null
        if ($preSha -and $postSha -and $postSha -eq $preSha) {
            $tmp = [System.IO.Path]::GetTempFileName()
            try {
                git diff origin/main...HEAD > $tmp 2>$null
                if ($LASTEXITCODE -ne 0) { git diff HEAD > $tmp 2>$null }
                Get-FileHashHex $tmp | Set-Content (Join-Path $root '.claude/.change-review-ok')
            } finally {
                Remove-Item $tmp -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
exit 0
