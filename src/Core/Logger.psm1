function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [ValidateSet('INFO','SUCCESS','ERROR','WARN')]
        [string]$Level = 'INFO',
        [string]$Component = 'Core'
    )

    $colorMap = @{
        'INFO'    = 'Cyan'
        'SUCCESS' = 'Green'
        'ERROR'   = 'Red'
        'WARN'    = 'Yellow'
    }

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $consoleLine = "[{0}] [{1}] [{2}] {3}" -f $timestamp, $Level, $Component, $Message
    
    # Console Output
    Write-Host $consoleLine -ForegroundColor $colorMap[$Level]

    # File Output (JSON Structured Log)
    if ($Script:LogFilePath) {
        $logEntry = @{
            Timestamp = $timestamp
            Level     = $Level
            Component = $Component
            Message   = $Message
        } | ConvertTo-Json -Compress
        
        try {
            Add-Content -Path $Script:LogFilePath -Value $logEntry -ErrorAction SilentlyContinue
        } catch {}
    }

    # GUI Callback (if attached)
    if ($Script:GuiLogCallback -is [scriptblock]) {
        & $Script:GuiLogCallback $consoleLine $Level
    }
}

function Initialize-Logger {
    [CmdletBinding()]
    param(
        [string]$LogPath
    )
    $Script:LogFilePath = $LogPath
    if (-not (Test-Path (Split-Path $LogPath))) {
        New-Item -ItemType Directory -Path (Split-Path $LogPath) -Force | Out-Null
    }
    Write-Log -Message "Logger initialized at $LogPath" -Level INFO -Component "Logger"
}

Export-ModuleMember -Function Write-Log, Initialize-Logger
