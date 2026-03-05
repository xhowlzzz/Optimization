function Invoke-GpuOptimization {
    [CmdletBinding()]
    param()
    
    Write-Log -Message "Starting GPU Optimization..." -Level INFO -Component "GPU"
    
    # HAGS
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -Name 'HwSchMode' -Value 2 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    
    # Shader Cache (NVIDIA)
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\NVIDIA Corporation\Global\NVTweak' -Name 'ShaderCacheLimit' -Value 0xFFFFFFFF -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    
    # MSI Mode
    $targetClasses = @(
        '{4d36e968-e325-11ce-bfc1-08002be10318}', # Display
        '{4d36e972-e325-11ce-bfc1-08002be10318}'  # Network
    )
    
    $pnpDevices = Get-PnpDevice -Status OK -PresentOnly | Where-Object { $targetClasses -contains $_.ClassGuid }
    foreach ($dev in $pnpDevices) {
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($dev.InstanceId)\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
        if (Test-Path $regPath) {
            Set-ItemProperty -Path $regPath -Name 'MSISupported' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
            Write-Log -Message "Enabled MSI Mode for: $($dev.FriendlyName)" -Level SUCCESS -Component "GPU"
        }
    }

    # ---------------------------------------------------------
    # GAMING OPTIMIZATIONS (FPS Boost)
    # ---------------------------------------------------------
    Write-Log -Message "Applying Gaming & FPS Optimizations..." -Level INFO -Component "GPU"

    # 1. Multimedia Class Scheduler Service (MMCSS) Tuning
    # Prioritizes gaming tasks over background processes
    $sysProfile = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    Set-RegistryValueSafe -Path $sysProfile -Name "SystemResponsiveness" -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path $sysProfile -Name "NetworkThrottlingIndex" -Value 0xFFFFFFFF -Type ([Microsoft.Win32.RegistryValueKind]::DWord)

    # 2. GPU Priority for Games
    $gamesProfile = "$sysProfile\Tasks\Games"
    if (Test-Path $gamesProfile) {
        Set-RegistryValueSafe -Path $gamesProfile -Name "GPU Priority" -Value 8 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
        Set-RegistryValueSafe -Path $gamesProfile -Name "Priority" -Value 6 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
        Set-RegistryValueSafe -Path $gamesProfile -Name "Scheduling Category" -Value "High" -Type ([Microsoft.Win32.RegistryValueKind]::String)
        Set-RegistryValueSafe -Path $gamesProfile -Name "SFIO Priority" -Value "High" -Type ([Microsoft.Win32.RegistryValueKind]::String)
        Write-Log -Message "Set High GPU Priority for Gaming Tasks" -Level SUCCESS -Component "GPU"
    }

    # 3. Disable Game DVR & Game Bar (Reduces Overlay Overhead)
    $gameConfig = "HKCU:\System\GameConfigStore"
    Set-RegistryValueSafe -Path $gameConfig -Name "GameDVR_Enabled" -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path $gameConfig -Name "GameDVR_FSEBehaviorMode" -Value 2 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) # Disable FSO

    $policyDVR = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
    if (-not (Test-Path $policyDVR)) { New-Item -Path $policyDVR -Force | Out-Null }
    Set-RegistryValueSafe -Path $policyDVR -Name "AllowGameDVR" -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    
    Write-Log -Message "Disabled Game DVR & Fullscreen Optimizations" -Level SUCCESS -Component "GPU"

    # 4. Import NVIDIA Profile (if available)
    # We check if nvidiaInspector.exe is available in the Tools folder
    
    $nipPath = Join-Path $PSScriptRoot "..\..\Tools\IlumnulOS.nip"
    $inspectorPath = Join-Path $PSScriptRoot "..\..\Tools\nvidiaInspector.exe"
    
    if (Test-Path $nipPath) {
        if (Test-Path $inspectorPath) {
            Write-Log -Message "Importing NVIDIA Profile..." -Level INFO -Component "GPU"
            try {
                Start-Process -FilePath $inspectorPath -ArgumentList "-silent -import `"$nipPath`"" -Wait -WindowStyle Hidden
                Write-Log -Message "NVIDIA Profile Imported Successfully" -Level SUCCESS -Component "GPU"
            } catch {
                Write-Log -Message "Failed to import NVIDIA Profile" -Level ERROR -Component "GPU"
            }
        } else {
            Write-Log -Message "NVIDIA Profile found ($nipPath) but nvidiaInspector.exe is missing in Tools folder." -Level WARN -Component "GPU"
        }
    }
}

Export-ModuleMember -Function Invoke-GpuOptimization
