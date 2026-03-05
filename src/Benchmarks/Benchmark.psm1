function Invoke-SystemBenchmark {
    [CmdletBinding()]
    param()
    
    Write-Log -Message "Starting System Benchmark..." -Level INFO -Component "Benchmark"
    
    $results = @{}
    
    # Network Latency
    Write-Log -Message "Testing Network Latency..." -Level INFO -Component "Benchmark"
    $ping = Test-Connection -ComputerName 1.1.1.1 -Count 10 -ErrorAction SilentlyContinue | Measure-Object -Property ResponseTime -Average
    $results.NetworkLatency = [math]::Round($ping.Average, 2)
    Write-Log -Message "Avg Latency: $($results.NetworkLatency)ms" -Level INFO -Component "Benchmark"
    
    # Disk Speed
    Write-Log -Message "Testing Disk Speed..." -Level INFO -Component "Benchmark"
    $disk = Get-WmiObject -Class Win32_WinSAT
    if (-not $disk) {
        winsat disk -drive c -ran -read -count 10 | Out-Null
        $disk = Get-WmiObject -Class Win32_WinSAT
    }
    $results.DiskScore = $disk.DiskScore
    Write-Log -Message "Disk Score: $($disk.DiskScore)" -Level INFO -Component "Benchmark"
    
    # Memory Speed
    Write-Log -Message "Testing Memory Speed..." -Level INFO -Component "Benchmark"
    $mem = Get-WmiObject -Class Win32_WinSAT
    $results.MemoryScore = $mem.MemoryScore
    Write-Log -Message "Memory Score: $($mem.MemoryScore)" -Level INFO -Component "Benchmark"
    
    return $results
}

Export-ModuleMember -Function Invoke-SystemBenchmark
