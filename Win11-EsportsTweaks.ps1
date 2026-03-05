<#
.SYNOPSIS
    Win11 Esports Optimizer Pro
    A premium-grade optimization utility for Windows 11 gaming.

.DESCRIPTION
    This script is the main entry point for the modular optimization framework.
    It loads all necessary components and launches the WPF Dashboard.

.NOTES
    Author: Howl
    Version: 2.0.0
    License: MIT
#>

# Ensure Execution Policy
if ((Get-ExecutionPolicy) -ne 'Unrestricted' -and (Get-ExecutionPolicy) -ne 'Bypass') {
    Write-Warning "Execution Policy is restricted. Attempting to bypass..."
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Module Loading Path
$ModulePath = Join-Path $PSScriptRoot "src"

# Import Core
Write-Host "Loading Core Modules..." -ForegroundColor Cyan
Import-Module (Join-Path $ModulePath "Core\Logger.psm1") -Force
Import-Module (Join-Path $ModulePath "Core\Config.psm1") -Force
Import-Module (Join-Path $ModulePath "Core\Security.psm1") -Force
Import-Module (Join-Path $ModulePath "Core\Registry.psm1") -Force
Import-Module (Join-Path $ModulePath "Core\Update.psm1") -Force

# Initialize Logger
Initialize-Logger -LogPath (Join-Path ([Environment]::GetFolderPath("Desktop")) "Win11Optimizer.log")

# Check Admin
Ensure-RunningAsAdministrator

# Import Feature Modules
Write-Log "Loading Feature Modules..." -Level INFO
Import-Module (Join-Path $ModulePath "Modules\Network.psm1") -Force
Import-Module (Join-Path $ModulePath "Modules\CPU.psm1") -Force
Import-Module (Join-Path $ModulePath "Modules\GPU.psm1") -Force
Import-Module (Join-Path $ModulePath "Modules\System.psm1") -Force
Import-Module (Join-Path $ModulePath "Modules\Input.psm1") -Force

# Import Benchmarks
Import-Module (Join-Path $ModulePath "Benchmarks\Benchmark.psm1") -Force

# Import UI
Write-Log "Initializing UI..." -Level INFO
Import-Module (Join-Path $ModulePath "UI\Dashboard.ps1") -Force

# Check for Updates (Async)
Start-Job -ScriptBlock {
    param($path)
    Import-Module (Join-Path $path "Core\Update.psm1") -Force
    Update-Win11Tweaks
} -ArgumentList $ModulePath | Out-Null

# Launch Dashboard
Show-Dashboard
