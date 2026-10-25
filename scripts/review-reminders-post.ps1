# PostToolUse hook -- companion to review-reminders.ps1 (PreToolUse). If a git commit that
# consumed a review-ok marker then failed, reissues the marker so a rejected attempt (e.g.
# a separate pre-commit hook, nothing staged, a merge conflict) doesn't force a pointless
# re-review -- the diff hasn't changed, so the same review still applies.
#
# WHY compare git ref state instead of parsing tool_response: the exact PostToolUse
# response schema (success/exitCode field names) isn't worth depending on when the
# question can be answered from ground truth instead -- if HEAD didn't move, the commit
# failed. Push recovery is deliberately unsupported because the actual destination may
# differ from the configured upstream.
#
# Get-FileHashHex/Get-CommitDiffHash/Get-PushDiffHash/Resolve-CdRoot are defined in
# _review-gate-lib.ps1 -- shared with review-reminders.ps1. See that file for their WHY.
# Dot-sourced inside this same try/catch so a missing/corrupt lib fails open.
try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $payload = $raw | ConvertFrom-Json -ErrorAction Stop
    $toolInput = $payload.tool_input
    if ($null -eq $toolInput) { $toolInput = $payload.toolInput }
    $cmd = $toolInput.command
    . (Join-Path $PSScriptRoot '_review-gate-classify.ps1')
    $verdict = Get-ReviewGateCommandVerdict $cmd
    . (Join-Path $PSScriptRoot '_review-gate-lib.ps1')
} catch { exit 0 }

if ($verdict -ne 'COMMIT') { exit 0 }

# WHY this now calls Get-CommitDiffHash/Get-PushDiffHash instead of its own inline
# diff+hash computation: this file used to inline a third copy of the same "redirect git
# diff to a temp file, hash it" pattern instead of reusing review-reminders.ps1's
# Get-CommitDiffHash/Get-PushDiffHash -- structurally duplicated (not a behavior bug: the
# inline copy computed byte-identical output, confirmed by direct comparison during the
# 2026-07-29 dedup refactor), but a future fix to the hashing recipe could still have
# landed in one call site and silently not the other. Now unified on the same shared
# functions the PreToolUse hook uses.
$commandContext = Get-ReviewGateCommandContext $cmd
if ($commandContext.Unsupported) { exit 0 }
$contextDir = (Get-Location).Path
foreach ($contextPath in @($commandContext.Paths)) {
    try {
        $candidate = if ([System.IO.Path]::IsPathRooted($contextPath)) {
            $contextPath
        } else {
            Join-Path $contextDir $contextPath
        }
        $contextDir = (Resolve-Path -LiteralPath $candidate -ErrorAction Stop).Path
    } catch { exit 0 }
}
$cdRoot = Resolve-CdRoot -Cmd $cmd
$root = if (@($commandContext.Paths).Count -gt 0) {
    git -C $contextDir rev-parse --show-toplevel 2>$null
} elseif ($cdRoot) {
    $cdRoot
} else {
    git rev-parse --show-toplevel 2>$null
}
if (-not $root) { exit 0 }

# WHY Set-Location here: see the matching comment in review-reminders.ps1.
try { Set-Location $root } catch { exit 0 }

if ($verdict -eq 'COMMIT') {
    $preShaFile = Join-Path $root '.claude/.pending-commit-presha'
    if (Test-Path $preShaFile) {
        $preShaLine = (Get-Content $preShaFile -Raw -ErrorAction SilentlyContinue)
        Remove-Item $preShaFile -Force -ErrorAction SilentlyContinue
        $parts = if ($preShaLine) { @($preShaLine.Trim() -split '\s+', 2) } else { @() }
        $preSha = if ($parts.Count -ge 1) { $parts[0] } else { $null }
        $reviewed = if ($parts.Count -ge 2) { $parts[1] } else { $null }
        $postSha = git rev-parse HEAD 2>$null
        if ($preSha -and $postSha -and $postSha -eq $preSha) {
            $current = Get-CommitDiffHash
            if ($reviewed -and $current -and $current -eq $reviewed) {
                Write-MarkerAtomic (Join-Path $root '.claude/.code-review-ok') $reviewed
            }
        }
    }
}
exit 0
