@echo off
setlocal enabledelayedexpansion

:: Memory Bank - Windows Installer
:: Run this once from the cloned repository. Then use "mb" from any project.

set "MB_REPO=%~dp0"
if "%MB_REPO:~-1%"=="\" set "MB_REPO=%MB_REPO:~0,-1%"
set "MB_BIN=%USERPROFILE%\.mb\bin"
set "MB_WRAPPER=%MB_BIN%\mb.bat"

echo.
echo  Memory Bank
echo  ===========
echo.

:: 1. Verify this is the right directory
if not exist "%MB_REPO%\scripts\mb.ps1" (
    echo  [ERROR] Cannot find scripts\mb.ps1 in %MB_REPO%
    echo  Run install.bat from the cloned memory-bank repository.
    echo.
    pause
    exit /b 1
)

:: 2. Register MB_HOME permanently (user-level env var)
setx MB_HOME "%MB_REPO%" >nul 2>&1
if errorlevel 1 (
    echo  [ERROR] Could not set MB_HOME. Try running as Administrator.
    echo.
    pause
    exit /b 1
)
echo  [OK] MB_HOME = %MB_REPO%

:: 3. Create bin directory and mb.bat wrapper
if not exist "%MB_BIN%" mkdir "%MB_BIN%"

(
  echo @echo off
  echo if not defined MB_HOME ^(
  echo   echo [ERROR] MB_HOME not set. Run install.bat again.
  echo   exit /b 1
  echo ^)
  echo powershell.exe -NoLogo -ExecutionPolicy Bypass -File "%%MB_HOME%%\scripts\mb.ps1" %%*
) > "%MB_WRAPPER%"
echo  [OK] mb command installed to %MB_BIN%

:: 4. Add bin directory to user PATH (safe: uses PowerShell to avoid 1024-char setx limit)
powershell.exe -NoLogo -ExecutionPolicy Bypass -Command ^
  "$p = [Environment]::GetEnvironmentVariable('PATH','User');" ^
  "if ($p -notlike '*%MB_BIN%*') {" ^
  "  [Environment]::SetEnvironmentVariable('PATH', $p + ';%MB_BIN%', 'User');" ^
  "  Write-Host ' [OK] Added mb to PATH'" ^
  "} else {" ^
  "  Write-Host ' [OK] mb already in PATH'" ^
  "}"

echo.
echo  Open a new terminal window, then in any project:
echo.
echo      mb init
echo      mb status
echo.
echo  Done.
echo.
pause
