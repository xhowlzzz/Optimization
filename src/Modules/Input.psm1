function Invoke-InputOptimization {
    [CmdletBinding()]
    param()
    
    Write-Log -Message "Starting Input Optimization..." -Level INFO -Component "Input"
    
    # Mouse/Keyboard Data Queue
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\mouclass\Parameters' -Name 'MouseDataQueueSize' -Value 20 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters' -Name 'KeyboardDataQueueSize' -Value 20 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    
    # USB Power Management
    $usbRoot = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\USB'
    Get-ChildItem -Path $usbRoot -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Device Parameters' } | ForEach-Object {
        $path = "HKLM:$($_.Name.Substring($_.Name.IndexOf('\SYSTEM')))"
        Set-ItemProperty -Path $path -Name 'SelectiveSuspendEnabled' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $path -Name 'DeviceSelectiveSuspended' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    }
}

Export-ModuleMember -Function Invoke-InputOptimization
