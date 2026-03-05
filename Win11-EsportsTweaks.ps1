<#
.SYNOPSIS
    Win11 Esports Optimizer Pro (Bootstrapper & Launcher)
    
.DESCRIPTION
    This script serves two purposes:
    1. Bootstrapper: If running via 'iwr | iex', it downloads the full project suite to a temporary location.
    2. Launcher: It loads the modular framework and launches the WPF Dashboard.

.NOTES
    Author: Howl
    Version: 2.0.2
    License: MIT
#>

# Define Global Error Action to prevent silent closures
$ErrorActionPreference = 'Stop'

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
    if (Test-Path $ProjectRoot) { Remove-Item $ProjectRoot -Recurse -Force -ErrorAction SilentlyContinue }
    if (Test-Path $ExtractPath) { Remove-Item $ExtractPath -Recurse -Force -ErrorAction SilentlyContinue }
    
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
        if (-not $SourceDir) { throw "Failed to extract repository structure." }
        
        Move-Item -Path "$($SourceDir.FullName)" -Destination $ProjectRoot -Force
        
        # Relaunch the script from disk to get proper $PSScriptRoot context
        $LocalScriptPath = Join-Path $ProjectRoot "Win11-EsportsTweaks.ps1"
        
        if (-not (Test-Path $LocalScriptPath)) { throw "Main script not found after extraction at $LocalScriptPath" }

        Write-Host " [LAUNCHING] Starting Dashboard..." -ForegroundColor Green
        
        # Start new process and WAIT for it, keeping the window open if it fails
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$LocalScriptPath`""
        $psi.Verb = "runas"
        $psi.UseShellExecute = $true
        [System.Diagnostics.Process]::Start($psi)
        
        exit
    } catch {
        Write-Error "Bootstrapping failed: $($_.Exception.Message)"
        Write-Host "Please download the release ZIP manually from GitHub."
        Read-Host "Press Enter to exit..."
        exit
    }
}

# 2. LAUNCHER LOGIC (Running locally with full file structure)

# Ensure Execution Policy
if ((Get-ExecutionPolicy) -ne 'Unrestricted' -and (Get-ExecutionPolicy) -ne 'Bypass') {
    Write-Warning "Execution Policy is restricted. Attempting to bypass..."
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $psi.Verb = "runas"
    [System.Diagnostics.Process]::Start($psi)
    exit
}

try {
    # Verify Modules Exist
    if (-not (Test-Path $ModulePath)) { throw "Module directory not found at $ModulePath" }

    # Import Core
    Write-Host "Loading Core Modules..." -ForegroundColor Cyan
    $CoreModules = @("Logger.psm1", "Config.psm1", "Security.psm1", "Registry.psm1", "Update.psm1")
    foreach ($mod in $CoreModules) {
        $path = Join-Path $ModulePath "Core\$mod"
        if (Test-Path $path) { Import-Module $path -Force } else { Write-Warning "Missing Core Module: $mod" }
    }

    # Initialize Logger
    Initialize-Logger -LogPath (Join-Path ([Environment]::GetFolderPath("Desktop")) "Win11Optimizer.log")

    # Check Admin
    Ensure-RunningAsAdministrator

    # Import Feature Modules
    Write-Log "Loading Feature Modules..." -Level INFO
    $FeatureModules = @("Network.psm1", "CPU.psm1", "GPU.psm1", "System.psm1", "Input.psm1")
    foreach ($mod in $FeatureModules) {
        $path = Join-Path $ModulePath "Modules\$mod"
        if (Test-Path $path) { Import-Module $path -Force } else { Write-Log "Missing Feature Module: $mod" -Level WARN }
    }

    # Import Benchmarks
    Import-Module (Join-Path $ModulePath "Benchmarks\Benchmark.psm1") -Force -ErrorAction SilentlyContinue

    # Import UI
    Write-Log "Initializing UI..." -Level INFO
    $UiModule = Join-Path $ModulePath "UI\Dashboard.ps1"
    if (Test-Path $UiModule) {
        Import-Module $UiModule -Force
    } else {
        throw "UI Module not found at $UiModule"
    }

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
