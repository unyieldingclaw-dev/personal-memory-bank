# PreToolUse hook — blocks git commit/push until the matching review slash command has run.
# /code-review writes .claude/.code-review-ok on an Approve verdict; /change-review writes
# .claude/.change-review-ok when no finding is Blocking. Each marker authorizes exactly one
# commit or push -- this hook deletes it the moment it's consumed, so the next change needs a
# fresh review. Uses the {"continue": false, "stopReason": ...} JSON-stdout protocol (not exit
# codes) because settings.json wires this hook with a "|| true" fail-open suffix for portability
# across machines without pwsh/bash -- that wrapping swallows a nonzero exit code, but stdout
# JSON survives it and is what Claude Code actually reads to decide whether to block.
try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $cmd = ($raw | ConvertFrom-Json).tool_input.command
} catch { exit 0 }

if (-not $cmd) { exit 0 }

$root = git rev-parse --show-toplevel 2>$null
if (-not $root) { exit 0 }

function Test-AndConsumeMarker {
    param([string]$Marker)
    if (Test-Path $Marker) {
        Remove-Item $Marker -Force
        return $true
    }
    return $false
}

if ($cmd -match '(^|[;&|]\s*)git\s+commit\b') {
    if (-not (Test-AndConsumeMarker (Join-Path $root '.claude/.code-review-ok'))) {
        Write-Output '{"continue": false, "stopReason": "Run /code-review before committing -- it writes the review-ok marker this hook checks."}'
    }
} elseif ($cmd -match '(^|[;&|]\s*)git\s+push\b') {
    if (-not (Test-AndConsumeMarker (Join-Path $root '.claude/.change-review-ok'))) {
        Write-Output '{"continue": false, "stopReason": "Run /change-review before pushing -- it writes the review-ok marker this hook checks."}'
    }
}
