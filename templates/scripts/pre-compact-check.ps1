<#
.SYNOPSIS
    PreCompact hook — quality gate before context compaction.
.DESCRIPTION
    Blocks compaction unless the memory bank shows substantive session work:
      1. activeContext.md has ≥3 substantive content lines (not just a last-reviewed touch)
      2. progress.md contains at least one entry dated today
    If either check fails, exits 2 to block compaction with an actionable message.
    A handoff.md dated today bypasses all checks (handoff protocol already captures state);
    a stale one does not, and says so.
    Fails open on unexpected errors (exits 0) and logs to .pmb-hook-errors.log.
#>

param()

try {
    $today = Get-Date -Format 'yyyy-MM-dd'

    $blockReasons = @()
    $staleHandoffNote = $null

    # Bypass: a handoff.md means state is captured via the Handoff Protocol -- but ONLY if the
    # handoff is from today.
    #
    # WHY the staleness test exists: until 2026-08-27 this was a bare Test-Path existence check. A
    # handoff is written immediately before a context boundary and is meant to be deleted once
    # merged into memory-bank/ (Handoff Protocol step 5). One that outlives its session is either
    # consumed or abandoned -- in both cases it no longer represents captured state, yet it kept
    # handing out a free pass. Not hypothetical: a handoff dated 2026-08-26 was found still in the
    # repo root on 2026-08-27, silently disabling this entire gate for every compaction in a long
    # session. The bypass was doing the opposite of its job -- the staler the handoff, the more
    # likely the memory bank actually needed the check.
    #
    # WHY today rather than an age in hours: it matches check 2's own "entry dated today"
    # convention, so the gate has one notion of freshness rather than two.
    #
    # WHY an unreadable timestamp falls through instead of bypassing: a bypass that cannot be
    # verified must not be honoured. Falling through is safe -- it runs the ordinary checks, it
    # does not hard-block.
    if (Test-Path "handoff.md") {
        $handoffDate = $null
        try { $handoffDate = (Get-Item "handoff.md").LastWriteTime.ToString('yyyy-MM-dd') } catch { $handoffDate = $null }
        if ($handoffDate -eq $today) { exit 0 }
        # WHY a note rather than a blockReason: a stale handoff REMOVES THE BYPASS, it is not itself
        # a failure. If the memory bank is genuinely fresh the gate must still pass. Appending it to
        # $blockReasons instead was the first implementation and it hard-blocked a healthy bank --
        # caught by tests/test-pre-compact-check.sh's "stale but fresh" case, which exists for that.
        if ($handoffDate) {
            $staleHandoffNote = "handoff.md is dated $handoffDate, not today ($today) — a stale handoff no longer represents captured state, so it did not bypass this gate. Merge it into memory-bank/ and delete it (Handoff Protocol step 5)."
        } else {
            $staleHandoffNote = "handoff.md is present but its modification date could not be read — an unverifiable bypass is not honoured. Delete it if it is spent."
        }
    }

    # Check 1: activeContext.md — must have ≥3 substantive lines
    # Substantive = non-frontmatter, non-heading, non-empty, ≥20 chars
    $activeCtx = "memory-bank/activeContext.md"
    if (Test-Path $activeCtx) {
        $lines = Get-Content $activeCtx
        $inFm = $false; $fmCount = 0; $substantive = 0
        foreach ($line in $lines) {
            if ($line -eq '---') {
                $fmCount++
                $inFm = ($fmCount -eq 1)
                if ($fmCount -ge 2) { $inFm = $false }
                continue
            }
            if ($inFm) { continue }
            if ($line -match '^#{1,6}' -or [string]::IsNullOrWhiteSpace($line)) { continue }
            if ($line.Trim().Length -ge 20) { $substantive++ }
        }
        if ($substantive -lt 3) {
            $blockReasons += "activeContext.md has only $substantive substantive line(s) (need ≥3) — update it with current session state before compacting"
        }
    } else {
        $blockReasons += "activeContext.md missing — run 'mb init'"
    }

    # Check 2: progress.md — must contain at least one entry dated today
    $progressFile = "memory-bank/progress.md"
    if (Test-Path $progressFile) {
        $content = Get-Content $progressFile -Raw
        $hasEntry = ($content -split "`n") | Where-Object { $_ -match "^(#{1,6} |- )?$([regex]::Escape($today))" }
        if (-not $hasEntry) {
            $blockReasons += "progress.md has no entry dated $today — add today's progress before compacting"
        }
    } else {
        $blockReasons += "progress.md missing — run 'mb init'"
    }

    if ($blockReasons.Count -eq 0) { exit 0 }

    Write-Host "Compaction paused — PMB state needs attention. $($blockReasons.Count) check(s) failed."
    foreach ($reason in $blockReasons) {
        Write-Host "  - $reason"
    }
    # Printed only alongside a real failure: it explains why the handoff did not save them.
    if ($staleHandoffNote) { Write-Host "  note: $staleHandoffNote" }
    Write-Host "Fix the above, then compact. Or create a handoff.md dated today to bypass via the Handoff Protocol."
    exit 2
} catch {
    Write-Host "[HOOK ERROR] pre-compact-check.ps1 failed unexpectedly. Proceeding in fails-open mode."
    try { Add-Content ".pmb-hook-errors.log" "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [HOOK] pre-compact-check.ps1: $_" -ErrorAction SilentlyContinue } catch { Write-Verbose "Could not write .pmb-hook-errors.log; ignoring." }
    exit 0
}
