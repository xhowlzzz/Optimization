# Import Core Registry Utilities
$regModule = Join-Path $PSScriptRoot "..\Core\Registry.psm1"
if (Test-Path $regModule) {
    Import-Module $regModule -ErrorAction SilentlyContinue
}

function Invoke-AncelTweaks {
    Write-Log -Message "Applying Ancel's Performance Tweaks..." -Level INFO -Component "BatchTweaks"

    # --- Power Settings ---
    # Disable Hibernation (Already in Tweaks.psm1, reinforcing)
    powercfg -h off | Out-Null
    
    # --- Network Tweaks (TCP/IP) ---
    # Netsh Int TCP Global
    netsh int tcp set global rss=enabled | Out-Null
    netsh int tcp set global autotuninglevel=normal | Out-Null
    netsh int tcp set global ecncapability=disabled | Out-Null
    netsh int tcp set global timestamps=disabled | Out-Null
    netsh int tcp set global initialrto=2000 | Out-Null
    netsh int tcp set global rsc=disabled | Out-Null
    netsh int tcp set global nonsackrttresiliency=disabled | Out-Null
    netsh int tcp set global maxsynretransmissions=2 | Out-Null
    
    # Netsh Int TCP Supplemental
    netsh int tcp set supplemental template=custom icw=10 | Out-Null
    
    # --- BCD Tweaks (Boot Configuration) ---
    # Disable Boot Screen Animation
    bcdedit /set bootux disabled | Out-Null
    # Disable Boot Log
    bcdedit /set bootlog no | Out-Null
    # Disable Boot Menu Policy
    bcdedit /set bootmenupolicy Standard | Out-Null
    # Disable Quiet Boot
    bcdedit /set quietboot yes | Out-Null
    
    # --- Registry Tweaks from Ancel's Batch ---
    
    # 1. System Responsiveness & Multimedia
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "SystemResponsiveness" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" -Name "GPU Priority" -Value 8 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" -Name "Priority" -Value 6 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" -Name "Scheduling Category" -Value "High" -Type String
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" -Name "SFIO Priority" -Value "High" -Type String

    # 2. File System (NTFS)
    $fsKey = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
    Set-RegistryValueSafe -Path $fsKey -Name "NtfsDisableLastAccessUpdate" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path $fsKey -Name "NtfsDisable8dot3NameCreation" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path $fsKey -Name "NtfsMemoryUsage" -Value 2 -Type DWord # Increased cache
    
    # 3. Memory Management
    $memKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    Set-RegistryValueSafe -Path $memKey -Name "LargeSystemCache" -Value 1 -Type DWord # Favor system cache
    Set-RegistryValueSafe -Path $memKey -Name "DisablePagingExecutive" -Value 1 -Type DWord # Keep kernel in RAM
    
    # 4. Priority Control
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 38 -Type DWord # 26 Hex
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "IRQ8Priority" -Value 1 -Type DWord
    
    # 5. Explorer / Desktop
    Set-RegistryValueSafe -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value "0"
    Set-RegistryValueSafe -Path "HKCU:\Control Panel\Desktop" -Name "AutoEndTasks" -Value "1"
    Set-RegistryValueSafe -Path "HKCU:\Control Panel\Desktop" -Name "WaitToKillAppTimeout" -Value "2000"
    Set-RegistryValueSafe -Path "HKCU:\Control Panel\Desktop" -Name "HungAppTimeout" -Value "1000"
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "WaitToKillServiceTimeout" -Value "2000"
    
    # 6. Disable Throttling
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "NetworkThrottlingIndex" -Value 0xFFFFFFFF -Type DWord
    
    # 7. GPU Tweaks (NVIDIA/AMD common)
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "PlatformSupportMiracast" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Scheduler" -Name "EnablePreemption" -Value 0 -Type DWord
    
    # 8. Disable Fullscreen Optimizations (Global)
    Set-RegistryValueSafe -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_FSEBehaviorMode" -Value 2 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_HonorUserFSEBehaviorMode" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Value 1 -Type DWord
    
    # 9. USB Polling (Attempt to set global if not per-device)
    # Note: This is usually device specific, but setting global flags can help
    # Ancel's script does specific device iterating, which we already have in Input.psm1
    
    # 10. Disable Game Bar Presence Writer
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\Windows.Gaming.GameBar.PresenceServer.Internal.PresenceWriter" -Name "ActivationType" -Value 0 -Type DWord
    
    # --- Service Disables (Specific to Ancel's list) ---
    $servicesToDisable = @(
        "XblAuthManager", "XblGameSave", "XboxNetApiSvc", "XboxGipSvc", # Xbox Services (if not using Game Pass)
        "DiagTrack", "dmwappushservice", "MapsBroker", "PcaSvc", "TrkWks", "WSearch", "WerSvc"
    )
    foreach ($svc in $servicesToDisable) {
        if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
            Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
            Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
        }
    }
    
    # --- Scheduled Tasks (Maintenance) ---
    Disable-ScheduledTask -TaskPath "\Microsoft\Windows\Customer Experience Improvement Program\" -TaskName "*" -ErrorAction SilentlyContinue
    Disable-ScheduledTask -TaskPath "\Microsoft\Windows\Application Experience\" -TaskName "*" -ErrorAction SilentlyContinue
}

Export-ModuleMember -Function Invoke-AncelTweaks
