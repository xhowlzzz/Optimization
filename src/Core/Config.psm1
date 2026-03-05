function Get-Config {
    [CmdletBinding()]
    param(
        [string]$Path = "$PSScriptRoot\..\config.json"
    )
    if (Test-Path $Path) {
        return Get-Content -Path $Path -Raw | ConvertFrom-Json
    } else {
        # Return Default Configuration
        return @{
            General = @{
                SkipRestorePoint = $false
                IncludeRiskyTweaks = $false
                AutoUpdate = $true
            }
            Tweaks = @{
                DisableTelemtry = $true
                DisableBloatware = $true
                UltimatePowerPlan = $true
                NetworkOptimization = $true
            }
        }
    }
}

function Save-Config {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Config,
        [string]$Path = "$PSScriptRoot\..\config.json"
    )
    $Config | ConvertTo-Json -Depth 10 | Set-Content -Path $Path
}

Export-ModuleMember -Function Get-Config, Save-Config
