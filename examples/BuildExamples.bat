@echo off
:: Markus Scholtes 2017
:: Create examples for PS2EXE (Windows PowerShell 5.1 and PowerShell 7, single file)
:: Needs PowerShell 7.6+ (pwsh) to build; the 5.1 executables are compiled via powershell.exe automatically

pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0BuildExamples.ps1" %*
