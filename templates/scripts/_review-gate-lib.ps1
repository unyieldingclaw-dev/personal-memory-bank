# scripts/_review-gate-lib.ps1 -- shared helpers for review-reminders.ps1 / review-reminders-post.ps1
# (PreToolUse / PostToolUse review-gate hook pair). Dot-sourced, not executed directly.
#
# WHY this file exists: Get-FileHashHex was duplicated verbatim in both hook files; the
# cd-chain-walk + JSON command extraction (~20 lines) was duplicated as raw inline code in
# both, never wrapped in a function at all; and review-reminders-post.ps1 never reused
# Get-CommitDiffHash/Get-PushDiffHash, instead inlining its own third, structurally
# duplicated copy of the same diff+hash pattern. See
# docs/superpowers/specs/2026-07-29-review-gate-hook-lib-dedup-design.md for the full design.
#
# WHY Resolve-CdRoot takes the already-parsed $cmd string as an explicit parameter, unlike
# bash's parameterless resolve_cd_root() (which relies on a caller-set global $input): both
# PowerShell hook files already parse $raw into $cmd near the top of the file
# (($raw | ConvertFrom-Json).tool_input.command) because their *own* subsequent case-matching
# ($cmd -match 'git\s+commit\b', etc.) operates on the parsed value, not the raw payload --
# unlike bash, PowerShell needs the parsed command string for reasons unrelated to
# root-resolution. Since the caller has already parsed $cmd for its own purposes before
# root-resolution runs, having Resolve-CdRoot re-parse the raw JSON internally would just be
# redundant, not a reduction in duplication. Taking $cmd as an explicit parameter is
# therefore the correct contract for PowerShell, not an inconsistency with bash's design --
# the two languages' surrounding scripts have genuinely different structure at this point.
#
# WHY resolve the FULL leading cd chain, not just the first cd: a chained command
# (`cd "A" && cd "B" && git commit ...`) must resolve to B's root, not A's, or a marker
# earned reviewing A wrongly authorizes a commit that actually runs in B. Reproduced
# directly against a previous single-match regex: it captured "A" and only "A" from that
# exact chained string. A single-quoted here-string (@'...'@) holds the pattern so both `"`
# and `'` can appear in it with no escaping, matching _review-gate-lib.sh's heredoc approach
# for the same reason.
function Resolve-CdRoot {
    param([string]$Cmd)
    $cdRoot = $null
    $chainPatternText = @'
^cd\s+(?:"([^"]+)"|'([^']+)')\s*&&\s*
'@
    $chainPattern = [regex]$chainPatternText
    $restCmd = $Cmd
    $curDir = (Get-Location).Path
    $matchedAny = $false
    while ($true) {
        $m = $chainPattern.Match($restCmd)
        if (-not $m.Success) { break }
        $matchedAny = $true
        $p = if ($m.Groups[1].Success) { $m.Groups[1].Value } else { $m.Groups[2].Value }
        $curDir = if ([System.IO.Path]::IsPathRooted($p)) { $p } else { [System.IO.Path]::GetFullPath((Join-Path $curDir $p)) }
        $restCmd = $restCmd.Substring($m.Length)
    }
    if ($matchedAny) {
        $candidate = git -C $curDir rev-parse --show-toplevel 2>$null
        if ($candidate) { $cdRoot = $candidate }
    }
    return $cdRoot
}

# WHY hash a file written via redirection, not a piped/captured string: PowerShell's
# pipeline re-tokenizes external-command output into a line-object array and back, which
# does not reproduce the exact byte stream (trailing newline, line endings) that piping
# the same command through bash produces. Empirically confirmed: (git diff HEAD) -join
# "`n" then hashed did NOT match `git diff HEAD | sha256sum` for the identical diff.
# Redirecting to a file (`>`) writes raw bytes with no such re-tokenization on either
# platform -- confirmed empirically to produce byte-identical files (and therefore
# identical hashes) whether written from PowerShell or from bash. This matters because
# review-reminders.ps1 is the hook that actually runs on any machine with pwsh installed
# (preferred over the .sh fallback), so its hash must match what /code-review's
# instructions produce regardless of which shell the human or agent used to write it.
function Get-FileHashHex {
    param([string]$Path)
    return (Get-FileHash -Path $Path -Algorithm SHA256).Hash.ToLower()
}

function Get-CommitDiffHash {
    $tmp = [System.IO.Path]::GetTempFileName()
    try {
        git diff HEAD > $tmp 2>$null
        return Get-FileHashHex $tmp
    } finally {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }
}

function Get-PushDiffHash {
    $tmp = [System.IO.Path]::GetTempFileName()
    try {
        git diff origin/main...HEAD > $tmp 2>$null
        if ($LASTEXITCODE -ne 0) {
            git diff HEAD > $tmp 2>$null
        }
        return Get-FileHashHex $tmp
    } finally {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }
}
