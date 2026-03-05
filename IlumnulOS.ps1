<#
.SYNOPSIS
    IlumnulOS Optimizer (Bootstrapper & Launcher)
    
.DESCRIPTION
    This script serves two purposes:
    1. Bootstrapper: If running via 'iwr | iex', it downloads the full project suite to a temporary location.
    2. Launcher: It loads the modular framework and launches the WPF Dashboard.

.NOTES
    Author: Howl
    Version: 2.0.8 (Stable)
    License: MIT
#>

# Global Trap for unhandled exceptions
Trap {
    Write-Host " [CRITICAL FAILURE] An unhandled exception occurred:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
    Read-Host "Press Enter to exit..."
    exit
}

$ErrorActionPreference = 'Stop'

# 1. BOOTSTRAPPER LOGIC
# We detect if we are running in a temporary context (Bootstrapper) or the full repo context.
# If $PSScriptRoot is empty (iex) or we are in the temp folder WITHOUT the src directory, we bootstrap.
$IsWebExecution = ($null -eq $PSScriptRoot) -or ($PSScriptRoot -eq '')
$CurrentDir = if ($IsWebExecution) { Get-Location } else { $PSScriptRoot }
$HasSrc = Test-Path (Join-Path $CurrentDir "src")

if ($IsWebExecution -or -not $HasSrc) {
    Write-Host " [BOOTSTRAPPER] Initializing IlumnulOS Optimizer..." -ForegroundColor Cyan
    
    $InstallDir = "$env:TEMP\IlumnulOS"
    $ZipPath = "$env:TEMP\IlumnulOS_Repo.zip"
    $ExtractPath = "$env:TEMP\IlumnulOS_Extract"
    
    # Clean up
    if (Test-Path $InstallDir) { Remove-Item $InstallDir -Recurse -Force -ErrorAction SilentlyContinue }
    if (Test-Path $ExtractPath) { Remove-Item $ExtractPath -Recurse -Force -ErrorAction SilentlyContinue }
    
    try {
        Write-Host " [DOWNLOADING] Fetching latest version..." -ForegroundColor Yellow
        $RepoUrl = "https://github.com/xhowlzzz/Optimization/archive/refs/heads/main.zip"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $RepoUrl -OutFile $ZipPath -UseBasicParsing
        
        Write-Host " [EXTRACTING] Unpacking modules..." -ForegroundColor Yellow
        Expand-Archive -Path $ZipPath -DestinationPath $ExtractPath -Force
        
        # Locate the inner root folder (e.g., Optimization-main)
        $InnerFolder = Get-ChildItem -Path $ExtractPath -Directory | Select-Object -First 1
        if (-not $InnerFolder) { throw "Extraction failed: No folder found in ZIP." }
        
        # Move to InstallDir
        Move-Item -Path $InnerFolder.FullName -Destination $InstallDir -Force
        
        $ToolsDir = Join-Path $InstallDir "Tools"
        if (-not (Test-Path $ToolsDir)) { New-Item -Path $ToolsDir -ItemType Directory -Force | Out-Null }
        
        # We need the CLI tool (nvidiaInspector.exe) for automation, but the user also requested Profile Inspector (GUI).
        # We will try to download the CLI version as it supports silent import.
        
        $InspectorZip = "$env:TEMP\nvidiaInspector.zip"
        
        try {
            Write-Host " [DOWNLOADING] NVIDIA Inspector..." -ForegroundColor Yellow
            # Download NVIDIA Inspector (CLI) v1.9.7.8
            # Using the direct Orbmu2k download link
            $cliUrl = "https://download.orbmu2k.de/download.php?id=51"
            Invoke-WebRequest -Uri $cliUrl -OutFile $InspectorZip -UseBasicParsing
            
            Expand-Archive -Path $InspectorZip -DestinationPath "$env:TEMP\InspectorExtract" -Force
            
            # Move nvidiaInspector.exe to Tools
            $exe = Get-ChildItem -Path "$env:TEMP\InspectorExtract" -Recurse -Filter "nvidiaInspector.exe" | Select-Object -First 1
            if ($exe) { 
                Copy-Item -Path $exe.FullName -Destination $ToolsDir -Force 
            }
            
            # Cleanup
            Remove-Item -Path "$env:TEMP\InspectorExtract" -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $InspectorZip -Force -ErrorAction SilentlyContinue
            
        } catch {
            Write-Warning "Failed to download NVIDIA Inspector. Manual import of .nip profile will be required."
        }

        $LauncherScript = Join-Path $InstallDir "IlumnulOS.ps1"
        if (-not (Test-Path $LauncherScript)) { throw "Launcher script missing at $LauncherScript" }

        Write-Host " [LAUNCHING] Starting Dashboard in new window..." -ForegroundColor Green
        
        # Launch the downloaded script in a new PowerShell window
        # -NoExit ensures the window stays open if it crashes
        # -WindowStyle Normal ensures it's visible
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoExit -ExecutionPolicy Bypass -File `"$LauncherScript`""
        $psi.Verb = "runas" # Request Admin
        $psi.UseShellExecute = $true
        [System.Diagnostics.Process]::Start($psi) | Out-Null
        
        Write-Host "Dashboard launched. You can close this window." -ForegroundColor Gray
        Read-Host "Press Enter to exit..."
        exit

    } catch {
        Write-Host " [ERROR] Bootstrapping failed!" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Read-Host "Press Enter to exit..."
        exit
    }
}

# 2. LAUNCHER LOGIC
# This runs when the script is executed from the InstallDir (with src/ present)

$ModulePath = Join-Path $PSScriptRoot "src"

try {
    # .NET Framework Check (4.7.2+ required)
    $net = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release -ErrorAction SilentlyContinue
    if (-not $net -or $net.Release -lt 461808) {
        throw "Microsoft .NET Framework 4.7.2 or greater is required. Please update Windows."
    }

    # Self-Elevation Check (Redundant if Bootstrapper used runas, but good for manual runs)
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
        Write-Warning "Elevation required. Relaunching..."
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoExit -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        $psi.Verb = "runas"
        [System.Diagnostics.Process]::Start($psi) | Out-Null
        exit
    }

    Write-Host " [LOADER] Loading IlumnulOS Optimizer..." -ForegroundColor Cyan

    # Verify Structure
    if (-not (Test-Path $ModulePath)) { throw "Corrupt installation: 'src' folder missing." }

    # Import Core
    $Core = @("Logger.psm1", "Config.psm1", "Security.psm1", "Registry.psm1", "Update.psm1")
    foreach ($m in $Core) { Import-Module (Join-Path $ModulePath "Core\$m") -Force }

    Initialize-Logger -LogPath (Join-Path ([Environment]::GetFolderPath("Desktop")) "IlumnulOS.log")
    Write-Log "Core initialized." -Level INFO
    
    # Troubleshooting Note:
    # If XAML errors occur regarding 'LineHeight', ensure 'TextBox' uses 'Block.LineHeight' (Attached Property) 
    # instead of the direct 'LineHeight' property, which only exists on 'TextBlock'.
    Write-Log "XAML Schema: TextBox supports Block.LineHeight; TextBlock supports LineHeight." -Level DEBUG

    # Import Modules
    $Modules = @("Network.psm1", "CPU.psm1", "GPU.psm1", "System.psm1", "Input.psm1", "Tweaks.psm1", "BatchTweaks.psm1", "End.psm1")
    foreach ($m in $Modules) { Import-Module (Join-Path $ModulePath "Modules\$m") -Force }
    Write-Log "Feature modules loaded." -Level INFO

    # Import Benchmarks
    Import-Module (Join-Path $ModulePath "Benchmarks\Benchmark.psm1") -Force
    
    # Import UI
    # Note: Renamed to .psm1 to properly support Export-ModuleMember
    $UiModule = Join-Path $ModulePath "UI\Dashboard.psm1"
    if (Test-Path $UiModule) {
        Import-Module $UiModule -Force
    } else {
        throw "UI Module not found at $UiModule"
    }

    Write-Log "UI initialized." -Level INFO

    # Launch
    Show-Dashboard

} catch {
    Write-Host " [CRITICAL ERROR] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Location: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
    Read-Host "Press Enter to exit..."
}
