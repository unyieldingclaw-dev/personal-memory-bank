# PostToolUse hook -- companion to review-reminders.ps1 (PreToolUse). If a git commit/push
# that consumed a review-ok marker then failed, reissues the marker so a rejected attempt
# (e.g. a separate pre-commit hook, nothing staged, a merge conflict) doesn't force a
# pointless re-review -- the diff hasn't changed, so the same review still applies.
#
# WHY compare git ref state instead of parsing tool_response: the exact PostToolUse
# response schema (success/exitCode field names) isn't worth depending on when the
# question can be answered from ground truth instead -- if HEAD (for commit) or the
# upstream ref (for push) didn't move, the command failed, full stop, regardless of what
# any response field says.
#
# Get-FileHashHex/Get-CommitDiffHash/Get-PushDiffHash/Resolve-CdRoot are defined in
# _review-gate-lib.ps1 -- shared with review-reminders.ps1. See that file for their WHY.
# Dot-sourced inside this same try/catch so a missing/corrupt lib fails open.
try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $cmd = ($raw | ConvertFrom-Json).tool_input.command
    . (Join-Path $PSScriptRoot "_review-gate-lib.ps1")
} catch { exit 0 }

if (-not $cmd) { exit 0 }

# WHY this now calls Get-CommitDiffHash/Get-PushDiffHash instead of its own inline
# diff+hash computation: this file used to inline a third copy of the same "redirect git
# diff to a temp file, hash it" pattern instead of reusing review-reminders.ps1's
# Get-CommitDiffHash/Get-PushDiffHash -- structurally duplicated (not a behavior bug: the
# inline copy computed byte-identical output, confirmed by direct comparison during the
# 2026-07-29 dedup refactor), but a future fix to the hashing recipe could still have
# landed in one call site and silently not the other. Now unified on the same shared
# functions the PreToolUse hook uses.
$cdRoot = Resolve-CdRoot -Cmd $cmd
$root = if ($cdRoot) { $cdRoot } else { git rev-parse --show-toplevel 2>$null }
if (-not $root) { exit 0 }

# WHY Set-Location here: see the matching comment in review-reminders.ps1.
try { Set-Location $root } catch { exit 0 }

if ($cmd -match 'git\s+commit\b') {
    $preShaFile = Join-Path $root '.claude/.pending-commit-presha'
    if (Test-Path $preShaFile) {
        $preSha = (Get-Content $preShaFile -Raw -ErrorAction SilentlyContinue)
        Remove-Item $preShaFile -Force -ErrorAction SilentlyContinue
        $preSha = if ($preSha) { $preSha.Trim() } else { $null }
        $postSha = git rev-parse HEAD 2>$null
        if ($preSha -and $postSha -and $postSha -eq $preSha) {
            # HEAD didn't move -- commit failed. A failed commit can't have altered the
            # working tree, so recomputing the hash fresh reproduces the same value.
            Get-CommitDiffHash | Set-Content (Join-Path $root '.claude/.code-review-ok')
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
            Get-PushDiffHash | Set-Content (Join-Path $root '.claude/.change-review-ok')
        }
    }
}
exit 0
