@echo off
setlocal enabledelayedexpansion

for /f "usebackq delims=" %%i in (`pwsh -NoLogo -ExecutionPolicy Bypass -File "%MB_HOME%\scripts\pick-folder.ps1" -Description "Select the project folder to initialize with PMB"`) do set "TARGET_PATH=%%i"

if "!TARGET_PATH!"=="" (
    echo No folder selected. Exiting.
    pause & exit /b 0
)

echo.
echo Initializing PMB in: !TARGET_PATH!
echo.
call mb init "!TARGET_PATH!"
echo.
pause
