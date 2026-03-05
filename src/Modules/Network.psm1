function Invoke-NetworkOptimization {
    [CmdletBinding()]
    param()
    
    Write-Log -Message "Starting Network Optimization..." -Level INFO -Component "Network"

    # TCP/IP Stack
    $tcpParams = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters'
    Set-RegistryValueSafe -Path $tcpParams -Name 'TcpAckFrequency' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path $tcpParams -Name 'TcpNoDelay' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path $tcpParams -Name 'TcpDelAckTicks' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path $tcpParams -Name 'DefaultTTL' -Value 64 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    
    # Netsh Global
    try {
        netsh int tcp set global autotuninglevel=disabled | Out-Null
        netsh int tcp set global rss=enabled | Out-Null
        netsh int tcp set global rsc=disabled | Out-Null
    } catch {
        Write-Log -Message "Netsh failed: $_" -Level WARN -Component "Network"
    }

    # Adapter Properties (Advanced)
    $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' -and $_.HardwareInterface -eq $true }
    foreach ($nic in $adapters) {
        Write-Log -Message "Optimizing Adapter: $($nic.Name)" -Level INFO -Component "Network"
        Disable-NetAdapterRsc -Name $nic.Name -ErrorAction SilentlyContinue | Out-Null
        Enable-NetAdapterRss -Name $nic.Name -ErrorAction SilentlyContinue | Out-Null
        
        $props = @(
            "Interrupt Moderation", "Flow Control", "Energy Efficient Ethernet", "Green Ethernet"
        )
        foreach ($p in $props) {
            Set-NetAdapterAdvancedProperty -Name $nic.Name -DisplayName $p -DisplayValue "Disabled" -NoRestart -ErrorAction SilentlyContinue | Out-Null
        }
    }
}

Export-ModuleMember -Function Invoke-NetworkOptimization
