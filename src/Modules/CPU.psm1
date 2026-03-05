function Invoke-CpuOptimization {
    [CmdletBinding()]
    param()
    
    Write-Log -Message "Starting CPU Optimization..." -Level INFO -Component "CPU"
    
    # BCD Tweaks
    try {
        bcdedit /set disabledynamictick yes | Out-Null
        bcdedit /set useplatformclock no | Out-Null
        bcdedit /set tscsyncpolicy Enhanced | Out-Null
    } catch {
        Write-Log -Message "BCD Edit failed: $_" -Level WARN -Component "CPU"
    }

    # Power Plan
    $ultimateGuid = '932d88d2-5a9e-4e48-9333-68d73f1f31f9'
    powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 $ultimateGuid | Out-Null
    powercfg /setactive $ultimateGuid | Out-Null
    
    # Vendor Specific
    $cpu = Get-CimInstance Win32_Processor
    if ($cpu.Manufacturer -match 'AMD') {
        Write-Log -Message "Applying AMD Ryzen Optimizations" -Level INFO -Component "CPU"
        # ... (AMD Logic)
    } elseif ($cpu.Manufacturer -match 'Intel') {
        Write-Log -Message "Applying Intel Core Optimizations" -Level INFO -Component "CPU"
        # Disable TSX
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Kernel' -Name 'DisableTsx' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    }
}

Export-ModuleMember -Function Invoke-CpuOptimization
