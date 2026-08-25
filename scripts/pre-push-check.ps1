<#
.SYNOPSIS
    Pre-push git hook — full error and warning check before any push.
.DESCRIPTION
    Called by .git/hooks/pre-push. Runs six checks and blocks the push on
    errors; emits warnings but does not block on advisory issues.
    Fails open: unexpected errors print [HOOK ERROR] and allow the push.
#>

param()

$ErrorActionPreference = 'Continue'

# WHY three counters, not one flag: a check has three possible outcomes — it passed,
# it failed, or it could not run. The original model had only $failed, so both "warned"
# and "could not determine" rendered as success, and the summary printed
# "All pre-push checks passed" over the top of them. Four of the seven checks below are
# advisory and can never set $failed, so that summary was asserting a result it had not
# earned. $unknown exists specifically so a check that did not execute cannot be
# mistaken for one that passed.
$failed  = $false
$warned  = 0
$unknown = 0

# ENFORCE=true promotes warnings and unknowns to blocking. Default is advisory, matching
# templates/.github/workflows/memory-bank-size.yml — a gate that blocks on a stale
# template gets disabled within a week, so honesty is the default and enforcement opt-in.
# `-ceq` (case-SENSITIVE) deliberately: PowerShell's default `-eq` is case-insensitive, so
# `ENFORCE=True` would enforce here while bash's `[ "$ENFORCE" = "true" ]` would not —
# the same variable producing different gate behaviour per platform.
$enforce = if ($env:ENFORCE) { $env:ENFORCE -ceq 'true' } else { $false }

Write-Host ""
Write-Host "Pre-push checks" -ForegroundColor Cyan
Write-Host "===============" -ForegroundColor Cyan
Write-Host ""

try {

# Check 1: Unresolved merge conflicts (block)
$conflicts = git diff --name-only --diff-filter=U 2>$null
if ($conflicts) {
    Write-Host "[ERROR] Unresolved merge conflicts:" -ForegroundColor Red
    $conflicts | ForEach-Object { Write-Host "        $_" -ForegroundColor Red }
    $failed = $true
    Write-Host ""
}

# Check 2: Conflict markers in tracked files (block)
# WHY: git grep --cached finds <<< markers staged for commit, catching conflicts
# that slipped through without being flagged by --diff-filter=U.
$null = git grep -l "^<<<<<<< " --cached 2>&1
if ($LASTEXITCODE -eq 0) {
    $markerFiles = git grep -l "^<<<<<<< " --cached 2>&1
    Write-Host "[ERROR] Conflict markers found in staged files:" -ForegroundColor Red
    $markerFiles | ForEach-Object { Write-Host "        $_" -ForegroundColor Red }
    $failed = $true
    Write-Host ""
}

# Check 3: Uncommitted changes in working tree (warn)
$dirty = git status --porcelain 2>$null
if ($dirty) {
    Write-Host "[WARN] Uncommitted changes in working tree:" -ForegroundColor Yellow
    $dirty | Select-Object -First 10 | ForEach-Object { Write-Host "       $_" -ForegroundColor Yellow }
    if ($dirty.Count -gt 10) { Write-Host "       ... and $($dirty.Count - 10) more" -ForegroundColor Yellow }
    Write-Host "       Commit or stash before pushing if these should be included." -ForegroundColor Yellow
    $warned++
    Write-Host ""
}

# Check 4: .gitattributes present (warn)
if (-not (Test-Path ".gitattributes")) {
    Write-Host "[WARN] No .gitattributes — line-ending normalization not enforced." -ForegroundColor Yellow
    Write-Host "       Create .gitattributes with '* text=auto eol=lf' to suppress CRLF warnings." -ForegroundColor Yellow
    $warned++
    Write-Host ""
} else {
    Write-Host "[OK]   .gitattributes present" -ForegroundColor Green
}

# Check 5: Possible secrets in commits being pushed (block)
# When a tracking ref exists, diff against it. When there is none (first push or
# untracked branch), scan all commits not yet on any known remote so first pushes
# are covered rather than silently skipped.
$remote = git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>&1
$hasUpstream = ($LASTEXITCODE -eq 0 -and $remote -notmatch 'fatal')
$secretPatterns = @(
    @{ label = "AWS access key";            pattern = 'AKIA[0-9A-Z]{16}' }
    @{ label = "OpenAI/Anthropic API key";  pattern = 'sk-[a-zA-Z0-9]{32,}' }
    @{ label = "GitHub personal token";     pattern = 'ghp_[a-zA-Z0-9]{36}' }
    @{ label = "Generic password assignment"; pattern = 'password\s*=\s*["\x27][^"\x27\s]{8,}' }
    @{ label = "Generic secret assignment";  pattern = 'secret\s*=\s*["\x27][^"\x27\s]{8,}' }
)
# WHY: fixtures/security/ and docs/ are excluded from secret scanning:
# fixtures/security/ intentionally contains vulnerable code for regression testing;
# docs/ (specs, plans) may quote fixture content as documentation examples.
$inExcluded = $false
if ($hasUpstream) {
    $pushDiff = git diff "$remote..HEAD" 2>&1 | ForEach-Object {
        if ($_ -match '^\+\+\+ b/') { $inExcluded = $_ -match '^\+\+\+ b/(fixtures/|docs/)' }
        if (-not $inExcluded -and $_ -match '^\+[^+]') { $_ }
    }
} else {
    # WHY: HEAD --not --remotes finds every commit reachable from HEAD but not from any
    # remote-tracking ref — this is exactly the set of commits a first push would
    # send. --format="" suppresses commit headers; only the patch lines remain.
    #
    # WHY `HEAD` is stated explicitly and must not be removed: without a positive rev,
    # `git log --not --remotes` has no starting point to walk from and returns NOTHING
    # when the repo has no remote-tracking refs — silently skipping the secret scan in
    # exactly the first-push case this branch exists to cover, while printing
    # "no commits to push". Verified: in a fresh repo containing a planted AKIA key,
    # the form without HEAD yields 0 lines; with HEAD it yields the commit and the key
    # is caught. Covered by tests/test-pre-push-check.sh.
    $pushDiff = git log HEAD --not --remotes --format="" -p 2>&1 | ForEach-Object {
        if ($_ -match '^\+\+\+ b/') { $inExcluded = $_ -match '^\+\+\+ b/(fixtures/|docs/)' }
        if (-not $inExcluded -and $_ -match '^\+[^+]') { $_ }
    }
    if (-not $pushDiff) {
        Write-Host "[SKIP] Secret scan — no unpushed commits found to scan." -ForegroundColor DarkGray
        Write-Host ""
    }
}
foreach ($entry in $secretPatterns) {
    $hits = $pushDiff | Where-Object { $_ -match $entry.pattern }
    if ($hits) {
        Write-Host "[ERROR] Possible $($entry.label) in push diff:" -ForegroundColor Red
        $hits | Select-Object -First 3 | ForEach-Object { Write-Host "        $_" -ForegroundColor Red }
        $failed = $true
        Write-Host ""
    }
}

# Check 6: Files over 500 KB in push (warn)
$largeFiles = @()
$pushFileList = if ($hasUpstream) {
    git diff --name-only "$remote..HEAD" 2>&1
} else {
    git log HEAD --not --remotes --format="" --name-only 2>&1 | Where-Object { $_ -match '\S' } | Sort-Object -Unique
}
$pushFileList | ForEach-Object {
    if ($_ -and (Test-Path $_)) {
        $bytes = (Get-Item $_).Length
        if ($bytes -gt 512000) {
            $largeFiles += "$_ ($([math]::Round($bytes / 1KB)) KB)"
        }
    }
}
if ($largeFiles) {
    Write-Host "[WARN] Large files in push (>500 KB):" -ForegroundColor Yellow
    $largeFiles | ForEach-Object { Write-Host "       $_" -ForegroundColor Yellow }
    Write-Host "       Consider .gitignore or Git LFS for binary/generated files." -ForegroundColor Yellow
    $warned++
    Write-Host ""
}

# Check 7: memory-bank integrity via mb doctor
#
# WHY this no longer calls `mb validate`: that command was deprecated into `mb doctor` and
# now resolves to a shim that prints a redirect notice and exits 2 (measured, not assumed).
# The old check treated any non-zero $LASTEXITCODE as a memory-bank problem, so every push in
# every managed project emitted "[WARN] mb validate reported issues — memory bank may be
# inconsistent:" and then quoted the redirect notice underneath it as though that were the
# evidence. Nothing could clear it: the warning did not describe the memory bank at all, and
# it was immediately followed by "[PASS] All pre-push checks passed" — a self-contradicting
# gate. Observed on ai-code-review-agent, which is pinned at PMB 1.1.1 and still runs the old
# check. An exit code cannot distinguish "ran and passed" from "ran and failed" from "never
# ran" — that is the general trap, and every deprecated alias inherits it.
#
# WHY the verdict is parsed from output rather than taken from an exit code: `mb doctor`
# also exits 0 regardless of what it finds, so switching commands alone would have
# preserved the bug. Its output is structured — every check emits [OK], [WARN] or
# [ERROR] — so counting those lines yields both the verdict AND a positive assertion
# that the command actually ran. Zero result lines means no checks executed (deprecated
# shim, crash, missing binary), which is UNKNOWN, never success. Measured: a real run
# emits ~51 result lines; the shim emits 0.
if (Get-Command mb -ErrorAction SilentlyContinue) {
    $doctorOut = (& mb doctor 2>&1 | Out-String)
    # Count LINES carrying a marker, not marker occurrences — bash uses `grep -c`, which is
    # line-based. Counting matches here would double-count any line bearing two markers and
    # silently diverge from the POSIX path.
    $resultLines = (($doctorOut -split "`r?`n") | Where-Object { $_ -match '\[(OK|WARN|ERROR)\]' }).Count
    if ($resultLines -eq 0) {
        Write-Host "[UNKNOWN] mb doctor produced no check results — memory bank NOT verified." -ForegroundColor Yellow
        Write-Host "          The command ran but emitted no [OK]/[WARN]/[ERROR] lines."
        $unknown++
        Write-Host ""
    } else {
        $errorLines = (($doctorOut -split "`r?`n") | Where-Object { $_ -match '\[ERROR\]' }).Count
        if ($errorLines -gt 0) {
            Write-Host "[WARN] mb doctor reported $errorLines error(s) across $resultLines result lines:" -ForegroundColor Yellow
            ($doctorOut -split "`n" | Select-String -Pattern '\[ERROR\]' | Select-Object -First 5) |
                ForEach-Object { Write-Host "       $($_.ToString().Trim())" }
            $warned++
            Write-Host ""
        } else {
            # "result lines", not "checks": this counts emitted [OK]/[WARN]/[ERROR] markers,
            # which exceeds the number of named doctor checks. Claiming a check count this
            # figure does not represent would repeat the unearned-assertion bug being fixed.
            Write-Host "[OK]   mb doctor: $resultLines result lines, no errors" -ForegroundColor Green
        }
    }
} else {
    Write-Host "[UNKNOWN] mb not in PATH — memory bank NOT verified." -ForegroundColor Yellow
    $unknown++
}

} catch {
    Write-Host "[HOOK ERROR] pre-push-check.ps1 failed: $_" -ForegroundColor Yellow
    # WHY this re-checks $failed instead of exiting 0 unconditionally: the try block spans
    # all seven checks, so a throw in a LATER check would otherwise discard a blocking
    # finding an EARLIER one already made — a confirmed secret in check 5 silently
    # dropped by an exception in check 6 or 7, and the push allowed. Fail-open applies to
    # checks that could not be evaluated, never to one that already failed.
    if ($failed) {
        Write-Host "[BLOCKED] A blocking check failed before the error above. Push aborted." -ForegroundColor Red
        Write-Host ""
        exit 1
    }
    Write-Host "Proceeding in fails-open mode." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
# WHY the summary distinguishes three states: "[PASS] All pre-push checks passed" may
# only print when every check actually passed. Previously it printed whenever no
# BLOCKING check failed, so it appeared directly beneath warnings it contradicted, and
# beneath a check that had not run at all. A summary that cannot express "warned" or
# "could not verify" will always overstate the result.
if ($failed) {
    Write-Host "[BLOCKED] Push aborted. Fix the errors above, then push again." -ForegroundColor Red
    Write-Host ""
    exit 1
} elseif ($unknown -ne 0) {
    Write-Host "[DEGRADED] $unknown check(s) could not run; $warned warning(s). Not all checks were verified." -ForegroundColor Yellow
    if ($enforce) {
        Write-Host "           ENFORCE=true — treating unverified checks as blocking." -ForegroundColor Red
        Write-Host ""
        exit 1
    }
    Write-Host ""
    exit 0
} elseif ($warned -ne 0) {
    Write-Host "[PASS with $warned warning(s)] No blocking issues; review the warnings above." -ForegroundColor Yellow
    if ($enforce) {
        Write-Host "           ENFORCE=true — treating warnings as blocking." -ForegroundColor Red
        Write-Host ""
        exit 1
    }
    Write-Host ""
    exit 0
} else {
    Write-Host "[PASS] All pre-push checks passed." -ForegroundColor Green
    Write-Host ""
    exit 0
}
