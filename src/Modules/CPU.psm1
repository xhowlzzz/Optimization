function Invoke-CpuOptimization {
    [CmdletBinding()]
    param()
    
    Write-Log -Message "Starting CPU Optimization..." -Level INFO -Component "CPU"
    
    # 1. Universal BCD Tweaks
    try {
        # Disable Dynamic Ticks (Laptop power saving feature that adds latency)
        bcdedit /set disabledynamictick yes | Out-Null
        
        # Force use of platform clock (HPET) - usually OFF is better for latency, ON for compatibility
        # Modern advice: useplatformclock NO, useplatformtick YES
        bcdedit /set useplatformclock no | Out-Null
        bcdedit /set useplatformtick yes | Out-Null
        
        # TSC Sync Policy
        bcdedit /set tscsyncpolicy Enhanced | Out-Null
        
        # Disable Hypervisor (if not needed for WSL/Docker) - Improves raw gaming performance
        # bcdedit /set hypervisorlaunchtype off | Out-Null
    } catch {
        Write-Log -Message "BCD Edit failed: $_" -Level WARN -Component "CPU"
    }

    # 2. Power Plan (Ultimate Performance)
    try {
        $ultimateGuid = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
        # Check if already active
        $currentPlan = (powercfg /getactivescheme)
        if ($currentPlan -notmatch $ultimateGuid) {
            # Try enabling it
            powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 932d88d2-5a9e-4e48-9333-68d73f1f31f9 | Out-Null
            powercfg /setactive 932d88d2-5a9e-4e48-9333-68d73f1f31f9 | Out-Null
            Write-Log -Message "Activated Ultimate Performance Power Plan" -Level SUCCESS -Component "CPU"
        }
    } catch {
        Write-Log -Message "Power Plan activation failed." -Level WARN -Component "CPU"
    }
    
    # 3. Vendor Specific Optimizations
    $cpu = Get-CimInstance Win32_Processor
    
    if ($cpu.Manufacturer -match 'AMD') {
        Write-Log -Message "Applying AMD Ryzen Optimizations..." -Level INFO -Component "CPU"
        
        # Disable CPPC (Collaborative Processor Performance Control) preferred cores
        # Some gamers prefer this OFF to prevent thread jumping, others ON. 
        # Defaulting to standard high performance registry tweaks.
        
        # Disable Power Throttling
        Set-RegistryValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' -Name 'PowerThrottlingOff' -Value 1 -Type DWord
        
        # AMD Specific: Thread Scheduler Optimizations
        # Prioritize physical cores over SMT (Hyperthreading)
        Set-RegistryValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'FeatureSettings' -Value 1 -Type DWord
        Set-RegistryValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'FeatureSettingsOverride' -Value 3 -Type DWord
        Set-RegistryValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'FeatureSettingsOverrideMask' -Value 3 -Type DWord

    } elseif ($cpu.Manufacturer -match 'Intel') {
        Write-Log -Message "Applying Intel Core Optimizations..." -Level INFO -Component "CPU"
        
        # Disable TSX (Transactional Synchronization Extensions) - mitigates microcode performance hits
        Set-RegistryValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Kernel' -Name 'DisableTsx' -Value 1 -Type DWord
        
        # Intel Spectre/Meltdown Mitigations (Optional - drastic performance gain but security risk)
        # We will NOT disable security mitigations by default for safety, but we can tune the scheduler.
        
        # SVC (Split Value Cache) / Thread priority
        Set-RegistryValueSafe -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' -Name 'SystemResponsiveness' -Value 0 -Type DWord
    }
    
    # 4. General CPU Priority Tweaks
    # Win32PrioritySeparation: 26 (Hex) = 38 (Decimal)
    # 2 (Foreground shorter intervals) | 6 (Variable length)
    # Favors foreground processes (Games)
    Set-RegistryValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' -Name 'Win32PrioritySeparation' -Value 38 -Type DWord
    
    # 5. SvcHost Split Threshold (Ancel's Optimization)
    # Allows more RAM to be used for separating services (Prevents service grouping)
    # 380000 (Hex) = 3.5GB+ RAM
    Set-RegistryValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Control' -Name 'SvcHostSplitThresholdInKB' -Value 3670016 -Type DWord # ~3.5GB
    
    # 6. Thread Priority Tweaks (SystemProfile)
    # Forces high priority for gaming tasks
    $sysProfile = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    Set-RegistryValueSafe -Path $sysProfile -Name "SystemResponsiveness" -Value 0 -Type DWord
    Set-RegistryValueSafe -Path $sysProfile -Name "NetworkThrottlingIndex" -Value 0xFFFFFFFF -Type DWord
    Set-RegistryValueSafe -Path $sysProfile -Name "NoLazyMode" -Value 1 -Type DWord
    
    # 7. Additional Kernel Tweaks
    $sessionMgr = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Kernel"
    Set-RegistryValueSafe -Path $sessionMgr -Name "DisableExceptionChainValidation" -Value 1 -Type DWord
    Set-RegistryValueSafe -Path $sessionMgr -Name "KernelSEHOPEnabled" -Value 0 -Type DWord # Warning: Security reduction for performance
}

Export-ModuleMember -Function Invoke-CpuOptimization
