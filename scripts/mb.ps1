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
    [ValidateSet("init", "install-hooks", "validate", "doctor", "status", "audit", "query", "compact", "update", "archive", "slim", "commit", "upgrade", "budget", "help")]
    [string]$Command = "help",
    [Parameter(Position=1)]
    [string]$Arg = "",
    # WHY: PowerShell parses --dry-run as a named parameter flag, not a positional
    # string. A dedicated [switch] is the idiomatic PS7 way to accept a boolean flag.
    [switch]$DryRun
)

# WHY: $PSScriptRoot is the directory containing mb.ps1 (scripts/).
# The repo root is one level up; templates/ lives there.
# $env:MB_HOME overrides this for globally installed mb (via install.bat).
$RepoRoot = if ($env:MB_HOME) { $env:MB_HOME } else { Split-Path -Parent $PSScriptRoot }

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
    Write-Host "  init          Initialize Memory Bank in the current project"
    Write-Host "  install-hooks Install pre-push git hook into .git/hooks/ (retrofit for existing projects)"
    Write-Host "  validate      Check that required files and frontmatter are present"
    Write-Host "  doctor        Full health check (git, hooks, file sizes, staleness)"
    Write-Host "  status        Show file sizes, timestamps, and health check"
    Write-Host "  audit         Freshness audit — flag stale or overdue files"
    Write-Host "  query         Search memory-bank by tag or section header"
    Write-Host "  compact       Print AI prompt to compact (deduplicate + summarize) memory"
    Write-Host "  update        Reminder to update Memory Bank (manual action)"
    Write-Host "  archive       Show instructions for archiving old content"
    Write-Host "  slim          Check if activeContext.md needs trimming"
    Write-Host "  commit        Stage and commit Memory Bank changes"
    Write-Host "  upgrade       Propagate current governance templates to this project"
    Write-Host "  budget        Check token budget health (CLAUDE.md + memory-bank/ sizes)"
    Write-Host "  help          Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  mb audit              Check freshness of all memory-bank files"
    Write-Host "  mb query auth         Find files tagged auth/* or sections mentioning auth"
    Write-Host "  mb compact            Get AI prompt to compact memory"
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
    Write-Host "1. Move detailed session history to docs/archive/ (see docs/archive/README.md for naming)"
    Write-Host "2. Keep only current state in activeContext.md"
    Write-Host "3. Completed 'Next Steps' should move to progress.md"
    Write-Host ""
    Write-Host "Tell the AI:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host '  "Archive old content from activeContext.md to docs/archive/"' -ForegroundColor White
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
        Write-Host '  "Trim activeContext.md to essentials - move history to docs/archive/"' -ForegroundColor White
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
    
    # WHY: Detect subworktrees so we refuse memory-bank/ mutations from the wrong root.
    # git rev-parse --git-common-dir returns the shared .git dir; in the main worktree
    # that resolves to .git/ inside $PWD. In a subworktree it's a different path.
    $commonGitDir = git rev-parse --git-common-dir 2>$null
    $localGitDir  = Join-Path $PWD ".git"
    if ($commonGitDir -and (Resolve-Path $commonGitDir -ErrorAction SilentlyContinue) -ne (Resolve-Path $localGitDir -ErrorAction SilentlyContinue)) {
        Write-Host "[ERROR] You are in a git subworktree." -ForegroundColor Red
        Write-Host "Commit memory-bank/ from the main worktree root instead." -ForegroundColor Yellow
        Write-Host ""
        return
    }

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
        $claudeTokens = [math]::Round($claudeKB * 250)
        $claudeColor = if ($claudeKB -gt 8) { "Yellow" } else { "Green" }
        $claudeStatus = if ($claudeKB -gt 8) { "WARN" } else { "OK" }
        Write-Host "  CLAUDE.md      $claudeKB KB  ~$claudeTokens tokens  [$claudeStatus] (loads every session)" -ForegroundColor $claudeColor
    } else {
        Write-Host "  CLAUDE.md      not found" -ForegroundColor Red
    }
    if (Test-Path $MemoryBankPath) {
        $mbBytes = (Get-ChildItem $MemoryBankPath -Recurse -File | Measure-Object -Property Length -Sum).Sum
        $mbKB = [math]::Round($mbBytes / 1KB, 1)
        $mbTokens = [math]::Round($mbKB * 250)
        $mbColor = if ($mbKB -gt 40) { "Yellow" } else { "Green" }
        $mbStatus = if ($mbKB -gt 40) { "WARN" } else { "OK" }
        Write-Host "  memory-bank/   $mbKB KB  ~$mbTokens tokens  [$mbStatus] (re-read after every compaction)" -ForegroundColor $mbColor
    }
    $autocompact = $env:CLAUDE_AUTOCOMPACT_PCT_OVERRIDE
    $autocompactDisplay = if ($autocompact) { "$autocompact%" } else { "not set (~95%)" }
    Write-Host "  Auto-compact:  $autocompactDisplay  (CLAUDE_AUTOCOMPACT_PCT_OVERRIDE)" -ForegroundColor DarkCyan
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

function Invoke-Init {
    Write-Host ""
    Write-Host "Memory Bank" -ForegroundColor Cyan
    Write-Host "===========" -ForegroundColor Cyan
    Write-Host ""

    $TemplatesDir = Join-Path $RepoRoot "templates"
    if (-not (Test-Path $TemplatesDir)) {
        Write-Host "[ERROR] Templates not found at $TemplatesDir" -ForegroundColor Red
        Write-Host "Run install.bat from the memory-bank repo, or set MB_HOME." -ForegroundColor Yellow
        return
    }

    $Target = $PWD.Path
    $Created = @()
    $Skipped = @()

    function Copy-IfNew {
        param([string]$Src, [string]$Dst, [string]$Label)
        $dir = Split-Path -Parent $Dst
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        if (-not (Test-Path $Dst)) {
            Copy-Item -Path $Src -Destination $Dst -Force
            $script:Created += $Label
        } else {
            $script:Skipped += $Label
        }
    }

    # memory-bank/ files
    foreach ($f in Get-ChildItem (Join-Path $TemplatesDir "memory-bank") -File) {
        Copy-IfNew -Src $f.FullName -Dst (Join-Path $Target "memory-bank\$($f.Name)") -Label "memory-bank/$($f.Name)"
    }

    # CLAUDE.md
    Copy-IfNew -Src (Join-Path $TemplatesDir "CLAUDE.md") -Dst (Join-Path $Target "CLAUDE.md") -Label "CLAUDE.md"

    # .claude/settings.json
    Copy-IfNew -Src (Join-Path $TemplatesDir ".claude\settings.json") -Dst (Join-Path $Target ".claude\settings.json") -Label ".claude/settings.json"

    # Hook scripts (explicit allowlist — prevents accidental export of future internal files)
    # NOTE: These are the only portable governance scripts exported by mb init.
    # Additions require a corresponding entry in templates/scripts/ AND a CI integrity update.
    foreach ($script in @("dangerous-commands.sh","dangerous-commands.ps1","check-contract.sh","check-contract.ps1","update-reviewed.sh","update-reviewed.ps1","pre-push-check.sh","pre-push-check.ps1")) {
        Copy-IfNew -Src (Join-Path $TemplatesDir "scripts\$script") -Dst (Join-Path $Target "scripts\$script") -Label "scripts/$script"
    }

    # .git/hooks/pre-push — install as executable git hook
    $gitDir = Join-Path $Target ".git"
    if (Test-Path $gitDir) {
        $hookSrc = Join-Path $TemplatesDir "hooks\pre-push"
        $hookDst = Join-Path $gitDir "hooks\pre-push"
        if (Test-Path $hookSrc) {
            if (-not (Test-Path $hookDst)) {
                Copy-Item -Path $hookSrc -Destination $hookDst -Force
                # WHY: git hooks must be executable on Unix; on Windows Git for Windows respects
                # the executable bit via core.fileMode. Set it so the hook works cross-platform.
                if ($IsLinux -or $IsMacOS) { chmod +x $hookDst 2>/dev/null }
                $Created += ".git/hooks/pre-push"
            } else {
                $Skipped += ".git/hooks/pre-push"
            }
        }
    }

    # .claude/commands/
    foreach ($f in Get-ChildItem (Join-Path $TemplatesDir "claude-commands") -File) {
        Copy-IfNew -Src $f.FullName -Dst (Join-Path $Target ".claude\commands\$($f.Name)") -Label ".claude/commands/$($f.Name)"
    }

    # standards/ files — governance contracts referenced at runtime by commands
    $standardsTemplate = Join-Path $TemplatesDir "standards"
    if (Test-Path $standardsTemplate) {
        foreach ($f in Get-ChildItem $standardsTemplate -File) {
            Copy-IfNew -Src $f.FullName -Dst (Join-Path $Target "standards\$($f.Name)") -Label "standards/$($f.Name)"
        }
    }

    # .gitignore
    $gitignore = Join-Path $Target ".gitignore"
    if (Test-Path $gitignore) {
        if ((Get-Content $gitignore -Raw) -notmatch "handoff\.md") {
            Add-Content -Path $gitignore -Value "`n# Memory Bank`nhandoff.md"
            $Created += ".gitignore (added handoff.md)"
        }
    } else {
        Set-Content -Path $gitignore -Value "# Memory Bank`nhandoff.md"
        $Created += ".gitignore"
    }

    foreach ($item in $Created) { Write-Host "  [+] $item" -ForegroundColor Green }
    foreach ($item in $Skipped) { Write-Host "  [=] $item (kept existing)" -ForegroundColor DarkGray }

    Write-Host ""
    if ($Created.Count -gt 0) {
        Write-Host "Ready. Open Claude Code and start your first session." -ForegroundColor Green
    } else {
        Write-Host "Already initialized — no files changed." -ForegroundColor DarkGray
    }
    Write-Host ""
    Write-Host "Next:" -ForegroundColor Yellow
    Write-Host "  Edit memory-bank/projectbrief.md  -- what does this project do?"
    Write-Host "  Edit memory-bank/techContext.md   -- what is your stack?"
    Write-Host "  Run: mb status"
    Write-Host ""
}

function Invoke-InstallHooks {
    # WHY: Separate from mb init so users who already initialized can retrofit the pre-push hook
    # without re-running init (which would skip everything as already present). mb init handles
    # new projects; install-hooks handles the retrofit case.
    Write-Host ""
    Write-Host "Install Git Hooks" -ForegroundColor Cyan
    Write-Host "=================" -ForegroundColor Cyan
    Write-Host ""

    $gitDir = Join-Path $PWD.Path ".git"
    if (-not (Test-Path $gitDir)) {
        Write-Host "[ERROR] No .git directory found. Run this from the root of a git repository." -ForegroundColor Red
        return
    }

    $TemplatesDir = Join-Path $RepoRoot "templates"
    if (-not (Test-Path $TemplatesDir)) {
        Write-Host "[ERROR] Templates not found at $TemplatesDir" -ForegroundColor Red
        Write-Host "Run install.bat from the memory-bank repo, or set MB_HOME." -ForegroundColor Yellow
        return
    }

    $Target = $PWD.Path
    $Installed = @()
    $Skipped   = @()

    # Ensure scripts/ exists and pre-push check scripts are present
    $scriptsDir = Join-Path $Target "scripts"
    if (-not (Test-Path $scriptsDir)) {
        if (-not $DryRun) { New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null }
    }
    foreach ($scriptName in @("pre-push-check.ps1", "pre-push-check.sh")) {
        $src = Join-Path $TemplatesDir "scripts\$scriptName"
        $dst = Join-Path $scriptsDir $scriptName
        if (-not (Test-Path $src)) {
            Write-Host "[WARN] Template source missing: $src" -ForegroundColor Yellow
            continue
        }
        if (Test-Path $dst) {
            Write-Host "  [=] scripts/$scriptName (already present)" -ForegroundColor DarkGray
            $Skipped += "scripts/$scriptName"
        } else {
            if ($DryRun) {
                Write-Host "  [+] scripts/$scriptName (would create)" -ForegroundColor Green
            } else {
                Copy-Item -Path $src -Destination $dst -Force
                Write-Host "  [+] scripts/$scriptName" -ForegroundColor Green
            }
            $Installed += "scripts/$scriptName"
        }
    }

    # Install .git/hooks/pre-push
    $hookSrc  = Join-Path $TemplatesDir "hooks\pre-push"
    $hooksDir = Join-Path $gitDir "hooks"
    $hookDst  = Join-Path $hooksDir "pre-push"

    if (-not (Test-Path $hookSrc)) {
        Write-Host "[ERROR] Hook template not found: $hookSrc" -ForegroundColor Red
        return
    }
    if (-not (Test-Path $hooksDir) -and -not $DryRun) {
        New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null
    }

    if (Test-Path $hookDst) {
        Write-Host "  [=] .git/hooks/pre-push (already installed)" -ForegroundColor DarkGray
        Write-Host "      To reinstall: delete .git/hooks/pre-push and re-run mb install-hooks" -ForegroundColor DarkGray
        $Skipped += ".git/hooks/pre-push"
    } else {
        if ($DryRun) {
            Write-Host "  [+] .git/hooks/pre-push (would install)" -ForegroundColor Green
        } else {
            Copy-Item -Path $hookSrc -Destination $hookDst -Force
            # WHY: git hooks must be executable on Unix; Windows Git for Windows checks the bit too.
            if ($IsLinux -or $IsMacOS) { chmod +x $hookDst 2>/dev/null }
            Write-Host "  [+] .git/hooks/pre-push" -ForegroundColor Green
        }
        $Installed += ".git/hooks/pre-push"
    }

    Write-Host ""
    if ($DryRun) {
        Write-Host "Dry run — no files written." -ForegroundColor Yellow
    } elseif ($Installed.Count -gt 0) {
        Write-Host "Done. The pre-push check will run automatically on every 'git push'." -ForegroundColor Green
    } else {
        Write-Host "Hooks already in place — nothing changed." -ForegroundColor DarkGray
    }
    Write-Host ""
}

function Show-Validate {
    Write-Host ""
    Write-Host "Validation" -ForegroundColor Cyan
    Write-Host "==========" -ForegroundColor Cyan
    Write-Host ""

    $pass = $true

    # Required files
    $required = @(
        @{Path="memory-bank/projectbrief.md";   Label="memory-bank/projectbrief.md"},
        @{Path="memory-bank/systemPatterns.md"; Label="memory-bank/systemPatterns.md"},
        @{Path="memory-bank/techContext.md";    Label="memory-bank/techContext.md"},
        @{Path="memory-bank/activeContext.md";  Label="memory-bank/activeContext.md"},
        @{Path="memory-bank/progress.md";       Label="memory-bank/progress.md"},
        @{Path="CLAUDE.md";                     Label="CLAUDE.md"}
    )

    Write-Host "Required files" -ForegroundColor Yellow
    foreach ($item in $required) {
        if (Test-Path $item.Path) {
            Write-Host "  [OK]      $($item.Label)" -ForegroundColor Green
        } else {
            Write-Host "  [MISSING] $($item.Label)" -ForegroundColor Red
            $pass = $false
        }
    }

    # Frontmatter check
    Write-Host ""
    Write-Host "Frontmatter" -ForegroundColor Yellow
    $mbFiles = @("projectbrief.md","systemPatterns.md","techContext.md","activeContext.md","progress.md")
    foreach ($name in $mbFiles) {
        $path = "memory-bank/$name"
        if (-not (Test-Path $path)) { continue }
        $content = Get-Content $path -Raw
        $hasAuth     = $content -match '(?m)^authority:'
        $hasReviewed = $content -match '(?m)^last-reviewed:'
        if ($hasAuth -and $hasReviewed) {
            Write-Host "  [OK]   $name" -ForegroundColor Green
        } else {
            $missing = @()
            if (-not $hasAuth)     { $missing += "authority" }
            if (-not $hasReviewed) { $missing += "last-reviewed" }
            Write-Host "  [WARN] $name -- missing: $($missing -join ', ')" -ForegroundColor Yellow
        }
    }

    # Handoff check
    Write-Host ""
    if (Test-Path "handoff.md") {
        Write-Host "  [WARN] handoff.md present -- merge it into memory-bank/ and delete" -ForegroundColor Yellow
    }

    Write-Host ""
    if ($pass) {
        Write-Host "All checks passed." -ForegroundColor Green
    } else {
        Write-Host "Issues found. Run 'mb init' to create missing files." -ForegroundColor Red
    }
    Write-Host ""
}

# mb doctor reports mechanically observable integrity signals,
# not semantic correctness or workflow compliance.
# Keep checks deterministic, explainable, and low-noise.
function Show-Doctor {
    Write-Host ""
    Write-Host "Doctor" -ForegroundColor Cyan
    Write-Host "======" -ForegroundColor Cyan
    Write-Host ""

    # 0. Version
    $versionFile = Join-Path $RepoRoot "VERSION"
    if (Test-Path $versionFile) {
        $version = (Get-Content $versionFile -Raw).Trim()
        Write-Host "[OK]   Memory Bank v$version" -ForegroundColor Green
    } else {
        Write-Host "[WARN] VERSION file not found" -ForegroundColor Yellow
    }

    # 1. Git repo
    $isGit = git rev-parse --is-inside-work-tree 2>$null
    if ($isGit -eq "true") {
        Write-Host "[OK]   Git repository detected" -ForegroundColor Green
    } else {
        Write-Host "[WARN] Not a git repository — mb commit won't work" -ForegroundColor Yellow
    }

    # 2. Templates reachable
    $TemplatesDir = Join-Path $RepoRoot "templates"
    if (Test-Path $TemplatesDir) {
        Write-Host "[OK]   Templates found (MB_HOME = $RepoRoot)" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] Templates not found — run install.bat from the memory-bank repo" -ForegroundColor Red
    }

    # 3. Required files
    $allFiles = $true
    foreach ($f in @("projectbrief.md","systemPatterns.md","techContext.md","activeContext.md","progress.md")) {
        if (-not (Test-Path "memory-bank/$f")) { $allFiles = $false; break }
    }
    if ($allFiles) {
        Write-Host "[OK]   All memory-bank files present" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] One or more memory-bank files missing — run 'mb init'" -ForegroundColor Red
    }

    if (Test-Path "CLAUDE.md") {
        Write-Host "[OK]   CLAUDE.md present" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] CLAUDE.md missing — run 'mb init'" -ForegroundColor Red
    }

    # 4. Hooks
    $settingsPath = ".claude/settings.json"
    if (Test-Path $settingsPath) {
        $settings = Get-Content $settingsPath -Raw
        if ($settings -match "PostToolUse") {
            Write-Host "[OK]   PostToolUse hook active (last-reviewed auto-updates)" -ForegroundColor Green
        } else {
            Write-Host "[WARN] No PostToolUse hook — last-reviewed won't auto-update" -ForegroundColor Yellow
            Write-Host "       Copy templates/.claude/settings.json to enable" -ForegroundColor DarkGray
        }
        # Hook script existence: extract full relative paths from "command": lines,
        # deduplicate by logical name (basename), check any implementation file exists.
        # Works for both adopted projects (scripts/X) and this repo (templates/scripts/X).
        $commandLines = ($settings -split "`n") | Where-Object { $_ -match '"command":' }
        $hookPaths = $commandLines | ForEach-Object {
            [regex]::Matches($_, '[A-Za-z][A-Za-z0-9_/-]*\.(sh|ps1)') | ForEach-Object { $_.Value }
        } | Sort-Object -Unique
        $seenBases = @{}
        $missingHooks = @()
        $presentHooks = @()
        foreach ($hookPath in $hookPaths) {
            $base = $hookPath -replace '\.[^.]+$', ''
            $name = Split-Path -Leaf $base
            if ($seenBases.ContainsKey($name)) { continue }
            $seenBases[$name] = $true
            if (Get-ChildItem "${base}.*" -ErrorAction SilentlyContinue) {
                $presentHooks += $name
            } else {
                $missingHooks += $name
            }
        }
        if ($missingHooks.Count -eq 0 -and $presentHooks.Count -gt 0) {
            Write-Host "[OK]   Hook scripts present ($($presentHooks -join ', '))" -ForegroundColor Green
        } elseif ($missingHooks.Count -gt 0) {
            foreach ($h in $missingHooks) {
                Write-Host "[WARN] Hook script missing: $h — run 'mb init' to install" -ForegroundColor Yellow
            }
        }
        # Pre-push git hook
        $prePushHook = ".git/hooks/pre-push"
        if (Test-Path $prePushHook) {
            Write-Host "[OK]   .git/hooks/pre-push installed" -ForegroundColor Green
        } else {
            Write-Host "[WARN] .git/hooks/pre-push not installed — git push runs without pre-push checks" -ForegroundColor Yellow
            Write-Host "       Run 'mb init' to install, or copy templates/hooks/pre-push to .git/hooks/pre-push" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "[WARN] No .claude/settings.json — safety hooks inactive" -ForegroundColor Yellow
        Write-Host "       Copy templates/.claude/settings.json to enable" -ForegroundColor DarkGray
    }

    # 5. Token Budget drift
    $globalClaude = Join-Path $env:USERPROFILE ".claude\CLAUDE.md"
    if ((Test-Path "CLAUDE.md") -and (Test-Path $globalClaude)) {
        $localContent = Get-Content "CLAUDE.md" -Raw
        $globalContent = Get-Content $globalClaude -Raw
        $localHasSentinel = $localContent -match "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE"
        $globalHasSentinel = $globalContent -match "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE"
        if ($globalHasSentinel -and -not $localHasSentinel) {
            Write-Host "[WARN] Token Budget section may have drifted from ~/.claude/CLAUDE.md" -ForegroundColor Yellow
            Write-Host "       Run 'mb init' to refresh or manually copy the Token Budget section" -ForegroundColor DarkGray
        } elseif ($localHasSentinel) {
            Write-Host "[OK]   Token Budget section current" -ForegroundColor Green
        }
    }

    # 6. File sizes
    $hasOverLimit = $false
    $sizeSpecs = @(
        @{Name="projectbrief.md"; Max=150},
        @{Name="systemPatterns.md"; Max=300},
        @{Name="techContext.md"; Max=400},
        @{Name="activeContext.md"; Max=150},
        @{Name="progress.md"; Max=400}
    )
    foreach ($s in $sizeSpecs) {
        $p = "memory-bank/$($s.Name)"
        if (Test-Path $p) {
            $lines = (Get-Content $p).Count
            if ($lines -gt $s.Max) {
                Write-Host "[WARN] memory-bank/$($s.Name) is $lines lines (max $($s.Max)) — run 'mb slim'" -ForegroundColor Yellow
                $hasOverLimit = $true
            }
        }
    }
    if (-not $hasOverLimit) {
        Write-Host "[OK]   File sizes within limits" -ForegroundColor Green
    }

    # 7. Handoff
    if (Test-Path "handoff.md") {
        Write-Host "[WARN] handoff.md found — merge into memory-bank/ and delete" -ForegroundColor Yellow
    } else {
        Write-Host "[OK]   No pending handoff" -ForegroundColor Green
    }

    # 8. Compaction integrity
    $integrityIssues = @()
    $mbFilesIntegrity = @("projectbrief.md","systemPatterns.md","techContext.md","activeContext.md","progress.md")
    foreach ($f in $mbFilesIntegrity) {
        $p = "memory-bank/$f"
        if (-not (Test-Path $p)) { continue }
        $content = Get-Content $p -Raw

        # Compaction depth
        if ($content -match '(?m)^compaction_generation:\s*(\d+)') {
            $gen = [int]$Matches[1]
            if ($gen -ge 3) {
                $integrityIssues += @{Level="WARN"; Msg="memory-bank/$f compaction_generation=$gen (degraded — regenerate from canonical sources)"}
            } elseif ($gen -eq 2) {
                $integrityIssues += @{Level="CAUTION"; Msg="memory-bank/$f compaction_generation=$gen (recursive abstraction risk)"}
            }
        }

        # Canonical-source absence: check lineage entries in frontmatter only.
        # Scope to the frontmatter block (between first two '---' delimiters) so that
        # document-body list items with the same indentation pattern are never tested
        # as file paths — the previous full-file scan caused false positives on every
        # bullet point in progress.md and similar files.
        $fmMatch = [regex]::Match($content, '(?s)^---\r?\n(.+?)\r?\n---')
        if ($fmMatch.Success) {
            $fm = $fmMatch.Groups[1].Value
            # Only process multi-line lineage; 'lineage: []' (inline empty) has no list items.
            $lineageBlock = [regex]::Match($fm, '(?m)^lineage:\s*\r?\n((?:[ \t]+-[^\r\n]*(?:\r?\n)?)*)')
            if ($lineageBlock.Success -and $lineageBlock.Groups[1].Length -gt 0) {
                $lineageItems = [regex]::Matches($lineageBlock.Groups[1].Value, '(?m)^\s+-\s+(.+)')
                foreach ($lm in $lineageItems) {
                    $ancestor = ($lm.Groups[1].Value.Trim() -replace '@.*', '').Trim()
                    if (-not [string]::IsNullOrWhiteSpace($ancestor) -and -not (Test-Path $ancestor)) {
                        $integrityIssues += @{Level="ERROR"; Msg="memory-bank/$f lineage root missing: $ancestor (recovery impossible)"}
                    }
                }
            }
        }
    }

    if ($integrityIssues.Count -eq 0) {
        Write-Host "[OK]   Compaction integrity — all files at generation 0-1" -ForegroundColor Green
    } else {
        foreach ($issue in $integrityIssues) {
            $color = if ($issue.Level -eq "ERROR") { "Red" } elseif ($issue.Level -eq "WARN") { "Yellow" } else { "DarkYellow" }
            Write-Host "[$($issue.Level)] $($issue.Msg)" -ForegroundColor $color
        }
        Write-Host "       Run 'mb compact' to regenerate from lower-generation sources" -ForegroundColor DarkGray
    }

    # 9. Staleness summary
    $staleVolatile = 0
    $staleStable = 0
    foreach ($f in @("projectbrief.md", "systemPatterns.md", "techContext.md", "activeContext.md", "progress.md")) {
        $p = "memory-bank/$f"
        if (-not (Test-Path $p)) { continue }
        $content = Get-Content $p -Raw
        $lastReviewed = if ($content -match '(?m)^last-reviewed:\s*(\d{4}-\d{2}-\d{2})') { $Matches[1] } else { $null }
        $thresholdStr = if ($content -match '(?m)^staleness-threshold:\s*(\d+)d') { $Matches[1] } else { $null }
        $authority = if ($content -match '(?m)^authority:\s*([a-z]+)') { $Matches[1] } else { $null }
        if (-not $lastReviewed -or $lastReviewed -eq 'YYYY-MM-DD' -or -not $thresholdStr) { continue }
        if ($authority -eq 'immutable') { continue }
        try {
            $lastDate = [datetime]::ParseExact($lastReviewed, 'yyyy-MM-dd', $null)
            $daysSince = ([datetime]::Today - $lastDate).Days
            $thresholdDays = [int]$thresholdStr
            if ($daysSince -gt $thresholdDays) {
                if ($authority -eq 'stable') { $staleStable++ } else { $staleVolatile++ }
            }
        } catch { continue }
    }
    $staleTotal = $staleVolatile + $staleStable
    if ($staleTotal -eq 0) {
        Write-Host "[OK]   All memory-bank files within staleness threshold" -ForegroundColor Green
    } else {
        $parts = @()
        if ($staleVolatile -gt 0) { $parts += "$staleVolatile volatile/accumulating" }
        if ($staleStable -gt 0) { $parts += "$staleStable stable" }
        $detail = $parts -join ", "
        Write-Host "[WARN] $staleTotal stale memory-bank file(s) detected ($detail) — run 'mb audit' for details" -ForegroundColor Yellow
    }

    # 10. Placeholder residue
    $placeholderPatterns = @(
        @{Re='\bTODO\b';       Label='TODO'},
        @{Re='\bTBD\b';        Label='TBD'},
        @{Re='\bFIXME\b';      Label='FIXME'},
        @{Re='(?i)FILL IN';    Label='FILL IN'},
        @{Re='(?i)\[your ';    Label='[your ...'},
        @{Re='(?i)lorem ipsum'; Label='lorem ipsum'},
        @{Re='YYYY-MM-DD';     Label='YYYY-MM-DD'}
    )
    $placeholderFilesWarned = 0
    foreach ($f in @("projectbrief.md","systemPatterns.md","techContext.md","activeContext.md","progress.md")) {
        $p = "memory-bank/$f"
        if (-not (Test-Path $p)) { continue }
        $content = Get-Content $p -Raw
        $matched = @()
        $occurrences = 0
        foreach ($pat in $placeholderPatterns) {
            $hits = [regex]::Matches($content, $pat.Re)
            if ($hits.Count -gt 0) {
                $matched += $pat.Label
                $occurrences += $hits.Count
            }
        }
        if ($matched.Count -gt 0) {
            $hitList = $matched -join ', '
            Write-Host "[WARN] memory-bank/$f — placeholder text detected ($occurrences occurrence(s)): $hitList" -ForegroundColor Yellow
            $placeholderFilesWarned++
        }
    }
    if ($placeholderFilesWarned -eq 0) {
        Write-Host "[OK]   No placeholder text in memory-bank files" -ForegroundColor Green
    }

    # Startup context — observability section (not a numbered health check)
    Write-Host ""
    Write-Host "  Startup Context"
    $startupFiles = @()
    if (Test-Path "CLAUDE.md") { $startupFiles += "CLAUDE.md" }
    foreach ($f in @("projectbrief.md","systemPatterns.md","techContext.md","activeContext.md","progress.md")) {
        $p = "memory-bank/$f"
        if (Test-Path $p) { $startupFiles += $p }
    }
    $totalBytes = 0
    foreach ($f in $startupFiles) { $totalBytes += (Get-Item $f).Length }
    $totalTokens = [int]($totalBytes / 4)
    Write-Host "  Files loaded:      $($startupFiles.Count)"
    Write-Host "  Estimated tokens:  ~$totalTokens"
    Write-Host "  Largest contributors:"
    $startupFiles |
        Select-Object @{N='File';E={$_}}, @{N='Bytes';E={(Get-Item $_).Length}} |
        Sort-Object -Property Bytes -Descending |
        Select-Object -First 3 |
        ForEach-Object {
            $tok = [int]($_.Bytes / 4)
            Write-Host ("    {0,-37} ~{1} tokens" -f $_.File, $tok)
        }
    $commit30d = git log --before="30 days ago" -1 --format="%H" -- $startupFiles 2>$null
    if ($commit30d) {
        $total30d = 0
        foreach ($f in $startupFiles) {
            try {
                # WHY: git show returns the file content at that commit; byte-counting
                # the raw string gives an approximation consistent with current-file sizing.
                $content30d = git show "${commit30d}:${f}" 2>$null
                if ($content30d) { $total30d += [System.Text.Encoding]::UTF8.GetByteCount($content30d) }
            } catch {}
        }
        if ($total30d -gt 0) {
            $growth = [int](($totalBytes - $total30d) * 100 / $total30d)
            if ($growth -gt 20) {
                Write-Host ("  30-day growth:     +{0}% [WARN] — context expanding faster than 20%/month" -f $growth) -ForegroundColor Yellow
            } else {
                $sign = if ($growth -ge 0) { "+" } else { "" }
                Write-Host ("  30-day growth:     {0}{1}% [OK]" -f $sign, $growth) -ForegroundColor Green
            }
        } else {
            Write-Host "  30-day growth:     (files added in last 30 days, no baseline)"
        }
    } else {
        Write-Host "  30-day growth:     (no git history older than 30 days)"
    }
    if ($staleTotal -gt 0) {
        Write-Host "  Stale but loaded:  $staleTotal file(s) [WARN]" -ForegroundColor Yellow
    } else {
        Write-Host "  Stale but loaded:  none [OK]" -ForegroundColor Green
    }

    Write-Host ""
}

function Show-Audit {
    Write-Host ""
    Write-Host "Memory Bank Freshness Audit" -ForegroundColor Cyan
    Write-Host "===========================" -ForegroundColor Cyan
    Write-Host ""

    if (-not (Test-Path $MemoryBankPath)) {
        Write-Host "Error: memory-bank/ directory not found" -ForegroundColor Red
        return
    }

    $today = Get-Date
    $files = @("projectbrief.md", "systemPatterns.md", "techContext.md", "activeContext.md", "progress.md")

    Write-Host "File                    Last Reviewed    Stale Threshold   Status" -ForegroundColor Yellow
    Write-Host "----                    -------------    ---------------   ------"

    $totalBytes = 0
    $staleCount = 0

    foreach ($name in $files) {
        $path = Join-Path $MemoryBankPath $name
        if (-not (Test-Path $path)) {
            Write-Host "$($name.PadRight(22))   -                -                 " -NoNewline
            Write-Host "MISSING" -ForegroundColor Red
            continue
        }

        $totalBytes += (Get-Item $path).Length
        $content = Get-Content $path -Raw

        # WHY: Parse frontmatter fields directly from file content so the script
        # works without a YAML parser dependency.
        $lastReviewed = if ($content -match '(?m)^last-reviewed:\s*(\d{4}-\d{2}-\d{2})') { $Matches[1] } else { $null }
        $staleThreshold = if ($content -match '(?m)^staleness-threshold:\s*(\d+)d') { [int]$Matches[1] } else { 90 }
        $reviewCycle = if ($content -match '(?m)^review-cycle:\s*(\d+)d') { [int]$Matches[1] } else { $null }

        if ($null -eq $lastReviewed) {
            Write-Host "$($name.PadRight(22))   no frontmatter   ${staleThreshold}d                " -NoNewline
            Write-Host "NO FRONTMATTER" -ForegroundColor Yellow
            continue
        }

        $reviewedDate = [datetime]::ParseExact($lastReviewed, "yyyy-MM-dd", $null)
        $daysSince = ($today - $reviewedDate).Days

        $staleStr = "${staleThreshold}d"
        $reviewedStr = $lastReviewed.PadRight(15)

        if ($daysSince -gt $staleThreshold) {
            $status = "[STALE] $daysSince days ago"
            $color = "Red"
            $staleCount++
        } elseif ($null -ne $reviewCycle -and $daysSince -gt $reviewCycle) {
            $status = "[DUE] $daysSince days ago"
            $color = "Yellow"
        } else {
            $status = "OK ($daysSince days ago)"
            $color = "Green"
        }

        Write-Host "$($name.PadRight(22))   $reviewedStr   $($staleStr.PadRight(17))   " -NoNewline
        Write-Host $status -ForegroundColor $color
    }

    $totalKB = [math]::Round($totalBytes / 1KB, 1)
    Write-Host ""
    Write-Host "Total memory-bank/ size: $totalKB KB" -ForegroundColor ($totalKB -gt 60 ? "Yellow" : "DarkCyan")

    if ($totalKB -gt 60 -and $staleCount -ge 2) {
        Write-Host ""
        Write-Host "Compaction recommended: run 'mb compact' to get a cleanup prompt." -ForegroundColor Yellow
    } elseif ($staleCount -gt 0) {
        Write-Host "Run 'mb archive' or evict stale entries per MEMORY-BANK.md criteria." -ForegroundColor Yellow
    } else {
        Write-Host "All files current." -ForegroundColor Green
    }
    Write-Host ""
}

function Show-Query {
    param([string]$Keyword)

    if ([string]::IsNullOrWhiteSpace($Keyword)) {
        Write-Host "Usage: mb query <keyword>" -ForegroundColor Yellow
        Write-Host "Example: mb query auth" -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "Query: $Keyword" -ForegroundColor Cyan
    Write-Host "======$('=' * $Keyword.Length)" -ForegroundColor Cyan
    Write-Host ""

    if (-not (Test-Path $MemoryBankPath)) {
        Write-Host "Error: memory-bank/ directory not found" -ForegroundColor Red
        return
    }

    $files = @("projectbrief.md", "systemPatterns.md", "techContext.md", "activeContext.md", "progress.md")
    $found = $false

    foreach ($name in $files) {
        $path = Join-Path $MemoryBankPath $name
        if (-not (Test-Path $path)) { continue }

        $lines = Get-Content $path
        $matchedTags = @()
        $matchedSections = @()
        $inFrontmatter = $false
        $frontmatterDone = $false
        $frontmatterCount = 0

        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]

            # WHY: Track frontmatter boundaries (--- delimiters) to search tags: block.
            if ($line -eq "---" -and -not $frontmatterDone) {
                $frontmatterCount++
                $inFrontmatter = $frontmatterCount -eq 1
                if ($frontmatterCount -eq 2) { $frontmatterDone = $true; $inFrontmatter = $false }
                continue
            }

            if ($inFrontmatter -and $line -match '^\s+-\s+(.+)$') {
                $tag = $Matches[1]
                # WHY: Hierarchical partial match — "auth" matches "auth/session".
                if ($tag -like "*$Keyword*") { $matchedTags += $tag }
                continue
            }

            if (-not $inFrontmatter -and $line -match '^##\s+(.+)$') {
                $heading = $Matches[1]
                if ($heading -like "*$Keyword*") { $matchedSections += "  ## $heading (line $($i+1))" }
            }
        }

        if ($matchedTags.Count -gt 0 -or $matchedSections.Count -gt 0) {
            $found = $true
            Write-Host "$name" -ForegroundColor White
            if ($matchedTags.Count -gt 0) {
                Write-Host "  Tags: $($matchedTags -join ', ')" -ForegroundColor DarkCyan
            }
            foreach ($s in $matchedSections) { Write-Host $s -ForegroundColor DarkCyan }
            Write-Host ""
        }
    }

    if (-not $found) {
        Write-Host "No matches for '$Keyword' in tags or section headers." -ForegroundColor Yellow
        Write-Host "Check your tag vocabulary in standards/MEMORY-BANK.md." -ForegroundColor Yellow
    }
    Write-Host ""
}

function Show-Compact {
    Write-Host ""
    Write-Host "Memory Compaction" -ForegroundColor Cyan
    Write-Host "=================" -ForegroundColor Cyan
    Write-Host ""

    # WHY: Check audit state first — compacting healthy files wastes effort.
    $totalBytes = 0
    if (Test-Path $MemoryBankPath) {
        $totalBytes = (Get-ChildItem $MemoryBankPath -File | Measure-Object -Property Length -Sum).Sum
    }
    $totalKB = [math]::Round($totalBytes / 1KB, 1)

    if ($totalKB -lt 60) {
        Write-Host "memory-bank/ is $totalKB KB — below the 60 KB compaction threshold." -ForegroundColor Green
        Write-Host "Compaction is most valuable when size > 60 KB and mb audit shows stale files." -ForegroundColor Yellow
        Write-Host ""
    }

    Write-Host "Paste this prompt to the AI to compact your memory:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "---" -ForegroundColor DarkGray
    Write-Host @"
Read all files in memory-bank/ in this authority order:
  1. projectbrief.md (immutable — never remove)
  2. systemPatterns.md
  3. techContext.md
  4. activeContext.md
  5. progress.md

Then compact the memory bank:
  - Identify and remove duplicate decisions (keep the most recent / authoritative copy)
  - Flag and surface any contradictions between files for my review
  - Remove entries from activeContext.md that are already captured in progress.md
  - Remove progress.md entries for work completed more than 6 months ago (archive them to docs/archive/ using filename progress-YYYY-MM-<topic>.md)
  - Condense verbose descriptions to their essential decision + rationale
  - Preserve all unique architectural decisions, constraints, and active work

After compacting, show me:
  - What was removed from each file and why
  - Any contradictions found (do not resolve them — surface them for my decision)
  - New line counts for each file

Do not commit the changes until I confirm.
"@ -ForegroundColor White
    Write-Host "---" -ForegroundColor DarkGray
    Write-Host ""
}

function Invoke-Upgrade {
    # WHY: $DryRun is read from the script-level switch parameter rather than
    # checking $Arg for "--dry-run". PS7 parses --dry-run as a named parameter
    # flag, not a positional string; a [switch] is the idiomatic PS7 equivalent.
    $dryRun = $DryRun.IsPresent

    Write-Host ""
    Write-Host "mb upgrade" -ForegroundColor Cyan
    Write-Host "==========" -ForegroundColor Cyan
    if ($dryRun) { Write-Host "(dry run — no files will be written)" -ForegroundColor Yellow }
    Write-Host ""

    # WHY: upgrade requires an mb-managed project; memory-bank/ is the sentinel.
    # Without this gate, upgrade could silently run in unrelated directories.
    if (-not (Test-Path "memory-bank")) {
        Write-Host "Error: No memory-bank/ directory found. Run 'mb upgrade' from the root of an mb-managed project." -ForegroundColor Red
        exit 1
    }

    $TemplatesDir = Join-Path $RepoRoot "templates"
    if (-not (Test-Path $TemplatesDir)) {
        Write-Host "Error: Templates not found at $TemplatesDir" -ForegroundColor Red
        Write-Host "Set MB_HOME or run from the memory-bank repo." -ForegroundColor Yellow
        exit 1
    }

    # WHY: Ownership is hardcoded as explicit arrays — NOT a config file.
    # Ownership semantics are behavior, not data. A config file would invite
    # accidental expansion of overwrite scope. Rationale comments are per-group.
    $templateOwned = @(
        # Cursor governance rules — pure governance substrate, no project customization expected
        ".cursor/rules/code-quality.mdc"
        ".cursor/rules/memory-bank.mdc"
        ".cursor/rules/workflow.mdc"
        ".cursor/rules/security.mdc"
        ".cursor/rules/code-review.mdc"
        ".cursor/rules/rules-file-integrity.mdc"
        # Claude Code settings — hook wiring, not project-specific
        ".claude/settings.json"
        # Hook scripts — deterministic enforcement scripts, no project customization
        "scripts/dangerous-commands.sh"
        "scripts/dangerous-commands.ps1"
        "scripts/check-contract.sh"
        "scripts/check-contract.ps1"
        "scripts/update-reviewed.sh"
        "scripts/update-reviewed.ps1"
        "scripts/pre-push-check.sh"
        "scripts/pre-push-check.ps1"
        # Slash commands — governance workflow commands from templates, not project-specific
        ".claude/commands/code-review.md"
        ".claude/commands/feature-dev.md"
        ".claude/commands/security-review.md"
        ".claude/commands/test-audit.md"
    )

    $advisoryDiff = @(
        # CLAUDE.md is a user cognition surface — users annotate it with project-specific guidance
        "CLAUDE.md"
        # Agent definitions likely contain project-specific tool lists and instructions
        ".claude/agents/researcher.md"
        ".claude/agents/security-reviewer.md"
    )

    # WHY: Template source paths are NOT a 1:1 mirror of target paths.
    # .cursor/rules/X -> templates/cursor/rules/X (no dot prefix)
    # .claude/commands/X -> templates/claude-commands/X (different directory name)
    # All other targets resolve directly under $TemplatesDir.
    function Get-TemplateSrc {
        param([string]$Target)
        if ($Target -like ".cursor/rules/*") {
            return Join-Path $TemplatesDir ("cursor/rules/" + $Target.Substring(".cursor/rules/".Length))
        } elseif ($Target -like ".claude/commands/*") {
            return Join-Path $TemplatesDir ("claude-commands/" + $Target.Substring(".claude/commands/".Length))
        } else {
            return Join-Path $TemplatesDir $Target
        }
    }

    # Process TEMPLATE_OWNED — overwrite unconditionally if stale
    foreach ($target in $templateOwned) {
        $src = Get-TemplateSrc -Target $target
        if (-not (Test-Path $src)) {
            Write-Host "[?] $target (template-owned source missing — skipped)" -ForegroundColor Yellow
            continue
        }
        if (-not (Test-Path $target)) {
            if ($dryRun) {
                Write-Host "[+?] $target (would add)" -ForegroundColor Green
            } else {
                $dir = Split-Path -Parent $target
                if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
                Copy-Item -Path $src -Destination $target -Force
                Write-Host "[+] $target (added)" -ForegroundColor Green
            }
        } elseif ((Get-FileHash $src).Hash -eq (Get-FileHash $target).Hash) {
            Write-Host "[=] $target (unchanged)" -ForegroundColor DarkGray
        } else {
            if ($dryRun) {
                Write-Host "[~?] $target (would update)" -ForegroundColor Yellow
            } else {
                Copy-Item -Path $src -Destination $target -Force
                Write-Host "[~] $target (updated)" -ForegroundColor Yellow
            }
        }
    }

    # Process ADVISORY_DIFF — compare and emit advisory diff, never write
    foreach ($target in $advisoryDiff) {
        $src = Get-TemplateSrc -Target $target
        if (-not (Test-Path $src)) {
            Write-Host "[?] $target (advisory source missing — cannot compare)" -ForegroundColor Yellow
            continue
        }
        if (-not (Test-Path $target)) {
            Write-Host "[=] $target (not present in project — no action needed)" -ForegroundColor DarkGray
            continue
        }
        if ((Get-FileHash $src).Hash -eq (Get-FileHash $target).Hash) {
            Write-Host "[=] $target (matches template)" -ForegroundColor DarkGray
        } else {
            Write-Host "[!] $target (differs from template — review manually)" -ForegroundColor Yellow
            $diffCmd = Get-Command diff -ErrorAction SilentlyContinue
            if ($diffCmd) {
                $diffOutput = & diff -u $src $target 2>$null
                $lines = if ($diffOutput) { $diffOutput -split "`n" } else { @() }
                if ($lines.Count -le 20) {
                    foreach ($line in $lines) { Write-Host "    $line" }
                } else {
                    for ($i = 0; $i -lt 20; $i++) { Write-Host "    $($lines[$i])" }
                    $remaining = $lines.Count - 20
                    Write-Host "    ... ($remaining more lines — compare manually with: diff $src $target)"
                }
            } else {
                Write-Host "    (diff not available — compare manually with: diff $src $target)"
            }
        }
    }

    Write-Host ""
}

# Run command
switch ($Command) {
    "init"          { Invoke-Init }
    "install-hooks" { Invoke-InstallHooks }
    "validate"      { Show-Validate }
    "doctor"        { Show-Doctor }
    "status"        { Show-Status }
    "audit"         { Show-Audit }
    "query"         { Show-Query -Keyword $Arg }
    "compact"       { Show-Compact }
    "update"        { Show-Update }
    "archive"       { Show-Archive }
    "slim"          { Show-Slim }
    "commit"        { Invoke-Commit }
    "upgrade"       { Invoke-Upgrade }
    "budget"        { Show-Budget }
    "help"          { Show-Help }
}
