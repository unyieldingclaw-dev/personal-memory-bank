# Emit PMB recovery context after Codex compacts the session.
param(
    [string]$Mode
)

try {
    $repoRoot = (& git rev-parse --show-toplevel 2>$null | Select-Object -First 1)
    if (-not $repoRoot) { exit 0 }
    Set-Location $repoRoot

    if ($Mode -ne 'recover') { exit 0 }

    [Console]::Out.WriteLine("After compaction, re-read all five memory-bank files before continuing and treat them as authoritative. Then read handoff.md if present as an ephemeral supplement, reconcile it with activeContext.md's Next Steps, surface any conflict, delete it only after merging its state, and resume from verified git/worktree/test state. Do not rely on the compaction summary alone.")
    exit 0
} catch {
    exit 0
}
