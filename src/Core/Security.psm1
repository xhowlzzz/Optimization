function Test-IsAdministrator {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal       = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

function Ensure-RunningAsAdministrator {
    if (-not (Test-IsAdministrator)) {
        Write-Warning "Elevation required. Relaunching..."
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 'powershell.exe'
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        $psi.Verb = 'runas'
        [Diagnostics.Process]::Start($psi) | Out-Null
        exit
    }
}

function New-SystemRestorePoint {
    [CmdletBinding()]
    param(
        [string]$Description = "Win11-EsportsTweaks Snapshot"
    )
    
    # Check if System Restore is enabled on C:
    try {
        Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description $Description -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        return $true
    } catch {
        Write-Warning "Failed to create restore point: $_"
        return $false
    }
}

Export-ModuleMember -Function Test-IsAdministrator, Ensure-RunningAsAdministrator, New-SystemRestorePoint
