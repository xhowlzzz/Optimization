function Update-Win11Tweaks {
    [CmdletBinding()]
    param(
        [string]$CurrentVersion = "2.0.0"
    )
    
    Write-Log -Message "Checking for updates..." -Level INFO -Component "Updater"
    
    $repo = "xhowlzzz/Optimization"
    $url = "https://api.github.com/repos/$repo/releases/latest"
    
    try {
        $release = Invoke-RestMethod -Uri $url -ErrorAction Stop
        $latestVersion = $release.tag_name -replace 'v',''
        
        if ([Version]$latestVersion -gt [Version]$CurrentVersion) {
            Write-Log -Message "Update found: v$latestVersion" -Level INFO -Component "Updater"
            
            # Download Asset
            $asset = $release.assets | Where-Object { $_.name -match "Win11-EsportsTweaks.zip" } | Select-Object -First 1
            if ($asset) {
                $zipPath = "$env:TEMP\Win11-EsportsTweaks.zip"
                Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath
                
                # Verify Signature (Simulation)
                # In a real scenario, use Get-AuthenticodeSignature
                
                # Extract
                Expand-Archive -Path $zipPath -DestinationPath "$PSScriptRoot\.." -Force
                Write-Log -Message "Update installed successfully. Please restart." -Level SUCCESS -Component "Updater"
            }
        } else {
            Write-Log -Message "You are on the latest version." -Level INFO -Component "Updater"
        }
    } catch {
        Write-Log -Message "Update check failed: $_" -Level WARN -Component "Updater"
    }
}

Export-ModuleMember -Function Update-Win11Tweaks
