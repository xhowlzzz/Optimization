function Set-RegistryValueSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter()][object]$Value,
        [Parameter()][Microsoft.Win32.RegistryValueKind]$Type = [Microsoft.Win32.RegistryValueKind]::String,
        [string]$Description = ''
    )
    
    try {
        # Translate HKEY roots to PSDrive
        $drivePath = $Path -replace '^HKEY_CURRENT_USER', 'HKCU:' -replace '^HKEY_LOCAL_MACHINE', 'HKLM:'
        
        # Check if parent path exists, try to create if not (Catch access denied here too)
        if (-not (Test-Path -Path $drivePath -ErrorAction SilentlyContinue)) {
            try {
                New-Item -Path $drivePath -Force -ErrorAction Stop | Out-Null
            } catch {
                Write-Log -Message "Skipped '$Path' (Access Denied/Create Failed). $_" -Level WARN -Component "Registry"
                return
            }
        }
        
        # Check if value exists and matches to avoid redundant writes
        # Use ErrorAction SilentlyContinue to handle permissions on read
        $current = Get-ItemProperty -Path $drivePath -Name $Name -ErrorAction SilentlyContinue
        
        if ($current -and $current.$Name -eq $Value) {
            Write-Log -Message "Skipped '$Name' (Already set). $Description" -Level INFO -Component "Registry"
            return
        }

        # Attempt Write
        try {
            New-ItemProperty -Path $drivePath -Name $Name -Value $Value -PropertyType $Type -Force -ErrorAction Stop | Out-Null
            Write-Log -Message "Set '$Name' to '$Value'. $Description" -Level SUCCESS -Component "Registry"
        } catch [System.Security.SecurityException], [System.UnauthorizedAccessException] {
            Write-Log -Message "Access Denied setting '$Name' at '$Path'. (Protected Key)" -Level WARN -Component "Registry"
        } catch {
            Write-Log -Message "Failed to set '$Name' at '$Path': $_" -Level ERROR -Component "Registry"
        }
    } catch {
        # Fallback catch for any path parsing errors
        Write-Log -Message "Registry Error: $_" -Level ERROR -Component "Registry"
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
