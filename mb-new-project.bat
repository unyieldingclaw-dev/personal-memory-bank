@echo off
setlocal enabledelayedexpansion

for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command ^
  "[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms') | Out-Null; ^
   $f = New-Object System.Windows.Forms.FolderBrowserDialog; ^
   $f.Description = 'Select the project folder to initialize with PMB'; ^
   $f.ShowNewFolderButton = $true; ^
   if ($f.ShowDialog() -eq 'OK') { $f.SelectedPath }"`) do set "TARGET_PATH=%%i"

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
