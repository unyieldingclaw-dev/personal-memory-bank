<#
.SYNOPSIS
    PreToolUse hook — agent spawn count advisory.
.DESCRIPTION
    Tracks cumulative Agent tool invocations per 2-hour window (not nesting depth).
    Emits a WARN when count exceeds the budget (≤6 per PERFORMANCE-BUDGET.md).
    State is stored in .pmb-delegation-depth (gitignored).
    Resets automatically after 2 hours of inactivity (session boundary).
    Always exits 0 — this is advisory, not blocking.
    NOTE: True nesting depth cannot be tracked — no PostToolUse:Agent hook exists.
#>

param()

try {
    $depthFile = '.pmb-delegation-depth'
    $maxAge = 120  # minutes before resetting depth (session boundary)
    $budgetLimit = 6  # cumulative spawns per 2-hour window; see standards/PERFORMANCE-BUDGET.md

    $depth = 0
    if (Test-Path $depthFile) {
        $content = Get-Content $depthFile -Raw -ErrorAction SilentlyContinue
        if ($content -match 'depth=(\d+)') { $depth = [int]$Matches[1] }
        if ($content -match 'timestamp=(\d{4}-\d{2}-\d{2} \d{2}:\d{2})') {
            try {
                $ts = [datetime]::ParseExact($Matches[1], 'yyyy-MM-dd HH:mm', $null)
                if (([datetime]::Now - $ts).TotalMinutes -gt $maxAge) { $depth = 0 }
            } catch { Write-Verbose "Could not parse stored timestamp; leaving depth unchanged." }
        }
    }

    if ($depth -ge $budgetLimit) {
        Write-Host "[WARN] Agent spawn count: $($depth + 1) this session (budget: ≤$budgetLimit per standards/PERFORMANCE-BUDGET.md)"
        Write-Host "       High agent volume increases prompt-injection surface. Consider consolidating tasks."
    }

    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm'
    try { Set-Content -Path $depthFile -Value "depth=$($depth + 1)`ntimestamp=$ts" -NoNewline -ErrorAction Stop } catch { Write-Verbose "Could not persist $depthFile; depth tracking will reset next run." }

    exit 0
} catch {
    try { Add-Content ".pmb-hook-errors.log" "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [HOOK] delegation-depth-check.ps1: $_" -ErrorAction SilentlyContinue } catch { Write-Verbose "Could not write .pmb-hook-errors.log; ignoring." }
    exit 0
}
