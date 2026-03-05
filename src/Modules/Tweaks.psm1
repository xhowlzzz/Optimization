# Import Core Registry Utilities
$regModule = Join-Path $PSScriptRoot "..\Core\Registry.psm1"
if (Test-Path $regModule) {
    Import-Module $regModule -ErrorAction SilentlyContinue
}

function Invoke-PrivacyTweaks {
    Write-Log -Message "Applying Privacy Tweaks..." -Level INFO -Component "Tweaks"

    # Disable Telemetry & Data Collection
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "MaxTelemetryAllowed" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Value 0 -Type DWord # Redundant check
    
    # Disable Activity History
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Value 0 -Type DWord
    
    # Disable Location Tracking
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\MdmCommon\SettingValues" -Name "LocationSyncEnabled" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "ShowGlobalPrompts" -Value 0 -Type DWord
    
    # Disable Tailored Experiences & Offers
    Set-RegistryValueSafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" -Name "TailoredExperiencesWithDiagnosticDataEnabled" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CPSS\Store\TailoredExperiencesWithDiagnosticDataEnabled" -Name "Value" -Value 0 -Type DWord
    
    # Disable Feedback
    Set-RegistryValueSafe -Path "HKCU:\SOFTWARE\Microsoft\Siuf\Rules" -Name "NumberOfSIUFInPeriod" -Value 0 -Type DWord
    Remove-RegistryValueSafe -Path "HKCU:\SOFTWARE\Microsoft\Siuf\Rules" -Name "PeriodInNanoSeconds"
    
    # Disable Inking & Typing Dictionary
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\InputPersonalization" -Name "RestrictImplicitInkCollection" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\InputPersonalization" -Name "RestrictImplicitTextCollection" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore" -Name "HarvestContacts" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Personalization\Settings" -Name "AcceptedPrivacyPolicy" -Value 0 -Type DWord
    
    # Disable App Permissions (Global Deny)
    $privacyPaths = @(
        "location", "webcam", "userNotificationListener", "userAccountInformation", "contacts",
        "appointments", "phoneCall", "phoneCallHistory", "email", "userDataTasks", "chat",
        "radios", "bluetoothSync", "appDiagnostics", "documentsLibrary", "downloadsFolder",
        "musicLibrary", "picturesLibrary", "videosLibrary", "broadFileSystemAccess"
    )
    foreach ($p in $privacyPaths) {
        Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\$p" -Name "Value" -Value "Deny"
    }

    # Policy Denies
    $policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"
    Set-RegistryValueSafe -Path $policyPath -Name "LetAppsAccessLocation" -Value 2 -Type DWord
    Set-RegistryValueSafe -Path $policyPath -Name "LetAppsAccessCamera" -Value 2 -Type DWord
    Set-RegistryValueSafe -Path $policyPath -Name "LetAppsActivateWithVoice" -Value 2 -Type DWord
    Set-RegistryValueSafe -Path $policyPath -Name "LetAppsActivateWithVoiceAboveLock" -Value 2 -Type DWord
    Set-RegistryValueSafe -Path $policyPath -Name "LetAppsAccessNotifications" -Value 2 -Type DWord
    Set-RegistryValueSafe -Path $policyPath -Name "LetAppsAccessAccountInfo" -Value 2 -Type DWord
    Set-RegistryValueSafe -Path $policyPath -Name "LetAppsAccessContacts" -Value 2 -Type DWord
    Set-RegistryValueSafe -Path $policyPath -Name "LetAppsAccessCalendar" -Value 2 -Type DWord
    Set-RegistryValueSafe -Path $policyPath -Name "LetAppsAccessPhone" -Value 2 -Type DWord
    Set-RegistryValueSafe -Path $policyPath -Name "LetAppsAccessCallHistory" -Value 2 -Type DWord
    Set-RegistryValueSafe -Path $policyPath -Name "LetAppsAccessEmail" -Value 2 -Type DWord
    Set-RegistryValueSafe -Path $policyPath -Name "LetAppsAccessTasks" -Value 2 -Type DWord
    Set-RegistryValueSafe -Path $policyPath -Name "LetAppsAccessMessaging" -Value 2 -Type DWord
    Set-RegistryValueSafe -Path $policyPath -Name "LetAppsAccessRadios" -Value 2 -Type DWord
    Set-RegistryValueSafe -Path $policyPath -Name "LetAppsAccessTrustedDevices" -Value 2 -Type DWord
    Set-RegistryValueSafe -Path $policyPath -Name "LetAppsSyncWithDevices" -Value 2 -Type DWord
    Set-RegistryValueSafe -Path $policyPath -Name "LetAppsAccessGazeInput" -Value 2 -Type DWord
    Set-RegistryValueSafe -Path $policyPath -Name "LetAppsGetDiagnosticInfo" -Value 2 -Type DWord
    Set-RegistryValueSafe -Path $policyPath -Name "LetAppsAccessMotion" -Value 2 -Type DWord
    Set-RegistryValueSafe -Path $policyPath -Name "LetAppsRunInBackground" -Value 2 -Type DWord
    Set-RegistryValueSafe -Path $policyPath -Name "LetAppsAccessSystemAIModels" -Value 2 -Type DWord
    Set-RegistryValueSafe -Path $policyPath -Name "LetAppsAccessHumanPresence" -Value 2 -Type DWord
    Set-RegistryValueSafe -Path $policyPath -Name "LetAppsAccessBackgroundSpatialPerception" -Value 2 -Type DWord
    
    # Disable Voice Activation
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Speech_OneCore\Settings\VoiceActivation\UserPreferenceForAllApps" -Name "AgentActivationEnabled" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\SOFTWARE\Microsoft\Speech_OneCore\Settings\VoiceActivation\UserPreferenceForAllApps" -Name "AgentActivationLastUsed" -Value 0 -Type DWord

    # Disable Background Apps Global Toggle
    Set-RegistryValueSafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "BackgroundAppGlobalToggle" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -Name "GlobalUserDisabled" -Value 1 -Type DWord
    
    # Disable Suggested Actions & Smart Clipboard
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\SmartActionPlatform\SmartClipboard" -Name "Disabled" -Value 1 -Type DWord
    
    # Disable Shared Experiences
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\CDP" -Name "RomeSdkChannelUserAuthzPolicy" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\CDP" -Name "NearShareChannelUserAuthzPolicy" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\CDP" -Name "CdpSessionUserAuthzPolicy" -Value 0 -Type DWord

    # Disable Edge/Web Tracking
    Set-RegistryValueSafe -Path "HKCU:\Control Panel\International\User Profile" -Name "HttpAcceptLanguageOptOut" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Policies\Microsoft\Windows\EdgeUI" -Name "DisableMFUTracking" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\EdgeUI" -Name "DisableMFUTracking" -Value 1 -Type DWord
}

function Invoke-UITweaks {
    Write-Log -Message "Applying UI/UX Tweaks..." -Level INFO -Component "Tweaks"

    # Classic Context Menu (Win11)
    Set-RegistryValueSafe -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" -Name "(default)" -Value ""
    
    # Taskbar Alignment (Left)
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -Value 0 -Type DWord
    
    # Disable Snap Layouts
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "EnableSnapBar" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "EnableSnapAssistFlyout" -Value 0 -Type DWord
    
    # File Explorer Tweaks
    # Remove Gallery
    if (Test-Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}") {
        Remove-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}" -Force -Recurse -ErrorAction SilentlyContinue
    }
    # Remove Home
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}") {
        Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}" -Force -Recurse -ErrorAction SilentlyContinue
    }
    
    # Open Explorer to This PC
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "HubMode" -Value 1 -Type DWord
    
    # Start Menu Layout
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_Layout" -Value 1 -Type DWord # More Pins
    
    # Hide Recommendations & Recent Apps
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Start" -Name "ShowRecentList" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "HideRecentlyAddedApps" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoInstrumentation" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoStartMenuMFUprogramsList" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "ShowOrHideMostUsedApps" -Value 2 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "HideRecentlyAddedApps" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "HideRecommendedPersonalizedSites" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_IrisRecommendations" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_AccountNotifications" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Start" -Name "HideRecommendedSection" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "HideRecommendedSection" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Start" -Name "AllAppsViewMode" -Value 2 -Type DWord # List View

    # Taskbar Cleanup
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarMn" -Value 0 -Type DWord # Remove Chat
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "HideSCAMeetNow" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests" -Value 0 -Type DWord # Widgets
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds" -Name "EnableFeeds" -Value 0 -Type DWord
    
    # Visual Effects & Theme
    Set-RegistryValueSafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUsesLightTheme" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) -Type Binary
    Set-RegistryValueSafe -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value "0"
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAnimations" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "EnableAeroPeek" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "AlwaysHibernateThumbnails" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "IconsOnly" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ListviewAlphaSelect" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Control Panel\Desktop" -Name "DragFullWindows" -Value "0"
    Set-RegistryValueSafe -Path "HKCU:\Control Panel\Desktop" -Name "FontSmoothing" -Value "2"
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ListviewShadow" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 3 -Type DWord
    
    # Wallpaper (Custom)
    Invoke-WallpaperApply
    
    # Lock Screen
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "DisableLogonBackgroundImage" -Value 1 -Type DWord
    
    # Notifications & Action Center
    Remove-RegistryValueSafe -Path "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "DisableNotificationCenter"
    
    # Hide specific Quick Actions
    $quickActions = @(
        "Microsoft.QuickAction.BlueLightReduction", "Microsoft.QuickAction.Accessibility",
        "Microsoft.QuickAction.NearShare", "Microsoft.QuickAction.Cast", "Microsoft.QuickAction.ProjectL2"
    )
    foreach ($qa in $quickActions) {
        Set-RegistryValueSafe -Path "HKCU:\Control Panel\Quick Actions\Control Center\Unpinned" -Name $qa -Value ([byte[]]@()) -Type Binary
    }
    
    # Explorer View Settings
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1 -Type DWord # Show Hidden Files
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0 -Type DWord # Show Extensions
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "ShowFrequent" -Value 0 -Type DWord # Hide Frequent
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_TrackDocs" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_TrackProgs" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "OpenFolderInNewTab" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoWebServices" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoPublishingWizard" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "MultiTaskingAltTabFilter" -Value 3 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings" -Name "IsDynamicSearchBoxEnabled" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\StorageSense" -Name "AllowStorageSenseGlobal" -Value 0 -Type DWord
    
    # Menu Delay
    Set-RegistryValueSafe -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value "0"
    
    # New: Disable Shake to Minimize
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "DisallowShaking" -Value 1 -Type DWord
    
    # New: Disable Sync Provider Notifications
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowSyncProviderNotifications" -Value 0 -Type DWord
}

function Invoke-WallpaperApply {
    Write-Log -Message "Applying Custom Wallpaper..." -Level INFO -Component "Tweaks"
    
    # Define paths
    # Assuming the script is running from root or src/Modules, we need to find assets
    # $PSScriptRoot is src/Modules
    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
    $sourceWallpaper = Join-Path $repoRoot "assets\Background.png"
    
    # Persistent Destination (C:\ProgramData is standard for shared app data)
    $destDir = "C:\ProgramData\IlumnulOS"
    $destWallpaper = Join-Path $destDir "Background.png"
    
    if (Test-Path $sourceWallpaper) {
        # Create destination directory if it doesn't exist
        if (-not (Test-Path $destDir)) {
            New-Item -Path $destDir -ItemType Directory -Force | Out-Null
        }
        
        # Copy file
        Copy-Item -Path $sourceWallpaper -Destination $destWallpaper -Force
        
        # Apply Wallpaper via Registry
        # BackgroundType: 0 = Picture, 1 = Solid Color, 2 = Slideshow
        Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers" -Name "BackgroundType" -Value 0 -Type DWord
        Set-RegistryValueSafe -Path "HKCU:\Control Panel\Desktop" -Name "WallPaper" -Value $destWallpaper -Type String
        # WallpaperStyle: 2 = Stretch, 6 = Fit, 10 = Fill (Best for most screens)
        Set-RegistryValueSafe -Path "HKCU:\Control Panel\Desktop" -Name "WallpaperStyle" -Value "10" -Type String
        Set-RegistryValueSafe -Path "HKCU:\Control Panel\Desktop" -Name "TileWallpaper" -Value "0" -Type String
        
        # Force Refresh
        # Use SystemParametersInfo via C# signature or RUNDLL32 (RUNDLL is easier but less reliable, C# is better)
        # We'll use a simple RUNDLL call first, which usually works for wallpapers
        RUNDLL32.EXE user32.dll,UpdatePerUserSystemParameters
        
        Write-Log -Message "Wallpaper set to: $destWallpaper" -Level SUCCESS -Component "Tweaks"
    } else {
        Write-Log -Message "Wallpaper file not found at: $sourceWallpaper. Keeping default." -Level WARN -Component "Tweaks"
        
        # Fallback to Solid Black if custom wallpaper missing (keep existing behavior fallback)
        Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers" -Name "BackgroundType" -Value 1 -Type DWord
        Set-RegistryValueSafe -Path "HKCU:\Control Panel\Desktop" -Name "WallPaper" -Value ""
        Set-RegistryValueSafe -Path "HKCU:\Control Panel\Colors" -Name "Background" -Value "0 0 0"
    }
}

function Invoke-SystemTweaks {
    Write-Log -Message "Applying System & Performance Tweaks..." -Level INFO -Component "Tweaks"

    # Bypass Win11 Requirements
    Set-RegistryValueSafe -Path "HKCU:\Control Panel\UnsupportedHardwareNotificationCache" -Name "SV2" -Value 0 -Type DWord
    $setupKeys = "HKLM:\SYSTEM\Setup\LabConfig"
    Set-RegistryValueSafe -Path $setupKeys -Name "BypassCPUCheck" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path $setupKeys -Name "BypassRAMCheck" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path $setupKeys -Name "BypassSecureBootCheck" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path $setupKeys -Name "BypassStorageCheck" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path $setupKeys -Name "BypassTPMCheck" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\Setup\MoSetup" -Name "AllowUpgradesWithUnsupportedTPMOrCPU" -Value 1 -Type DWord
    
    # Disable AI & Copilot
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowCopilotButton" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\Software\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "DisableAIDataAnalysis" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "AllowRecallEnablement" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "DisableClickToDo" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\Software\Microsoft\Windows\Shell\Copilot\BingChat" -Name "IsUserEligible" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint" -Name "DisableGenerativeFill" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\WindowsNotepad" -Name "DisableAIFeatures" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\input\Settings" -Name "InsightsEnabled" -Value 0 -Type DWord
    
    # Disable UAC
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "PromptOnSecureDesktop" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 0 -Type DWord
    
    # Disable Windows Updates/Store Auto Download
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore" -Name "AutoDownload" -Value 2 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\Maps" -Name "AutoUpdateEnabled" -Value 0 -Type DWord
    
    # Performance
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 38 -Type DWord # 0x26
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Value 1 -Type DWord # User requested 1
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "NetworkThrottlingIndex" -Value 0xFFFFFFFF -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "SystemResponsiveness" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "NtfsDisableLastAccessUpdate" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\FTH" -Name "Enabled" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "MaxCachedIcons" -Value "4096"
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -Type DWord
    
    # New: Prefetch/Superfetch (SSD Optimization)
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" -Name "EnablePrefetcher" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" -Name "EnableSuperfetch" -Value 0 -Type DWord
    
    # Power
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "HibernateEnabled" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "SleepStudyDisabled" -Value 1 -Type DWord
    
    # Gaming
    Set-RegistryValueSafe -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AudioCaptureEnabled" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "CursorCaptureEnabled" -Value 0 -Type DWord
    
    # Miscellaneous
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings" -Name "TaskbarEndTask" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\ControlSet001\Services\UCPD" -Name "Start" -Value 4 -Type DWord # Disable User Choice Driver
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Start" -Name "RightCompanionToggledOpen" -Value 0 -Type DWord # Phone
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration" -Name "IsResumeAllowed" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Lighting" -Name "AmbientLightingEnabled" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching" -Name "SearchOrderConfig" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance" -Name "MaintenanceDisabled" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "DisableAutomaticRestartSignOn" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" -Name "ScoobeSystemSettingEnabled" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Keyboard Layout\Toggle" -Name "Language Hotkey" -Value "3"
    Set-RegistryValueSafe -Path "HKCU:\SOFTWARE\Microsoft\CTF\LangBar" -Name "ShowStatus" -Value 3 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\Software\Policies\Microsoft\Windows\Windows Search" -Name "DisableWebSearch" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\Software\Policies\Microsoft\Windows\Windows Search" -Name "ConnectedSearchUseWeb" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Installer" -Name "DisableCoInstallers" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\DesktopSpotlight\Settings" -Name "EnabledState" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\System\CurrentControlSet\Control\CrashControl" -Name "DisplayParameters" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\ControlSet001\Control\Session Manager" -Name "DisableWpbtExecution" -Value 1 -Type DWord
    
    # Disable Notifications (Toast)
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications" -Name "ToastEnabled" -Value 0 -Type DWord
    $toastPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings"
    Set-RegistryValueSafe -Path $toastPath -Name "NOC_GLOBAL_SETTING_ALLOW_TOASTS_ABOVE_LOCK" -Value 0 -Type DWord
    
    # Disable Services (Registry Method)
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Services\DiagTrack" -Name "Start" -Value 4 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Services\dmwappushservice" -Name "Start" -Value 4 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting" -Name "Disabled" -Value 1 -Type DWord
    
    # Disable Magnifier & Narrator
    Set-RegistryValueSafe -Path "HKCU:\SOFTWARE\Microsoft\ScreenMagnifier" -Name "FollowMouse" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\SOFTWARE\Microsoft\Narrator" -Name "ReadHints" -Value 0 -Type DWord
    
    # New: Input Tweaks (Accessibility Keys)
    $stickyKeys = "HKCU:\Control Panel\Accessibility\StickyKeys"
    Set-RegistryValueSafe -Path $stickyKeys -Name "Flags" -Value "506" -Type String
    $keyboardResponse = "HKCU:\Control Panel\Accessibility\Keyboard Response"
    Set-RegistryValueSafe -Path $keyboardResponse -Name "Flags" -Value "122" -Type String
    $toggleKeys = "HKCU:\Control Panel\Accessibility\ToggleKeys"
    Set-RegistryValueSafe -Path $toggleKeys -Name "Flags" -Value "58" -Type String
    
    # New: Network Tweaks (Supplemental)
    $tcpParams = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
    Set-RegistryValueSafe -Path $tcpParams -Name "GlobalMaxTcpWindowSize" -Value 65535 -Type DWord
    Set-RegistryValueSafe -Path $tcpParams -Name "TcpWindowSize" -Value 65535 -Type DWord
    Set-RegistryValueSafe -Path $tcpParams -Name "MaxUserPort" -Value 65534 -Type DWord
    Set-RegistryValueSafe -Path $tcpParams -Name "TcpTimedWaitDelay" -Value 30 -Type DWord
}

function Invoke-AllTweaks {
    Invoke-PrivacyTweaks
    Invoke-UITweaks
    Invoke-SystemTweaks
}

Export-ModuleMember -Function Invoke-AllTweaks, Invoke-PrivacyTweaks, Invoke-UITweaks, Invoke-SystemTweaks, Invoke-WallpaperApply
