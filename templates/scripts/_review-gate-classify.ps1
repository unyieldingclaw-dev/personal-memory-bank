# Classify a PreToolUse payload as COMMIT / PUSH / MERGE / NONE.
# This is the PowerShell-native twin of _review-gate-classify.py. Keeping classification
# native matters on Windows, where pwsh is the primary hook path and python3 is not assumed.

$script:ReviewGateGlobalWithArg = @('-c', '-C', '--exec-path', '--git-dir', '--work-tree',
    '--namespace', '--config-env', '--super-prefix')
$script:ReviewGateGlobalFlags = @('--no-pager', '--paginate', '-p', '--bare',
    '--no-replace-objects', '--literal-pathspecs', '--no-optional-locks',
    '--glob-pathspecs', '--noglob-pathspecs', '--icase-pathspecs', '--html-path',
    '--man-path', '--info-path', '--no-lazy-fetch')
$script:ReviewGateWrappers = @('env', 'sudo', 'doas', 'command', 'nohup', 'time', 'nice',
    'ionice', 'stdbuf', 'setsid', 'eval', 'exec')
$script:ReviewGateShellLaunchers = @('bash', 'sh', 'dash', 'zsh', 'ksh', 'fish', 'ash')
$script:ReviewGatePowerShellLaunchers = @('pwsh', 'powershell')
$script:ReviewGateXargsWithArg = @('-a', '--arg-file', '-E', '--eof', '-I', '--replace',
    '-L', '--max-lines', '-n', '--max-args', '-P', '--max-procs', '-s', '--max-chars')
$script:ReviewGateSshWithArg = @('-B', '-b', '-c', '-D', '-E', '-e', '-F', '-I', '-i', '-J',
    '-L', '-l', '-m', '-O', '-o', '-P', '-p', '-Q', '-R', '-S', '-W', '-w')

# PowerShell's -eq, -ceq, -contains, -ccontains and -in, and the string overloads of StartsWith and
# EndsWith, compare by culture, which ignores characters such as U+00AD (soft hyphen) and equates
# look-alikes: @('-I') -ccontains ('-I' + [char]0xAD) is True, and so is [char]0x207D -in @('(')
# (measured, pwsh 7.6). The first made this twin skip `git` in `xargs -I<U+00AD> git commit` as an
# option argument; the second split `git -c a.b=c<U+207D>x commit` before its verb. Both commits
# ran, and the Python twin, which compares code points, denied both. So every comparison here is
# ordinal (the -match regexes aside: they only add matches); characters are compared as [int], since
# char -eq ignores case. tests/test-review-gate-classify-parity.sh parses this file and refuses a
# culture-aware comparison.
function Test-ReviewGateSame([string]$A, [string]$B) { return [string]::Equals($A, $B, [System.StringComparison]::Ordinal) }
function Test-ReviewGateOneOf([string]$Text, [string[]]$List) {
    foreach ($x in $List) { if ([string]::Equals($Text, $x, [System.StringComparison]::Ordinal)) { return $true } }
    return $false
}

function Get-ReviewGateBaseName {
    param([string]$Token)
    $trimmed = $Token.Trim([char[]]@('"', "'")) -replace '\\', '/'
    $base = ($trimmed -split '/')[-1].ToLowerInvariant()
    if ($base.EndsWith('.exe', [System.StringComparison]::Ordinal)) { $base = $base.Substring(0, $base.Length - 4) }
    return $base
}

function Get-ReviewGateLeadingExecutable {
    param([string[]]$Tokens)
    $i = 0
    while ($i -lt $Tokens.Count) {
        $token = $Tokens[$i]
        $bare = $token.Trim([char[]]@('"', "'"))
        if ($token -match '^[A-Za-z_][A-Za-z0-9_]*=' -or
            (Test-ReviewGateOneOf (Get-ReviewGateBaseName $bare) $script:ReviewGateWrappers)) {
            $i++
            continue
        }
        break
    }
    if ($i -ge $Tokens.Count) { return $null }
    return [PSCustomObject]@{
        Executable = $Tokens[$i]
        Rest       = @($Tokens | Select-Object -Skip ($i + 1))
    }
}

function Get-ReviewGateGitVerb {
    param([string[]]$Tokens)
    $i = 0
    while ($i -lt $Tokens.Count) {
        $token = $Tokens[$i]
        if (Test-ReviewGateOneOf $token $script:ReviewGateGlobalWithArg) {
            $i += 2
            continue
        }
        if ($token.StartsWith('--', [System.StringComparison]::Ordinal) -and $token.Contains('=') -and
            (Test-ReviewGateOneOf $token.Split('=', 2)[0] $script:ReviewGateGlobalWithArg)) {
            $i++
            continue
        }
        if ((Test-ReviewGateOneOf $token $script:ReviewGateGlobalFlags) -or
            $token.StartsWith('-', [System.StringComparison]::Ordinal)) {
            $i++
            continue
        }
        return $token.Trim([char[]]@('"', "'")).ToLowerInvariant()
    }
    return $null
}

function Get-ReviewGateLeadingCdPath {
    param([string]$Command)
    $patternText = @'
^cd\s+(?:"([^"]+)"|'([^']+)')\s*&&\s*
'@
    $pattern = [regex]$patternText
    $paths = @()
    $rest = $Command
    while ($true) {
        $match = $pattern.Match($rest)
        if (-not $match.Success) { break }
        $paths += if ($match.Groups[1].Success) { $match.Groups[1].Value } else { $match.Groups[2].Value }
        $rest = $rest.Substring($match.Length)
    }
    return @($paths)
}

# Tag names if $Command is exactly the tag-only push shape, else nothing. The pattern text is
# _review-gate-classify.py's TAG_PUSH, whose comment has the WHY. \A and \z because .NET's $
# also matches before a final newline; [regex] rather than -match, which ignores case.
function Get-ReviewGateTagPushName {
    param([string]$Command)
    $shapeText = @'
cd[ \t]+(?:"(?:[A-Za-z]:)?/[\x20\x21\x23\x25-\x29\x2B-\x3E\x40-\x5A\x5E\x5F\x61-\x7E]*"|'(?:[A-Za-z]:)?/[\x20-\x23\x25\x26\x28\x29\x2B-\x3E\x40-\x5A\x5E\x5F\x61-\x7E]*')[ \t]*&&[ \t]*git[ \t]+push[ \t]+[A-Za-z0-9_][A-Za-z0-9._-]*((?:[ \t]+(?:refs/tags/|tag[ \t]+)[A-Za-z0-9_][A-Za-z0-9._/-]*)+)
'@
    $nameText = @'
(?:refs/tags/|tag[ \t]+)([A-Za-z0-9_][A-Za-z0-9._/-]*)
'@
    if ([string]::IsNullOrEmpty($Command)) { return @() }
    $shape = ([regex]"\A(?:$shapeText)\z").Match($Command)
    if (-not $shape.Success) { return @() }
    return @(([regex]$nameText).Matches($shape.Groups[1].Value) | ForEach-Object { $_.Groups[1].Value })
}

function Get-ReviewGateGitContextPath {
    param([string[]]$Tokens)
    $paths = @()
    $i = 0
    while ($i -lt $Tokens.Count) {
        $token = $Tokens[$i].Trim([char[]]@('"', "'"))
        if (Test-ReviewGateSame $token '-C') {
            if ($i + 1 -ge $Tokens.Count) {
                return [PSCustomObject]@{ Paths = @(); Unsupported = $true }
            }
            $paths += $Tokens[$i + 1].Trim([char[]]@('"', "'"))
            $i += 2
            continue
        }
        if ($token.StartsWith('-C', [System.StringComparison]::Ordinal) -and $token.Length -gt 2) {
            $paths += $token.Substring(2)
            $i++
            continue
        }
        $option = $token.Split('=', 2)[0]
        if (Test-ReviewGateOneOf $option @('--git-dir', '--work-tree')) {
            return [PSCustomObject]@{ Paths = @(); Unsupported = $true }
        }
        if (Test-ReviewGateOneOf $token $script:ReviewGateGlobalWithArg) {
            $i += 2
            continue
        }
        if ($token.StartsWith('--', [System.StringComparison]::Ordinal) -and $token.Contains('=') -and
            (Test-ReviewGateOneOf $option $script:ReviewGateGlobalWithArg)) {
            $i++
            continue
        }
        if ((Test-ReviewGateOneOf $token $script:ReviewGateGlobalFlags) -or
            $token.StartsWith('-', [System.StringComparison]::Ordinal)) {
            $i++
            continue
        }
        break
    }
    return [PSCustomObject]@{ Paths = @($paths); Unsupported = $false }
}

function Get-ReviewGateVerdictFromInvocation {
    param([string]$Executable, [string[]]$Rest)
    $base = Get-ReviewGateBaseName $Executable
    if (Test-ReviewGateSame $base 'git') {
        $verb = Get-ReviewGateGitVerb $Rest
        if (Test-ReviewGateSame $verb 'commit') { return 'COMMIT' }
        if (Test-ReviewGateSame $verb 'push') { return 'PUSH' }
    } elseif (Test-ReviewGateSame $base 'gh') {
        $flat = (($Rest | ForEach-Object { $_.Trim([char[]]@('"', "'")) }) -join ' ')
        if ($flat -match '^pr\s+merge(?:\s|$)') { return 'MERGE' }
        if ($flat -match '^api(?:\s|$)' -and $flat -match '/pulls/\d+/merge') { return 'MERGE' }
    }
    return $null
}

function ConvertFrom-ReviewGateOuterQuote {
    param([string]$Value)
    $value = $Value.Trim()
    if ($value.Length -ge 2 -and [int]$value[0] -eq [int]$value[$value.Length - 1] -and
        ([int]$value[0] -eq 34 -or [int]$value[0] -eq 39)) {
        return $value.Substring(1, $value.Length - 2)
    }
    return $value
}

function Get-ReviewGateDollarParen {
    param([string]$Text, [int]$Start)
    $depth = 1
    $quote = 0
    $escaped = $false
    for ($i = $Start; $i -lt $Text.Length; $i++) {
        $c = [int]$Text[$i]
        if ($escaped) { $escaped = $false; continue }
        if ($c -eq 92 -and $quote -ne 39) { $escaped = $true; continue }
        if ($quote -ne 0) {
            if ($c -eq $quote) { $quote = 0 }
            continue
        }
        if ($c -eq 34 -or $c -eq 39) { $quote = $c; continue }
        if ($c -eq 36 -and $i + 1 -lt $Text.Length -and [int]$Text[$i + 1] -eq 40) {
            $depth++; $i++; continue
        }
        if ($c -eq 41) {
            $depth--
            if ($depth -eq 0) {
                return [PSCustomObject]@{ Body = $Text.Substring($Start, $i - $Start); End = $i }
            }
        }
    }
    return [PSCustomObject]@{ Body = $Text.Substring($Start); End = $Text.Length - 1 }
}

function Get-ReviewGateBacktickBody {
    param([string]$Text, [int]$Start)
    $escaped = $false
    for ($i = $Start; $i -lt $Text.Length; $i++) {
        $c = [int]$Text[$i]
        if ($escaped) { $escaped = $false; continue }
        if ($c -eq 92) { $escaped = $true; continue }
        if ($c -eq 96) {
            return [PSCustomObject]@{ Body = $Text.Substring($Start, $i - $Start); End = $i }
        }
    }
    return [PSCustomObject]@{ Body = $Text.Substring($Start); End = $Text.Length - 1 }
}

function Split-ReviewGateCommand {
    param([string]$Command)
    $segments = [System.Collections.Generic.List[string]]::new()
    $nested = [System.Collections.Generic.List[string]]::new()
    $buffer = [System.Text.StringBuilder]::new()
    $quote = 0
    $escaped = $false
    $i = 0
    while ($i -lt $Command.Length) {
        $ch = $Command[$i]
        $c = [int]$ch
        if ($escaped) {
            [void]$buffer.Append($ch); $escaped = $false; $i++; continue
        }
        if ($c -eq 92 -and $quote -ne 39) {
            [void]$buffer.Append($ch); $escaped = $true; $i++; continue
        }
        if ($quote -eq 39) {
            [void]$buffer.Append($ch)
            if ($c -eq 39) { $quote = 0 }
            $i++; continue
        }
        if ($c -eq 34) {
            [void]$buffer.Append($ch)
            $quote = if ($quote -eq 34) { 0 } else { 34 }
            $i++; continue
        }
        if ($c -eq 36 -and $i + 1 -lt $Command.Length -and [int]$Command[$i + 1] -eq 40) {
            $sub = Get-ReviewGateDollarParen $Command ($i + 2)
            foreach ($part in @(Split-ReviewGateCommand $sub.Body)) { $nested.Add($part) }
            [void]$buffer.Append(' ')
            $i = $sub.End + 1
            continue
        }
        if ($c -eq 96) {
            $sub = Get-ReviewGateBacktickBody $Command ($i + 1)
            foreach ($part in @(Split-ReviewGateCommand $sub.Body)) { $nested.Add($part) }
            [void]$buffer.Append(' ')
            $i = $sub.End + 1
            continue
        }
        if ($quote -eq 34) { [void]$buffer.Append($ch); $i++; continue }

        # && and || (38, 124); then ; & | CR LF ( ) (59 38 124 13 10 40 41).
        $doubleOperator = ($c -eq 38 -or $c -eq 124) -and $i + 1 -lt $Command.Length -and
            [int]$Command[$i + 1] -eq $c
        $singleOperator = $c -eq 59 -or $c -eq 38 -or $c -eq 124 -or $c -eq 13 -or $c -eq 10 -or
            $c -eq 40 -or $c -eq 41
        if ($doubleOperator -or $singleOperator) {
            $segment = $buffer.ToString().Trim()
            if ($segment) { $segments.Add($segment) }
            [void]$buffer.Clear()
            $i += if ($doubleOperator) { 2 } else { 1 }
            continue
        }
        if ($c -eq 34 -or $c -eq 39) { $quote = $c }
        [void]$buffer.Append($ch)
        $i++
    }
    $segment = $buffer.ToString().Trim()
    if ($segment) { $segments.Add($segment) }
    return @($segments) + @($nested)
}

function Get-ReviewGateNestedCommand {
    param([string]$Executable, [string[]]$Rest)
    $base = Get-ReviewGateBaseName $Executable
    $bare = @($Rest | ForEach-Object { $_.Trim([char[]]@('"', "'")) })
    if (Test-ReviewGateOneOf $base $script:ReviewGateShellLaunchers) {
        for ($i = 0; $i + 1 -lt $bare.Count; $i++) {
            $option = $bare[$i]
            if ($option.StartsWith('-', [System.StringComparison]::Ordinal) -and
                -not $option.StartsWith('--', [System.StringComparison]::Ordinal) -and
                $option.Substring(1).Contains('c')) {
                return ,(ConvertFrom-ReviewGateOuterQuote $Rest[$i + 1])
            }
        }
        return @()
    }
    if (Test-ReviewGateOneOf $base $script:ReviewGatePowerShellLaunchers) {
        for ($i = 0; $i -lt $bare.Count; $i++) {
            if ((Test-ReviewGateOneOf $bare[$i].ToLowerInvariant() @('-c', '-command')) -and $i + 1 -lt $Rest.Count) {
                return ,(ConvertFrom-ReviewGateOuterQuote (($Rest | Select-Object -Skip ($i + 1)) -join ' '))
            }
        }
        return @()
    }
    if (Test-ReviewGateSame $base 'cmd') {
        for ($i = 0; $i -lt $bare.Count; $i++) {
            if ((Test-ReviewGateOneOf $bare[$i].ToLowerInvariant() @('/c', '/k')) -and $i + 1 -lt $Rest.Count) {
                return ,(ConvertFrom-ReviewGateOuterQuote (($Rest | Select-Object -Skip ($i + 1)) -join ' '))
            }
        }
        return @()
    }
    if (Test-ReviewGateSame $base 'ssh') {
        $i = 0
        while ($i -lt $Rest.Count) {
            $option = $bare[$i]
            if (Test-ReviewGateSame $option '--') { $i++; break }
            if (-not $option.StartsWith('-', [System.StringComparison]::Ordinal)) { break }
            $i += if ((Test-ReviewGateOneOf $option $script:ReviewGateSshWithArg) -and $i + 1 -lt $Rest.Count) { 2 } else { 1 }
        }
        if ($i + 1 -lt $Rest.Count) {
            return ,(ConvertFrom-ReviewGateOuterQuote (($Rest | Select-Object -Skip ($i + 1)) -join ' '))
        }
        return @()
    }
    if (Test-ReviewGateSame $base 'xargs') {
        $i = 0
        while ($i -lt $Rest.Count) {
            $option = $bare[$i]
            if (Test-ReviewGateSame $option '--') { $i++; break }
            if (-not $option.StartsWith('-', [System.StringComparison]::Ordinal)) { break }
            $name = $option.Split('=', 2)[0]
            $i += if ((Test-ReviewGateOneOf $name $script:ReviewGateXargsWithArg) -and
                -not $option.Contains('=') -and $i + 1 -lt $Rest.Count) { 2 } else { 1 }
        }
        if ($i -lt $Rest.Count) {
            return ,(ConvertFrom-ReviewGateOuterQuote (($Rest | Select-Object -Skip $i) -join ' '))
        }
        return @()
    }
    if ((Test-ReviewGateSame $base 'busybox') -and $Rest.Count -gt 0 -and
        (Test-ReviewGateOneOf (Get-ReviewGateBaseName $Rest[0]) $script:ReviewGateShellLaunchers)) {
        return ,(ConvertFrom-ReviewGateOuterQuote ($Rest -join ' '))
    }
    return @()
}

function Get-ReviewGateGuardedInvocation {
    param([string]$Command, [string[]]$InheritedPaths = @(), [int]$Depth = 0)
    if ($Depth -gt 8) { return @() }
    $prefixPaths = @($InheritedPaths) + @(Get-ReviewGateLeadingCdPath $Command)
    $guardedInvocations = [System.Collections.Generic.List[object]]::new()
    foreach ($segment in @(Split-ReviewGateCommand $Command)) {
        if ([string]::IsNullOrWhiteSpace($segment)) { continue }
        $tokens = @([regex]::Matches($segment, '"(?:\\.|[^"])*"|''(?:\\.|[^''])*''|\S+') | ForEach-Object { $_.Value })
        $leading = Get-ReviewGateLeadingExecutable $tokens
        if ($null -eq $leading) { continue }
        $verdict = Get-ReviewGateVerdictFromInvocation $leading.Executable $leading.Rest
        if ($verdict) {
            $gitContext = if (Test-ReviewGateSame (Get-ReviewGateBaseName $leading.Executable) 'git') {
                Get-ReviewGateGitContextPath $leading.Rest
            } else { [PSCustomObject]@{ Paths = @(); Unsupported = $false } }
            $guardedInvocations.Add([PSCustomObject]@{
                Verdict = $verdict
                Paths = @($prefixPaths) + @($gitContext.Paths)
                Unsupported = $gitContext.Unsupported
            })
            continue
        }
        foreach ($nestedCommand in @(Get-ReviewGateNestedCommand $leading.Executable $leading.Rest)) {
            foreach ($guardedInvocation in @(Get-ReviewGateGuardedInvocation $nestedCommand $prefixPaths ($Depth + 1))) {
                $guardedInvocations.Add($guardedInvocation)
            }
        }
    }
    return @($guardedInvocations)
}

function Get-ReviewGateCommandContext {
    param([string]$Command)
    $guardedInvocations = @(Get-ReviewGateGuardedInvocation $Command)
    if ($guardedInvocations.Count -gt 1) {
        return [PSCustomObject]@{ Verdict = 'MULTI'; Paths = @(); Unsupported = $false }
    }
    if ($guardedInvocations.Count -eq 1) { return $guardedInvocations[0] }
    return [PSCustomObject]@{ Verdict = 'NONE'; Paths = @(); Unsupported = $false }
}

function Get-ReviewGateCommandVerdict {
    param([string]$Command)
    return (Get-ReviewGateCommandContext $Command).Verdict
}

function Get-ReviewGateVerdictFromPayload {
    param([string]$Raw)
    if ([string]::IsNullOrWhiteSpace($Raw)) { throw 'empty payload' }
    $data = $Raw | ConvertFrom-Json -ErrorAction Stop
    $toolInput = $data.tool_input
    if ($null -eq $toolInput) { $toolInput = $data.toolInput }
    if ($null -eq $toolInput) { throw 'tool input missing' }
    $command = $toolInput.command
    if ($command -isnot [string] -or [string]::IsNullOrWhiteSpace($command)) { return 'NONE' }
    return Get-ReviewGateCommandVerdict $command
}

if (-not (Test-ReviewGateSame $MyInvocation.InvocationName '.')) {
    try {
        $raw = [Console]::In.ReadToEnd()
        Get-ReviewGateVerdictFromPayload $raw
        exit 0
    } catch {
        exit 1
    }
}
