<#
.SYNOPSIS
    Win11 Esports Optimizer Pro (Bootstrapper & Launcher)
    
.DESCRIPTION
    This script serves two purposes:
    1. Bootstrapper: If running via 'iwr | iex', it downloads the full project suite to a temporary location.
    2. Launcher: It loads the modular framework and launches the WPF Dashboard.

.NOTES
    Author: Howl
    Version: 2.0.1
    License: MIT
#>

# 1. BOOTSTRAPPER LOGIC (Handle 'iwr | iex' scenario)
$IsWebExecution = ($null -eq $PSScriptRoot) -or ($PSScriptRoot -eq '')
$ProjectRoot = if ($IsWebExecution) { "$env:TEMP\Win11Optimizer" } else { $PSScriptRoot }
$ModulePath = Join-Path $ProjectRoot "src"

if ($IsWebExecution -or -not (Test-Path $ModulePath)) {
    Write-Host " [BOOTSTRAPPER] Initializing Win11 Esports Optimizer..." -ForegroundColor Cyan
    
    # Define installation paths
    $ZipPath = "$env:TEMP\Win11Optimizer_Repo.zip"
    $ExtractPath = "$env:TEMP\Win11Optimizer_Extract"
    
    # Clean up previous runs
    Remove-Item $ProjectRoot -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $ExtractPath -Recurse -Force -ErrorAction SilentlyContinue
    
    try {
        Write-Host " [DOWNLOADING] Fetching latest version from GitHub..." -ForegroundColor Yellow
        $RepoUrl = "https://github.com/xhowlzzz/Optimization/archive/refs/heads/main.zip"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $RepoUrl -OutFile $ZipPath -UseBasicParsing
        
        Write-Host " [EXTRACTING] Unpacking modules..." -ForegroundColor Yellow
        Expand-Archive -Path $ZipPath -DestinationPath $ExtractPath -Force
        
        # Move inner folder content to target ProjectRoot
        # GitHub zips usually extract to 'Optimization-main'
        $SourceDir = Get-ChildItem -Path $ExtractPath -Directory | Select-Object -First 1
        Move-Item -Path "$($SourceDir.FullName)" -Destination $ProjectRoot -Force
        
        # Relaunch the script from disk to get proper $PSScriptRoot context
        $LocalScriptPath = Join-Path $ProjectRoot "Win11-EsportsTweaks.ps1"
        
        Write-Host " [LAUNCHING] Starting Dashboard..." -ForegroundColor Green
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$LocalScriptPath`"" -Verb RunAs
        exit
    } catch {
        Write-Error "Bootstrapping failed: $($_.Exception.Message)"
        Write-Host "Please download the release ZIP manually from GitHub."
        exit
    }
}

# 2. LAUNCHER LOGIC (Running locally with full file structure)

# Ensure Execution Policy
if ((Get-ExecutionPolicy) -ne 'Unrestricted' -and (Get-ExecutionPolicy) -ne 'Bypass') {
    Write-Warning "Execution Policy is restricted. Attempting to bypass..."
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

try {
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

} catch {
    Write-Host "CRITICAL ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    Read-Host "Press Enter to exit..."
}
