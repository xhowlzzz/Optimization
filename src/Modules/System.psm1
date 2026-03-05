function Invoke-RemoveWindowsAI {
    [CmdletBinding()]
    param()

    Write-Log -Message "Starting Advanced Windows AI Removal..." -Level INFO -Component "AI-Debloat"

    # 1. Disable Recall & AI Features via Registry (Machine & User)
    $aiKeys = @(
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI",
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot",
        "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot",
        "HKLM:\SOFTWARE\Policies\Microsoft\Edge",
        "HKCU:\Software\Policies\Microsoft\Edge"
    )

    foreach ($key in $aiKeys) {
        if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
        
        # General AI & Copilot
        Set-ItemProperty -Path $key -Name "TurnOffWindowsCopilot" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $key -Name "DisableAIDataAnalysis" -Value 1 -Type DWord -Force
        
        # Edge Specific
        if ($key -match "Edge") {
            Set-ItemProperty -Path $key -Name "HubsSidebarEnabled" -Value 0 -Type DWord -Force # Disables Sidebar (Copilot home)
            Set-ItemProperty -Path $key -Name "ShowCopilot" -Value 0 -Type DWord -Force
        }
    }

    # 2. Disable Recall Snapshotting (Privacy)
    $recallKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy"
    if (-not (Test-Path $recallKey)) { New-Item -Path $recallKey -Force | Out-Null }
    Set-ItemProperty -Path $recallKey -Name "RecallEnabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $recallKey -Name "SnapshottingEnabled" -Value 0 -Type DWord -Force

    # 3. Remove AI Appx Packages (Aggressive)
    $aiApps = @(
        "Microsoft.Windows.Ai.Copilot.Provider",
        "Microsoft.Copilot",
        "Microsoft.Windows.Recall",
        "Microsoft.BingSearch" # Often tied to Copilot/Start search
    )
    foreach ($app in $aiApps) {
        Get-AppxPackage -Name "*$app*" -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like "*$app*" } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
        Write-Log -Message "Removed AI App: $app" -Level SUCCESS -Component "AI-Debloat"
    }

    # 4. Disable AI Services
    $aiServices = @("WindowsAI", "RecallService", "CopilotService")
    foreach ($svc in $aiServices) {
        if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
            Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
            Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Log -Message "Disabled AI Service: $svc" -Level SUCCESS -Component "AI-Debloat"
        }
    }
}

function Invoke-SystemDebloat {
    [CmdletBinding()]
    param(
        [switch]$IncludeOneDrive = $true
    )
    
    Write-Log -Message "Starting Comprehensive System Debloat..." -Level INFO -Component "System"
    
    # 1. Disable Telemetry & Bloat Services
    $services = @(
        "DiagTrack",           # Connected User Experiences and Telemetry
        "dmwappushservice",    # WAP Push Message Routing Service
        "SysMain",             # Superfetch (often causes high disk usage)
        "MapsBroker",          # Downloaded Maps Manager
        "WerSvc",              # Windows Error Reporting
        "PcaSvc",              # Program Compatibility Assistant
        "dps",                 # Diagnostic Policy Service
        "WSearch",             # Windows Search (Optional, but often bloat for gamers)
        "RetailDemo",          # Retail Demo Service
        "lfsvc",               # Geolocation Service
        "WbioSrvc"             # Windows Biometric Service (Optional, remove if not using Hello)
    )
    foreach ($svc in $services) {
        if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
            Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
            Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Log -Message "Disabled Service: $svc" -Level SUCCESS -Component "System"
        }
    }
    
    # 2. Remove Telemetry Scheduled Tasks
    $tasks = @(
        "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
        "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
        "\Microsoft\Windows\Application Experience\StartupAppTask",
        "\Microsoft\Windows\Autochk\Proxy",
        "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
        "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
        "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
        "\Microsoft\Windows\Maintenance\WinSAT",
        "\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem",
        "\Microsoft\Windows\Maps\MapsUpdateTask",
        "\Microsoft\Windows\Maps\MapsToastTask"
    )
    foreach ($taskPath in $tasks) {
        Get-ScheduledTask -TaskPath $taskPath -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue
        Write-Log -Message "Removed Task: $taskPath" -Level SUCCESS -Component "System"
    }
    
    # 3. Remove Bloatware Appx Packages
    # Extensive list for "Gamer OS" feel
    $bloatware = @(
        "Microsoft.3DBuilder",
        "Microsoft.BingFinance",
        "Microsoft.BingNews",
        "Microsoft.BingWeather",
        "Microsoft.GetHelp",
        "Microsoft.Getstarted",
        "Microsoft.MicrosoftOfficeHub",
        "Microsoft.MicrosoftSolitaireCollection",
        "Microsoft.MixedReality.Portal",
        "Microsoft.Office.OneNote",
        "Microsoft.People",
        "Microsoft.SkypeApp",
        "Microsoft.Wallet",
        "Microsoft.WindowsAlarms",
        "Microsoft.WindowsFeedbackHub",
        "Microsoft.WindowsMaps",
        "Microsoft.WindowsSoundRecorder",
        "Microsoft.YourPhone",
        "Microsoft.ZuneMusic",
        "Microsoft.ZuneVideo",
        "Microsoft.Xbox.TCUI", 
        "Microsoft.XboxGameOverlay",
        "Microsoft.XboxGamingOverlay",
        "Microsoft.XboxSpeechToTextOverlay",
        "Microsoft.GamingApp",
        "Microsoft.OutlookForWindows",
        "Microsoft.DevHome",
        "Microsoft.549981C3F5F10", # Cortana
        "Microsoft.Todos",
        "Microsoft.PowerAutomateDesktop",
        "Clipchamp.Clipchamp",
        "Microsoft.WindowsCamera",
        "Microsoft.Windows.Photos",
        "Microsoft.Paint",
        "Microsoft.ScreenSketch", # Snip & Sketch
        "Microsoft.MicrosoftStickyNotes",
        "Microsoft.WindowsCalculator",
        "Microsoft.WindowsTerminal", # Optional: Some users prefer cmd
        # Third Party / Sponsored
        "Disney",
        "Netflix",
        "Spotify",
        "Instagram",
        "TikTok",
        "Facebook",
        "Twitter",
        "LinkedIn",
        "Pandora",
        "Amazon",
        "eBay",
        "Booking",
        "AdobeLightroom",
        "DolbyAccess",
        "Duolingo",
        "Fitbit",
        "Flipboard",
        "PhotoshopExpress",
        "PicsArt",
        "PrimeVideo",
        "Shazam",
        "TuneInRadio",
        "Uber",
        "Wunderlist"
    )

    foreach ($app in $bloatware) {
        # Remove for current user and all users
        Get-AppxPackage -Name "*$app*" -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        # Remove from provisioning (so it doesn't come back for new users)
        Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like "*$app*" } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
        Write-Log -Message "Removed Bloatware: $app" -Level SUCCESS -Component "System"
    }

    # Disable Windows Updates/Store Auto Download
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore" -Name "AutoDownload" -Value 2 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\Maps" -Name "AutoUpdateEnabled" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoUpdate" -Value 1 -Type DWord # Aggressive
    
    # Disable Defender (Soft/Registry)
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableAntiSpyware" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" -Name "DisableRealtimeMonitoring" -Value 1 -Type DWord
    
    # Clean Settings Tips
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "AllowOnlineTips" -Value 0 -Type DWord
    
    # Performance

    # 4. Optional: Remove OneDrive
    if ($IncludeOneDrive) {
        Invoke-OneDriveRemove
    }
}

function Invoke-OneDriveRemove {
    Write-Log -Message "Removing OneDrive..." -Level INFO -Component "OneDrive"
    
    # Kill OneDrive process (PowerShell native)
    Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    
    # Uninstall command
    $onedriveSetup = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
    if (-not (Test-Path $onedriveSetup)) {
        $onedriveSetup = "$env:SystemRoot\System32\OneDriveSetup.exe"
    }
    
    if (Test-Path $onedriveSetup) {
        Start-Process $onedriveSetup -ArgumentList "/uninstall" -Wait -NoNewWindow
        Write-Log -Message "OneDrive Uninstalled." -Level SUCCESS -Component "OneDrive"
    } else {
        Write-Log -Message "OneDrive setup not found." -Level WARN -Component "OneDrive"
    }
    
    # Remove OneDrive leftovers
    Remove-Item -Path "$env:UserProfile\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:LocalAppData\Microsoft\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:ProgramData\Microsoft OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
    
    # Remove from Explorer
    if (Test-Path "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}") {
        Set-ItemProperty -Path "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" -Name "System.IsPinnedToNameSpaceTree" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    }
}

Export-ModuleMember -Function Invoke-SystemDebloat, Invoke-RemoveWindowsAI, Invoke-OneDriveRemove
