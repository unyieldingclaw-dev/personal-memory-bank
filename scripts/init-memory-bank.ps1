<#
.SYNOPSIS
    Initialize Memory Bank Standard in a project.

.DESCRIPTION
    Creates memory-bank/ directory with template files, .cursor/rules/ with rule files,
    and CLAUDE.md for Claude Code compatibility.

.PARAMETER ProjectPath
    Path to the project. Defaults to current directory.

.PARAMETER SkipCursor
    Skip creating .cursor/rules/ files.

.PARAMETER SkipClaude
    Skip creating CLAUDE.md file.

.PARAMETER Force
    Overwrite existing files.

.EXAMPLE
    .\init-memory-bank.ps1
    
.EXAMPLE
    .\init-memory-bank.ps1 -ProjectPath "C:\Projects\MyApp" -Force
#>

param(
    [string]$ProjectPath = ".",
    [switch]$SkipCursor,
    [switch]$SkipClaude,
    [switch]$Force
)

# WHY: We calculate paths relative to script location, not current directory,
# because users might run this from anywhere (downloaded, cloned, or via irm).
# This ensures we always find the templates/ folder regardless of where they invoke from.
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TemplatesDir = Join-Path (Split-Path -Parent $ScriptDir) "templates"

# WHY: Resolve-Path with SilentlyContinue prevents errors when path doesn't exist yet.
# We fall back to Get-Location (current directory) as a sensible default for new projects.
# This allows ".\init-memory-bank.ps1" to work without specifying a path.
$ProjectPath = Resolve-Path $ProjectPath -ErrorAction SilentlyContinue
if (-not $ProjectPath) {
    $ProjectPath = Get-Location
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Memory Bank Standard - Project Setup" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Project: $ProjectPath" -ForegroundColor Yellow
Write-Host ""

# WHY: Fail fast if templates are missing - better to error immediately than
# create partial/broken setup. This catches the common mistake of running the
# script from the wrong directory or after moving it without the templates/ folder.
if (-not (Test-Path $TemplatesDir)) {
    Write-Host "Error: Templates directory not found at $TemplatesDir" -ForegroundColor Red
    Write-Host "Make sure you're running this from the memory-bank-standard directory." -ForegroundColor Red
    exit 1
}

# WHY: Centralized copy function enforces consistent behavior across all file operations.
# The -Force flag respects user intent (overwrite vs skip), preventing accidental data loss
# while still allowing intentional updates. We create parent directories automatically
# because PowerShell's Copy-Item doesn't do this, and failing on missing dirs is confusing.
# WHY: Operates on a single file rather than a directory tree. Callers iterate source
# files and invoke Copy-Template per file so the skip-if-exists decision can be made
# independently for each destination -- a recursive Copy-Item would be all-or-nothing
# and would clobber any Memory Bank file a user had already customized, defeating the
# whole point of preserving user edits across re-runs.
function Copy-Template {
    param(
        [string]$Source,
        [string]$Destination
    )

    # WHY: Auto-create parent directories to avoid cryptic "path not found" errors.
    # Users shouldn't need to manually create .cursor/rules/ before running this.
    # WHY: Pipe to Out-Null because New-Item emits the created DirectoryInfo object to
    # the pipeline by default, which would interleave noisy "Directory: ..." output with
    # our own Write-Host status lines and make the setup log hard to scan.
    $DestDir = Split-Path -Parent $Destination
    if (-not (Test-Path $DestDir)) {
        New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
    }

    if (Test-Path $Destination) {
        if ($Force) {
            Write-Host "  Overwriting: $Destination" -ForegroundColor Yellow
        } else {
            # WHY: Skip existing files by default to preserve user customizations.
            # Memory Bank files often get hand-edited, and we don't want to clobber them.
            Write-Host "  Skipping (exists): $Destination" -ForegroundColor DarkGray
            return
        }
    } else {
        Write-Host "  Creating: $Destination" -ForegroundColor Green
    }
    Copy-Item -Path $Source -Destination $Destination -Force
}

# 1. Create memory-bank directory
Write-Host "1. Setting up Memory Bank files..." -ForegroundColor Cyan
$MemoryBankSrc = Join-Path $TemplatesDir "memory-bank"
$MemoryBankDst = Join-Path $ProjectPath "memory-bank"

if (-not (Test-Path $MemoryBankDst)) {
    New-Item -ItemType Directory -Path $MemoryBankDst -Force | Out-Null
}

Get-ChildItem $MemoryBankSrc -File | ForEach-Object {
    Copy-Template -Source $_.FullName -Destination (Join-Path $MemoryBankDst $_.Name)
}

# 2. Create .cursor/rules if not skipped
if (-not $SkipCursor) {
    Write-Host ""
    Write-Host "2. Setting up Cursor rules..." -ForegroundColor Cyan
    $CursorSrc = Join-Path $TemplatesDir "cursor\rules"
    $CursorDst = Join-Path $ProjectPath ".cursor\rules"
    
    if (-not (Test-Path $CursorDst)) {
        New-Item -ItemType Directory -Path $CursorDst -Force | Out-Null
    }
    
    Get-ChildItem $CursorSrc -File | ForEach-Object {
        Copy-Template -Source $_.FullName -Destination (Join-Path $CursorDst $_.Name)
    }
} else {
    Write-Host ""
    Write-Host "2. Skipping Cursor rules (--SkipCursor)" -ForegroundColor DarkGray
}

# 3. Create CLAUDE.md, AGENTS.md, and .claude/commands/ if not skipped
if (-not $SkipClaude) {
    Write-Host ""
    Write-Host "3. Setting up Claude Code..." -ForegroundColor Cyan
    $ClaudeSrc = Join-Path $TemplatesDir "CLAUDE.md"
    $ClaudeDst = Join-Path $ProjectPath "CLAUDE.md"
    Copy-Template -Source $ClaudeSrc -Destination $ClaudeDst

    # WHY: AGENTS.md is the cross-tool rules file readable by Claude Code, Cursor, Codex,
    # and Gemini CLI. Copying it per-project ensures any tool can pick up the rules even
    # without the global ~/.claude/AGENTS.md setup.
    $AgentsSrc = Join-Path $TemplatesDir "AGENTS.md"
    $AgentsDst = Join-Path $ProjectPath "AGENTS.md"
    Copy-Template -Source $AgentsSrc -Destination $AgentsDst

    # Copy .claude/commands/ slash commands
    $ClaudeCommandsSrc = Join-Path $TemplatesDir "claude-commands"
    $ClaudeCommandsDst = Join-Path $ProjectPath ".claude\commands"
    if (-not (Test-Path $ClaudeCommandsDst)) {
        New-Item -ItemType Directory -Path $ClaudeCommandsDst -Force | Out-Null
    }
    Get-ChildItem $ClaudeCommandsSrc -File | ForEach-Object {
        Copy-Template -Source $_.FullName -Destination (Join-Path $ClaudeCommandsDst $_.Name)
    }
} else {
    Write-Host ""
    Write-Host "3. Skipping CLAUDE.md, AGENTS.md, and .claude/commands/ (-SkipClaude)" -ForegroundColor DarkGray
}

# 4. Copy handoff and plan templates
Write-Host ""
Write-Host "4. Copying utility templates..." -ForegroundColor Cyan
Copy-Template -Source (Join-Path $TemplatesDir "handoff.md") -Destination (Join-Path $ProjectPath "templates\handoff.md")
Copy-Template -Source (Join-Path $TemplatesDir "plan.md") -Destination (Join-Path $ProjectPath "templates\plan.md")

# WHY: We modify .gitignore to prevent committing temporary AI files.
# .superpowers/ contains brainstorming sessions (can be large, not needed in repo).
# handoff.md is ephemeral - only exists between context switches, should never be committed.
# We check for existing entries to avoid duplicate lines on repeated runs.
Write-Host ""
Write-Host "5. Updating .gitignore..." -ForegroundColor Cyan
$GitIgnore = Join-Path $ProjectPath ".gitignore"
$IgnoreLines = @(
    "",
    "# Memory Bank Standard",
    ".superpowers/",
    "handoff.md"
)

if (Test-Path $GitIgnore) {
    $Content = Get-Content $GitIgnore -Raw
    # WHY: Check for .superpowers/ specifically because it's the most unique marker.
    # If it exists, assume we've already added our entries (idempotent behavior).
    if ($Content -notmatch "\.superpowers/") {
        Add-Content -Path $GitIgnore -Value ($IgnoreLines -join "`n")
        Write-Host "  Added .superpowers/ to .gitignore" -ForegroundColor Green
    } else {
        Write-Host "  .gitignore already configured" -ForegroundColor DarkGray
    }
} else {
    # WHY: Create .gitignore if missing - many projects forget this file initially.
    # Better to create it with our entries than skip this step.
    Set-Content -Path $GitIgnore -Value ($IgnoreLines -join "`n")
    Write-Host "  Created .gitignore" -ForegroundColor Green
}

# Summary
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Setup Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Created files:" -ForegroundColor Yellow
Write-Host "  memory-bank/"
Write-Host "    projectbrief.md    - Fill in your project requirements"
Write-Host "    systemPatterns.md  - Document your architecture"
Write-Host "    techContext.md     - Specify your tech stack"
Write-Host "    activeContext.md   - Track current work"
Write-Host "    progress.md        - Track progress"
if (-not $SkipCursor) {
    Write-Host "  .cursor/rules/"
    Write-Host "    memory-bank.mdc       - Memory Bank loading"
    Write-Host "    security.mdc          - Security guardrails"
    Write-Host "    code-quality.mdc      - Quality standards"
    Write-Host "    enterprise-logging.mdc - Structured logging"
    Write-Host "    workflow.mdc          - Feature development workflow"
    Write-Host "    accessibility.mdc     - WCAG 2.1 AA (glob-scoped to UI files)"
    Write-Host "    rules-file-integrity.mdc - Anti-prompt-injection hygiene for rule files (glob-scoped)"
}
if (-not $SkipClaude) {
    Write-Host "  CLAUDE.md            - Claude Code instructions"
    Write-Host "  AGENTS.md            - Cross-tool rules (Claude Code + Cursor + Codex + Gemini)"
    Write-Host "  .claude/commands/"
    Write-Host "    code-review.md          - /code-review slash command (security, perf, style, tests)"
    Write-Host "    accessibility-review.md - /accessibility-review slash command (WCAG 2.1 AA)"
}
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Fill in memory-bank/projectbrief.md with your project details"
Write-Host "  2. Fill in memory-bank/techContext.md with your tech stack"
Write-Host "  3. Start coding - AI will automatically have context!"
Write-Host ""
Write-Host "Tip: For one-time global setup (rules + plugins for ALL projects)," -ForegroundColor DarkCyan
Write-Host "     see docs/CLAUDE-CODE-PLUGINS.md" -ForegroundColor DarkCyan
Write-Host ""
Write-Host "Quick commands:" -ForegroundColor Yellow
Write-Host "  mb status  - Check Memory Bank health"
Write-Host "  mb update  - Update Memory Bank files"
Write-Host "  Handoff    - Create handoff for context continuation"
Write-Host ""
