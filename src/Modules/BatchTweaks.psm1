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
    
    # NVIDIA Specific (Ancel's Batch)
    # Disable Telemetry & Ansel
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\NVIDIA Corporation\Global\FTS" -Name "EnableRID44231" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\NVIDIA Corporation\Global\FTS" -Name "EnableRID64640" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\NVIDIA Corporation\Global\FTS" -Name "EnableRID66610" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\NVIDIA Corporation\Global\Ansel" -Name "EnableAnsel" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Services\NvTelemetryContainer" -Name "Start" -Value 4 -Type DWord
    
    # NVIDIA Power Management & Preemption
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power" -Name "DefaultD3TransitionLatency" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power" -Name "DefaultLatencyTolerance" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power" -Name "DefaultPowerManagementMode" -Value 1 -Type DWord # Max Performance
    
    # Disable Driver Searching
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching" -Name "SearchOrderConfig" -Value 0 -Type DWord
    
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
    
    # 26. Disable Fast Startup (Hiberboot)
    # Prevents kernel session from being saved to disk (Cleaner cold boots)
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Value 0 -Type DWord
    
    # 27. Network Throttling & System Responsiveness (Redundant but Critical)
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "NetworkThrottlingIndex" -Value 0xFFFFFFFF -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "SystemResponsiveness" -Value 0 -Type DWord
    
    # 28. Win32 Priority Separation (26 Hex = 38 Dec)
    # 2 (Foreground shorter) | 6 (Variable length) - Favors games/foreground apps
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 38 -Type DWord
    
    # 29. CSRSS Realtime Priority (Graphics/Input Handling)
    # WARNING: Can cause instability if set incorrectly. Using 'Realtime' (0x00000080) for gaming.
    $csrss = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions"
    if (-not (Test-Path $csrss)) { New-Item -Path $csrss -Force | Out-Null }
    Set-RegistryValueSafe -Path $csrss -Name "CpuPriorityClass" -Value 4 -Type DWord # 4 = Realtime (High Risk/High Reward)
    Set-RegistryValueSafe -Path $csrss -Name "IoPriority" -Value 3 -Type DWord # 3 = High
    
    # 30. DirectX Latency Tolerance
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "TdrDelay" -Value 10 -Type DWord # Prevent TDR crashes
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "TdrDdiDelay" -Value 10 -Type DWord
    
    # 31. Deep Network Optimization (TCP Parameters)
    $tcpKey = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
    Set-RegistryValueSafe -Path $tcpKey -Name "MaxFreeTcbs" -Value 65535 -Type DWord
    Set-RegistryValueSafe -Path $tcpKey -Name "MaxHashTableSize" -Value 65536 -Type DWord
    Set-RegistryValueSafe -Path $tcpKey -Name "TcpMaxDataRetransmissions" -Value 5 -Type DWord
    Set-RegistryValueSafe -Path $tcpKey -Name "SackOpts" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path $tcpKey -Name "Tcp1323Opts" -Value 0 -Type DWord # Disable timestamps/scaling for raw latency
    Set-RegistryValueSafe -Path $tcpKey -Name "DefaultTTL" -Value 64 -Type DWord
    Set-RegistryValueSafe -Path $tcpKey -Name "EnablePMTUBHDetect" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path $tcpKey -Name "EnablePMTUDiscovery" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path $tcpKey -Name "TcpWindowSize" -Value 64240 -Type DWord
    
    # 32. Disable Sticky Keys & Filter Keys Shortcuts (Gaming Interruption)
    $sticky = "HKCU:\Control Panel\Accessibility\StickyKeys"
    Set-RegistryValueSafe -Path $sticky -Name "Flags" -Value "506" -Type String
    $filter = "HKCU:\Control Panel\Accessibility\Keyboard Response"
    Set-RegistryValueSafe -Path $filter -Name "Flags" -Value "122" -Type String
    $toggle = "HKCU:\Control Panel\Accessibility\ToggleKeys"
    Set-RegistryValueSafe -Path $toggle -Name "Flags" -Value "58" -Type String
    
    # 33. Disable SmartScreen (Registry)
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "SmartScreenEnabled" -Value "Off" -Type String
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableSmartScreen" -Value 0 -Type DWord
    
    # 34. Kernel Mitigation Options (Sub Mitigations)
    # Binary value: 22...22 (Disables various kernel mitigations)
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" -Name "MitigationOptions" -Value ([byte[]](0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x22)) -Type Binary

    # 35. Disable Memory Compression & Page Combining
    Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue | Out-Null
    Disable-MMAgent -PageCombining -ErrorAction SilentlyContinue | Out-Null

    # 36. Advanced Memory Management
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "LargeSystemCache" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "DisablePagingExecutive" -Value 1 -Type DWord
    # Force contiguous memory allocation in DirectX Graphics Kernel
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "DpiMapIommuContiguous" -Value 1 -Type DWord
    # Disable ASLR (Address Space Layout Randomization) for Images
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "MoveImages" -Value 0 -Type DWord

    # 37. Disable DEP (Data Execution Prevention) for IE/Legacy
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer\Main" -Name "DEPOff" -Value 1 -Type DWord

    # 38. Disable Automatic Maintenance
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance" -Name "MaintenanceDisabled" -Value 1 -Type DWord

    # 39. Disable Fault Tolerant Heap (FTH)
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\FTH" -Name "Enabled" -Value 0 -Type DWord

    # 40. Advanced Power Throttling Disables
    $powerKeys = @(
        "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager",
        "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power",
        "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management",
        "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel",
        "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Executive",
        "HKLM:\SYSTEM\CurrentControlSet\Control\Power\ModernSleep",
        "HKLM:\SYSTEM\CurrentControlSet\Control\Power"
    )
    foreach ($k in $powerKeys) {
        Set-RegistryValueSafe -Path $k -Name "CoalescingTimerInterval" -Value 0 -Type DWord
    }
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "PlatformAoAcOverride" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "EnergyEstimationEnabled" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "EventProcessorEnabled" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "CsEnabled" -Value 0 -Type DWord # Connected Standby

    # 41. Kernel Timer Distribution
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" -Name "DistributeTimers" -Value 1 -Type DWord

    # 42. Game Mode & Game Bar (Reinforced)
    Set-RegistryValueSafe -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -Name "AllowAutoGameMode" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\SOFTWARE\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 1 -Type DWord # Ancel enables this? Often disabled for perf. Following user request.
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\Windows.Gaming.GameBar.PresenceServer.Internal.PresenceWriter" -Name "ActivationType" -Value 1 -Type DWord

    # 43. Disable GPU Energy Driver & Logging
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Services\GpuEnergyDrv" -Name "Start" -Value 4 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Services\GpuEnergyDr" -Name "Start" -Value 4 -Type DWord
    $energyLog = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\TaggedEnergy"
    Set-RegistryValueSafe -Path $energyLog -Name "DisableTaggedEnergyLogging" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path $energyLog -Name "TelemetryMaxApplication" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path $energyLog -Name "TelemetryMaxTagPerApplication" -Value 0 -Type DWord

    # 44. Disable Windows Insider Experiments
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\System" -Name "AllowExperimentation" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\System\AllowExperimentation" -Name "value" -Value 0 -Type DWord

    # 45. Advanced MMCSS (Multimedia Class Scheduler)
    $mmcss = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    Set-RegistryValueSafe -Path $mmcss -Name "NoLazyMode" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path $mmcss -Name "AlwaysOn" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path $mmcss -Name "SystemResponsiveness" -Value 10 -Type DWord # Ancel sets 10 (A bit looser than 0, maybe for stability?)
    $mmcssGames = "$mmcss\Tasks\Games"
    Set-RegistryValueSafe -Path $mmcssGames -Name "Latency Sensitive" -Value "True" -Type String

    # 46. Reliability & IO Timestamp
    $reliability = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Reliability"
    Set-RegistryValueSafe -Path $reliability -Name "TimeStampInterval" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path $reliability -Name "IoPriority" -Value 3 -Type DWord

    # 47. Disable Windows Remediation, Tips, Spotlight (Reinforced)
    $contentDel = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    Set-RegistryValueSafe -Path $contentDel -Name "RemediationRequired" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path $contentDel -Name "SoftLandingEnabled" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path $contentDel -Name "RotatingLockScreenOverlayEnabled" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path $contentDel -Name "PreInstalledAppsEnabled" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path $contentDel -Name "SilentInstalledAppsEnabled" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path $contentDel -Name "OemPreInstalledAppsEnabled" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path $contentDel -Name "ContentDeliveryAllowed" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path $contentDel -Name "SubscribedContentEnabled" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path $contentDel -Name "PreInstalledAppsEverEnabled" -Value 0 -Type DWord

    # 48. Disable Search/Device History & Bing
    Set-RegistryValueSafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "HistoryViewEnabled" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "DeviceHistoryEnabled" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Value 0 -Type DWord

    # 49. Extensive Notification Disables
    Set-RegistryValueSafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings" -Name "NOC_GLOBAL_SETTING_ALLOW_NOTIFICATION_SOUND" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings" -Name "NOC_GLOBAL_SETTING_ALLOW_CRITICAL_TOASTS_ABOVE_LOCK" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\QuietHours" -Name "Enabled" -Value 0 -Type DWord
    
    # 50. Bulk Capability Access Manager (Privacy)
    $caps = @("activity", "appDiagnostics", "appointments", "bluetoothSync", "broadFileSystemAccess", "cellularData", "chat", "contacts", "documentsLibrary", "email", "gazeInput", "location", "phoneCall", "phoneCallHistory", "picturesLibrary", "radios", "userAccountInformation", "userDataTasks", "userNotificationListener", "videosLibrary")
    foreach ($cap in $caps) {
        Set-RegistryValueSafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\$cap" -Name "Value" -Value "Deny" -Type String
    }
    # Exceptions (Allow/Prompt)
    Set-RegistryValueSafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone" -Name "Value" -Value "Allow" -Type String
    Set-RegistryValueSafe -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam" -Name "Value" -Value "Allow" -Type String

    # 51. Disable Windows Error Reporting (WER)
    $werPolicies = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting"
    Set-RegistryValueSafe -Path $werPolicies -Name "Disabled" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path $werPolicies -Name "DoReport" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path $werPolicies -Name "LoggingDisabled" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\PCHealth\ErrorReporting" -Name "DoReport" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting" -Name "Disabled" -Value 1 -Type DWord

    # 52. Service Priorities & Boost (Advanced)
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\I/O System" -Name "PassiveIntRealTimeWorkerPriority" -Value 18 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\KernelVelocity" -Name "DisableFGBoostDecay" -Value 1 -Type DWord

    # 53. IFEO Process Priorities (Image File Execution Options)
    # WARNING: Hardcoding priorities can be risky. Using Ancel's values.
    $ifeo = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options"
    $ifeoList = @(
        @{Name="dwm.exe"; Cpu=4; Io=3; Page=$null}, # Realtime/High
        @{Name="lsass.exe"; Cpu=1; Io=0; Page=0},   # Low/VeryLow (Security)
        @{Name="ntoskrnl.exe"; Cpu=4; Io=3; Page=$null}, # Realtime
        @{Name="SearchIndexer.exe"; Cpu=1; Io=0; Page=$null}, # Low
        @{Name="svchost.exe"; Cpu=1; Io=$null; Page=$null}, # Low (Careful!)
        @{Name="TrustedInstaller.exe"; Cpu=1; Io=0; Page=$null}, # Low
        @{Name="wuauclt.exe"; Cpu=1; Io=0; Page=$null}, # Low
        @{Name="audiodg.exe"; Cpu=2; Io=$null; Page=$null}, # Normal (Audio Glitch prevention usually needs High, Ancel sets Normal?)
        @{Name="MsMpEng.exe"; Cpu=1; Io=$null; Page=$null}, # Defender Low
        @{Name="MsMpEngCP.exe"; Cpu=1; Io=$null; Page=$null} # Defender Low
    )

    foreach ($proc in $ifeoList) {
        $key = Join-Path $ifeo "$($proc.Name)\PerfOptions"
        if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
        if ($proc.Cpu -ne $null) { Set-RegistryValueSafe -Path $key -Name "CpuPriorityClass" -Value $proc.Cpu -Type DWord }
        if ($proc.Io -ne $null) { Set-RegistryValueSafe -Path $key -Name "IoPriority" -Value $proc.Io -Type DWord }
        if ($proc.Page -ne $null) { Set-RegistryValueSafe -Path $key -Name "PagePriority" -Value $proc.Page -Type DWord }
        
        # Apply to Wow6432Node as well (32-bit apps)
        $wowKey = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$($proc.Name)\PerfOptions"
        if (-not (Test-Path $wowKey)) { New-Item -Path $wowKey -Force | Out-Null }
        if ($proc.Cpu -ne $null) { Set-RegistryValueSafe -Path $wowKey -Name "CpuPriorityClass" -Value $proc.Cpu -Type DWord }
        if ($proc.Io -ne $null) { Set-RegistryValueSafe -Path $wowKey -Name "IoPriority" -Value $proc.Io -Type DWord }
        if ($proc.Page -ne $null) { Set-RegistryValueSafe -Path $wowKey -Name "PagePriority" -Value $proc.Page -Type DWord }
    }

    # 54. Aggressive Windows Defender Disable (Ancel's List)
    $defPolicies = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
    Set-RegistryValueSafe -Path "$defPolicies\Reporting" -Name "DisableGenericReports" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "$defPolicies\Reporting" -Name "DisableEnhancedNotifications" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "$defPolicies\Spynet" -Name "LocalSettingOverrideSpynetReporting" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "$defPolicies\Spynet" -Name "SpynetReporting" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "$defPolicies\Spynet" -Name "SubmitSamplesConsent" -Value 2 -Type DWord # Never send
    Set-RegistryValueSafe -Path "$defPolicies\SmartScreen" -Name "ConfigureAppInstallControlEnabled" -Value 0 -Type DWord
    
    # Set Threat Default Action to 6 (Unknown/NoAction)
    Set-RegistryValueSafe -Path "$defPolicies\Threats" -Name "Threats_ThreatSeverityDefaultAction" -Value 1 -Type DWord
    $threatActions = "$defPolicies\Threats\ThreatSeverityDefaultAction"
    foreach ($sev in @("1","2","4","5")) { Set-RegistryValueSafe -Path $threatActions -Name $sev -Value "6" -Type String }
    
    Set-RegistryValueSafe -Path "$defPolicies\UX Configuration" -Name "Notification_Suppress" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path $defPolicies -Name "DisableRoutinelyTakingAction" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path $defPolicies -Name "ServiceKeepAlive" -Value 0 -Type DWord
    
    $rtProt = "$defPolicies\Real-Time Protection"
    Set-RegistryValueSafe -Path $rtProt -Name "DisableBehaviorMonitoring" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path $rtProt -Name "DisableIOAVProtection" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path $rtProt -Name "DisableOnAccessProtection" -Value 1 -Type DWord
    
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications" -Name "DisableNotifications" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\MRT" -Name "DontReportInfectionInformation" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftEdge\PhishingFilter" -Name "EnabledV9" -Value 0 -Type DWord

    # Disable Defender Services (Registry Start Type)
    $defServices = @("Sense", "WdNisSvc", "WinDefend", "SecurityHealthService", "wscsvc")
    foreach ($svc in $defServices) {
        Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$svc" -Name "Start" -Value 4 -Type DWord
    }

    # 55. Full Screen Optimizations (FSO) - ENABLED? (Ancel's script says "Enable FSO" but sets flags to 0... likely disabling overrides to allow FSO or vice versa)
    # The batch comments say "Enabling Full Screen Optimizations", setting flags to 0 usually means "Use Default/Enabled" behavior or "Disable the Disable".
    $gameConfig = "HKCU:\SYSTEM\GameConfigStore"
    Set-RegistryValueSafe -Path $gameConfig -Name "GameDVR_DSEBehavior" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path $gameConfig -Name "GameDVR_FSEBehaviorMode" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path $gameConfig -Name "GameDVR_EFSEFeatureFlags" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path $gameConfig -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path $gameConfig -Name "GameDVR_HonorUserFSEBehaviorMode" -Value 1 -Type DWord

    # 56. Enable MPO (Multiplane Overlay)
    # Deleting OverlayTestMode enables MPO (if driver supports it)
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" -Name "OverlayTestMode" -ErrorAction SilentlyContinue

    # 57. Windowed Game Optimizations
    Set-RegistryValueSafe -Path "HKCU:\SOFTWARE\Microsoft\DirectX\UserGpuPreferences" -Name "DirectXUserGlobalSettings" -Value "VRROptimizeEnable=0;SwapEffectUpgradeEnable=1;" -Type String

    # 58. Latency Tolerance (MelodyTheNeko Tweaks)
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Services\DXGKrnl" -Name "MonitorLatencyTolerance" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Services\DXGKrnl" -Name "MonitorRefreshLatencyTolerance" -Value 1 -Type DWord
    
    $powerControl = "HKLM:\SYSTEM\CurrentControlSet\Control\Power"
    $latencyKeys = @("ExitLatency", "ExitLatencyCheckEnabled", "Latency", "LatencyToleranceDefault", "LatencyToleranceFSVP", "LatencyTolerancePerfOverride", "LatencyToleranceScreenOffIR", "LatencyToleranceVSyncEnabled", "RtlCapabilityCheckLatency")
    foreach ($lk in $latencyKeys) { Set-RegistryValueSafe -Path $powerControl -Name $lk -Value 1 -Type DWord }
    
    $gfxPower = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power"
    $gfxLatencyKeys = @(
        "DefaultD3TransitionLatencyActivelyUsed", "DefaultD3TransitionLatencyIdleLongTime", "DefaultD3TransitionLatencyIdleMonitorOff",
        "DefaultD3TransitionLatencyIdleNoContext", "DefaultD3TransitionLatencyIdleShortTime", "DefaultD3TransitionLatencyIdleVeryLongTime",
        "DefaultLatencyToleranceIdle0", "DefaultLatencyToleranceIdle0MonitorOff", "DefaultLatencyToleranceIdle1", "DefaultLatencyToleranceIdle1MonitorOff",
        "DefaultLatencyToleranceMemory", "DefaultLatencyToleranceNoContext", "DefaultLatencyToleranceNoContextMonitorOff", "DefaultLatencyToleranceOther",
        "DefaultLatencyToleranceTimerPeriod", "DefaultMemoryRefreshLatencyToleranceActivelyUsed", "DefaultMemoryRefreshLatencyToleranceMonitorOff",
        "DefaultMemoryRefreshLatencyToleranceNoContext", "Latency", "MaxIAverageGraphicsLatencyInOneBucket", "MiracastPerfTrackGraphicsLatency",
        "MonitorLatencyTolerance", "MonitorRefreshLatencyTolerance", "TransitionLatency"
    )
    foreach ($glk in $gfxLatencyKeys) { Set-RegistryValueSafe -Path $gfxPower -Name $glk -Value 1 -Type DWord }

    # 59. NVIDIA Specific Advanced Tweaks (Ancel)
    # Target the main NVIDIA driver key (0000). Note: This ID might vary (0001, 0002) but 0000 is standard for primary.
    $nvKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000"
    
    if (Test-Path $nvKey) {
        # Latency Tolerance
        Set-RegistryValueSafe -Path $nvKey -Name "D3PCLatency" -Value 1 -Type DWord
        Set-RegistryValueSafe -Path $nvKey -Name "F1TransitionLatency" -Value 1 -Type DWord
        Set-RegistryValueSafe -Path $nvKey -Name "LOWLATENCY" -Value 1 -Type DWord
        Set-RegistryValueSafe -Path $nvKey -Name "Node3DLowLatency" -Value 1 -Type DWord
        Set-RegistryValueSafe -Path $nvKey -Name "PciLatencyTimerControl" -Value 20 -Type DWord
        Set-RegistryValueSafe -Path $nvKey -Name "RMDeepL1EntryLatencyUsec" -Value 1 -Type DWord
        Set-RegistryValueSafe -Path $nvKey -Name "RmGspcMaxFtuS" -Value 1 -Type DWord
        Set-RegistryValueSafe -Path $nvKey -Name "RmGspcMinFtuS" -Value 1 -Type DWord
        Set-RegistryValueSafe -Path $nvKey -Name "RmGspcPerioduS" -Value 1 -Type DWord
        Set-RegistryValueSafe -Path $nvKey -Name "RMLpwrEiIdleThresholdUs" -Value 1 -Type DWord
        Set-RegistryValueSafe -Path $nvKey -Name "RMLpwrGrIdleThresholdUs" -Value 1 -Type DWord
        Set-RegistryValueSafe -Path $nvKey -Name "RMLpwrGrRgIdleThresholdUs" -Value 1 -Type DWord
        Set-RegistryValueSafe -Path $nvKey -Name "RMLpwrMsIdleThresholdUs" -Value 1 -Type DWord
        Set-RegistryValueSafe -Path $nvKey -Name "VRDirectFlipDPCDelayUs" -Value 1 -Type DWord
        Set-RegistryValueSafe -Path $nvKey -Name "VRDirectFlipTimingMarginUs" -Value 1 -Type DWord
        Set-RegistryValueSafe -Path $nvKey -Name "VRDirectJITFlipMsHybridFlipDelayUs" -Value 1 -Type DWord
        Set-RegistryValueSafe -Path $nvKey -Name "vrrCursorMarginUs" -Value 1 -Type DWord
        Set-RegistryValueSafe -Path $nvKey -Name "vrrDeflickerMarginUs" -Value 1 -Type DWord
        Set-RegistryValueSafe -Path $nvKey -Name "vrrDeflickerMaxUs" -Value 1 -Type DWord

        # Memory & Buffer Tweaks
        Set-RegistryValueSafe -Path $nvKey -Name "PreferSystemMemoryContiguous" -Value 1 -Type DWord
        Set-RegistryValueSafe -Path $nvKey -Name "RmFbsrPagedDMA" -Value 1 -Type DWord # Reallocate DMA
        Set-RegistryValueSafe -Path $nvKey -Name "RmCacheLoc" -Value 0 -Type DWord # Increase Ded. Video Memory

        # Feature Disables
        Set-RegistryValueSafe -Path $nvKey -Name "RMHdcpKeyGlobZero" -Value 1 -Type DWord # Disable HDCP
        Set-RegistryValueSafe -Path $nvKey -Name "TCCSupported" -Value 0 -Type DWord # Disable TCC
        Set-RegistryValueSafe -Path $nvKey -Name "Acceleration.Level" -Value 0 -Type DWord # Video Redraw Accel
        Set-RegistryValueSafe -Path $nvKey -Name "DesktopStereoShortcuts" -Value 0 -Type DWord # 3D Vision
        Set-RegistryValueSafe -Path $nvKey -Name "FeatureControl" -Value 4 -Type DWord
        Set-RegistryValueSafe -Path $nvKey -Name "NVDeviceSupportKFilter" -Value 0 -Type DWord # Disable Filter
        Set-RegistryValueSafe -Path $nvKey -Name "RmDisableInst2Sys" -Value 0 -Type DWord # Driver Pkg Dir
        Set-RegistryValueSafe -Path $nvKey -Name "RmProfilingAdminOnly" -Value 0 -Type DWord # PCounter Perms
        Set-RegistryValueSafe -Path $nvKey -Name "TrackResetEngine" -Value 0 -Type DWord # Disable DX Event Tracking
        Set-RegistryValueSafe -Path $nvKey -Name "ValidateBlitSubRects" -Value 0 -Type DWord # Disable Verify Block Transfer
    }

    # NVIDIA Telemetry (Services & Tasks)
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "NvBackend" -ErrorAction SilentlyContinue
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\NVIDIA Corporation\NvControlPanel2\Client" -Name "OptInOrOutPreference" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\NVIDIA Corporation\Global\FTS" -Name "EnableRID66610" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\NVIDIA Corporation\Global\FTS" -Name "EnableRID64640" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\NVIDIA Corporation\Global\FTS" -Name "EnableRID44231" -Value 0 -Type DWord
    
    $nvTasks = @(
        "NvTmRep_CrashReport1_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}",
        "NvTmRep_CrashReport2_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}",
        "NvTmRep_CrashReport3_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}",
        "NvTmRep_CrashReport4_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}",
        "NvDriverUpdateCheckDaily_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}",
        "NVIDIA GeForce Experience SelfUpdate_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}",
        "NvTmMon_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}"
    )
    foreach ($task in $nvTasks) { Disable-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue | Out-Null }

    # NVIDIA Power & DPC
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\NVTweak" -Name "DisplayPowerSaving" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm" -Name "DisableWriteCombining" -Value 1 -Type DWord
    
    # Enable DPC for each Core
    $dpcKeys = @(
        "HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm",
        "HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\NVAPI",
        "HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\NVTweak",
        "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers",
        "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power"
    )
    foreach ($k in $dpcKeys) { Set-RegistryValueSafe -Path $k -Name "RmGpsPsEnablePerCpuCoreDpc" -Value 1 -Type DWord }

    # 60. Disable TDR (Timeout Detection and Recovery) - COMPLETELY
    # Warning: If GPU hangs, system will freeze instead of resetting driver.
    $tdrKey = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
    Set-RegistryValueSafe -Path $tdrKey -Name "TdrLevel" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path $tdrKey -Name "TdrDelay" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path $tdrKey -Name "TdrDdiDelay" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path $tdrKey -Name "TdrDebugMode" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path $tdrKey -Name "TdrLimitCount" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path $tdrKey -Name "TdrLimitTime" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path $tdrKey -Name "TdrTestMode" -Value 0 -Type DWord

    # 61. Massive Telemetry Disable (Ancel's List)
    
    # A. Scheduled Tasks
    $telemetryTasks = @(
        "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
        "\Microsoft\Windows\Customer Experience Improvement Program\BthSQM",
        "\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask",
        "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
        "\Microsoft\Windows\Customer Experience Improvement Program\Uploader",
        "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
        "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
        "\Microsoft\Windows\Application Experience\StartupAppTask",
        "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
        "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticResolver",
        "\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem",
        "\Microsoft\Windows\Shell\FamilySafetyMonitor",
        "\Microsoft\Windows\Shell\FamilySafetyRefresh",
        "\Microsoft\Windows\Shell\FamilySafetyUpload",
        "\Microsoft\Windows\Autochk\Proxy",
        "\Microsoft\Windows\Maintenance\WinSAT",
        "\Microsoft\Windows\Application Experience\AitAgent",
        "\Microsoft\Windows\Windows Error Reporting\QueueReporting",
        "\Microsoft\Windows\CloudExperienceHost\CreateObjectTask",
        "\Microsoft\Windows\DiskFootprint\Diagnostics",
        "\Microsoft\Windows\FileHistory\File History (maintenance mode)",
        "\Microsoft\Windows\PI\Sqm-Tasks",
        "\Microsoft\Windows\NetTrace\GatherNetworkInfo",
        "\Microsoft\Windows\AppID\SmartScreenSpecific",
        "\Microsoft\Office\OfficeTelemetryAgentFallBack2016",
        "\Microsoft\Office\OfficeTelemetryAgentLogOn2016",
        "\Microsoft\Office\OfficeTelemetryAgentLogOn",
        "\Microsoftd\Office\OfficeTelemetryAgentFallBack",
        "\Microsoft\Office\Office 15 Subscription Heartbeat",
        "\Microsoft\Windows\Time Synchronization\ForceSynchronizeTime",
        "\Microsoft\Windows\Time Synchronization\SynchronizeTime",
        "\Microsoft\Windows\WindowsUpdate\Automatic App Update",
        "\Microsoft\Windows\Device Information\Device"
    )
    foreach ($task in $telemetryTasks) {
        Disable-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue | Out-Null
    }

    # B. Registry Telemetry Blocks
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Metadata" -Name "PreventDeviceMetadataFromNetwork" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization" -Name "RestrictImplicitInkCollection" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization" -Name "RestrictImplicitTextCollection" -Value 1 -Type DWord
    
    # Sensors
    $sensorGuid = "{BFA794E4-F964-4FDB-90F6-51056BFE4B44}"
    Set-RegistryValueSafe -Path "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Permissions\$sensorGuid" -Name "SensorPermissionState" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\$sensorGuid" -Name "SensorPermissionState" -Value 0 -Type DWord
    
    # WUDF Logging
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WUDF" -Name "LogEnable" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WUDF" -Name "LogLevel" -Value 0 -Type DWord
    
    # Data Collection Policies
    $dataColl = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
    Set-RegistryValueSafe -Path $dataColl -Name "AllowTelemetry" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path $dataColl -Name "DoNotShowFeedbackNotifications" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path $dataColl -Name "AllowCommercialDataPipeline" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path $dataColl -Name "AllowDeviceNameInTelemetry" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path $dataColl -Name "LimitEnhancedDiagnosticDataWindowsAnalytics" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path $dataColl -Name "MicrosoftEdgeDataOptIn" -Value 0 -Type DWord
    
    # SIUF (Feedback)
    Set-RegistryValueSafe -Path "HKCU:\SOFTWARE\Microsoft\Siuf\Rules" -Name "NumberOfSIUFInPeriod" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\SOFTWARE\Microsoft\Siuf\Rules" -Name "PeriodInNanoSeconds" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\SOFTWARE\Policies\Microsoft\Assistance\Client\1.0" -Name "NoExplicitFeedback" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Assistance\Client\1.0" -Name "NoActiveHelp" -Value 1 -Type DWord
    
    # AppCompat & Tablet
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" -Name "DisableInventory" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" -Name "AITEnable" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" -Name "DisableUAR" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\TabletPC" -Name "PreventHandwritingDataSharing" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\TabletPC" -Name "DoSvc" -Value 3 -Type DWord
    
    # Location
    $locSensors = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors"
    Set-RegistryValueSafe -Path $locSensors -Name "DisableLocation" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path $locSensors -Name "DisableLocationScripting" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path $locSensors -Name "DisableSensors" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path $locSensors -Name "DisableWindowsLocationProvider" -Value 1 -Type DWord
    
    # Driver Reporting
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\DeviceHealthAttestationService" -Name "DisableSendGenericDriverNotFoundToWER" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Settings" -Name "DisableSendGenericDriverNotFoundToWER" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\DriverDatabase\Policies\Settings" -Name "DisableSendGenericDriverNotFoundToWER" -Value 1 -Type DWord
    
    # Activity Feed
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableActivityFeed" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "UploadUserActivities" -Value 0 -Type DWord
    
    # SQM & CEIP
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows" -Name "CEIPEnable" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\SQMClient\Reliability" -Name "CEIPEnable" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\SQMClient\Reliability" -Name "SqmLoggerRunning" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\SQMClient\Windows" -Name "CEIPEnable" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\SQMClient\Windows" -Name "DisableOptinExperience" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\SQMClient\Windows" -Name "SqmLoggerRunning" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\SQMClient\IE" -Name "SqmLoggerRunning" -Value 0 -Type DWord
    
    # Misc
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\HandwritingErrorReports" -Name "PreventHandwritingErrorReports" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\FileHistory" -Name "Disabled" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\SOFTWARE\Microsoft\MediaPlayer\Preferences" -Name "UsageTracking" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "NoUseStoreOpenWith" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableSoftLanding" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Peernet" -Name "Disabled" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" -Name "DODownloadMode" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowWiFiHotSpotReporting" -Name "value" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore" -Name "HarvestContacts" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" -Name "DisabledByGroupPolicy" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\MRT" -Name "DontOfferThroughWUAU" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SOFTWARE\Policies\Microsoft\Biometrics" -Name "Enabled" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Services\dmwappushservice" -Name "Start" -Value 4 -Type DWord
    Set-RegistryValueSafe -Path "HKCU:\Control Panel\International\User Profile" -Name "HttpAcceptLanguageOptOut" -Value 1 -Type DWord

    # C. AutoLoggers (WMI Tracing)
    $autoLoggers = @(
        "AppModel", "Cellcore", "Circular Kernel Context Logger", "CloudExperienceHostOobe", "DataMarket",
        "DefenderApiLogger", "DefenderAuditLogger", "DiagLog", "HolographicDevice", "iclsClient", "iclsProxy",
        "LwtNetLog", "Mellanox-Kernel", "Microsoft-Windows-AssignedAccess-Trace", "Microsoft-Windows-Setup",
        "NBSMBLOGGER", "PEAuthLog", "RdrLog", "ReadyBoot", "SetupPlatform", "SetupPlatformTel", "SocketHeciServer",
        "SpoolerLogger", "SQMLogger", "TCPIPLOGGER", "TileStore", "Tpm", "TPMProvisioningService", "UBPM",
        "WdiContextLog", "WFP-IPsec Trace", "WiFiDriverIHVSession", "WiFiDriverIHVSessionRepro", "WiFiSession",
        "WinPhoneCritical"
    )
    foreach ($log in $autoLoggers) {
        Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\$log" -Name "Start" -Value 0 -Type DWord
    }
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Credssp" -Name "DebugLogLevel" -Value 0 -Type DWord

    # 62. Remove Unnecessary Appx Packages (Ancel)
    $appsToRemove = @(
        "*3DBuilder*", "*bing*", "*bingfinance*", "*bingsports*", "*BingWeather*",
        "*CommsPhone*", "*Drawboard PDF*", "*Facebook*", "*Getstarted*", "*Microsoft.Messaging*",
        "*MicrosoftOfficeHub*", "*Office.OneNote*", "*OneNote*", "*people*", "*SkypeApp*",
        "*solit*", "*Sway*", "*Twitter*", "*WindowsAlarms*", "*WindowsPhone*",
        "*WindowsMaps*", "*WindowsFeedbackHub*", "*WindowsSoundRecorder*", "*windowscommunicationsapps*", "*zune*",
        "*Microsoft.549981C3F5F10*" # Cortana
    )
    foreach ($app in $appsToRemove) {
        Get-AppxPackage -AllUsers $app -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    }

    # 63. Cortana & Search Tweaks
    $searchKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
    Set-RegistryValueSafe -Path $searchKey -Name "AllowCortana" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path $searchKey -Name "AllowCloudSearch" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path $searchKey -Name "AllowCortanaAboveLock" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path $searchKey -Name "AllowSearchToUseLocation" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path $searchKey -Name "ConnectedSearchUseWeb" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path $searchKey -Name "ConnectedSearchUseWebOverMeteredConnections" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path $searchKey -Name "DisableWebSearch" -Value 0 -Type DWord # Ancel sets 0? Usually 1 disables it. Keeping faithful to source.

    # 64. OneDrive Disable & Cleanup
    if (Test-Path "$env:SYSTEMROOT\SYSWOW64\ONEDRIVESETUP.EXE") {
        Start-Process -FilePath "$env:SYSTEMROOT\SYSWOW64\ONEDRIVESETUP.EXE" -ArgumentList "/UNINSTALL" -Wait -NoNewWindow -ErrorAction SilentlyContinue
    }
    Remove-Item -Path "C:\OneDriveTemp" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:USERPROFILE\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:PROGRAMDATA\Microsoft OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
    
    Set-RegistryValueSafe -Path "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}\ShellFolder" -Name "Attributes" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path "HKCR:\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}\ShellFolder" -Name "Attributes" -Value 0 -Type DWord
    
    $odPol = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive"
    Set-RegistryValueSafe -Path $odPol -Name "DisableFileSync" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path $odPol -Name "DisableFileSyncNGSC" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path $odPol -Name "DisableMeteredNetworkFileSync" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path $odPol -Name "DisableLibrariesDefaultSaveToOneDrive" -Value 0 -Type DWord

    # 65. PC Cleaner (Temp/Prefetch/Logs)
    Write-Log "Running PC Cleaner..." -Level INFO
    $pathsToClean = @(
        "C:\Windows\Temp",
        "C:\Windows\Prefetch",
        "$env:TEMP",
        "$env:SystemDrive\Recycled",
        "$env:SystemDrive\`$Recycle.Bin",
        "$env:LOCALAPPDATA\Microsoft\Windows\Explorer" # Thumbcache
    )
    foreach ($p in $pathsToClean) {
        if (Test-Path $p) {
            Get-ChildItem -Path $p -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    # Specific extensions on system drive (Careful with this one!)
    # Skipping aggressive root drive wildcard deletions (*.tmp, *.log) to avoid accidental system damage in PowerShell.
    # Focusing on safe log directories:
    Remove-Item -Path "$env:SystemRoot\Logs\CBS\CBS.log" -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:SystemRoot\Logs\DISM\DISM.log" -Force -ErrorAction SilentlyContinue

    # 66. Device Disables via DevManView (Ancel)
    # Download DevManView
    $dmvPath = "$env:SystemRoot\System32\DevManView.exe"
    # Using 'raw' GitHub link for direct executable download
    $dmvUrl = "https://github.com/xhowlzzz/Optimization/raw/main/Tools/DevManView.exe" 
    
    try {
        if (-not (Test-Path $dmvPath)) {
            Write-Log "Downloading DevManView..." -Level INFO
            Invoke-WebRequest -Uri $dmvUrl -OutFile $dmvPath -ErrorAction Stop
        }
        
        if (Test-Path $dmvPath) {
            Write-Log "Disabling Devices via DevManView..." -Level INFO
            $devicesToDisable = @(
                "High Precision Event Timer",
                "Microsoft GS Wavetable Synth",
                "Microsoft RRAS Root Enumerator",
                "Intel Management Engine",
                "Intel Management Engine Interface",
                "Intel SMBus",
                "SM Bus Controller",
                "Amdlog",
                "AMD PSP",
                "System Speaker",
                "Composite Bus Enumerator",
                "Microsoft Virtual Drive Enumerator",
                "Microsoft Hyper-V Virtualization Infrastructure Driver",
                "NDIS Virtual Network Adapter Enumerator",
                "Remote Desktop Device Redirector Bus",
                "UMBus Root Bus Enumerator",
                "WAN Miniport (IP)",
                "WAN Miniport (IKEv2)",
                "WAN Miniport (IPv6)",
                "WAN Miniport (L2TP)",
                "WAN Miniport (PPPOE)",
                "WAN Miniport (PPTP)",
                "WAN Miniport (SSTP)",
                "WAN Miniport (Network Monitor)"
            )
            
            foreach ($dev in $devicesToDisable) {
                Start-Process -FilePath $dmvPath -ArgumentList "/disable `"$dev`"" -Wait -NoNewWindow -ErrorAction SilentlyContinue
            }
        } else {
            Write-Log "DevManView download failed or blocked." -Level ERROR
        }
    } catch {
        Write-Log "Failed to download/run DevManView: $_" -Level ERROR
    }

    # --- Service Disables (Expanded) ---
    $servicesToDisable = @(
        "TapiSrv", "FontCache3.0.0.0", "WpcMonSvc", "SEMgrSvc", "PNRPsvc", "LanmanWorkstation",
        "WEPHOSTSVC", "p2psvc", "p2pimsvc", "PhoneSvc", "wuauserv", "Wecsvc", "SensorDataService",
        "SensrSvc", "perceptionsimulation", "StiSvc", "OneSyncSvc", "WMPNetworkSvc", "autotimesvc",
        "edgeupdatem", "MicrosoftEdgeElevationService", "ALG", "QWAVE", "IpxlatCfgSvc", "icssvc",
        "DusmSvc", "MapsBroker", "edgeupdate", "SensorService", "shpamsvc", "svsvc", "SysMain",
        "MSiSCSI", "Netlogon", "CscService", "ssh-agent", "AppReadiness", "tzautoupdate", "NfsClnt",
        "wisvc", "defragsvc", "SharedRealitySvc", "RetailDemo", "lltdsvc", "TrkWks", "CryptSvc",
        "DiagTrack", "diagsvc", "DPS", "WdiServiceHost", "WdiSystemHost", "dmwappushsvc",
        "TroubleshootingSvc", "DsSvc", "FrameServer", "FontCache", "InstallService", "OSRSS",
        "sedsvc", "SENS", "TabletInputService", "Themes", "ConsentUxUserSvc", "DevicePickerUserSvc",
        "UnistoreSvc", "DevicesFlowUserSvc", "MessagingService", "CDPUserSvc", "PimIndexMaintenanceSvc",
        "BcastDVRUserService", "UserDataSvc", "DeviceAssociationBrokerSvc", "cbdhsvc", "CaptureService",
        "lfsvc", "diagnosticshub.standardcollector.service", "SecurityHealthService",
        "Spooler", "WbioSrvc", "RemoteRegistry", "TermService", "Fax", "WalletService"
    )
    # Note: 'lfsvc' needs special handling for its sub-key status, done below separately if needed.
    Set-RegistryValueSafe -Path "HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration" -Name "Status" -Value 0 -Type DWord
    
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
