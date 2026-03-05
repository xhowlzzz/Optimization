function Invoke-SystemDebloat {
    [CmdletBinding()]
    param()
    
    Write-Log -Message "Starting System Debloat..." -Level INFO -Component "System"
    
    # Services
    $services = @("DiagTrack", "dmwappushservice", "SysMain", "MapsBroker")
    foreach ($svc in $services) {
        if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
            Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
            Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Log -Message "Disabled Service: $svc" -Level SUCCESS -Component "System"
        }
    }
    
    # Scheduled Tasks (Telemetry)
    $tasks = @(
        "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
        "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator"
    )
    foreach ($taskPath in $tasks) {
        Unregister-ScheduledTask -TaskName ($taskPath.Split('\')[-1]) -Confirm:$false -ErrorAction SilentlyContinue
        Write-Log -Message "Removed Task: $taskPath" -Level SUCCESS -Component "System"
    }
    
    # Appx Packages
    $bloatware = @("Microsoft.BingNews", "Microsoft.GetHelp", "Microsoft.People")
    foreach ($app in $bloatware) {
        Get-AppxPackage -Name $app -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue
    }
}

Export-ModuleMember -Function Invoke-SystemDebloat
