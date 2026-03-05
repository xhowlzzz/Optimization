function Invoke-InputOptimization {
    [CmdletBinding()]
    param()
    
    Write-Log -Message "Starting Input Optimization..." -Level INFO -Component "Input"
    
    # Mouse/Keyboard Data Queue
    Set-RegistryValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters' -Name 'MouseDataQueueSize' -Value 20 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters' -Name 'KeyboardDataQueueSize' -Value 20 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    
    # USB Power Management (Optimized with Timeout & Job)
    Write-Log -Message "Optimizing USB Power Settings (Background Job)..." -Level INFO -Component "Input"
    
    # Run heavy registry operations in a background job to prevent UI freeze
    $job = Start-Job -ScriptBlock {
        $usbRoot = 'HKLM:\SYSTEM\CurrentControlSet\Enum\USB'
        if (Test-Path -Path $usbRoot) {
            # Use PowerShell drive directly and filter early
            Get-ChildItem -Path $usbRoot -ErrorAction SilentlyContinue | ForEach-Object {
                Get-ChildItem -Path $_.PSPath -ErrorAction SilentlyContinue | ForEach-Object {
                    $deviceParamsPath = Join-Path $_.PSPath "Device Parameters"
                    if (Test-Path -Path $deviceParamsPath) {
                        try {
                            Set-ItemProperty -Path $deviceParamsPath -Name 'SelectiveSuspendEnabled' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                            Set-ItemProperty -Path $deviceParamsPath -Name 'DeviceSelectiveSuspended' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                            Set-ItemProperty -Path $deviceParamsPath -Name 'EnhancedPowerManagementEnabled' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                            Set-ItemProperty -Path $deviceParamsPath -Name 'AllowIdleIrpInD3' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                        } catch {}
                    }
                }
            }
        }
        return "Done"
    }

    # Wait for the job with a strict timeout (e.g., 5 seconds max)
    # If it takes longer, we assume it's stuck on a bad driver/key and move on
    if (Wait-Job -Job $job -Timeout 5) {
        Receive-Job -Job $job | Out-Null
        Write-Log -Message "USB Power Optimization Complete." -Level SUCCESS -Component "Input"
    } else {
        Stop-Job -Job $job
        Write-Log -Message "USB Optimization timed out (skipped to prevent freeze)." -Level WARN -Component "Input"
    }
    Remove-Job -Job $job -Force
}

Export-ModuleMember -Function Invoke-InputOptimization
