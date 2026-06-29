#Requires -Modules Pester

BeforeAll {
    $RepoRoot = Split-Path $PSScriptRoot -Parent

    function New-TestProject {
        param([string]$Base, [string]$Name)
        $path = Join-Path $Base $Name
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        return $path
    }

    function New-PartialMbProject {
        param([string]$Base, [string]$Name)
        $path = New-TestProject -Base $Base -Name $Name
        $mb   = Join-Path $path 'memory-bank'
        New-Item -ItemType Directory -Path $mb -Force | Out-Null
        Set-Content (Join-Path $mb 'projectbrief.md') "---`nauthority: immutable`nlast-reviewed: 2026-01-01`n---`n# Project Brief`nContent here.`nMore content.`nLine three.`nLine four."
        return $path
    }
}

Describe "Get-MbMode" {
    BeforeAll {
        . (Join-Path $RepoRoot 'scripts/mb.ps1') -Command help 2>$null
    }

    It "returns 'init' when no memory-bank directory exists" {
        $p = New-TestProject -Base $TestDrive -Name 'mode-init'
        Get-MbMode -ProjectPath $p | Should -Be 'init'
    }

    It "returns 'upgrade' when memory-bank directory exists" {
        $p = New-TestProject -Base $TestDrive -Name 'mode-upgrade'
        New-Item -ItemType Directory -Path (Join-Path $p 'memory-bank') | Out-Null
        Get-MbMode -ProjectPath $p | Should -Be 'upgrade'
    }
}

Describe "Get-MbUpgradeAnalysis" {
    BeforeAll {
        . (Join-Path $RepoRoot 'scripts/mb.ps1') -Command help 2>$null
        $script:RepoRoot2 = $RepoRoot
        $script:TestProject = New-PartialMbProject -Base $TestDrive -Name 'analysis-test'
    }

    It "reports missing memory-bank files" {
        $analysis = Get-MbUpgradeAnalysis -ProjectPath $script:TestProject -TemplatesDir (Join-Path $script:RepoRoot2 'templates')
        $analysis.Missing | Should -Contain 'systemPatterns.md'
        $analysis.Missing | Should -Contain 'techContext.md'
        $analysis.Missing | Should -Contain 'activeContext.md'
        $analysis.Missing | Should -Contain 'progress.md'
    }

    It "reports present memory-bank files" {
        $analysis = Get-MbUpgradeAnalysis -ProjectPath $script:TestProject -TemplatesDir (Join-Path $script:RepoRoot2 'templates')
        $analysis.Present | Should -Contain 'projectbrief.md'
    }
}

Describe "Invoke-MbVerify" {
    BeforeAll {
        . (Join-Path $RepoRoot 'scripts/mb.ps1') -Command help 2>$null
        $script:RepoRoot3 = $RepoRoot

        $script:HealthyProject = New-TestProject -Base $TestDrive -Name 'verify-healthy'
        $mbDst = Join-Path $script:HealthyProject 'memory-bank'
        New-Item -ItemType Directory -Path $mbDst | Out-Null
        Get-ChildItem (Join-Path $RepoRoot 'templates/memory-bank') -File | ForEach-Object {
            $content = Get-Content $_.FullName -Raw
            $content = $content -replace 'YYYY-MM-DD', '2026-06-29'
            Set-Content (Join-Path $mbDst $_.Name) $content -NoNewline
        }

        $script:BadProject = New-TestProject -Base $TestDrive -Name 'verify-bad'
        $mbBad = Join-Path $script:BadProject 'memory-bank'
        New-Item -ItemType Directory -Path $mbBad | Out-Null
        Set-Content (Join-Path $mbBad 'projectbrief.md') "---`nlast-reviewed: 2026-06-29`n---`n# Stub"
    }

    It "passes for a fully initialized project" {
        $result = Invoke-MbVerify -ProjectPath $script:HealthyProject -TemplatesDir (Join-Path $script:RepoRoot3 'templates')
        $result.Passed | Should -Be $true
        $result.Missing.Count | Should -Be 0
    }

    It "fails when required files are missing" {
        $result = Invoke-MbVerify -ProjectPath $script:BadProject -TemplatesDir (Join-Path $script:RepoRoot3 'templates')
        $result.Passed | Should -Be $false
        $result.Missing.Count | Should -BeGreaterThan 0
    }
}
