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
}

Export-ModuleMember -Function Invoke-GpuOptimization
