<#
.SYNOPSIS
    PreCompact hook — memory gate check before context compaction.
.DESCRIPTION
    Checks whether memory-bank volatile files were modified today OR handoff.md exists.
    If neither: prints an actionable warning so Claude can update state before compaction.
    Always exits 0 — compaction is never blocked. Fails open on any error.
#>

param()

try {
    $today = (Get-Date).Date

    $memoryBankFresh = $false
    foreach ($file in @("memory-bank/activeContext.md", "memory-bank/progress.md")) {
        if (Test-Path $file) {
            $mtime = (Get-Item $file).LastWriteTime.Date
            if ($mtime -eq $today) {
                $memoryBankFresh = $true
                break
            }
        }
    }

    if ($memoryBankFresh -or (Test-Path "handoff.md")) {
        exit 0
    }

    Write-Host "[PreCompact] Memory bank has not been updated this session and no handoff.md exists."
    Write-Host "Update memory-bank/activeContext.md with current state, or run the Handoff Protocol"
    Write-Host "(create handoff.md) before compaction proceeds."
    exit 0
} catch {
    Write-Host "[HOOK ERROR] pre-compact-check.ps1 failed unexpectedly. Proceeding in fails-open mode."
    exit 0
}
