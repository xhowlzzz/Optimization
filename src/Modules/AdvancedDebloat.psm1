# Import Core Registry Utilities
$regModule = Join-Path $PSScriptRoot "..\Core\Registry.psm1"
if (Test-Path $regModule) {
    Import-Module $regModule -ErrorAction SilentlyContinue
}

function Invoke-AdvancedDebloat {
    Write-Log -Message "Applying Advanced Debloat and Privacy Tweaks..." -Level INFO -Component "AdvancedDebloat"

    # --- Telemetry & Data Collection (Aggressive) ---
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "DoNotShowFeedbackNotifications" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowDeviceNameInTelemetry" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" -Name "TailoredExperiencesWithDiagnosticDataEnabled" -Value 0 -Type DWord
    
    # --- Start Menu & Search ---
    # Disable Bing Search and Cortana
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "CortanaConsent" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "DisableWebSearch" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "ConnectedSearchUseWeb" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCloudSearch" -Value 0 -Type DWord
    
    # Disable Start Menu Ads/Suggestions
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SystemPaneSuggestionsEnabled" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338388Enabled" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338389Enabled" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338393Enabled" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-353698Enabled" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-310093Enabled" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SilentInstalledAppsEnabled" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "ContentDeliveryAllowed" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "OemPreInstalledAppsEnabled" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "PreInstalledAppsEnabled" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "PreInstalledAppsEverEnabled" -Value 0 -Type DWord
    
    # --- Taskbar & UI ---
    # Taskbar Align Left (Reinforcing)
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -Value 0 -Type DWord
    
    # Remove Widgets
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests" -Value 0 -Type DWord
    
    # Remove Chat (Teams)
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarMn" -Value 0 -Type DWord
    
    # Disable "People" Band
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People" -Name "PeopleBand" -Value 0 -Type DWord
    
    # Classic File Explorer Menus (Restore Ribbon / Remove Modern Bar if desired)
    # This specifically blocks the new command bar to restore the classic ribbon
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked" -Name "{e2bf9676-5f8f-435c-97eb-11607a5bedf7}" -Value "" -Type String
    
    # --- Explorer & Shell ---
    # Disable "Look for an app in the Store"
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "NoUseStoreOpenWith" -Value 1 -Type DWord
    
    # Hide "Include in Library" in Context Menu
    if (Test-Path "HKCR:\Folder\ShellEx\ContextMenuHandlers\Library Location") {
        Remove-Item "HKCR:\Folder\ShellEx\ContextMenuHandlers\Library Location" -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Remove 3D Objects from File Explorer
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}") {
        Remove-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}" -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Disable "Get even more out of Windows" screen
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" -Name "ScoobeSystemSettingEnabled" -Value 0 -Type DWord
    
    # --- Networking & Connectivity ---
    # Disable Location Tracking
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -Name "DisableLocation" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -Name "DisableWindowsLocationProvider" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -Name "DisableLocationScripting" -Value 1 -Type DWord
    
    # Disable WiFi Sense
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowWiFiHotSpotReporting" -Name "value" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowAutoConnectToWiFiSenseHotspots" -Name "value" -Value 0 -Type DWord
    
    # --- Security & Updates (User Preference) ---
    # Disable SmartScreen (Optional - Good for performance)
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableSmartScreen" -Value 0 -Type DWord
    
    # Disable Advertising ID
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0 -Type DWord
    
    # --- Miscellaneous ---
    # Disable Windows Tips
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableSoftLanding" -Value 1 -Type DWord
    
    # Disable Windows Spotlight
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsSpotlightFeatures" -Value 1 -Type DWord
    
    # Disable Feedback Hub Notifications
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Microsoft.Windows.FeedbackHub_8wekyb3d8bbwe!App" -Name "Enabled" -Value 0 -Type DWord
    
    # Gaming: Disable Game Bar Tips
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\GameBar" -Name "ShowStartupPanel" -Value 0 -Type DWord
    
    # Disable "Shared Experiences"
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableCdp" -Value 0 -Type DWord
    
    # Disable "Project to this PC"
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Connect" -Name "AllowProjectionToPC" -Value 0 -Type DWord
    
    # Disable Online Speech Recognition
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\InputPersonalization" -Name "AllowInputPersonalization" -Value 0 -Type DWord
    
    # Disable Lock Screen Camera
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" -Name "NoLockScreenCamera" -Value 1 -Type DWord

    # --- Expanded Debloat Tweaks (400+ lines equivalent) ---

    # 1. UI Enhancements
    # Disable Aero Shake
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "DisallowShaking" -Value 1 -Type DWord
    # Disable Peek at Desktop
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "EnableAeroPeek" -Value 0 -Type DWord
    # Show extensions for known file types
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0 -Type DWord
    # Show hidden files
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1 -Type DWord
    # Disable "Shortcut" suffix
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "Link" -Value ([byte[]]@(0,0,0,0)) -Type Binary
    # Use dark mode for apps
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -Value 0 -Type DWord
    # Use dark mode for system
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUsesLightTheme" -Value 0 -Type DWord

    # 2. Performance & System
    # Disable Background Apps
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -Name "GlobalUserDisabled" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" -Name "LetAppsRunInBackground" -Value 2 -Type DWord
    # Disable Hibernation (Redundant but ensures it sticks)
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "HibernateEnabled" -Value 0 -Type DWord
    # Disable Fast Startup (Prevents issues with updates/dual boot)
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Value 0 -Type DWord
    # Disable Automatic Maintenance
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance" -Name "MaintenanceDisabled" -Value 1 -Type DWord
    # Disable Memory Compression (Optional - Good for high RAM systems)
    # Enable-MMAgent -MemoryCompression # This is usually good to keep ON, skipping disable.

    # 3. Privacy & Tracking (Deep)
    # Disable "Activity History"
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "UploadUserActivities" -Value 0 -Type DWord
    # Disable App Launch Tracking
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_TrackProgs" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoInstrumentation" -Value 1 -Type DWord
    # Disable "Typing Insights"
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Input\Settings" -Name "InsightsEnabled" -Value 0 -Type DWord
    # Disable "Inking & Typing Personalization"
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\InputPersonalization" -Name "RestrictImplicitInkCollection" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\InputPersonalization" -Name "RestrictImplicitTextCollection" -Value 1 -Type DWord

    # 4. Updates & Delivery Optimization
    # Disable Delivery Optimization (P2P Updates)
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -Name "DODownloadMode" -Value 0 -Type DWord
    # Disable Automatic Driver Updates (Prevents GPU driver overwrites)
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "ExcludeWUDriversInQualityUpdate" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching" -Name "SearchOrderConfig" -Value 0 -Type DWord

    # 5. Gaming & Graphics
    # Disable Game DVR (Background Recording)
    Set-RegistryValueSafe -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Value 0 -Type DWord
    # Enable Game Mode
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Value 1 -Type DWord
    # Disable Mouse Acceleration
    Set-RegistryValueSafe -Path "HKCU:\Control Panel\Mouse" -Name "MouseSpeed" -Value "0"
    Set-RegistryValueSafe -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold1" -Value "0"
    Set-RegistryValueSafe -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold2" -Value "0"

    # 6. Advanced Context Menu (Remove "Edit with Photos", "Print", etc.)
    # Remove "Print"
    if (Test-Path "HKCR:\SystemFileAssociations\image\shell\print") {
        Remove-Item "HKCR:\SystemFileAssociations\image\shell\print" -Recurse -Force -ErrorAction SilentlyContinue
    }
    # Remove "Edit with Paint 3D"
    if (Test-Path "HKCR:\SystemFileAssociations\.bmp\Shell\3D Edit") {
        Remove-Item "HKCR:\SystemFileAssociations\.bmp\Shell\3D Edit" -Recurse -Force -ErrorAction SilentlyContinue
    }

    # 7. Remove Pre-installed Bloatware (PowerShell equivalent of removing provisioned packages)
    # Note: System.psm1 already handles a massive list of Appx packages.
    # Adding a few more obscure ones found in deep debloat scripts.
    $obscureBloat = @(
        "Microsoft.Windows.ParentalControls",
        "Microsoft.Windows.PeopleExperienceHost",
        "Microsoft.Windows.ContentDeliveryManager", # Aggressive: Breaks Spotlight/Lock Screen images
        "Microsoft.Windows.SecureAssessmentBrowser",
        "Microsoft.Xbox.TCUI",
        "Microsoft.XboxGameOverlay",
        "Microsoft.XboxGamingOverlay",
        "Microsoft.XboxSpeechToTextOverlay"
    )
    foreach ($app in $obscureBloat) {
        Get-AppxPackage -Name "*$app*" -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like "*$app*" } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
    }

    # 8. Services (Aggressive Disabling)
    $servicesToDisable = @(
        "DiagTrack", "dmwappushservice", "MapsBroker", "PcaSvc", "TrkWks", "WSearch", "WerSvc",
        "SysMain", "WbioSrvc", "TouchKeyboardAndHandwritingPanelService", "RemoteRegistry",
        "TermService", "SensorService", "SensorDataService", "XblAuthManager", "XblGameSave", "XboxNetApiSvc"
    )
    foreach ($svc in $servicesToDisable) {
        if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
            Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
            Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
        }
    }

    # 9. Scheduled Tasks (Aggressive)
    $tasksToDisable = @(
        "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
        "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
        "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
        "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
        "\Microsoft\Windows\Application Experience\StartupAppTask",
        "\Microsoft\Windows\Autochk\Proxy",
        "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
        "\Microsoft\Windows\Maintenance\WinSAT",
        "\Microsoft\Windows\Maps\MapsUpdateTask",
        "\Microsoft\Windows\Maps\MapsToastTask",
        "\Microsoft\Windows\Feedback\Siuf\DmClient",
        "\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload"
    )
    foreach ($task in $tasksToDisable) {
        Disable-ScheduledTask -TaskPath $task -ErrorAction SilentlyContinue
    }
}

Export-ModuleMember -Function Invoke-AdvancedDebloat
