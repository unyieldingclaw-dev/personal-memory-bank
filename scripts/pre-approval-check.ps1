<#
.SYNOPSIS
    Stop hook enforcing the Pre-Approval Protocol (standards/WORKFLOW.md). Twin of
    pre-approval-check.sh; tests/test-pre-approval-check.sh holds the two in parity.
.DESCRIPTION
    Tier A: a turn ending in an approve-or-choose ask must carry a "Findings" heading AND a
    Recommendation. Tier B: a turn ending in any other question must carry a Recommendation.
    Emits {"decision":"block",...} on stdout and always exits 0. settings.json runs this script as
    the first link of `pwsh ... || bash pre-approval-check.sh ... || <fallback notifier> || true`,
    with stderr discarded, so a non-zero exit would also run the .sh twin: a second check and a
    second notification. Owns the "Claude has paused" notification, launched detached on every exit
    except a block.
    Spec: docs/superpowers/specs/2026-09-21-pre-approval-protocol-design.md
#>
$ErrorActionPreference = 'Stop'
$script:blocked = $false
$logPath = '.pmb-pre-approval.log'
$errLogPath = '.pmb-hook-errors.log'
$reasonA = 'Pre-approval protocol: this message asks the user to approve or choose, but lacks a Findings section and/or a Recommendation. Run the checks the options depend on (standards/WORKFLOW.md, Pre-Approval Protocol) and re-send the ask with both. If it does not ask for approval or a choice, reply `Not an approval ask:` with one line of why, and stop.'
$reasonB = 'Pre-approval protocol: this message ends in a question but gives no Recommendation. Add what you recommend and why. If no recommendation can apply (for example, you need a fact only the user has), reply `No recommendation applies:` with one line of why, and stop.'

# WHY explicit IgnoreCase rather than relying on -match's default: the .sh twin's Python `re` is
# case-sensitive unless told otherwise, and a silent difference let "**My recommendation:**" pass
# one twin and fail the other (review finding N3). Both twins now pin it.
$rxOpts = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Multiline
$askRx = [regex]::new('should I (proceed|continue)|want me to|shall I|go ahead|does that work|which (option|approach|would you)|your call|tell me (which|whether|how|what)|how would you like|would you like|proceed\?|(say|type) "approved"|\bapprove (it|this|that|the)\b|\bapprove\?|say the word|your go-ahead|let me know (if|once|whether|when|which)|before (I|we) (move|proceed|continue|start|begin)', $rxOpts)
$findingsRx = [regex]::new('^#{1,4}[ \t].*\bfindings\b', $rxOpts)
$recommendRx = [regex]::new('^#{1,4}[ \t].*recommend|\*\*[^*\n]*recommend|\*\*verdict:', $rxOpts)
$escARx = [regex]::new('^\W*not an approval ask:', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
$escBRx = [regex]::new('^\W*no recommendation applies:', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

function Add-LogLine {
    param([string]$Line)
    try { Add-Content -LiteralPath $logPath -Value $Line } catch { Write-Verbose "Could not write $logPath; ignoring." }
}

# At most one line per kind, so a persistent fault cannot bury other hooks' errors in `mb doctor`'s
# `tail -3` of the shared log. The key has a session field, but every caller passes '-' (most errors
# come before a session id is known), so in practice it is once per kind until the log is cleared.
# The trial log still records each fail-open this script reaches.
function Write-HookErrorOnce {
    param([string]$Session, [string]$Kind, [string]$Detail)
    $key = "pre-approval-check.ps1: session=$Session kind=$Kind"
    try {
        if ((Test-Path -LiteralPath $errLogPath) -and (Select-String -LiteralPath $errLogPath -SimpleMatch -Pattern $key -Quiet)) { return }
        Add-Content -LiteralPath $errLogPath -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [HOOK] $key $Detail"
    } catch { Write-Verbose "Could not write $errLogPath; ignoring." }
}

# Every fail-open also goes to the trial log (review finding F6), with no message text.
function Add-FailOpenLine {
    param([string]$Session, [string]$Kind)
    Add-LogLine -Line "$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss') session=$Session event=failopen kind=$Kind"
}

function Invoke-PausedNotification {
    $onWindows = $IsWindows -or ($env:OS -eq 'Windows_NT')
    $stub = $env:PMB_NOTIFY_STUB
    $delay = 0
    if ($env:PMB_NOTIFY_STUB_DELAY) { $delay = [int]$env:PMB_NOTIFY_STUB_DELAY }
    if ($onWindows) {
        # WHY Start-Process: it launches through ShellExecute, so the child does not inherit (and
        # hold open) the hook's stdout pipe. The harness would otherwise wait for the popup to close.
        if ($stub) {
            $exe = (Get-Process -Id $PID).Path
            $cmd = "Start-Sleep -Seconds $delay; Add-Content -LiteralPath '$stub' -Value notify"
        } else {
            $exe = 'powershell.exe'
            # WScript.Shell.Popup is set to close after 600 s (not timed, spec section 3); nothing else
            # would close a detached popup.
            $cmd = "(New-Object -ComObject WScript.Shell).Popup('Claude has paused and is waiting for input.', 600, 'Claude Code', 64) | Out-Null"
        }
        Start-Process -FilePath $exe -ArgumentList "-NoProfile -NonInteractive -Command `"$cmd`"" -WindowStyle Hidden
    } elseif ($stub) {
        & /bin/sh -c "(sleep $delay; echo notify >> '$stub') >/dev/null 2>&1 </dev/null &"
    } else {
        & /bin/sh -c 'osascript -e ''display notification "Claude has paused and is waiting for input." with title "Claude Code"'' >/dev/null 2>&1 </dev/null & notify-send ''Claude Code'' ''Claude has paused and is waiting for input.'' >/dev/null 2>&1 </dev/null &'
    }
}

try {
    # WHY case-sensitive AND ordinal: -eq ignores case, so "OFF" disabled this twin but not the .sh,
    # whose test is exact (review finding C2); -ceq fixes that but is still culture-aware, so 'off'
    # plus a zero-width character (measured with U+200B) compared equal here and not in the .sh.
    if ([string]::Equals($env:PMB_PRE_APPROVAL, 'off', [StringComparison]::Ordinal)) { return }
    # WHY a UTF-8 StreamReader, not [Console]::In: on Windows the latter decodes with the OEM code
    # page (ibm437), splitting each non-ASCII character into several (review finding F5). Same fix as
    # dangerous-commands.ps1.
    $raw = if ([Console]::IsInputRedirected) {
        (New-Object System.IO.StreamReader([Console]::OpenStandardInput(), (New-Object System.Text.UTF8Encoding($false)), $true)).ReadToEnd()
    } else { '' }
    if ($env:PMB_PRE_APPROVAL_TEST_FAULT -eq '1') { throw 'test-only fault (tests/test-pre-approval-check.sh)' }

    $d = $null
    try { $d = $raw | ConvertFrom-Json } catch { $d = $null }
    if ($null -eq $d -or $d -isnot [System.Management.Automation.PSCustomObject]) {
        Write-HookErrorOnce -Session '-' -Kind 'parse' -Detail 'payload could not be parsed; turn allowed without checking'
        Add-FailOpenLine -Session '-' -Kind 'parse'
        return
    }

    $sid = '-'
    if ($d.session_id) {
        $sid = [string]$d.session_id
        if ($sid.Length -gt 8) { $sid = $sid.Substring(0, 8) }
    }
    $msg = ''
    if ($d.last_assistant_message -is [string]) { $msg = $d.last_assistant_message }
    $hasF = $findingsRx.IsMatch($msg)
    $hasR = $recommendRx.IsMatch($msg)
    $now = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'

    if (($d.stop_hook_active -is [bool]) -and $d.stop_hook_active) {
        $esc = 'none'
        if ($escARx.IsMatch($msg)) { $esc = 'not_an_approval_ask' } elseif ($escBRx.IsMatch($msg)) { $esc = 'no_recommendation_applies' }
        $f = if ($hasF) { 'yes' } else { 'no' }
        $r = if ($hasR) { 'yes' } else { 'no' }
        Add-LogLine -Line "$now session=$sid event=post-block findings=$f recommendation=$r escape=$esc"
        return
    }
    if ([string]::IsNullOrWhiteSpace($msg)) { return }

    $end = if ($msg.Length -gt 400) { $msg.Substring($msg.Length - 400) } else { $msg }
    $tierA = $askRx.IsMatch($end)
    $tierB = $false
    if (-not $tierA) {
        $lines = @([regex]::Split($end, '\r\n|\n|\r') | Where-Object { $_.Trim() })
        if ($lines.Count -gt 0) {
            $last = $lines[-1].TrimEnd().TrimEnd([char[]]@('*', '_', '`', "'", '"', ')')).TrimEnd()
            # WHY ordinal: the default EndsWith is culture-aware and ignores zero-width, soft-hyphen and
            # some control characters, so "?" plus U+200B was a question here but not in the .sh.
            $tierB = $last.EndsWith('?', [StringComparison]::Ordinal)
        }
    }

    $tier = $null
    $missing = $null
    if ($tierA -and -not ($hasF -and $hasR)) {
        $tier = 'A'
        if (-not ($hasF -or $hasR)) { $missing = 'both' } elseif (-not $hasF) { $missing = 'findings' } else { $missing = 'recommendation' }
    } elseif ($tierB -and -not $hasR) {
        $tier = 'B'
        $missing = 'recommendation'
    }
    if ($tier) {
        $script:blocked = $true
        Add-LogLine -Line "$now session=$sid event=block tier=$tier missing=$missing"
        $reason = if ($tier -eq 'A') { $reasonA } else { $reasonB }
        [Console]::Out.WriteLine(([ordered]@{ decision = 'block'; reason = $reason } | ConvertTo-Json -Compress))
    }
}
catch {
    Write-HookErrorOnce -Session '-' -Kind 'unexpected' -Detail "$_"
    Add-FailOpenLine -Session '-' -Kind 'unexpected'
}
finally {
    if (-not $script:blocked) {
        try { Invoke-PausedNotification } catch { Write-Verbose "Notification launch failed; ignoring." }
    }
    exit 0
}
