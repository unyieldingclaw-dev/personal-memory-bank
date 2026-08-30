<#
.SYNOPSIS
    Auto-update last-reviewed frontmatter in memory-bank files after edits.

.DESCRIPTION
    Called by the PostToolUse hook after Write/Edit tool calls. Reads tool input
    JSON from stdin, checks if the edited file is inside memory-bank/, and updates
    the last-reviewed: frontmatter line with today's date. Silent on success.
#>

# WHY: Reads from stdin because Claude Code PostToolUse hooks pass tool input as JSON
# via stdin, not as command-line arguments.
try {
    # Same OEM-code-page defect fixed in dangerous-commands.ps1 on 2026-08-30, same fix. PowerShell
    # decodes piped stdin with [Console]::InputEncoding (ibm437 here), so a non-ASCII byte arrives
    # mangled. The blast radius here is narrower -- this script reads only .tool_input.file_path --
    # but a memory-bank path containing a non-ASCII character would silently fail to match, and this
    # script already fails silently by design, so nothing would report it.
    # detectEncodingFromByteOrderMarks MUST be $false. The 2-arg StreamReader(Stream, Encoding)
    # overload defaults it TRUE, so a leading BOM of a DIFFERENT encoding silently overrides the
    # UTF8Encoding passed in -- $sr.CurrentEncoding reported "Unicode" for an FF FE payload.
    # Reproduced end-to-end: a UTF-16-BOM payload carrying a BLOCK-tier command produced NO
    # output and exit 0, because the wide decode destroyed the literal substring the matchers
    # look for. Pinning the encoding while leaving BOM detection on pins nothing.
    $input_json = if ([Console]::IsInputRedirected) {
        (New-Object System.IO.StreamReader(
            [Console]::OpenStandardInput(),
            (New-Object System.Text.UTF8Encoding($false)),
            $false)).ReadToEnd()
    } else { "" }
    if ([string]::IsNullOrWhiteSpace($input_json)) { exit 0 }

    $parsed = $input_json | ConvertFrom-Json -ErrorAction Stop

    # WHY .tool_input.file_path, not .file_path: the real payload nests everything
    # under "tool_input" (e.g. {"tool_name":"Edit","tool_input":{"file_path":"..."}}),
    # matching the same fix already applied in check-contract.ps1 (confirmed there by
    # capturing a live hook payload). This script had the same flat-read bug and,
    # unlike check-contract.ps1/dangerous-commands.ps1, was never included in that fix
    # -- $file_path was always $null, so the script silently exited 0 on every call
    # without ever updating last-reviewed.
    $file_path = $parsed.tool_input.file_path
    if ([string]::IsNullOrWhiteSpace($file_path)) { exit 0 }

    # WHY: Normalize path separators before checking — Claude may pass forward slashes
    # on Windows or mixed paths depending on context.
    $normalized = $file_path -replace '\\', '/'
    if ($normalized -notmatch '/memory-bank/') { exit 0 }

    if (-not (Test-Path $file_path)) { exit 0 }

    $today = Get-Date -Format "yyyy-MM-dd"
    $content = Get-Content $file_path -Raw

    # WHY: Only update if the frontmatter block exists and contains last-reviewed.
    # Don't add frontmatter to files that don't have it — that's a human decision.
    if ($content -match 'last-reviewed:') {
        $updated = $content -replace '(?m)^last-reviewed:.*$', "last-reviewed: $today"
        if ($updated -ne $content) {
            Set-Content $file_path $updated -NoNewline
        }
    }
} catch {
    # WHY: Silent failure — this hook must never block agent work. If the update
    # fails, the agent continues; the user can run mb audit to find stale files.
    # WHY: Log to .pmb-hook-errors.log so mb doctor can surface repeated failures.
    try { Add-Content ".pmb-hook-errors.log" "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [HOOK] update-reviewed.ps1: $_" -ErrorAction SilentlyContinue } catch { Write-Verbose "Could not write .pmb-hook-errors.log; ignoring." }
    exit 0
}

exit 0
