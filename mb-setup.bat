@echo off
pwsh.exe -NoLogo -ExecutionPolicy Bypass -File "%~dp0scripts\mb.ps1" setup %*
