function Invoke-EndOptimization {
    Write-Log -Message "Optimization Process Finished." -Level INFO -Component "End"
    
    # 1. Clear DNS Cache
    Write-Log -Message "Flushing DNS Cache..." -Level INFO -Component "End"
    Clear-DnsClientCache -ErrorAction SilentlyContinue
    
    # 2. Clear Temp Files
    Write-Log -Message "Cleaning Temporary Files..." -Level INFO -Component "End"
    $tempFolders = @(
        "$env:TEMP",
        "$env:SystemRoot\Temp"
    )
    foreach ($folder in $tempFolders) {
        if (Test-Path $folder) {
            Get-ChildItem -Path $folder -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        }
    }
    
    # 3. Final Memory Cleanup
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    
    # 4. Summary Log
    Write-Log -Message "---------------------------------------------------" -Level INFO -Component "End"
    Write-Log -Message "All optimization tasks completed successfully." -Level SUCCESS -Component "End"
    Write-Log -Message "A system restart is recommended to apply all changes." -Level WARN -Component "End"
    Write-Log -Message "---------------------------------------------------" -Level INFO -Component "End"
}

Export-ModuleMember -Function Invoke-EndOptimization
