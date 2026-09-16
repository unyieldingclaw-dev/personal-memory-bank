<# Translate PMB's existing compaction policy into Codex's hook response contract. #>
param(
    [ValidateSet('pre', 'recover')]
    [string]$Mode
)

try {
    $repoRoot = (& git rev-parse --show-toplevel 2>$null | Select-Object -First 1)
    if (-not $repoRoot) { exit 0 }
    Set-Location $repoRoot

    if ($Mode -eq 'pre') {
        $checker = Join-Path $repoRoot 'scripts/pre-compact-check.ps1'
        if (-not (Test-Path -LiteralPath $checker)) { exit 0 }

        & pwsh -NoProfile -NonInteractive -File $checker *> $null
        $gateCode = $LASTEXITCODE
        if ($gateCode -eq 2) {
            [ordered]@{
                continue      = $false
                stopReason    = 'PMB memory-bank state is not ready for compaction.'
                systemMessage = 'Update memory-bank/activeContext.md and memory-bank/progress.md, or create a current handoff.md, then retry compaction. Run scripts/pre-compact-check.ps1 for detailed reasons.'
            } | ConvertTo-Json -Compress
        }
        # A policy block is carried by valid JSON. All unexpected failures remain fail-open.
        exit 0
    }

    [Console]::Out.WriteLine("After compaction, re-read all five memory-bank files before continuing and treat them as authoritative. Then read handoff.md if present as an ephemeral supplement, reconcile it with activeContext.md's Next Steps, surface any conflict, delete it only after merging its state, and resume from verified git/worktree/test state. Do not rely on the compaction summary alone.")
    exit 0
} catch {
    exit 0
}
