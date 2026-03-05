function Invoke-InputOptimization {
    [CmdletBinding()]
    param()
    
    Write-Log -Message "Starting Input Optimization..." -Level INFO -Component "Input"
    
    # Mouse/Keyboard Data Queue
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\mouclass\Parameters' -Name 'MouseDataQueueSize' -Value 20 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters' -Name 'KeyboardDataQueueSize' -Value 20 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    
    # USB Power Management
    $usbRoot = 'HKLM:\SYSTEM\CurrentControlSet\Enum\USB'
    if (Test-Path -Path $usbRoot) {
        Get-ChildItem -Path $usbRoot -ErrorAction SilentlyContinue | ForEach-Object {
            Get-ChildItem -Path $_.PSPath -ErrorAction SilentlyContinue | ForEach-Object {
                $deviceParamsPath = Join-Path $_.PSPath "Device Parameters"
                if (Test-Path -Path $deviceParamsPath) {
                    Set-ItemProperty -Path $deviceParamsPath -Name 'SelectiveSuspendEnabled' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $deviceParamsPath -Name 'DeviceSelectiveSuspended' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
}

Export-ModuleMember -Function Invoke-InputOptimization
