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

function Get-ReviewGateBaseName {
    param([string]$Token)
    $trimmed = $Token.Trim([char[]]@('"', "'")) -replace '\\', '/'
    $base = ($trimmed -split '/')[-1].ToLowerInvariant()
    if ($base.EndsWith('.exe')) { $base = $base.Substring(0, $base.Length - 4) }
    return $base
}

function Get-ReviewGateLeadingExecutable {
    param([string[]]$Tokens)
    $i = 0
    while ($i -lt $Tokens.Count) {
        $token = $Tokens[$i]
        $bare = $token.Trim([char[]]@('"', "'"))
        if ($token -match '^[A-Za-z_][A-Za-z0-9_]*=' -or
            $script:ReviewGateWrappers -contains (Get-ReviewGateBaseName $bare)) {
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
        if ($script:ReviewGateGlobalWithArg -ccontains $token) {
            $i += 2
            continue
        }
        if ($token.StartsWith('--') -and $token.Contains('=') -and
            $script:ReviewGateGlobalWithArg -ccontains $token.Split('=', 2)[0]) {
            $i++
            continue
        }
        if ($script:ReviewGateGlobalFlags -contains $token -or $token.StartsWith('-')) {
            $i++
            continue
        }
        return $token.Trim([char[]]@('"', "'")).ToLowerInvariant()
    }
    return $null
}

function Get-ReviewGateLeadingCdPaths {
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

function Get-ReviewGateGitContextPaths {
    param([string[]]$Tokens)
    $paths = @()
    $i = 0
    while ($i -lt $Tokens.Count) {
        $token = $Tokens[$i].Trim([char[]]@('"', "'"))
        if ($token -ceq '-C') {
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
        if ($option -in @('--git-dir', '--work-tree')) {
            return [PSCustomObject]@{ Paths = @(); Unsupported = $true }
        }
        if ($script:ReviewGateGlobalWithArg -ccontains $token) {
            $i += 2
            continue
        }
        if ($token.StartsWith('--') -and $token.Contains('=') -and
            $script:ReviewGateGlobalWithArg -ccontains $option) {
            $i++
            continue
        }
        if ($script:ReviewGateGlobalFlags -contains $token -or $token.StartsWith('-')) {
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
    if ($base -eq 'git') {
        $verb = Get-ReviewGateGitVerb $Rest
        if ($verb -eq 'commit') { return 'COMMIT' }
        if ($verb -eq 'push') { return 'PUSH' }
    } elseif ($base -eq 'gh') {
        $flat = (($Rest | ForEach-Object { $_.Trim([char[]]@('"', "'")) }) -join ' ')
        if ($flat -match '^pr\s+merge(?:\s|$)') { return 'MERGE' }
        if ($flat -match '^api(?:\s|$)' -and $flat -match '/pulls/\d+/merge') { return 'MERGE' }
    }
    return $null
}

function Remove-ReviewGateOuterQuotes {
    param([string]$Value)
    $value = $Value.Trim()
    if ($value.Length -ge 2 -and $value[0] -eq $value[$value.Length - 1] -and
        $value[0] -in @([char]34, [char]39)) {
        return $value.Substring(1, $value.Length - 2)
    }
    return $value
}

function Get-ReviewGateDollarParen {
    param([string]$Text, [int]$Start)
    $depth = 1
    $quote = [char]0
    $escaped = $false
    for ($i = $Start; $i -lt $Text.Length; $i++) {
        $ch = $Text[$i]
        if ($escaped) { $escaped = $false; continue }
        if ($ch -eq [char]92 -and $quote -ne [char]39) { $escaped = $true; continue }
        if ($quote -ne [char]0) {
            if ($ch -eq $quote) { $quote = [char]0 }
            continue
        }
        if ($ch -in @([char]34, [char]39)) { $quote = $ch; continue }
        if ($ch -eq '$' -and $i + 1 -lt $Text.Length -and $Text[$i + 1] -eq '(') {
            $depth++; $i++; continue
        }
        if ($ch -eq ')') {
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
        $ch = $Text[$i]
        if ($escaped) { $escaped = $false; continue }
        if ($ch -eq [char]92) { $escaped = $true; continue }
        if ($ch -eq [char]96) {
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
    $quote = [char]0
    $escaped = $false
    $i = 0
    while ($i -lt $Command.Length) {
        $ch = $Command[$i]
        if ($escaped) {
            [void]$buffer.Append($ch); $escaped = $false; $i++; continue
        }
        if ($ch -eq [char]92 -and $quote -ne [char]39) {
            [void]$buffer.Append($ch); $escaped = $true; $i++; continue
        }
        if ($quote -eq [char]39) {
            [void]$buffer.Append($ch)
            if ($ch -eq [char]39) { $quote = [char]0 }
            $i++; continue
        }
        if ($ch -eq [char]34) {
            [void]$buffer.Append($ch)
            $quote = if ($quote -eq [char]34) { [char]0 } else { [char]34 }
            $i++; continue
        }
        if ($ch -eq '$' -and $i + 1 -lt $Command.Length -and $Command[$i + 1] -eq '(') {
            $sub = Get-ReviewGateDollarParen $Command ($i + 2)
            foreach ($part in @(Split-ReviewGateCommand $sub.Body)) { $nested.Add($part) }
            [void]$buffer.Append(' ')
            $i = $sub.End + 1
            continue
        }
        if ($ch -eq [char]96) {
            $sub = Get-ReviewGateBacktickBody $Command ($i + 1)
            foreach ($part in @(Split-ReviewGateCommand $sub.Body)) { $nested.Add($part) }
            [void]$buffer.Append(' ')
            $i = $sub.End + 1
            continue
        }
        if ($quote -eq [char]34) { [void]$buffer.Append($ch); $i++; continue }

        $doubleOperator = $i + 1 -lt $Command.Length -and
            $Command.Substring($i, 2) -in @('&&', '||')
        $singleOperator = $ch -in @(';', '&', '|', "`r", "`n", '(', ')')
        if ($doubleOperator -or $singleOperator) {
            $segment = $buffer.ToString().Trim()
            if ($segment) { $segments.Add($segment) }
            [void]$buffer.Clear()
            $i += if ($doubleOperator) { 2 } else { 1 }
            continue
        }
        if ($ch -in @([char]34, [char]39)) { $quote = $ch }
        [void]$buffer.Append($ch)
        $i++
    }
    $segment = $buffer.ToString().Trim()
    if ($segment) { $segments.Add($segment) }
    return @($segments) + @($nested)
}

function Get-ReviewGateNestedCommands {
    param([string]$Executable, [string[]]$Rest)
    $base = Get-ReviewGateBaseName $Executable
    $bare = @($Rest | ForEach-Object { $_.Trim([char[]]@('"', "'")) })
    if ($script:ReviewGateShellLaunchers -contains $base) {
        for ($i = 0; $i + 1 -lt $bare.Count; $i++) {
            $option = $bare[$i]
            if ($option.StartsWith('-') -and -not $option.StartsWith('--') -and
                $option.Substring(1).Contains('c')) {
                return ,(Remove-ReviewGateOuterQuotes $Rest[$i + 1])
            }
        }
        return @()
    }
    if ($script:ReviewGatePowerShellLaunchers -contains $base) {
        for ($i = 0; $i -lt $bare.Count; $i++) {
            if ($bare[$i].ToLowerInvariant() -in @('-c', '-command') -and $i + 1 -lt $Rest.Count) {
                return ,(Remove-ReviewGateOuterQuotes (($Rest | Select-Object -Skip ($i + 1)) -join ' '))
            }
        }
        return @()
    }
    if ($base -eq 'cmd') {
        for ($i = 0; $i -lt $bare.Count; $i++) {
            if ($bare[$i].ToLowerInvariant() -in @('/c', '/k') -and $i + 1 -lt $Rest.Count) {
                return ,(Remove-ReviewGateOuterQuotes (($Rest | Select-Object -Skip ($i + 1)) -join ' '))
            }
        }
        return @()
    }
    if ($base -eq 'ssh') {
        $i = 0
        while ($i -lt $Rest.Count) {
            $option = $bare[$i]
            if ($option -eq '--') { $i++; break }
            if (-not $option.StartsWith('-')) { break }
            $i += if ($script:ReviewGateSshWithArg -ccontains $option -and $i + 1 -lt $Rest.Count) { 2 } else { 1 }
        }
        if ($i + 1 -lt $Rest.Count) {
            return ,(Remove-ReviewGateOuterQuotes (($Rest | Select-Object -Skip ($i + 1)) -join ' '))
        }
        return @()
    }
    if ($base -eq 'xargs') {
        $i = 0
        while ($i -lt $Rest.Count) {
            $option = $bare[$i]
            if ($option -eq '--') { $i++; break }
            if (-not $option.StartsWith('-')) { break }
            $name = $option.Split('=', 2)[0]
            $i += if ($script:ReviewGateXargsWithArg -ccontains $name -and
                -not $option.Contains('=') -and $i + 1 -lt $Rest.Count) { 2 } else { 1 }
        }
        if ($i -lt $Rest.Count) {
            return ,(Remove-ReviewGateOuterQuotes (($Rest | Select-Object -Skip $i) -join ' '))
        }
        return @()
    }
    if ($base -eq 'busybox' -and $Rest.Count -gt 0 -and
        $script:ReviewGateShellLaunchers -contains (Get-ReviewGateBaseName $Rest[0])) {
        return ,(Remove-ReviewGateOuterQuotes ($Rest -join ' '))
    }
    return @()
}

function Get-ReviewGateGuardedInvocations {
    param([string]$Command, [string[]]$InheritedPaths = @(), [int]$Depth = 0)
    if ($Depth -gt 8) { return @() }
    $prefixPaths = @($InheritedPaths) + @(Get-ReviewGateLeadingCdPaths $Command)
    $matches = [System.Collections.Generic.List[object]]::new()
    foreach ($segment in @(Split-ReviewGateCommand $Command)) {
        if ([string]::IsNullOrWhiteSpace($segment)) { continue }
        $tokens = @([regex]::Matches($segment, '"(?:\\.|[^"])*"|''(?:\\.|[^''])*''|\S+') | ForEach-Object { $_.Value })
        $leading = Get-ReviewGateLeadingExecutable $tokens
        if ($null -eq $leading) { continue }
        $verdict = Get-ReviewGateVerdictFromInvocation $leading.Executable $leading.Rest
        if ($verdict) {
            $gitContext = if ((Get-ReviewGateBaseName $leading.Executable) -eq 'git') {
                Get-ReviewGateGitContextPaths $leading.Rest
            } else { [PSCustomObject]@{ Paths = @(); Unsupported = $false } }
            $matches.Add([PSCustomObject]@{
                Verdict = $verdict
                Paths = @($prefixPaths) + @($gitContext.Paths)
                Unsupported = $gitContext.Unsupported
            })
            continue
        }
        foreach ($nestedCommand in @(Get-ReviewGateNestedCommands $leading.Executable $leading.Rest)) {
            foreach ($match in @(Get-ReviewGateGuardedInvocations $nestedCommand $prefixPaths ($Depth + 1))) {
                $matches.Add($match)
            }
        }
    }
    return @($matches)
}

function Get-ReviewGateCommandContext {
    param([string]$Command)
    $matches = @(Get-ReviewGateGuardedInvocations $Command)
    if ($matches.Count -gt 1) {
        return [PSCustomObject]@{ Verdict = 'MULTI'; Paths = @(); Unsupported = $false }
    }
    if ($matches.Count -eq 1) { return $matches[0] }
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

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $raw = [Console]::In.ReadToEnd()
        Write-Output -NoEnumerate (Get-ReviewGateVerdictFromPayload $raw)
        exit 0
    } catch {
        exit 1
    }
}
