# Import Core Registry Utilities
$regModule = Join-Path $PSScriptRoot "..\Core\Registry.psm1"
if (Test-Path $regModule) {
    Import-Module $regModule -ErrorAction SilentlyContinue
}

function Invoke-PerformanceBatch {
    Write-Log -Message "Applying Advanced Performance Tweaks..." -Level INFO -Component "BatchTweaks"

    # --- Power Settings ---
    # Disable Hibernation
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
    
    # Additional Network Tweaks (from reference)
    netsh int ip set global taskoffload=enabled | Out-Null
    netsh int ip set global neighborcachelimit=4096 | Out-Null
    netsh int ip set global routecachelimit=4096 | Out-Null
    netsh int ip set global sourceroutingbehavior=drop | Out-Null
    netsh int ip set global multicastforwarding=disabled | Out-Null
    netsh int ip set global dhcpmediasense=disabled | Out-Null
    netsh int ip set global randomizeidentifiers=disabled | Out-Null
    
    # DNS Optimization (Google DNS as placeholder, can be changed)
    # netsh interface ip set dns "Ethernet" static 8.8.8.8 | Out-Null
    # netsh interface ip add dns "Ethernet" 8.8.4.4 index=2 | Out-Null
    
    # Advanced per-interface Network Tweaks (Latency)
    try {
        $interfaces = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' }
        foreach ($nic in $interfaces) {
            $guid = $nic.InterfaceGuid
            $path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid"
            
            if (Test-Path $path) {
                # TcpAckFrequency: 1 = Disable delayed ACK (Better for gaming ping)
                Set-RegistryValueSafe -Path $path -Name "TcpAckFrequency" -Value 1 -Type DWord
                # TCPNoDelay: 1 = Disable Nagle's algorithm (Better for gaming latency)
                Set-RegistryValueSafe -Path $path -Name "TCPNoDelay" -Value 1 -Type DWord
                # TcpDelAckTicks: 0 = No delay
                Set-RegistryValueSafe -Path $path -Name "TcpDelAckTicks" -Value 0 -Type DWord
            }
        }
    } catch {
        Write-Log -Message "Failed to apply per-interface network tweaks: $_" -Level WARN -Component "BatchTweaks"
    }

    # --- File System (Advanced) ---
    # Disable Paging File Encryption (Performance)
    fsutil behavior set encryptpagingfile 0 | Out-Null
    # Increase MFT Zone (Better for many small files)
    fsutil behavior set mftzone 2 | Out-Null
    
    # --- CPU & Kernel Optimizations (High Performance) ---
    # Disable Spectre & Meltdown Mitigations (Warning: Security Risk, High Performance Reward)
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "FeatureSettingsOverride" -Value 3 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "FeatureSettingsOverrideMask" -Value 3 -Type DWord
    
    # Multimedia Scheduling - NoLazyMode
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "NoLazyMode" -Value 1 -Type DWord
    
    # Memory Management - L2 Cache & Images
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "SecondLevelDataCache" -Value 0 -Type DWord # 0 = Auto
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "MoveImages" -Value 0 -Type DWord
    
    # --- BCD Tweaks (Boot Configuration) ---
    # Disable Boot Screen Animation
    bcdedit /set bootux disabled | Out-Null
    # Disable Boot Log
    bcdedit /set bootlog no | Out-Null
    # Disable Boot Menu Policy
    bcdedit /set bootmenupolicy Standard | Out-Null
    # Disable Quiet Boot
    bcdedit /set quietboot yes | Out-Null
    # Disable Integrity Checks (Optional - allows unsigned drivers, use with caution)
    # bcdedit /set nointegritychecks yes | Out-Null
    
    # --- Registry Tweaks ---
    
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
    Set-RegistryValueSafe -Path $memKey -Name "IoPageLockLimit" -Value 983040 -Type DWord # Increase I/O throughput
    
    # 4. Priority Control
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 38 -Type DWord # 26 Hex
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "IRQ8Priority" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "DevicePriority" -Value 1 -Type DWord
    
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
    
    # 10. Disable Game Bar Presence Writer
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\Windows.Gaming.GameBar.PresenceServer.Internal.PresenceWriter" -Name "ActivationType" -Value 0 -Type DWord
    
    # 11. Mouse & Keyboard (Input Latency)
    # Mouse
    Set-RegistryValueSafe -Path "HKCU:\Control Panel\Mouse" -Name "MouseSpeed" -Value "0"
    Set-RegistryValueSafe -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold1" -Value "0"
    Set-RegistryValueSafe -Path "HKCU:\Control Panel\Mouse" -Name "MouseThreshold2" -Value "0"
    # Keyboard
    Set-RegistryValueSafe -Path "HKCU:\Control Panel\Keyboard" -Name "KeyboardDelay" -Value "0"
    Set-RegistryValueSafe -Path "HKCU:\Control Panel\Keyboard" -Name "KeyboardSpeed" -Value "31"
    
    # 12. USB Power (Global)
    $usbKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\2a737441-1930-4402-8d77-b949f808694c\48e6b7a6-50f5-4782-a5d4-53bb8f07e226"
    Set-RegistryValueSafe -Path $usbKey -Name "Attributes" -Value 2 -Type DWord # Expose in Power Options
    
    # 13. Disable Application Prelaunch
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "DisableApplicationPrelaunch" -Value 1 -Type DWord
    
    # 14. Network Throttling & QoS
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched" -Name "NonBestEffortLimit" -Value 0 -Type DWord
    
    # 15. Disable Fullscreen Optimization (Global - Redundant check)
    Set-RegistryValueSafe -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_FSEBehavior" -Value 2 -Type DWord
    
    # 16. Visual Effects (Performance)
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2 -Type DWord
    
    # 17. Power Throttling (Disable for everything)
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" -Name "PowerThrottlingOff" -Value 1 -Type DWord
    
    # 18. Hardware Accelerated GPU Scheduling (HAGS)
    # 2 = Enabled (Recommended for modern NVIDIA/AMD cards for DLSS 3/FSR)
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Value 2 -Type DWord
    
    # 19. VR Preemption (Reduces micro-stutter for VR and High-FPS gaming)
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\NVIDIA Corporation\Global\System" -Name "VrPreemption" -Value 0 -Type DWord
    
    # 20. Input Queue Size (For High Polling Rate Mice 1000Hz+)
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" -Name "MouseDataQueueSize" -Value 100 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" -Name "KeyboardDataQueueSize" -Value 100 -Type DWord
    
    # 21. Disable Teredo/ISATAP (Tunneling Protocols - reduce network overhead)
    netsh interface teredo set state disabled | Out-Null
    netsh interface isatap set state disabled | Out-Null
    
    # 22. Force Disable Transparency (Extreme Performance)
    Set-RegistryValueSafe -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 0 -Type DWord
    
    # [REMOVED] 23. DMA Remapping / Core Isolation Disables (User Requested Safety)
    # Keeping Memory Integrity intact.

    # 24. MMCSS Optimization (Gaming Profile)
    # Forces Windows to prioritize game threads over background multimedia
    $mmcssGames = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
    Set-RegistryValueSafe -Path $mmcssGames -Name "Affinity" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path $mmcssGames -Name "Background Only" -Value "False" -Type String
    Set-RegistryValueSafe -Path $mmcssGames -Name "Clock Rate" -Value 10000 -Type DWord
    Set-RegistryValueSafe -Path $mmcssGames -Name "GPU Priority" -Value 8 -Type DWord
    Set-RegistryValueSafe -Path $mmcssGames -Name "Priority" -Value 6 -Type DWord
    Set-RegistryValueSafe -Path $mmcssGames -Name "Scheduling Category" -Value "High" -Type String
    Set-RegistryValueSafe -Path $mmcssGames -Name "SFIO Priority" -Value "High" -Type String

    # 25. Disable USB Selective Suspend (Global)
    # Prevents USB devices (mouse/keyboard/headset) from disconnecting or lagging
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Services\USB" -Name "DisableSelectiveSuspend" -Value 1 -Type DWord
    
    # --- Service Disables (Expanded) ---
    $servicesToDisable = @(
        "XblAuthManager", "XblGameSave", "XboxNetApiSvc", "XboxGipSvc", # Xbox Services
        "DiagTrack", "dmwappushservice", "MapsBroker", "PcaSvc", "TrkWks", "WSearch", "WerSvc",
        "SysMain", # Superfetch
        "Spooler", # Print Spooler (Optional: Warning - disables printing)
        "WbioSrvc", # Biometric
        "TouchKeyboardAndHandwritingPanelService", # TabletInputService
        "RemoteRegistry",
        "TermService", # Remote Desktop
        "SensorService",
        "SensorDataService",
        "Fax",
        "RetailDemo",
        "WalletService"
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
    Disable-ScheduledTask -TaskPath "\Microsoft\Windows\Feedback\Siuf\" -TaskName "*" -ErrorAction SilentlyContinue
    Disable-ScheduledTask -TaskPath "\Microsoft\Windows\Location\" -TaskName "*" -ErrorAction SilentlyContinue
}

Export-ModuleMember -Function Invoke-PerformanceBatch
