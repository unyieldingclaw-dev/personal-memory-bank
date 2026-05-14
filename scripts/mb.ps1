<#
.SYNOPSIS
    Memory Bank utility commands.

.DESCRIPTION
    Quick commands for managing Memory Bank files.

.PARAMETER Command
    The command to run: status, update, archive, slim, commit, budget

.EXAMPLE
    .\mb.ps1 status
    
.EXAMPLE
    .\mb.ps1 commit
#>

# WHY: ValidateSet ensures typos show helpful error messages listing valid commands.
# Position=0 allows "mb status" instead of requiring "mb -Command status".
# Default to "help" so running "mb" alone shows usage, not an error.
param(
    [Parameter(Position=0)]
    [ValidateSet("status", "update", "archive", "slim", "commit", "budget", "help")]
    [string]$Command = "help"
)

# WHY: Hardcoded relative path assumes script runs from project root.
# This matches the expected usage pattern (developers run "mb" from their project).
$MemoryBankPath = "memory-bank"

function Show-Help {
    Write-Host ""
    Write-Host "Memory Bank Utility Commands" -ForegroundColor Cyan
    Write-Host "=============================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage: mb <command>" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  status   Show file sizes, timestamps, and health check"
    Write-Host "  update   Reminder to update Memory Bank (manual action)"
    Write-Host "  archive  Show instructions for archiving old content"
    Write-Host "  slim     Check if activeContext.md needs trimming"
    Write-Host "  commit   Stage and commit Memory Bank changes"
    Write-Host "  help     Show this help message"
    Write-Host ""
}

# WHY: Status command provides at-a-glance health check to prevent Memory Bank bloat.
# Files that grow too large slow down AI context loading and make them hard to scan.
# We enforce size limits to keep the system performant and maintainable.
# WHY: Files are declared explicitly in an ordered array rather than globbed from disk
# because display order is part of the UX (projectbrief first, progress last matches how
# a reader would onboard) and each file carries its own Target/Max metadata that globbing
# cannot supply. A missing file should also show as "MISSING" rather than silently vanish
# from the report -- only an explicit list can detect that.
function Show-Status {
    Write-Host ""
    Write-Host "Memory Bank Status" -ForegroundColor Cyan
    Write-Host "==================" -ForegroundColor Cyan
    Write-Host ""
    
    if (-not (Test-Path $MemoryBankPath)) {
        Write-Host "Error: memory-bank/ directory not found" -ForegroundColor Red
        Write-Host "Run init-memory-bank.ps1 to set up Memory Bank" -ForegroundColor Yellow
        return
    }
    
    # WHY: These size targets are based on AI token limits and human readability.
    # Target = comfortable size, Max = absolute limit before requiring action.
    # activeContext.md is capped hardest (100/150) because it represents only in-flight
    # state -- if it grows past that, stale context is leaking in and should be archived.
    # progress.md and techContext.md get the most headroom (250/400) because they
    # legitimately accumulate history (completed work, dependency lists).
    # systemPatterns.md sits in the middle (180/300) -- patterns grow as the architecture
    # matures, but each pattern should be terse. projectbrief.md stays smallest (80/150)
    # because non-negotiable requirements should be crisp, not prose.
    $files = @(
        @{Name="projectbrief.md"; Target=80; Max=150},
        @{Name="systemPatterns.md"; Target=180; Max=300},
        @{Name="techContext.md"; Target=250; Max=400},
        @{Name="activeContext.md"; Target=100; Max=150},
        @{Name="progress.md"; Target=250; Max=400}
    )
    
    Write-Host "File                    Lines   Target   Max     Status" -ForegroundColor Yellow
    Write-Host "----                    -----   ------   ---     ------"
    
    $hasIssues = $false
    
    foreach ($file in $files) {
        $path = Join-Path $MemoryBankPath $file.Name
        if (Test-Path $path) {
            $lines = (Get-Content $path | Measure-Object -Line).Lines

            if ($lines -gt $file.Max) {
                $status = "OVER LIMIT"
                $color = "Red"
                $hasIssues = $true
            } elseif ($lines -gt $file.Target) {
                $status = "Consider trimming"
                $color = "Yellow"
            } else {
                $status = "OK"
                $color = "Green"
            }
            
            $name = $file.Name.PadRight(22)
            $linesStr = $lines.ToString().PadLeft(5)
            $targetStr = $file.Target.ToString().PadLeft(6)
            $maxStr = $file.Max.ToString().PadLeft(5)
            
            Write-Host "$name $linesStr   $targetStr   $maxStr     " -NoNewline
            Write-Host $status -ForegroundColor $color
        } else {
            Write-Host "$($file.Name.PadRight(22))   -       -       -     " -NoNewline
            Write-Host "MISSING" -ForegroundColor Red
            $hasIssues = $true
        }
    }
    
    Write-Host ""
    
    # Check for handoff.md
    if (Test-Path "handoff.md") {
        Write-Host "Note: handoff.md exists - merge into Memory Bank and delete" -ForegroundColor Yellow
    }
    
    # Summary
    if ($hasIssues) {
        Write-Host "Issues detected. Run 'mb slim' or 'mb archive' to fix." -ForegroundColor Yellow
    } else {
        Write-Host "All files healthy." -ForegroundColor Green
    }
    Write-Host ""
}

# WHY: Show-Update / Show-Archive / Show-Slim print terminal instructions instead of
# living as documentation files. The friction of opening a browser or README mid-session
# is exactly the moment developers skip the Memory Bank discipline -- surfacing the
# canonical AI prompt at the shell (copy-paste ready) is what makes the workflow stick.
# These commands are guidance, not automation, because the actual edits require AI
# judgement about what to keep vs. archive; the script can't safely do that itself.
function Show-Update {
    Write-Host ""
    Write-Host "Update Memory Bank" -ForegroundColor Cyan
    Write-Host "==================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To update Memory Bank, tell the AI:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host '  "Update memory-bank files with the progress from this session"' -ForegroundColor White
    Write-Host ""
    Write-Host "The AI will update:" -ForegroundColor Yellow
    Write-Host "  - activeContext.md  (current focus, next steps)"
    Write-Host "  - progress.md       (completed items)"
    Write-Host "  - techContext.md    (if dependencies changed)"
    Write-Host "  - systemPatterns.md (if new patterns established)"
    Write-Host ""
}

function Show-Archive {
    Write-Host ""
    Write-Host "Archive Old Content" -ForegroundColor Cyan
    Write-Host "===================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To archive old content from activeContext.md:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Move detailed session history to docs/ARCHIVE.md"
    Write-Host "2. Keep only current state in activeContext.md"
    Write-Host "3. Completed 'Next Steps' should move to progress.md"
    Write-Host ""
    Write-Host "Tell the AI:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host '  "Archive old content from activeContext.md to docs/ARCHIVE.md"' -ForegroundColor White
    Write-Host ""
}

function Show-Slim {
    Write-Host ""
    Write-Host "Slim activeContext.md" -ForegroundColor Cyan
    Write-Host "=====================" -ForegroundColor Cyan
    Write-Host ""
    
    $path = Join-Path $MemoryBankPath "activeContext.md"
    if (Test-Path $path) {
        $lines = (Get-Content $path | Measure-Object -Line).Lines
        Write-Host "Current size: $lines lines" -ForegroundColor Yellow
        Write-Host "Target: 50-100 lines"
        Write-Host "Maximum: 150 lines"
        Write-Host ""
        
        if ($lines -gt 150) {
            Write-Host "ACTION NEEDED: File is over limit!" -ForegroundColor Red
        } elseif ($lines -gt 100) {
            Write-Host "RECOMMENDED: Consider trimming" -ForegroundColor Yellow
        } else {
            Write-Host "File is within target range" -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "To slim the file, tell the AI:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host '  "Trim activeContext.md to essentials - move history to docs/ARCHIVE.md"' -ForegroundColor White
    } else {
        Write-Host "Error: activeContext.md not found" -ForegroundColor Red
    }
    Write-Host ""
}

# WHY: Separate Memory Bank commits from feature commits for cleaner git history.
# Context updates are "chore" commits - they don't change functionality.
# We require confirmation to prevent accidental commits of incomplete context.
# Scoping to memory-bank/ folder prevents accidentally committing other changes.
function Invoke-Commit {
    Write-Host ""
    Write-Host "Commit Memory Bank Changes" -ForegroundColor Cyan
    Write-Host "==========================" -ForegroundColor Cyan
    Write-Host ""
    
    # WHY: 2>$null suppresses git errors if not in a repo (graceful handling).
    # --porcelain gives machine-readable output (stable across git versions).
    $status = git status --porcelain $MemoryBankPath 2>$null
    
    if (-not $status) {
        Write-Host "No changes in memory-bank/ to commit" -ForegroundColor Yellow
        return
    }
    
    Write-Host "Changes to commit:" -ForegroundColor Yellow
    $status | ForEach-Object { Write-Host "  $_" }
    Write-Host ""
    
    # WHY: Explicit confirmation prevents accidental commits during rapid iteration.
    # Memory Bank changes should be deliberate checkpoints, not automatic.
    $confirm = Read-Host "Commit these changes? (y/n)"
    if ($confirm -eq 'y' -or $confirm -eq 'Y') {
        git add $MemoryBankPath
        # WHY: "chore:" prefix follows conventional commits, making it clear this
        # is maintenance, not a feature/fix. Helps with changelog generation.
        git commit -m "chore: Update Memory Bank context"
        Write-Host ""
        Write-Host "Committed!" -ForegroundColor Green
    } else {
        Write-Host "Cancelled" -ForegroundColor Yellow
    }
    Write-Host ""
}

function Show-Budget {
    Write-Host ""
    Write-Host "Token Budget Health" -ForegroundColor Cyan
    Write-Host "===================" -ForegroundColor Cyan
    Write-Host ""
    $claudeFile = "CLAUDE.md"
    if (Test-Path $claudeFile) {
        $claudeKB = [math]::Round((Get-Item $claudeFile).Length / 1KB, 1)
        $claudeColor = if ($claudeKB -gt 8) { "Yellow" } else { "Green" }
        $claudeStatus = if ($claudeKB -gt 8) { "WARN" } else { "OK" }
        Write-Host "  CLAUDE.md      $claudeKB KB  [$claudeStatus] (loads every session)" -ForegroundColor $claudeColor
    } else {
        Write-Host "  CLAUDE.md      not found" -ForegroundColor Red
    }
    if (Test-Path $MemoryBankPath) {
        $mbBytes = (Get-ChildItem $MemoryBankPath -Recurse -File | Measure-Object -Property Length -Sum).Sum
        $mbKB = [math]::Round($mbBytes / 1KB, 1)
        $mbColor = if ($mbKB -gt 40) { "Yellow" } else { "Green" }
        $mbStatus = if ($mbKB -gt 40) { "WARN" } else { "OK" }
        Write-Host "  memory-bank/   $mbKB KB  [$mbStatus] (re-read after every compaction)" -ForegroundColor $mbColor
    }
    Write-Host ""
    Write-Host "  Quota tips:" -ForegroundColor DarkCyan
    Write-Host "    /compact Focus on decisions and file paths   (after planning/debugging)" -ForegroundColor White
    Write-Host "    /clear                                       (between unrelated tasks)" -ForegroundColor White
    Write-Host "    /cost                                        (check usage mid-session)" -ForegroundColor White
    Write-Host "    /model opus  ->  /model sonnet               (escalate then return)" -ForegroundColor White
    Write-Host ""
    if ($claudeKB -gt 8) { Write-Host "  CLAUDE.md is large. Trim unused sections." -ForegroundColor Yellow }
    if ($mbKB -gt 40) { Write-Host "  memory-bank/ is large. Run 'mb slim' or 'mb archive'." -ForegroundColor Yellow }
    Write-Host ""
}

# Run command
switch ($Command) {
    "status" { Show-Status }
    "update" { Show-Update }
    "archive" { Show-Archive }
    "slim" { Show-Slim }
    "commit" { Invoke-Commit }
    "budget" { Show-Budget }
    "help" { Show-Help }
}
