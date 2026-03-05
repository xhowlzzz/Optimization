function Invoke-RemoveWindowsAI {
    Write-Log -Message "Starting Windows AI Removal..." -Level INFO -Component "AI-Debloat"

    # 1. Disable Recall & AI Features via Registry
    $aiKeys = @(
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI",
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot",
        "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot"
    )

    foreach ($key in $aiKeys) {
        if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
        Set-ItemProperty -Path $key -Name "TurnOffWindowsCopilot" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $key -Name "DisableAIDataAnalysis" -Value 1 -Type DWord -Force
    }

    # 2. Disable Recall Snapshotting
    $recallKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy"
    if (-not (Test-Path $recallKey)) { New-Item -Path $recallKey -Force | Out-Null }
    Set-ItemProperty -Path $recallKey -Name "RecallEnabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $recallKey -Name "SnapshottingEnabled" -Value 0 -Type DWord -Force

    # 3. Remove AI Appx Packages
    $aiApps = @(
        "Microsoft.Windows.Ai.Copilot.Provider",
        "Microsoft.Copilot",
        "Microsoft.Windows.Recall"
    )
    foreach ($app in $aiApps) {
        Get-AppxPackage -Name "*$app*" -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue
        Write-Log -Message "Removed AI App: $app" -Level SUCCESS -Component "AI-Debloat"
    }

    # 4. Disable AI Services
    $aiServices = @("WindowsAI", "RecallService", "CopilotService")
    foreach ($svc in $aiServices) {
        if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
            Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
            Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Log -Message "Disabled AI Service: $svc" -Level SUCCESS -Component "AI-Debloat"
        }
    }
}

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

Export-ModuleMember -Function Invoke-SystemDebloat, Invoke-RemoveWindowsAI
