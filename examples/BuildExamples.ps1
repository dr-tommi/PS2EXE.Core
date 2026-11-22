#Requires -Version 7.6
<#
.SYNOPSIS
    Builds all examples as single-file executables for Windows PowerShell 5.1 and PowerShell 7.

.DESCRIPTION
    Every example script is compiled four times (console and GUI, each for both runtimes):
        out\PS5.1\<Name>.exe, out\PS5.1\<Name>-GUI.exe
        out\PS7\<Name>.exe,   out\PS7\<Name>-GUI.exe
    PowerShell 7 builds use -Core -PublishSingleFile. Each one gets its own work folder under
    out\PS7\.build\<Name>[-GUI], because dotnet's obj folder and the PS2EXE build cache are per folder.
    -PublishSingleFile needs PowerShell 7.6+ for the build itself, hence the #Requires.

.PARAMETER PowerShellVersion
    PowerShell SDK version for the PowerShell 7 builds. The matching .NET SDK must be installed.

.PARAMETER NoPause
    Do not wait for Enter at the end.

.EXAMPLE
    PS> .\BuildExamples.ps1
#>
[CmdletBinding()]
param (
    [version]$PowerShellVersion = '7.7.0',
    [switch]$NoPause
)

$ErrorActionPreference = 'Stop'

# Prefer the module built from this repository (build.ps1) over an installed one
$localModule = Join-Path $PSScriptRoot '..\bin\PS2EXE.Core\PS2EXE.Core.psd1'
if (Test-Path $localModule) {
    Import-Module $localModule -Force
} else {
    Import-Module PS2EXE.Core
}

$outPS5 = Join-Path $PSScriptRoot 'out\PS5.1'
$outPS7 = Join-Path $PSScriptRoot 'out\PS7'
$workPS7 = Join-Path $outPS7 '.build'
New-Item -ItemType Directory -Force -Path $outPS5, $outPS7, $workPS7 | Out-Null

# Write-Progress is not implemented for console executables, ScreenBuffer needs a console
$skip = @('Progress', 'ScreenBuffer-GUI')

$failed = [System.Collections.Generic.List[string]]::new()

foreach ($script in Get-ChildItem -Path $PSScriptRoot -Filter '*.ps1' | Where-Object BaseName -notlike 'BuildExamples*') {
    foreach ($gui in $false, $true) {
        $name = if ($gui) { "$($script.BaseName)-GUI" } else { $script.BaseName }
        if ($name -in $skip) { continue }

        Write-Host "=== $name ===" -ForegroundColor Cyan
        try {
            Write-Host '  Windows PowerShell 5.1'
            $exe = Join-Path $outPS5 "$name.exe"
            Remove-Item -Path $exe -Force -ErrorAction SilentlyContinue
            # The 5.1 build runs in a child powershell.exe whose errors do not throw here, so check the result
            Invoke-PS2EXE -InputFile $script.FullName -OutputFile $exe -NoConsole:$gui | Out-Null
            if (-not (Test-Path $exe)) { throw "$exe was not created" }
        } catch {
            Write-Host "  FAILED: $($_.Exception.Message)" -ForegroundColor Red
            $failed.Add("$name (5.1)")
        }

        try {
            Write-Host "  PowerShell $PowerShellVersion"
            $work = Join-Path $workPS7 $name
            New-Item -ItemType Directory -Force -Path $work | Out-Null
            Invoke-PS2EXE -InputFile $script.FullName -OutputFile (Join-Path $work "$name.exe") -NoConsole:$gui `
                -Core -PublishSingleFile -PowerShellVersion $PowerShellVersion -Quiet
            Copy-Item -Path (Join-Path $work "Release\$name.exe") -Destination $outPS7 -Force
        } catch {
            Write-Host "  FAILED: $($_.Exception.Message)" -ForegroundColor Red
            $failed.Add("$name (7)")
        }
    }
}

Write-Host
Write-Host "Output: $outPS5"
Write-Host "        $outPS7"
if ($failed.Count) {
    Write-Host "Failed: $($failed -join ', ')" -ForegroundColor Red
}

if (-not $NoPause) {
    $null = Read-Host 'Press enter to exit'
}
