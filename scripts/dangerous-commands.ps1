<#
.SYNOPSIS
    PreToolUse hook — 3-tier dangerous command guardrails for Claude Code.
.DESCRIPTION
    Reads the Bash tool input JSON from stdin, extracts the command string,
    and enforces BLOCK / CONFIRM / WARN tier matching via simple substring checks.
    All output goes to stdout so messages are visible even when stderr is suppressed.
    Fails open: any unexpected error prints [HOOK ERROR] and exits 0.
#>

param()

# Centralized tier messages — all pattern matches use these templates, no custom text per pattern.
$BLOCK_MSG   = "BLOCK: {0}. Refusing this command."
$CONFIRM_MSG = "CONFIRM REQUIRED: {0}. Run manually if intentional."
$WARN_MSG    = "WARNING: {0}. Proceeding."

try {
    # WHY: $input | Out-String matches how update-reviewed.ps1 reads stdin from Claude Code hooks.
    $raw = $input | Out-String
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $data = $raw | ConvertFrom-Json -ErrorAction Stop
    $cmd = if ($data.command) { [string]$data.command } else { "" }
} catch {
    Write-Host "[HOOK ERROR] dangerous-commands.ps1 failed unexpectedly."
    Write-Host "Proceeding in fails-open mode."
    exit 0
}

# BLOCK: irreversible or highly destructive — refuse unconditionally
$blockPatterns = @(
    @{ pattern = "rm -rf";           reason = "irreversible recursive deletion" }
    @{ pattern = "mkfs";             reason = "filesystem format" }
    @{ pattern = "dd if=";           reason = "disk wipe or dump" }
    @{ pattern = "git push --force"; reason = "force push (long form)" }
    @{ pattern = "git push -f";      reason = "force push (short form)" }
    @{ pattern = "DROP TABLE";       reason = "SQL table drop" }
    @{ pattern = "DROP DATABASE";    reason = "SQL database drop" }
    @{ pattern = "| bash";           reason = "command piped to bash (curl|bash, wget|bash, etc.)" }
    @{ pattern = "| sh";             reason = "command piped to sh" }
)

foreach ($entry in $blockPatterns) {
    if ($cmd.Contains($entry.pattern)) {
        Write-Host ($BLOCK_MSG -f $entry.reason)
        exit 1
    }
}

# CONFIRM: advanced ops with legitimate uses — require explicit manual invocation
$confirmPatterns = @(
    @{ pattern = "git filter-branch"; reason = "history rewriting" }
    @{ pattern = "git update-ref";    reason = "low-level ref manipulation" }
    @{ pattern = "sudo rm";           reason = "privileged deletion" }
    @{ pattern = "chmod -R 777";      reason = "world-writable recursive chmod" }
    @{ pattern = "--no-verify";       reason = "bypasses pre-commit hooks (local governance)" }
)

foreach ($entry in $confirmPatterns) {
    if ($cmd.Contains($entry.pattern)) {
        Write-Host ($CONFIRM_MSG -f $entry.reason)
        exit 1
    }
}

# WARN: credential/secrets access — legitimate workflows exist, surface the access only
$warnPatterns = @(
    @{ pattern = "id_rsa";           reason = "SSH private key access" }
    @{ pattern = ".pem";             reason = "certificate or key file access" }
    @{ pattern = ".env.production";  reason = "production secrets file" }
    @{ pattern = "credentials.json"; reason = "credential file access" }
)

foreach ($entry in $warnPatterns) {
    if ($cmd.Contains($entry.pattern)) {
        Write-Host ($WARN_MSG -f $entry.reason)
    }
}

exit 0
