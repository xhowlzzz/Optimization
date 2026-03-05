function Set-RegistryValueSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter()][object]$Value,
        [Parameter()][Microsoft.Win32.RegistryValueKind]$Type = [Microsoft.Win32.RegistryValueKind]::String,
        [string]$Description = ''
    )
    
    # Translate HKEY roots to PSDrive
    $drivePath = $Path -replace '^HKEY_CURRENT_USER', 'HKCU:' -replace '^HKEY_LOCAL_MACHINE', 'HKLM:'
    
    try {
        if (-not (Test-Path -Path $drivePath)) {
            New-Item -Path $drivePath -Force | Out-Null
        }
        
        # Check if value exists and matches to avoid redundant writes
        $current = Get-ItemProperty -Path $drivePath -Name $Name -ErrorAction SilentlyContinue
        if ($current -and $current.$Name -eq $Value) {
            Write-Log -Message "Skipped '$Name' (Already set). $Description" -Level INFO -Component "Registry"
            return
        }

        New-ItemProperty -Path $drivePath -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
        Write-Log -Message "Set '$Name' to '$Value'. $Description" -Level SUCCESS -Component "Registry"
    } catch {
        Write-Log -Message "Failed to set '$Name' at '$Path': $_" -Level ERROR -Component "Registry"
    }
}

function Remove-RegistryValueSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name
    )
    $drivePath = $Path -replace '^HKEY_CURRENT_USER', 'HKCU:' -replace '^HKEY_LOCAL_MACHINE', 'HKLM:'
    
    try {
        if (Test-Path $drivePath) {
            Remove-ItemProperty -Path $drivePath -Name $Name -ErrorAction SilentlyContinue
            Write-Log -Message "Removed '$Name' from '$Path'" -Level SUCCESS -Component "Registry"
        }
    } catch {
        Write-Log -Message "Failed to remove '$Name': $_" -Level ERROR -Component "Registry"
    }
}

Export-ModuleMember -Function Set-RegistryValueSafe, Remove-RegistryValueSafe
