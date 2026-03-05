function Update-Win11Tweaks {
    [CmdletBinding()]
    param(
        [string]$CurrentVersion = "2.0.8"
    )
    
    Write-Log -Message "Checking for updates..." -Level INFO -Component "Updater"
    
    $repo = "xhowlzzz/Optimization"
    $releasesUrl = "https://api.github.com/repos/$repo/releases/latest"
    $tagsUrl = "https://api.github.com/repos/$repo/tags"
    
    try {
        # 1. Try to get the latest release
        try {
            $release = Invoke-RestMethod -Uri $releasesUrl -ErrorAction Stop
            $latestVersion = $release.tag_name -replace 'v',''
            $downloadUrl = $release.zipball_url
        } catch {
            # 404 means no releases found. Fallback to checking tags.
            Write-Log -Message "No official releases found. Checking tags..." -Level DEBUG -Component "Updater"
            $tags = Invoke-RestMethod -Uri $tagsUrl -ErrorAction Stop
            if ($tags.Count -gt 0) {
                $release = $tags | Select-Object -First 1
                $latestVersion = $release.name -replace 'v',''
                $downloadUrl = $release.zipball_url
                
                # Sanitize version string (ensure it's X.Y.Z)
                if ($latestVersion -match "^(\d+\.\d+\.\d+)") {
                    $latestVersion = $matches[1]
                }
            } else {
                # No tags either, assume main branch is latest but versioning is unknown
                Write-Log -Message "No version tags found. Skipping update check." -Level INFO -Component "Updater"
                return
            }
        }

        # 2. Compare Versions
        # Simple version comparison
        if ([Version]$latestVersion -gt [Version]$CurrentVersion) {
            Write-Log -Message "Update found: v$latestVersion" -Level INFO -Component "Updater"
            
            # Download Logic (Source Code Zip)
            $zipPath = "$env:TEMP\IlumnulOS_Update.zip"
            $extractPath = "$env:TEMP\IlumnulOS_Update_Extract"
            
            if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }
            
            Write-Log -Message "Downloading update..." -Level INFO -Component "Updater"
            Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath
            
            Write-Log -Message "Installing update..." -Level INFO -Component "Updater"
            Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
            
            # Locate the inner root folder
            $innerFolder = Get-ChildItem -Path $extractPath -Directory | Select-Object -First 1
            if ($innerFolder) {
                # In a real scenario, we can't overwrite running files easily.
                # We would typically schedule a script to run on exit or next boot.
                # For this session, we'll notify the user.
                Write-Log -Message "New version downloaded to: $($innerFolder.FullName)" -Level SUCCESS -Component "Updater"
                Write-Log -Message "Please manually replace files or restart to apply." -Level WARN -Component "Updater"
            }
        } else {
            Write-Log -Message "You are on the latest version (v$CurrentVersion)." -Level INFO -Component "Updater"
        }
        
    } catch {
        # Suppress verbose 404 errors if it's just "not found"
        if ($_.Exception.Message -like "*404*") {
             Write-Log -Message "Update server unreachable or repo is private." -Level WARN -Component "Updater"
        } else {
             Write-Log -Message "Update check failed: $($_.Exception.Message)" -Level WARN -Component "Updater"
        }
    }
}

Export-ModuleMember -Function Update-Win11Tweaks
