function Invoke-InputOptimization {
    [CmdletBinding()]
    param()
    
    Write-Log -Message "Starting Input Optimization..." -Level INFO -Component "Input"
    
    # Mouse/Keyboard Data Queue
    Set-RegistryValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters' -Name 'MouseDataQueueSize' -Value 20 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters' -Name 'KeyboardDataQueueSize' -Value 20 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    
    # USB Power Management (Targeted & Optimized)
    Write-Log -Message "Optimizing USB Power Settings..." -Level INFO -Component "Input"
    
    $usbRoot = 'HKLM:\SYSTEM\CurrentControlSet\Enum\USB'
    
    # Use a faster, non-recursive approach to find only devices with "Device Parameters"
    # This avoids iterating through thousands of old device entries one by one in a slow loop
    if (Test-Path -Path $usbRoot) {
        try {
            # Get all USB devices (Level 1)
            $devices = Get-ChildItem -Path $usbRoot -ErrorAction SilentlyContinue
            
            foreach ($device in $devices) {
                # Get instances (Level 2)
                $instances = Get-ChildItem -Path $device.PSPath -ErrorAction SilentlyContinue
                
                foreach ($instance in $instances) {
                    $deviceParamsPath = Join-Path $instance.PSPath "Device Parameters"
                    
                    # Only attempt to set if the key actually exists
                    if (Test-Path -Path $deviceParamsPath) {
                        # Use direct registry setting for speed, bypass helper for this bulk operation
                        Set-ItemProperty -Path $deviceParamsPath -Name 'SelectiveSuspendEnabled' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                        Set-ItemProperty -Path $deviceParamsPath -Name 'DeviceSelectiveSuspended' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                        Set-ItemProperty -Path $deviceParamsPath -Name 'EnhancedPowerManagementEnabled' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                        Set-ItemProperty -Path $deviceParamsPath -Name 'AllowIdleIrpInD3' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                    }
                }
            }
            Write-Log -Message "USB Power Optimization Complete." -Level SUCCESS -Component "Input"
        } catch {
            Write-Log -Message "Error during USB optimization: $_" -Level WARN -Component "Input"
        }
    }
}

Export-ModuleMember -Function Invoke-InputOptimization
