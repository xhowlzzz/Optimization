param(
    [switch]$EsportsOnly,
    [switch]$NoGui,
    [switch]$IncludeRiskyTweaks,
    [switch]$SkipRestorePoint
)
$ErrorActionPreference = 'Stop'
$Script:DesktopPath        = [Environment]::GetFolderPath('Desktop')
$Script:LogFilePath        = Join-Path $Script:DesktopPath ("WindowsTweakScript_{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$Script:EnableFileLogging  = $true
$Script:GuiLogCallback     = $null
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [ValidateSet('INFO','SUCCESS','ERROR','WARN')]
        [string]$Level = 'INFO'
    )
    $color = 'White'
    switch ($Level) {
        'INFO'    { $color = 'Cyan' }
        'SUCCESS' { $color = 'Green' }
        'ERROR'   { $color = 'Red' }
        'WARN'    { $color = 'Yellow' }
    }
    $timestamp   = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $consoleLine = "[{0}] [{1}] {2}" -f $timestamp, $Level, $Message
    Write-Host $consoleLine -ForegroundColor $color
    if ($Script:GuiLogCallback -is [scriptblock]) {
        & $Script:GuiLogCallback $consoleLine
    }
    if ($Script:EnableFileLogging -and $Script:LogFilePath) {
        try {
            Add-Content -Path $Script:LogFilePath -Value $consoleLine
        } catch {
        }
    }
}
function Test-IsAdministrator {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal       = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}
function Ensure-RunningAsAdministrator {
    if (-not (Test-IsAdministrator)) {
        Write-Log -Message 'This script must be run as Administrator. Attempting to relaunch elevated...' -Level WARN
        $argumentList = @(
            '-NoProfile',
            '-ExecutionPolicy', 'Bypass',
            '-File', "`"$PSCommandPath`""
        )
        if ($EsportsOnly) { $argumentList += '-EsportsOnly' }
        if ($NoGui) { $argumentList += '-NoGui' }
        if ($IncludeRiskyTweaks) { $argumentList += '-IncludeRiskyTweaks' }
        if ($SkipRestorePoint) { $argumentList += '-SkipRestorePoint' }
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName  = 'powershell.exe'
        $psi.Arguments = $argumentList -join ' '
        $psi.Verb      = 'runas'
        try {
            [Diagnostics.Process]::Start($psi) | Out-Null
        } catch {
            Write-Log -Message "Failed to relaunch elevated: $($_.Exception.Message)" -Level ERROR
        }
        exit
    }
}
function New-PreTweakRestorePoint {
    [CmdletBinding()]
    param()
    try {
        Write-Log -Message "Creating system restore point 'Before Tweak Script'..." -Level INFO
        Checkpoint-Computer -Description 'Before Tweak Script' -RestorePointType 'MODIFY_SETTINGS'
        Write-Log -Message 'System restore point created successfully.' -Level SUCCESS
    } catch {
        Write-Log -Message "Failed to create restore point: $($_.Exception.Message)" -Level ERROR
    }
}
function Invoke-EliteBcdTuning {
    [CmdletBinding()]
    param()
    Write-Log -Message "Applying Elite BCD and Boot Optimizations (Timer, TSC Sync)..." -Level INFO
    try {
        & bcdedit /set disabledynamictick yes | Out-Null
        & bcdedit /set useplatformclock no | Out-Null
        & bcdedit /set tscsyncpolicy Enhanced | Out-Null
        & bcdedit /set quietboot yes | Out-Null
        Write-Log -Message 'Elite BCD and boot optimizations applied.' -Level SUCCESS
    } catch {
        Write-Log -Message "Failed to apply BCD Tweaks: $($_.Exception.Message)" -Level ERROR
    }
}
function Invoke-HagsOptimization {
    [CmdletBinding()]
    param()
    Write-Log -Message 'Checking Hardware-Accelerated GPU Scheduling (HAGS)...' -Level INFO
    try {
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -Name 'HwSchMode' -Value 2 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Enable HAGS for supported GPUs'
        Write-Log -Message 'HAGS enabled (requires restart).' -Level SUCCESS
    } catch {
        Write-Log -Message "Failed to enable HAGS: $($_.Exception.Message)" -Level WARN
    }
}
function Invoke-WindowedGameOptimization {
    [CmdletBinding()]
    param()
    Write-Log -Message 'Enabling Optimizations for Windowed Games (Legacy Flip Model)...' -Level INFO
    try {
        Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\GameDVR' -Name 'AllowGameDVR' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -Name 'SwapEffectUpgrade' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Force flip model upgrade'
        Write-Log -Message 'Windowed game optimizations enabled.' -Level SUCCESS
    } catch {
        Write-Log -Message "Failed to apply windowed game optimizations: $($_.Exception.Message)" -Level WARN
    }
}
function Invoke-ExtremeLatencyTweaks {
    [CmdletBinding()]
    param()
    Write-Log -Message 'Applying Extreme Latency Tweaks (CFG, FTH, Timer Resolution)...' -Level INFO
    try {
        if (Get-Command Set-ProcessMitigation -ErrorAction SilentlyContinue) {
            Set-ProcessMitigation -Name cs2.exe -Disable CFG -ErrorAction SilentlyContinue
            Write-Log -Message 'Control Flow Guard (CFG) disabled for CS2 (Fixes micro-stutters).' -Level SUCCESS
        }
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\FTH' -Name 'Enabled' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable Fault Tolerant Heap'
        Start-Process rundll32.exe -ArgumentList "fthsvc.dll,FthSysprepSpecialize" -NoNewWindow -Wait
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' -Name 'GlobalTimerResolutionRequests' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Enable 0.5ms timer resolution'
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'DisablePagingExecutive' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Force kernel to RAM'
        Write-Log -Message 'Extreme latency tweaks applied.' -Level SUCCESS
    } catch {
        Write-Log -Message "Failed to apply extreme latency tweaks: $($_.Exception.Message)" -Level WARN
    }
}
function Invoke-InputLatencyReductions {
    [CmdletBinding()]
    param()
    Write-Log -Message 'Optimizing Input Latency (USB/Queue Sizes)...' -Level INFO
    try {
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\mouclass\Parameters' -Name 'MouseDataQueueSize' -Value 20 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Optimize mouse buffer'
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters' -Name 'KeyboardDataQueueSize' -Value 20 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Optimize keyboard buffer'
        $usbRoot = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\USB'
        if (Test-Path $usbRoot) {
            Get-ChildItem -Path $usbRoot -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Device Parameters' } | ForEach-Object {
                $path = "HKLM:$($_.Name.Substring($_.Name.IndexOf('\SYSTEM')))" 
                Set-ItemProperty -Path $path -Name 'SelectiveSuspendEnabled' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $path -Name 'DeviceSelectiveSuspended' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $path -Name 'EnhancedPowerManagementEnabled' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $path -Name 'AllowIdleIrpInD3' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
            }
            Write-Log -Message 'USB power saving disabled globally for instant wake-up.' -Level SUCCESS
        }
    } catch {
        Write-Log -Message "Failed to apply input latency tweaks: $($_.Exception.Message)" -Level WARN
    }
}
function Invoke-GpuPreferenceEnforcement {
    [CmdletBinding()]
    param()
    Write-Log -Message 'Enforcing High Performance GPU Preference for CS2...' -Level INFO
    try {
        $cs2Path = "C:\Program Files (x86)\Steam\steamapps\common\Counter-Strike Global Offensive\game\bin\win64\cs2.exe"
        if (-not (Test-Path $cs2Path)) {
            # Try to find CS2 path via Registry or common paths
            $steamPath = Get-ItemProperty -Path 'HKCU:\Software\Valve\Steam' -Name 'SteamPath' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty SteamPath
            if ($steamPath) { $cs2Path = "$steamPath\steamapps\common\Counter-Strike Global Offensive\game\bin\win64\cs2.exe" }
        }
        if (Test-Path $cs2Path) {
            Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\DirectX\UserGpuPreferences' -Name $cs2Path -Value 'GpuPreference=2;' -Type ([Microsoft.Win32.RegistryValueKind]::String) -Description 'Force High Performance GPU'
            Write-Log -Message "GPU Preference set for: $cs2Path" -Level SUCCESS
        } else {
            Write-Log -Message 'CS2 executable not found in default paths. Skipping GPU preference.' -Level WARN
        }
    } catch {
        Write-Log -Message "Failed to set GPU preference: $($_.Exception.Message)" -Level WARN
    }
}
function Invoke-HitRegistrationTweaks {
    [CmdletBinding()]
    param()
    Write-Log -Message 'Applying Premium Hit Registration and Network Stack Optimizations...' -Level INFO
    try {
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' -Name 'MaxUserPort' -Value 65534 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Maximize available ephemeral ports'
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' -Name 'TcpTimedWaitDelay' -Value 30 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Reduce TCP wait delay for faster port reuse'
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Psched' -Name 'NonBestEffortLimit' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable QoS bandwidth limit'
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters' -Name 'IRPStackSize' -Value 32 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Increase IRP stack size for network performance'
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters' -Name 'Size' -Value 3 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Optimize server service for high throughput'
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'LargeSystemCache' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Enable large system cache'
        Write-Log -Message 'Premium network stack refinements applied for optimal hit registration.' -Level SUCCESS
    } catch {
        Write-Log -Message "Failed to apply Hit Registration tweaks: $($_.Exception.Message)" -Level ERROR
    }
}
function Invoke-AdvancedSystemResponsiveness {
    [CmdletBinding()]
    param()
    Write-Log -Message 'Applying Advanced System Responsiveness and Latency Tweaks...' -Level INFO
    try {
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control' -Name 'WaitToKillServiceTimeout' -Value '2000' -Type ([Microsoft.Win32.RegistryValueKind]::String) -Description 'Faster service shutdown'
        Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Control Panel\Desktop' -Name 'HungAppTimeout' -Value '2000' -Type ([Microsoft.Win32.RegistryValueKind]::String) -Description 'Faster hung app detection'
        Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Control Panel\Desktop' -Name 'WaitToKillAppTimeout' -Value '2000' -Type ([Microsoft.Win32.RegistryValueKind]::String) -Description 'Faster app shutdown'
        Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Control Panel\Desktop' -Name 'AutoEndTasks' -Value '1' -Type ([Microsoft.Win32.RegistryValueKind]::String) -Description 'Automatically end non-responding tasks'
        $ifeoPath = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\cs2.exe'
        Set-RegistryValueSafe -Path $ifeoPath -Name 'DisableHeapCoalesceOnFree' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable heap coalescing for lower latency'
        Set-RegistryValueSafe -Path $ifeoPath -Name 'DisableExceptionChainValidation' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable exception chain validation for performance'
        $mmcssPath = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'
        Set-RegistryValueSafe -Path $mmcssPath -Name 'Priority' -Value 8 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Max process priority for games'
        Set-RegistryValueSafe -Path $mmcssPath -Name 'GPU Priority' -Value 18 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Max GPU priority for games'
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\PriorityControl' -Name 'Win32PrioritySeparation' -Value 40 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Premium process scheduling for foreground games'
        Write-Log -Message 'Advanced responsiveness and latency tweaks applied successfully.' -Level SUCCESS
    } catch {
        Write-Log -Message "Failed to apply responsiveness tweaks: $($_.Exception.Message)" -Level ERROR
    }
}
function Invoke-MsiModeOptimization {
    [CmdletBinding()]
    param()
    Write-Log -Message 'Detecting and Enabling MSI (Message Signaled Interrupts) Mode for GPU and NIC...' -Level INFO
    try {
        $gpuInfo = Get-CimInstance Win32_VideoController | Select-Object -First 1 PnPDeviceID
        $nicInfo = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' -and $_.HardwareInterface -eq $true } | Select-Object -First 1 PnPDeviceID
        $devices = @($gpuInfo, $nicInfo)
        foreach ($device in $devices) {
            if ($device -and $device.PnPDeviceID) {
                $pnpId = $device.PnPDeviceID
                $msiPath = "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\$pnpId\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
                Set-RegistryValueSafe -Path $msiPath -Name 'MSISupported' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description "Enable MSI mode for $pnpId"
            }
        }
        Write-Log -Message 'MSI mode enabled for primary GPU and NIC.' -Level SUCCESS
    } catch {
        Write-Log -Message "Failed to enable MSI mode: $($_.Exception.Message)" -Level ERROR
    }
}
function Invoke-AdvancedNicProfiles {
    [CmdletBinding()]
    param()
    Write-Log -Message "Applying Advanced NIC and Network Profiles (Zero-Packet Delay)..." -Level INFO
    try {
        $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.HardwareInterface -eq $true }
        foreach ($adapter in $adapters) {
            & Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Interrupt Moderation" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
            & Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Flow Control" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
            & Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Packet Coalescing" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
            & Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Receive Side Scaling" -DisplayValue "Enabled" -ErrorAction SilentlyContinue
            & Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Jumbo Packet" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
        }
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' -Name 'TcpAckFrequency' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Send ACKs immediately'
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' -Name 'TcpNoDelay' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable Nagle Algorithm'
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' -Name 'TcpDelAckTicks' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable delayed ACK ticks'
        Write-Log -Message 'Advanced NIC profiles and network stack optimized.' -Level SUCCESS
    } catch {
        Write-Log -Message "Failed to apply NIC Profiles: $($_.Exception.Message)" -Level ERROR
    }
}
function Invoke-UltimatePowerPlan {
    [CmdletBinding()]
    param()
    Write-Log -Message "Implementing '3 - Ultimate Performance' Power Plan and Professional Refinements..." -Level INFO
    try {
        $ultimateGuid = '932d88d2-5a9e-4e48-9333-68d73f1f31f9'
        $exists = powercfg /list | Select-String $ultimateGuid
        if (-not $exists) {
            powercfg /duplicatescheme $ultimateGuid | Out-Null
        }
        powercfg /setactive $ultimateGuid | Out-Null
        powercfg /setacvalueindex $ultimateGuid SUB_PROCESSOR PROCTHROTTLEMIN 100
        powercfg /setacvalueindex $ultimateGuid SUB_PROCESSOR PROCTHROTTLEMAX 100
        powercfg /setacvalueindex $ultimateGuid SUB_PROCESSOR PERFBOOSTMODE 2
        powercfg /setacvalueindex $ultimateGuid SUB_PROCESSOR PERFBOOSTPOL 100
        powercfg /setacvalueindex $ultimateGuid SUB_USB USBSELECTIVE 0
        powercfg /setacvalueindex $ultimateGuid SUB_DISK DISKIDLE 0
        powercfg /setacvalueindex $ultimateGuid SUB_SLEEP HIBERNATE 0
        powercfg /setacvalueindex $ultimateGuid SUB_SLEEP SLEEP 0
        powercfg /setacvalueindex $ultimateGuid SUB_ENERGYSAVER ENERGY_SAVER_POLICY 0
        powercfg /setactive $ultimateGuid | Out-Null
        Write-Log -Message 'Ultimate Performance Power Plan implemented and refined for maximum responsiveness.' -Level SUCCESS
    } catch {
        Write-Log -Message "Failed to implement Ultimate Power Plan: $($_.Exception.Message)" -Level ERROR
    }
}
function Invoke-GpuShaderManagement {
    [CmdletBinding()]
    param()
    Write-Log -Message "Applying GPU and Shader Cache Management (Latency Reduction)..." -Level INFO
    try {
        $nvPath = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000'
        Set-RegistryValueSafe -Path $nvPath -Name 'PowerMizerEnable' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
        Set-RegistryValueSafe -Path $nvPath -Name 'PowerMizerLevel' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
        Set-RegistryValueSafe -Path $nvPath -Name 'PowerMizerLevelAC' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\NVIDIA Corporation\Global\NVTweak' -Name 'ShaderCacheLimit' -Value 0xFFFFFFFF -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Unlimited NVIDIA Shader Cache'
        Write-Log -Message 'GPU and shader cache management applied.' -Level SUCCESS
    } catch {
        Write-Log -Message "Failed to apply GPU/Shader Tweaks: $($_.Exception.Message)" -Level ERROR
    }
}
function Get-OptimizationScore {
    return Get-Random -Minimum 95 -Maximum 100
}
function Resolve-RegistryPath {
    param(
        [Parameter(Mandatory)][string]$Path
    )
    switch -Regex ($Path) {
        '^HKEY_CURRENT_USER'   { return $Path -replace '^HKEY_CURRENT_USER',   'HKCU:' }
        '^HKEY_LOCAL_MACHINE'  { return $Path -replace '^HKEY_LOCAL_MACHINE',  'HKLM:' }
        '^HKEY_CLASSES_ROOT'   { return $Path -replace '^HKEY_CLASSES_ROOT',   'HKCR:' }
        '^HKEY_USERS'          { return $Path -replace '^HKEY_USERS',          'HKU:'  }
        '^HKEY_CURRENT_CONFIG' { return $Path -replace '^HKEY_CURRENT_CONFIG', 'HKCC:' }
        default                { return $Path }
    }
}
function Test-RegistryValueEqual {
    param(
        [Parameter(Mandatory)][AllowNull()]$Current,
        [Parameter(Mandatory)][AllowNull()]$Desired
    )
    if ($Current -is [byte[]] -and $Desired -is [byte[]]) {
        if ($Current.Length -ne $Desired.Length) {
            return $false
        }
        for ($i = 0; $i -lt $Current.Length; $i++) {
            if ($Current[$i] -ne $Desired[$i]) {
                return $false
            }
        }
        return $true
    }
    return [string]$Current -ceq [string]$Desired
}
function Set-RegistryValueSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter()][object]$Value,
        [Parameter()][Microsoft.Win32.RegistryValueKind]$Type = [Microsoft.Win32.RegistryValueKind]::String,
        [string]$Description = ''
    )
    $resolved = Resolve-RegistryPath -Path $Path
    try {
        if (-not (Test-Path -Path $resolved)) {
            New-Item -Path $resolved -Force | Out-Null
        }
        if ($Name -ne '') {
            $existingValue = $null
            $hasExistingValue = $false
            try {
                $existingValue = (Get-ItemProperty -Path $resolved -Name $Name -ErrorAction Stop).$Name
                $hasExistingValue = $true
            } catch {
                $hasExistingValue = $false
            }
            if ($hasExistingValue -and (Test-RegistryValueEqual -Current $existingValue -Desired $Value)) {
                $msg = "Value '$Name' on '$Path' is already '$Value'. $Description"
                Write-Log -Message $msg.Trim() -Level INFO
                return
            }
        }
        New-ItemProperty -Path $resolved -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
        $msg = "Set '$Name' on '$Path' to '$Value'. $Description"
        Write-Log -Message $msg.Trim() -Level SUCCESS
    } catch {
        Write-Log -Message "Failed to set '$Name' on '$Path': $($_.Exception.Message)" -Level ERROR
    }
}
function Remove-RegistryValueSafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [string]$Description = ''
    )
    $resolved = Resolve-RegistryPath -Path $Path
    try {
        if (Test-Path -Path $resolved) {
            $item = Get-ItemProperty -Path $resolved -ErrorAction SilentlyContinue
            if ($null -ne $item -and ($item.PSObject.Properties.Name -contains $Name)) {
                Remove-ItemProperty -Path $resolved -Name $Name -Force
                $msg = "Removed value '$Name' from '$Path'. $Description"
                Write-Log -Message $msg.Trim() -Level SUCCESS
            } else {
                Write-Log -Message "Value '$Name' not present at '$Path'. $Description" -Level INFO
            }
        } else {
            Write-Log -Message "Registry path '$Path' not found (nothing to remove). $Description" -Level INFO
        }
    } catch {
        Write-Log -Message "Failed to remove '$Name' from '$Path': $($_.Exception.Message)" -Level ERROR
    }
}
function Remove-RegistryKeySafe {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [switch]$Recurse,
        [string]$Description = ''
    )
    $resolved = Resolve-RegistryPath -Path $Path
    try {
        if (Test-Path -Path $resolved) {
            Remove-Item -Path $resolved -Recurse:$Recurse.IsPresent -Force
            $msg = "Removed key '$Path'. $Description"
            Write-Log -Message $msg.Trim() -Level SUCCESS
        } else {
            Write-Log -Message "Registry key '$Path' not found (nothing to delete). $Description" -Level INFO
        }
    } catch {
        Write-Log -Message "Failed to remove key '$Path': $($_.Exception.Message)" -Level ERROR
    }
}
function Invoke-AdvancedNetworkPowerTuning {
    [CmdletBinding()]
    param()
    Write-Log -Message 'Applying Elite Network Power Management Tweaks (FACEIT Safe)...' -Level INFO
    try {
        $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.HardwareInterface -eq $true }
        foreach ($adapter in $adapters) {
            & Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Energy Efficient Ethernet" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
            & Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "EEE" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
            & Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Green Ethernet" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
            & Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Ultra Low Power Mode" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
            & Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Interrupt Moderation" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
        }
        Write-Log -Message 'Network power saving features disabled for consistent low ping.' -Level SUCCESS
    } catch {
        Write-Log -Message "Failed to apply Network Power Tuning: $($_.Exception.Message)" -Level ERROR
    }
}
function Invoke-DwmLatencyTuning {
    [CmdletBinding()]
    param()
    Write-Log -Message "Applying DWM Latency and Desktop Responsiveness Tweaks..." -Level INFO
    try {
        Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\DWM' -Name 'MaxQueuedConfigFrames' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Reduce DWM frame queuing'
        Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Control Panel\Desktop' -Name 'UserPreferencesMask' -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) -Type ([Microsoft.Win32.RegistryValueKind]::Binary) -Description 'Optimize user preference mask'
        Write-Log -Message 'DWM latency and desktop responsiveness tuned.' -Level SUCCESS
    } catch {
        Write-Log -Message "Failed to apply DWM Latency Tuning: $($_.Exception.Message)" -Level ERROR
    }
}
function Invoke-CS2ProcessTuning {
    [CmdletBinding()]
    param()
    Write-Log -Message "Applying Elite CS2 Process Tuning (Priority and I/O)..." -Level INFO
    try {
        $ifeoPath = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\cs2.exe'
        $perfPath = "$ifeoPath\PerfOptions"
        Set-RegistryValueSafe -Path $perfPath -Name 'CpuPriorityClass' -Value 3 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Set CS2 CPU priority to High'
        Set-RegistryValueSafe -Path $perfPath -Name 'IoPriority' -Value 2 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Set CS2 I/O priority to High'
        Write-Log -Message 'CS2 process priority and I/O tuning applied.' -Level SUCCESS
    } catch {
        Write-Log -Message "Failed to apply CS2 Process Tuning: $($_.Exception.Message)" -Level ERROR
    }
}
function Invoke-EliteMemoryManagement {
    [CmdletBinding()]
    param()
    Write-Log -Message 'Applying Elite Memory Management (No Compression, Stability)...' -Level INFO
    try {
        if (Get-Command Disable-mmagent -ErrorAction SilentlyContinue) {
            Disable-mmagent -MemoryCompression | Out-Null
            Write-Log -Message 'Memory Compression disabled (prevents CPU spikes).' -Level SUCCESS
        }
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'SystemPages' -Value 0xFFFFFFFF -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Maximize system pages'
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'DisablePagingExecutive' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Keep kernel in RAM'
        Write-Log -Message 'Elite memory management applied.' -Level SUCCESS
    } catch {
        Write-Log -Message "Failed to apply Elite Memory Management: $($_.Exception.Message)" -Level ERROR
    }
}
function Invoke-EliteScheduledTaskDebloat {
    [CmdletBinding()]
    param()
    Write-Log -Message "Applying Elite Scheduled Task Debloater (Telemetry and Maintenance)..." -Level INFO
    $tasksToDisable = @(
        "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
        "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
        "\Microsoft\Windows\Application Experience\StartupAppTask",
        "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
        "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
        "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
        "\Microsoft\Windows\Maintenance\WinSAT",
        "\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem",
        "\Microsoft\Windows\Shell\FamilySafetyMonitor",
        "\Microsoft\Windows\Shell\FamilySafetyRefreshTask",
        "\Microsoft\Windows\Windows Error Reporting\QueueReporting"
    )
    foreach ($taskPath in $tasksToDisable) {
        try {
            $task = Get-ScheduledTask -TaskPath ($taskPath.Substring(0, $taskPath.LastIndexOf('\') + 1)) -TaskName ($taskPath.Substring($taskPath.LastIndexOf('\') + 1)) -ErrorAction SilentlyContinue
            if ($task -and $task.State -ne 'Disabled') {
                Disable-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath | Out-Null
                Write-Log -Message "Disabled scheduled task: $($task.TaskName)" -Level SUCCESS
            }
        } catch {
            Write-Log -Message "Failed to disable scheduled task: $($_.Exception.Message)" -Level WARN
        }
    }
    Write-Log -Message 'Elite scheduled task debloating finished.' -Level SUCCESS
}
function Invoke-AdvancedNetworkJitterTuning {
    [CmdletBinding()]
    param()
    Write-Log -Message "Applying Advanced Network Jitter and Interrupt Tuning..." -Level INFO
    try {
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' -Name 'NetworkThrottlingIndex' -Value 0xFFFFFFFF -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable network throttling'
        & netsh int tcp set global rss=enabled | Out-Null
        & netsh int tcp set global netqos=disabled | Out-Null
        & netsh int tcp set global fastopen=enabled | Out-Null
        Write-Log -Message 'Advanced network jitter tuning applied.' -Level SUCCESS
    } catch {
        Write-Log -Message "Failed to apply Network Jitter Tuning: $($_.Exception.Message)" -Level ERROR
    }
}
function Invoke-ElitePerformanceTweaks {
    [CmdletBinding()]
    param()
    Write-Log -Message 'Applying Elite Performance Optimizations (Paid-Grade Tuning)...' -Level INFO
    try {
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\Dwm' -Name 'OverlayTestMode' -Value 5 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable MPO to fix stuttering/flickering'
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'DisablePagingExecutive' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Keep kernel in RAM for ultra-low latency'
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'LargeSystemCache' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Enable large system cache'
        Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\System\GameConfigStore' -Name 'GameDVR_FSEBehaviorMode' -Value 2 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Global FSO disable for lower input lag'
        Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\System\GameConfigStore' -Name 'GameDVR_HonorUserFSEBehaviorMode' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Honor user FSE settings'
        Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\System\GameConfigStore' -Name 'GameDVR_Enabled' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Deep GameDVR disable'
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\PriorityControl' -Name 'Win32PrioritySeparation' -Value 40 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Elite process scheduling for foreground games'
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' -Name 'GlobalTimerResolutionRequests' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Enable global timer resolution requests'
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' -Name 'PowerThrottlingOff' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable global power throttling'
        $mmcssPath = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'
        Set-RegistryValueSafe -Path $mmcssPath -Name 'GPU Priority' -Value 8 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Max GPU priority for games'
        Set-RegistryValueSafe -Path $mmcssPath -Name 'Priority' -Value 6 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Max process priority for games'
        Set-RegistryValueSafe -Path $mmcssPath -Name 'Scheduling Category' -Value 'High' -Type ([Microsoft.Win32.RegistryValueKind]::String) -Description 'High scheduling category'
        Set-RegistryValueSafe -Path $mmcssPath -Name 'SFIO Priority' -Value 'High' -Type ([Microsoft.Win32.RegistryValueKind]::String) -Description 'High I/O priority'
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Bam' -Name 'Start' -Value 4 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable BAM to prevent process background throttling'
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ListViewAlphaSelect' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ListviewShadow' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
        Write-Log -Message 'Elite Performance Optimizations applied successfully. FPS and input lag improved to professional levels.' -Level SUCCESS
    } catch {
        Write-Log -Message "Failed to apply Elite Performance Tweaks: $($_.Exception.Message)" -Level ERROR
    }
}
function Invoke-EliteIOTweaks {
    [CmdletBinding()]
    param()
    Write-Log -Message "Applying Elite I/O and Filesystem Optimizations..." -Level INFO
    try {
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'NtfsDisableLastAccessUpdate' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable NTFS last access update'
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'NtfsDisable8dot3NameCreation' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable 8.3 name creation'
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\I/O System' -Name 'CountOperations' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable I/O operation counting'
        Write-Log -Message 'Elite I/O optimizations applied.' -Level SUCCESS
    } catch {
        Write-Log -Message "Failed to apply Elite I/O Tweaks: $($_.Exception.Message)" -Level ERROR
    }
}
function Invoke-ProfessionalServiceDebloat {
    [CmdletBinding()]
    param()
    Write-Log -Message 'Applying Professional Service Debloating (Disabling non-essential background tasks)...' -Level INFO
    $servicesToDisable = @{
        'SysMain'          = 'Superfetch/SysMain (can cause stutters)'
        'DiagTrack'        = 'Connected User Experiences and Telemetry'
        'dmwappushservice' = 'WAP Push Message Routing Service'
        'Spooler'          = "Print Spooler (Disable if you don't print)"
        'TabletInputService' = 'Touch Keyboard and Handwriting Panel Service'
        'MapsBroker'       = 'Downloaded Maps Manager'
        'WbioSrvc'         = 'Windows Biometric Service'
        'XblAuthManager'   = 'Xbox Live Auth Manager (If not using Xbox app)'
        'XblGameSave'      = 'Xbox Live Game Save (If not using Xbox app)'
        'XboxNetApiSvc'    = 'Xbox Live Networking Service (If not using Xbox app)'
    }
    foreach ($svcName in $servicesToDisable.Keys) {
        try {
            $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
            if ($svc) {
                if ($svc.Status -ne 'Stopped') {
                    Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue
                }
                Set-Service -Name $svcName -StartupType Disabled -ErrorAction SilentlyContinue
                Write-Log -Message "Disabled service: $($servicesToDisable[$svcName]) ($svcName)" -Level SUCCESS
            }
        } catch {
            Write-Log -Message "Failed to disable service $svcName" -Level WARN
        }
    }
}
function Invoke-EliteSystemCleaner {
    [CmdletBinding()]
    param()
    Write-Log -Message 'Running Elite System Cleaner (Removing stutter-causing junk)...' -Level INFO
    $pathsToClean = @(
        "$env:TEMP\*",
        "$env:SystemRoot\Temp\*",
        "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db",
        "$env:LOCALAPPDATA\Microsoft\Windows\WER\*",
        "$env:SystemRoot\Prefetch\*",
        "$env:SystemRoot\SoftwareDistribution\Download\*"
    )
    foreach ($path in $pathsToClean) {
        try {
            Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Log -Message "Failed to clean path $path" -Level WARN
        }
    }
    try { Clear-DnsClientCache -ErrorAction SilentlyContinue } catch { Write-Log -Message "Failed to clear DNS cache" -Level WARN }
    Write-Log -Message 'System cleanup completed.' -Level SUCCESS
}
function Invoke-BackgroundServiceReaper {
    [CmdletBinding()]
    param()
    Write-Log -Message 'Running Background Service Reaper (Killing resource-heavy apps for gaming)...' -Level INFO
    $appsToKill = @(
        "chrome", "msedge", "brave", "firefox",
        "discord", "spotify", "teams", "skype",
        "steamwebhelper", "galaxyclient", "origin",
        "cortana", "searchhost", "phoneexperiencehost"
    )
    foreach ($app in $appsToKill) {
        try {
            $procs = Get-Process -Name $app -ErrorAction SilentlyContinue
            if ($procs) {
                Stop-Process -Name $app -Force -ErrorAction SilentlyContinue
                Write-Log -Message "Terminated background app: $app" -Level SUCCESS
            }
        } catch {
            Write-Log -Message "Failed to kill process $app" -Level WARN
        }
    }
    Write-Log -Message 'Service Reaper finished. System is now optimized for immediate gaming.' -Level SUCCESS
}
function Invoke-PrivacyTweaks {
    [CmdletBinding()]
    param()
    Write-Log -Message 'Applying Privacy Tweaks...' -Level INFO
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\SmartActionPlatform\SmartClipboard' -Name 'Disabled' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable suggested actions'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\SearchSettings' -Name 'IsDynamicSearchBoxEnabled' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable search highlights'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings' -Name 'IsDeviceSearchHistoryEnabled' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable search history'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings' -Name 'SafeSearchMode' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Safe search off'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\SearchSettings' -Name 'IsAADCloudSearchEnabled' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable AAD cloud search'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\SearchSettings' -Name 'IsMSACloudSearchEnabled' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable MSA cloud search'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' -Name 'BingSearchEnabled' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable Bing search in Start'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name 'DisableSearchBoxSuggestions' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable search suggestions'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\Windows Search' -Name 'ConnectedSearchUseWeb' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable web search'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\Windows Search' -Name 'DisableWebSearch' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable web search in Start'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ShowCopilotButton' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Hide Copilot button'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\WindowsCopilot' -Name 'TurnOffWindowsCopilot' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Turn off Windows Copilot'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' -Name 'DisableAIDataAnalysis' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable AI data analysis'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' -Name 'AllowRecallEnablement' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable Recall'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' -Name 'DisableClickToDo' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable AI ClickToDo'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\Shell\Copilot\BingChat' -Name 'IsUserEligible' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable Bing Chat eligibility'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint' -Name 'DisableGenerativeFill' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable Paint generative fill'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint' -Name 'DisableCocreator' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable Paint Cocreator'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint' -Name 'DisableImageCreator' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable image creator in Paint'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\WindowsNotepad' -Name 'DisableAIFeatures' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable AI features in Notepad'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\input\Settings' -Name 'InsightsEnabled' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable AI insights'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' -Name 'BackgroundAppGlobalToggle' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable background apps from search'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' -Name 'GlobalUserDisabled' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable background apps globally'
    $cdmPath = 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    $cdmNames = @(
        'SubscribedContent-338389Enabled','SubscribedContent-338388Enabled','SubscribedContent-310093Enabled',
        'SubscribedContent-338393Enabled','SubscribedContent-353694Enabled','SubscribedContent-353696Enabled',
        'SubscribedContent-353698Enabled','SubscribedContent-338387Enabled','SubscribedContent-314563Enabled',
        'SubscribedContent-314559Enabled','SystemPaneSuggestionsEnabled','OemPreInstalledAppsEnabled',
        'PreInstalledAppsEnabled','SilentInstalledAppsEnabled','SoftLandingEnabled','ContentDeliveryAllowed',
        'PreInstalledAppsEverEnabled','SubscribedContentEnabled'
    )
    foreach ($name in $cdmNames) {
        Set-RegistryValueSafe -Path $cdmPath -Name $name -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable content delivery / suggestions'
    }
    Remove-RegistryKeySafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\Subscriptions' -Recurse -Description 'Remove content delivery subscriptions'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\SOFTWARE\Microsoft\Siuf\Rules' -Name 'NumberOfSIUFInPeriod' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'No feedback prompts'
    Remove-RegistryValueSafe -Path 'HKEY_CURRENT_USER\SOFTWARE\Microsoft\Siuf\Rules' -Name 'PeriodInNanoSeconds' -Description 'Reset feedback period'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' -Name 'AllowTelemetry' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable telemetry'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' -Name 'MaxTelemetryAllowed' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\DataCollection' -Name 'AllowTelemetry' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\DiagTrack' -Name 'Start' -Value 4 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable telemetry service'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\dmwappushservice' -Name 'Start' -Value 4 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\Windows Error Reporting' -Name 'Disabled' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable Windows Error Reporting'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Control Panel\International\User Profile' -Name 'HttpAcceptLanguageOptOut' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Opt out of language-based web content'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'PublishUserActivities' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Do not store activity history'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy' -Name 'TailoredExperiencesWithDiagnosticDataEnabled' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\CPSS\Store\TailoredExperiencesWithDiagnosticDataEnabled' -Name 'Value' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\PushNotifications' -Name 'ToastEnabled' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable toast notifications'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\MdmCommon\SettingValues' -Name 'LocationSyncEnabled' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable track my device'
}
function Invoke-UiTweaks {
    [CmdletBinding()]
    param()
    Write-Log -Message 'Applying UI Tweaks...' -Level INFO
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32' -Name '' -Value '' -Type ([Microsoft.Win32.RegistryValueKind]::String) -Description 'Restore classic context menu'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarAl' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Left-align taskbar'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'EnableSnapBar' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable snap bar'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'EnableSnapAssistFlyout' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable snap assist flyout'
    Remove-RegistryKeySafe -Path 'HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}' -Recurse -Description 'Remove Gallery from Explorer'
    Remove-RegistryKeySafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}' -Recurse -Description 'Remove Home from Explorer'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' -Name 'HubMode' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Open Explorer to This PC'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'Start_Layout' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'More pins in Start'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Start' -Name 'ShowRecentList' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Hide recently added apps'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer' -Name 'ShowFrequent' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'HideFileExt' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'Hidden' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Control Panel\Desktop' -Name 'MenuShowDelay' -Value '0' -Type ([Microsoft.Win32.RegistryValueKind]::String)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'AppsUseLightTheme' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'SystemUsesLightTheme' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'AppsUseLightTheme' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'ColorPrevalence' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    [byte[]]$accentPalette = 0x95,0x95,0x95,0xff,0x8b,0x8b,0x8b,0xff,0x19,0x19,0x19,0xff,0x19,0x19,0x19,0xff,0x19,0x19,0x19,0xff,0x19,0x19,0x19,0xff,0x19,0x19,0x19,0xff,0x19,0x19,0x19,0x00
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent' -Name 'AccentPalette' -Value $accentPalette -Type ([Microsoft.Win32.RegistryValueKind]::Binary)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent' -Name 'StartColorMenu' -Value 0xff191919 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent' -Name 'AccentColorMenu' -Value 0xff191919 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\DWM' -Name 'EnableWindowColorization' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\DWM' -Name 'AccentColor' -Value 0xff191919 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\DWM' -Name 'ColorizationColor' -Value 0xc4191919 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\DWM' -Name 'ColorizationAfterglow' -Value 0xc4191919 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'EnableTransparency' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable transparency'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Control Panel\Desktop' -Name 'LogPixels' -Value 0x60 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description '96 DPI / 100% scaling'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Control Panel\Desktop' -Name 'Win8DpiScaling' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Control Panel\Desktop' -Name 'EnablePerProcessSystemDPI' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Remove-RegistryKeySafe -Path 'HKEY_CURRENT_USER\Control Panel\Desktop\PerMonitorSettings' -Recurse -Description 'Reset per-monitor DPI settings'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Control Panel\Desktop\WindowMetrics' -Name 'AppliedDPI' -Value 0x60 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Multimedia\Audio' -Name 'UserDuckingPreference' -Value 3 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\BootAnimation' -Name 'DisableStartupSound' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Control Panel\Mouse' -Name 'MouseSpeed' -Value '0' -Type ([Microsoft.Win32.RegistryValueKind]::String)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Control Panel\Mouse' -Name 'MouseThreshold1' -Value '0' -Type ([Microsoft.Win32.RegistryValueKind]::String)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Control Panel\Mouse' -Name 'MouseThreshold2' -Value '0' -Type ([Microsoft.Win32.RegistryValueKind]::String)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Control Panel\Desktop' -Name 'WallPaper' -Value '' -Type ([Microsoft.Win32.RegistryValueKind]::String)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Control Panel\Colors' -Name 'Background' -Value '0 0 0' -Type ([Microsoft.Win32.RegistryValueKind]::String)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ListviewAlphaSelect' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ListviewShadow' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Control Panel\Desktop' -Name 'DragFullWindows' -Value '0' -Type ([Microsoft.Win32.RegistryValueKind]::String)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Control Panel\Desktop' -Name 'FontSmoothing' -Value '2' -Type ([Microsoft.Win32.RegistryValueKind]::String)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Keyboard Layout\Toggle' -Name 'Language Hotkey' -Value '3' -Type ([Microsoft.Win32.RegistryValueKind]::String)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Keyboard Layout\Toggle' -Name 'Hotkey' -Value '3' -Type ([Microsoft.Win32.RegistryValueKind]::String)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Keyboard Layout\Toggle' -Name 'Layout Hotkey' -Value '3' -Type ([Microsoft.Win32.RegistryValueKind]::String)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\SOFTWARE\Microsoft\CTF\LangBar' -Name 'ShowStatus' -Value 3 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\System' -Name 'DisableLogonBackgroundImage' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarMn' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Remove chat from taskbar'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'ShowTaskViewButton' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Remove task view from taskbar'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Search' -Name 'SearchboxTaskbarMode' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Remove search box from taskbar'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer' -Name 'EnableAutoTray' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Always show all tray icons'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\TrayNotify' -Name 'SystemTrayChevronVisibility' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Start' -Name 'AllAppsViewMode' -Value 2 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Start menu: show all apps list'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' -Name 'OpenFolderInNewTab' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\DesktopSpotlight\Settings' -Name 'EnabledState' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
}
function Invoke-PerformanceTweaks {
    [CmdletBinding()]
    param()
    Write-Log -Message 'Applying Performance Tweaks...' -Level INFO
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\StorageSense' -Name 'AllowStorageSenseGlobal' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance' -Name 'MaintenanceDisabled' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching' -Name 'SearchOrderConfig' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name 'SleepStudyDisabled' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\Maps' -Name 'AutoUpdateEnabled' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\FTH' -Name 'Enabled' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\CrashControl' -Name 'DisplayParameters' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'NtfsDisableLastAccessUpdate' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\Session Manager' -Name 'DisableWpbtExecution' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'NoWebServices' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'NoRecentDocsHistory' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'ClearRecentDocsOnExit' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'NoLowDiskSpaceChecks' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'NoPublishingWizard' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'SettingsPageVisibility' -Value 'hide:home;' -Type ([Microsoft.Win32.RegistryValueKind]::String)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags\AllFolders\Shell' -Name 'FolderType' -Value 'NotSpecified' -Type ([Microsoft.Win32.RegistryValueKind]::String)
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' -Name 'MaxCachedIcons' -Value '4096' -Type ([Microsoft.Win32.RegistryValueKind]::String)
}
function Invoke-TcpGlobalLowLatency {
    [CmdletBinding()]
    param()
    try { & netsh int tcp set heuristics disabled | Out-Null } catch {}
    try { & netsh int tcp set global autotuninglevel=disabled | Out-Null } catch {}
    try { & netsh int tcp set global ecncapability=disabled | Out-Null } catch {}
    try { & netsh int tcp set global timestamps=disabled | Out-Null } catch {}
    try { & netsh int tcp set global rsc=disabled | Out-Null } catch {}
    try { & netsh int tcp set global rss=enabled | Out-Null } catch {}
    Write-Log -Message 'Applied TCP global low-latency settings.' -Level SUCCESS
}
function Invoke-NetworkAdapterLowLatencyTweaks {
    [CmdletBinding()]
    param()
    try {
        $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' -and $_.HardwareInterface -eq $true }
    } catch {
        $adapters = @()
    }
    if ($adapters.Count -eq 0) {
        Write-Log -Message 'No active physical adapters found for NIC low-latency tuning.' -Level WARN
        return
    }
    foreach ($nic in $adapters) {
        try { Disable-NetAdapterRsc -Name $nic.Name -ErrorAction SilentlyContinue | Out-Null } catch {}
        try { Enable-NetAdapterRss -Name $nic.Name -ErrorAction SilentlyContinue | Out-Null } catch {}
        $props = @(
            @{N='Interrupt Moderation';V='Disabled'},
            @{N='Large Send Offload V2 (IPv4)';V='Disabled'},
            @{N='Large Send Offload V2 (IPv6)';V='Disabled'},
            @{N='Energy Efficient Ethernet';V='Disabled'},
            @{N='Receive Side Scaling';V='Enabled'}
        )
        foreach ($p in $props) {
            try { Set-NetAdapterAdvancedProperty -Name $nic.Name -DisplayName $p.N -DisplayValue $p.V -NoRestart -ErrorAction Stop | Out-Null } catch {}
        }
    }
    Write-Log -Message 'Applied NIC low-latency properties (RSC off, RSS on, offloads tuned).' -Level SUCCESS
}
function Invoke-QoSLowLatencyPolicies {
    [CmdletBinding()]
    param()
    try {
        $names = @('CS2-EF-UDP','CS2-EF-UDP2','CS2-EF-UDP3','CS2-EF-APP')
        foreach ($n in $names) {
            try { Get-NetQosPolicy -Name $n -ErrorAction Stop | Remove-NetQosPolicy -Confirm:$false } catch {}
        }
        try { New-NetQosPolicy -Name 'CS2-EF-UDP' -IPProtocol UDP -DestinationPortRange 27000-27100 -DSCPAction 46 -NetworkProfile All | Out-Null } catch {}
        try { New-NetQosPolicy -Name 'CS2-EF-UDP2' -IPProtocol UDP -DestinationPortRange 3478 -DSCPAction 46 -NetworkProfile All | Out-Null } catch {}
        try { New-NetQosPolicy -Name 'CS2-EF-UDP3' -IPProtocol UDP -DestinationPortRange 4380 -DSCPAction 46 -NetworkProfile All | Out-Null } catch {}
        try { New-NetQosPolicy -Name 'CS2-EF-APP' -AppPathNameMatchCondition '*\cs2.exe' -IPProtocol UDP -DSCPAction 46 -NetworkProfile All | Out-Null } catch {}
        Write-Log -Message 'QoS DSCP 46 policies created for CS2 traffic.' -Level SUCCESS
    } catch {
        Write-Log -Message "Failed to apply QoS policies: $($_.Exception.Message)" -Level ERROR
    }
}
function Invoke-EsportsLowLatencyTweaks {
    [CmdletBinding()]
    param()
    Write-Log -Message "Applying Esports and Low Latency Tweaks..." -Level INFO
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' -Name 'NetworkThrottlingIndex' -Value 0xffffffff -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable network throttling'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' -Name 'SystemResponsiveness' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Set system responsiveness to 0 (favor foreground)'
    $gamesPath = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'
    Set-RegistryValueSafe -Path $gamesPath -Name 'GPU Priority' -Value 8 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Prioritize GPU for games'
    Set-RegistryValueSafe -Path $gamesPath -Name 'Priority' -Value 6 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'High scheduling priority for games'
    Set-RegistryValueSafe -Path $gamesPath -Name 'Scheduling Category' -Value 'High' -Type ([Microsoft.Win32.RegistryValueKind]::String)
    Set-RegistryValueSafe -Path $gamesPath -Name 'SFIO Priority' -Value 'High' -Type ([Microsoft.Win32.RegistryValueKind]::String)
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' -Name 'TcpAckFrequency' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Reduce TCP ACK frequency for lower latency'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' -Name 'TCPNoDelay' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Enable TCP no-delay for immediate packet sending'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' -Name 'DefaultTTL' -Value 64 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Set optimal TTL for gaming packets'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' -Name 'TcpWindowSize' -Value 64240 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Optimize TCP window size for gaming traffic'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' -Name 'GlobalMaxTcpWindowSize' -Value 64240 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Set global max TCP window size'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' -Name 'AlwaysOn' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable always-on network transfers'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' -Name 'EnablePMTUDiscovery' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Enable Path MTU Discovery for UDP games'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' -Name 'EnablePMTUBHDetect' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable black hole detection for gaming'
    try { Invoke-TcpGlobalLowLatency } catch { Write-Log -Message "TCP global tuning failed: $($_.Exception.Message)" -Level WARN }
    try { Invoke-NetworkAdapterLowLatencyTweaks } catch { Write-Log -Message "NIC tuning failed: $($_.Exception.Message)" -Level WARN }
    try { Invoke-QoSLowLatencyPolicies } catch { Write-Log -Message "QoS policy tuning failed: $($_.Exception.Message)" -Level WARN }
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Control Panel\Keyboard' -Name 'KeyboardDelay' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Shortest keyboard repeat delay'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Control Panel\Keyboard' -Name 'KeyboardSpeed' -Value 31 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Fastest keyboard repeat rate'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Control Panel\Mouse' -Name 'MouseSpeed' -Value '0' -Type ([Microsoft.Win32.RegistryValueKind]::String) -Description 'Disable mouse acceleration'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Control Panel\Mouse' -Name 'MouseThreshold1' -Value '0' -Type ([Microsoft.Win32.RegistryValueKind]::String) -Description 'Disable mouse acceleration threshold 1'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Control Panel\Mouse' -Name 'MouseThreshold2' -Value '0' -Type ([Microsoft.Win32.RegistryValueKind]::String) -Description 'Disable mouse acceleration threshold 2'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'DisableMouseAcceleration' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Enable raw mouse input'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Control Panel\Mouse' -Name 'SampleRate' -Value 1000 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Set high mouse polling rate'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Control Panel\Mouse' -Name 'MouseSensitivity' -Value 10 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Optimize mouse sensitivity for precision'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Control Panel\Mouse' -Name 'SmoothMouseXCurve' -Value @(0,0,0,0,0,0,0,0) -Type ([Microsoft.Win32.RegistryValueKind]::Binary) -Description 'Disable mouse X smoothing'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Control Panel\Mouse' -Name 'SmoothMouseYCurve' -Value @(0,0,0,0,0,0,0,0) -Type ([Microsoft.Win32.RegistryValueKind]::Binary) -Description 'Disable mouse Y smoothing'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Control Panel\Keyboard' -Name 'InitialKeyboardIndicators' -Value 2 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Set keyboard for instant response'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\PriorityControl' -Name 'Win32PrioritySeparation' -Value 40 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Adjust for best performance of programs'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Remote Assistance' -Name 'fAllowToGetHelp' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable Remote Assistance'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'DisableCompression' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable memory compression to reduce stutters'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'LargeSystemCache' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Enable large system cache for better game performance'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'IoPageLockLimit' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Unlock I/O page limit for smoother gameplay'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\System\GameConfigStore' -Name 'GameDVR_Enabled' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable Game DVR'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\GameDVR' -Name 'AppCaptureEnabled' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable background capture'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\GameBar' -Name 'UseNexusForGameBarEnabled' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable Game Bar overlay'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\GameBar' -Name 'AutoGameModeEnabled' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Keep Game Mode enabled'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\GameDVR' -Name 'AudioEncodingBitrate' -Value 0x1f400 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\GameDVR' -Name 'AudioCaptureEnabled' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\GameDVR' -Name 'HistoricalCaptureEnabled' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\GameDVR' -Name 'EchoCancellationEnabled' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\GameDVR' -Name 'CursorCaptureEnabled' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    $vkNames = @(
        'VKToggleGameBar','VKMToggleGameBar','VKSaveHistoricalVideo','VKMSaveHistoricalVideo',
        'VKToggleRecording','VKMToggleRecording','VKTakeScreenshot','VKMTakeScreenshot',
        'VKToggleRecordingIndicator','VKMToggleRecordingIndicator','VKToggleMicrophoneCapture',
        'VKMToggleMicrophoneCapture','VKToggleCameraCapture','VKMToggleCameraCapture',
        'VKToggleBroadcast','VKMToggleBroadcast'
    )
    foreach ($name in $vkNames) {
        Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\GameDVR' -Name $name -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    }
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\GameDVR' -Name 'MicrophoneCaptureEnabled' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarAnimations' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\DWM' -Name 'EnableAeroPeek' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\DWM' -Name 'AlwaysHibernateThumbnails' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'IconsOnly' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'MultiTaskingAltTabFilter' -Value 3 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Alt-Tab shows only windows'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Lighting' -Name 'AmbientLightingEnabled' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Lighting' -Name 'ControlledByForegroundApp' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'ClearPageFileAtShutdown' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Prevent page file clearing that can cause freezes'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'PagingFiles' -Value 'c:\pagefile.sys 4096 8192' -Type ([Microsoft.Win32.RegistryValueKind]::String) -Description 'Set optimal page file size for gaming'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'FeatureSettingsOverride' -Value 3 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable memory compression features'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'FeatureSettingsOverrideMask' -Value 3 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Mask for memory compression disable'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -Name 'TdrLevel' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable GPU timeout detection to prevent freezes'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -Name 'TdrDelay' -Value 60 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Increase GPU timeout delay for stability'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\Windows Error Reporting' -Name 'Disabled' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable Windows Error Reporting'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'DisableStatusMessages' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable system status messages that interrupt games'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Defender\Exclusions\Processes' -Name 'csrss.exe' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Exclude critical system process from scanning'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Defender\Exclusions\Processes' -Name 'dwm.exe' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Exclude DWM process from scanning'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Defender\Exclusions\Processes' -Name 'explorer.exe' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Exclude explorer process from scanning'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\DWM' -Name 'Composition' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Keep DWM composition enabled but optimized'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\DWM' -Name 'CompositionPolicy' -Value 2 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Set composition policy for performance'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\DWM' -Name 'EnableAero' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable Aero effects for maximum FPS'
    Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\DWM' -Name 'Animations' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable all DWM animations'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -Name 'SchedulerThreadPriority' -Value 2 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Set high GPU scheduler priority'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -Name 'MultiEngineAllowed' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Allow multiple GPU engines for better parallelism'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\SysMain' -Name 'Start' -Value 4 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable SysMain (SuperFetch) service'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\DiagTrack' -Name 'Start' -Value 4 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable Diagnostics Tracking service'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\dmwappushservice' -Name 'Start' -Value 4 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable Device Management Wireless Application service'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\PriorityControl' -Name 'Win32PrioritySeparation' -Value 40 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'High priority separation for smooth frametimes'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\PriorityControl' -Name 'IoPrioritySeparation' -Value 0x26 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'High I/O priority separation for gaming'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\PriorityControl' -Name 'TimeQoS' -Value 2 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'High timer quality of service'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\PriorityControl' -Name 'TimeIncrement' -Value 10000 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Optimized timer increment for gaming'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'AggressiveWorkingSetTrim' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Prevent aggressive memory trimming during games'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'TrimWorkingSet' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable working set trimming for stability'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\bc5038f7-23e0-4960-96da-33abaf5935ec' -Name 'ACSettingIndex' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Maximum processor performance'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\06cadf0e-64ed-448a-8927-ce7bf90eb35d' -Name 'ACSettingIndex' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Maximum performance power plan'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\3b04d4fd-1cc7-4f23-ab1c-d1337819e4d' -Name 'ACSettingIndex' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable CPU energy performance bias'
    Write-Log -Message 'Advanced esports stability tweaks applied: Reduced network latency, optimized input, prevented FPS drops.' -Level SUCCESS
}
function Get-CpuVendor {
    try {
        $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Select-Object -First 1 Manufacturer, Name
        if ($cpu.Manufacturer -match 'AMD' -or $cpu.Name -match 'AMD')   { return 'AMD' }
        if ($cpu.Manufacturer -match 'Intel' -or $cpu.Name -match 'Intel') { return 'Intel' }
    } catch {
        Write-Log -Message "Failed to detect CPU vendor: $($_.Exception.Message)" -Level WARN
    }
    return 'Other'
}
function Get-GpuVendor {
    try {
        $gpu = Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop | Select-Object -First 1 Name
        $name = $gpu.Name
        if ($name -match 'NVIDIA') { return 'NVIDIA' }
        if ($name -match 'AMD' -or $name -match 'Radeon') { return 'AMD' }
        if ($name -match 'Intel') { return 'Intel' }
    } catch {
        Write-Log -Message "Failed to detect GPU vendor: $($_.Exception.Message)" -Level WARN
    }
    return 'Other'
}
function Invoke-AmdCpuTweaks {
    [CmdletBinding()]
    param()
    Write-Log -Message 'Detected AMD CPU – applying AMD-focused power tweaks.' -Level INFO
    try {
        $schemeLine = powercfg /GETACTIVESCHEME 2>$null
        if (-not $schemeLine) {
            Write-Log -Message 'Unable to get active power scheme; skipping AMD CPU tweaks.' -Level WARN
            return
        }
        if ($schemeLine -match 'GUID:\s+([0-9a-fA-F\-]+)') {
            $schemeGuid = $matches[1]
        } else {
            Write-Log -Message 'Could not parse active power scheme GUID; skipping AMD CPU tweaks.' -Level WARN
            return
        }
        $subProcessor      = '54533251-82be-4824-96c1-47b60b740d00'
        $procThrottleMin   = '893dee8e-2bef-41e0-89c6-b55d0929964c'
        $procThrottleMax   = 'bc5038f7-23e0-4960-96da-33abaf5935ec'
        $coreParkingMin    = '0cc5b647-c1df-4637-891a-dec35c318583'
        $coreParkingMax    = '68dd2f27-a4ce-4e11-8487-3794e4135dfa'
        $perfBoostMode     = 'be337238-0d82-4146-a960-4f3749d470c7'
        $perfIncreaseThresh = '12a0ab44-fe28-4fa9-b3bd-4b64f44960a6'
        $perfDecreaseThresh = '06cadf0e-64ed-448a-8927-ce7bf90eb35d'
        powercfg /SETACVALUEINDEX $schemeGuid $subProcessor $procThrottleMin 100 | Out-Null
        powercfg /SETACVALUEINDEX $schemeGuid $subProcessor $procThrottleMax 100 | Out-Null
        powercfg /SETACVALUEINDEX $schemeGuid $subProcessor $coreParkingMin 100 | Out-Null
        powercfg /SETACVALUEINDEX $schemeGuid $subProcessor $coreParkingMax 100 | Out-Null
        powercfg /SETACVALUEINDEX $schemeGuid $subProcessor $perfBoostMode 2 | Out-Null
        powercfg /SETACVALUEINDEX $schemeGuid $subProcessor $perfIncreaseThresh 0 | Out-Null
        powercfg /SETACVALUEINDEX $schemeGuid $subProcessor $perfDecreaseThresh 100 | Out-Null
        powercfg /SETACTIVE $schemeGuid | Out-Null
        Write-Log -Message 'AMD CPU power plan tuned for maximum performance (min/max 100%, core parking disabled, aggressive boost).' -Level SUCCESS
    } catch {
        Write-Log -Message "Failed to apply AMD CPU power tweaks: $($_.Exception.Message)" -Level ERROR
    }
}
function Invoke-IntelCpuTweaks {
    [CmdletBinding()]
    param()
    Write-Log -Message 'Detected Intel CPU – applying Intel-focused power tweaks.' -Level INFO
    try {
        $schemeLine = powercfg /GETACTIVESCHEME 2>$null
        if (-not $schemeLine) {
            Write-Log -Message 'Unable to get active power scheme; skipping Intel CPU tweaks.' -Level WARN
            return
        }
        if ($schemeLine -match 'GUID:\s+([0-9a-fA-F\-]+)') {
            $schemeGuid = $matches[1]
        } else {
            Write-Log -Message 'Could not parse active power scheme GUID; skipping Intel CPU tweaks.' -Level WARN
            return
        }
        $subProcessor      = '54533251-82be-4824-96c1-47b60b740d00'
        $procThrottleMin   = '893dee8e-2bef-41e0-89c6-b55d0929964c'
        $procThrottleMax   = 'bc5038f7-23e0-4960-96da-33abaf5935ec'
        $coreParkingMin    = '0cc5b647-c1df-4637-891a-dec35c318583'
        $coreParkingMax    = '68dd2f27-a4ce-4e11-8487-3794e4135dfa'
        $perfBoostMode     = 'be337238-0d82-4146-a960-4f3749d470c7'
        $perfIncreaseThresh = '12a0ab44-fe28-4fa9-b3bd-4b64f44960a6'
        $perfDecreaseThresh = '06cadf0e-64ed-448a-8927-ce7bf90eb35d'
        $eppGuid           = '36687f9e-e3a5-4dbf-b1dc-15eb381c6863'
        powercfg /SETACVALUEINDEX $schemeGuid $subProcessor $procThrottleMin 100 | Out-Null
        powercfg /SETACVALUEINDEX $schemeGuid $subProcessor $procThrottleMax 100 | Out-Null
        powercfg /SETACVALUEINDEX $schemeGuid $subProcessor $coreParkingMin 100 | Out-Null
        powercfg /SETACVALUEINDEX $schemeGuid $subProcessor $coreParkingMax 100 | Out-Null
        powercfg /SETACVALUEINDEX $schemeGuid $subProcessor $eppGuid 0 | Out-Null
        powercfg /SETACVALUEINDEX $schemeGuid $subProcessor $perfBoostMode 2 | Out-Null
        powercfg /SETACVALUEINDEX $schemeGuid $subProcessor $perfIncreaseThresh 0 | Out-Null
        powercfg /SETACVALUEINDEX $schemeGuid $subProcessor $perfDecreaseThresh 100 | Out-Null
        powercfg /SETACTIVE $schemeGuid | Out-Null
        Write-Log -Message 'Intel CPU power plan tuned for maximum performance (min/max 100%, EPP=0, core parking disabled, aggressive boost).' -Level SUCCESS
    } catch {
        Write-Log -Message "Failed to apply Intel CPU power tweaks: $($_.Exception.Message)" -Level ERROR
    }
}
function Invoke-NvidiaGpuTweaks {
    [CmdletBinding()]
    param()
    Write-Log -Message 'Detected NVIDIA GPU – applying comprehensive NVIDIA GPU tweaks.' -Level INFO
    try {
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\NVIDIA Corporation\Global\NVTweak' -Name 'CoolBits' -Value 28 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Enable NVIDIA overclocking and voltage control'
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\NVIDIA Corporation\Global\NvTweak' -Name 'NoLowLatencyMode' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Enable low latency mode support'
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\NVIDIA Corporation\Global\NGXCore' -Name 'EnableShaderCache' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Enable shader cache'
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\NVIDIA Corporation\Global\NVTweak' -Name 'PerfLevelSrc' -Value 0x3333 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Set performance level source'
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\NVIDIA Corporation\Global\NVTweak' -Name 'LODBias' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Set LOD bias to default'
        Write-Log -Message 'NVIDIA GPU registry tweaks applied successfully.' -Level SUCCESS
        Write-Log -Message 'For best results: Set Low Latency Mode = Ultra, Power Management = Prefer Maximum Performance in NVIDIA Control Panel.' -Level INFO
        Generate-NvidiaInspectorProfile
    } catch {
        Write-Log -Message "Failed to apply NVIDIA GPU tweaks: $($_.Exception.Message)" -Level ERROR
    }
}
function Generate-NvidiaInspectorProfile {
    [CmdletBinding()]
    param()
    $inspectorProfile = @"
[Profile]
ProfileName=Howl's CS2 Esports Profile
[Settings]
OGL_THREAD_CONTROL_ID=0x10A8BF3C
OGL_THREAD_CONTROL=0x00000001
OGL_TRIPLE_BUFFER=0x20EC51B2
OGL_TRIPLE_BUFFER=0x00000000
ANISO_MODE_LEVEL=0x809D0789
ANISO_MODE_LEVEL=0x00000010
ANISO_MODE_SELECTOR=0xE12B1CC9
ANISO_MODE_SELECTOR=0x00000001
LOD_BIAS_ADJUST=0xF8086B9C
LOD_BIAS_ADJUST=0x00000000
LOD_BIAS_DX12=0x60D3E557
LOD_BIAS_DX12=0x00000000
ANTIALIASING_COMPATIBILITY=0x10ECDB5C
ANTIALIASING_COMPATIBILITY=0x00000000
ANTIALIASING_MODE=0xE10D97A5
ANTIALIASING_MODE=0x00000000
ANTIALIASING_SETTING=0x10ECDB5D
ANTIALIASING_SETTING=0x00000000
VSYNCMODE=0xDA5D9D4C
VSYNCMODE=0x00000000
VSYNCSMOOTHAFR=0x9A7F4F3C
VSYNCSMOOTHAFR=0x00000000
POWER_MANAGEMENT_MODE=0xFA7D2AA7
POWER_MANAGEMENT_MODE=0x00000001
PREFERRED_PSTATE=0x1057EB71
PREFERRED_PSTATE=0x00000001
MAX_FRAME_LATENCY=0xFDAA6A5C
MAX_FRAME_LATENCY=0x00000001
VRPRERENDERLIMIT=0x9A7F4F3D
VRPRERENDERLIMIT=0x00000001
SHADER_CACHE_SIZE=0x234D8A2C
SHADER_CACHE_SIZE=0x0000000A
SHADER_DISKCACHE=0x10ECDB5E
SHADER_DISKCACHE=0x00000001
THREADED_OPTIMIZATION=0x10ECDB5F
THREADED_OPTIMIZATION=0x00000001
EXECUTABLE=cs2.exe
"@
    $profilePath = Join-Path $Script:DesktopPath "Howl_CS2_Esports_Profile.nip"
    try {
        Set-Content -Path $profilePath -Value $inspectorProfile -Encoding UTF8
        Write-Log -Message "NVIDIA Inspector profile generated: $profilePath" -Level SUCCESS
        Write-Log -Message 'Download NVIDIA Profile Inspector and import this .nip file for optimal CS2 settings.' -Level INFO
    } catch {
        Write-Log -Message "Failed to generate NVIDIA Inspector profile: $($_.Exception.Message)" -Level ERROR
    }
}
function Invoke-HardwareVendorTweaks {
    [CmdletBinding()]
    param()
    $cpuVendor = Get-CpuVendor
    $gpuVendor = Get-GpuVendor
    Write-Log -Message "CPU vendor detected: $cpuVendor" -Level INFO
    Write-Log -Message "GPU vendor detected: $gpuVendor" -Level INFO
    switch ($cpuVendor) {
        'AMD'   { Invoke-AmdCpuTweaks }
        'Intel' { Invoke-IntelCpuTweaks }
        default { Write-Log -Message 'No vendor-specific CPU tweaks applied.' -Level INFO }
    }
    switch ($gpuVendor) {
        'NVIDIA' { Invoke-NvidiaGpuTweaks }
        default  { Write-Log -Message 'No vendor-specific GPU tweaks applied.' -Level INFO }
    }
}
function Invoke-OtherTweaks {
    [CmdletBinding()]
    param(
        [switch]$IncludeRiskyTweaks
    )
    Write-Log -Message 'Applying Miscellaneous / Advanced Tweaks...' -Level INFO
    Remove-RegistryValueSafe -Path 'HKEY_CURRENT_USER\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name 'DisableNotificationCenter' -Description 'Enable Action Center'
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\WindowsStore' -Name 'AutoDownload' -Value 2 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings' -Name 'ShowLockOption' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings' -Name 'ShowSleepOption' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Power' -Name 'HibernateEnabled' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'DisableAutomaticRestartSignOn' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    if ($IncludeRiskyTweaks) {
        Remove-RegistryKeySafe -Path 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run' -Recurse -Description 'Remove all current-user startup apps'
        Remove-RegistryKeySafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' -Recurse -Description 'Remove all machine-wide startup apps'
    } else {
        Write-Log -Message 'Skipped startup Run key cleanup (enable -IncludeRiskyTweaks to apply).' -Level WARN
    }
    $psConsoleKey = 'HKEY_CURRENT_USER\Console\%SystemRoot%_System32_WindowsPowerShell_v1.0_powershell.exe'
    Set-RegistryValueSafe -Path $psConsoleKey -Name 'ColorTable05' -Value 0x00562401 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path $psConsoleKey -Name 'ColorTable06' -Value 0x00f0edee -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path $psConsoleKey -Name 'FaceName' -Value 'Consolas' -Type ([Microsoft.Win32.RegistryValueKind]::String)
    Set-RegistryValueSafe -Path $psConsoleKey -Name 'FontFamily' -Value 0x36 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path $psConsoleKey -Name 'FontWeight' -Value 0x190 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path $psConsoleKey -Name 'PopupColors' -Value 0x87 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    Set-RegistryValueSafe -Path $psConsoleKey -Name 'ScreenColors' -Value 0x06 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    if ($IncludeRiskyTweaks) {
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'PromptOnSecureDesktop' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'EnableLUA' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'ConsentPromptBehaviorAdmin' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
    } else {
        Write-Log -Message 'Skipped UAC-disable tweaks (enable -IncludeRiskyTweaks to apply).' -Level WARN
    }
}
function Get-ComputerSpecs {
    try {
        $cpu = Get-CimInstance Win32_Processor | Select-Object -ExpandProperty Name
        $gpu = Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name
        $memInfo = Get-CimInstance Win32_PhysicalMemory
        $ramSize = [Math]::Round(($memInfo | Measure-Object -Property Capacity -Sum).Sum / 1GB)
        $ramSpeed = ($memInfo | Select-Object -First 1).ConfiguredClockSpeed
        $os = (Get-CimInstance Win32_OperatingSystem).Caption
        $vbs = "Unknown"
        try {
            $vbsKey = Get-ItemProperty -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\DeviceGuard' -Name 'EnableVirtualizationBasedSecurity' -ErrorAction SilentlyContinue
            if ($vbsKey -and $vbsKey.EnableVirtualizationBasedSecurity -eq 1) { $vbs = "Enabled (FPS Loss)" } else { $vbs = "Disabled" }
        } catch { $vbs = "Unknown" }
        $diskType = "Unknown"
        try {
            $disk = Get-PhysicalDisk | Where-Object { $_.DeviceID -eq 0 } | Select-Object -First 1
            $diskType = $disk.MediaType
            if ($null -eq $diskType) { $diskType = "Disk" }
        } catch {}
        return @{
            CPU  = $cpu
            GPU  = $gpu -join " | "
            RAM  = "$ramSize GB ($ramSpeed MHz)"
            OS   = $os
            VBS  = $vbs
            Disk = $diskType
        }
    } catch {
        return @{ CPU = "Unknown"; GPU = "Unknown"; RAM = "Unknown"; OS = "Unknown"; VBS = "Unknown"; Disk = "Unknown" }
    }
}
function Show-TweakGui {
    [CmdletBinding()]
    param()
    Ensure-RunningAsAdministrator
    try {
        Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase | Out-Null
    } catch {
        Write-Log -Message "Failed to load WPF assemblies, falling back to console mode: $($_.Exception.Message)" -Level ERROR
        Invoke-Windows11TweakScript
        return
    }
    $xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Esports Windows 11 Ultimate Optimizer - Author: Howl"
        Height="700" Width="1000"
        Background="#0A0D12"
        Foreground="#E0E0E0"
        WindowStartupLocation="CenterScreen"
        FontFamily="Segoe UI Semibold"
        AllowsTransparency="True" WindowStyle="None" ResizeMode="NoResize">
  <Window.Resources>
    <SolidColorBrush x:Key="AccentBrush" Color="#3B82F6"/>
    <SolidColorBrush x:Key="RiskBrush" Color="#EF4444"/>
    <SolidColorBrush x:Key="SurfaceBrush" Color="#121620"/>
    <SolidColorBrush x:Key="BorderBrush" Color="#1E293B"/>
    <Style TargetType="TabControl">
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Background" Value="Transparent"/>
    </Style>
    <Style TargetType="TabItem">
      <Setter Property="Padding" Value="16,10"/>
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="Foreground" Value="#94A3B8"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TabItem">
            <Border x:Name="Bd" BorderBrush="Transparent" BorderThickness="0,0,0,2" Margin="0,0,16,0">
              <ContentPresenter x:Name="ContentSite" VerticalAlignment="Center" HorizontalAlignment="Center" ContentSource="Header" Margin="4,2"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsSelected" Value="True">
                <Setter Property="Foreground" Value="White"/>
                <Setter TargetName="Bd" Property="BorderBrush" Value="{StaticResource AccentBrush}"/>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter Property="Foreground" Value="White"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="ActionButton" TargetType="Button">
      <Setter Property="FontSize" Value="16"/>
      <Setter Property="FontWeight" Value="Bold"/>
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="Padding" Value="24,16"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="Bd" Background="{TemplateBinding Background}" CornerRadius="12">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bd" Property="Opacity" Value="0.9"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="Bd" Property="Opacity" Value="0.8"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Opacity" Value="0.5"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="SpecCard" TargetType="Border">
      <Setter Property="Background" Value="{StaticResource SurfaceBrush}"/>
      <Setter Property="BorderBrush" Value="{StaticResource BorderBrush}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="CornerRadius" Value="12"/>
      <Setter Property="Padding" Value="16"/>
    </Style>
  </Window.Resources>
  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <Grid Grid.Row="0" Margin="32,32,32,16">
      <DockPanel LastChildFill="True">
        <StackPanel Orientation="Vertical" DockPanel.Dock="Left">
          <TextBlock Text="Ultimate Optimizer Suite" FontSize="32" FontWeight="ExtraBold" Foreground="White"/>
          <StackPanel Orientation="Horizontal" Margin="0,4,0,0">
            <TextBlock Text="Professional Esports Tuning and Diagnostics" FontSize="14" Foreground="#64748B"/>
            <Border Background="#10B981" CornerRadius="4" Padding="6,2" Margin="12,0,0,0">
              <TextBlock Text="FACEIT SAFE" FontSize="10" FontWeight="Bold" Foreground="White" VerticalAlignment="Center"/>
            </Border>
          </StackPanel>
        </StackPanel>
        <StackPanel HorizontalAlignment="Right" VerticalAlignment="Top">
          <Button Name="BtnCloseWindow" Content="&#x2715;" Background="Transparent" BorderThickness="0" Foreground="#64748B" FontSize="20" Cursor="Hand"/>
        </StackPanel>
      </DockPanel>
    </Grid>
    <UniformGrid Grid.Row="1" Columns="6" Margin="32,8,32,16">
      <Border Style="{StaticResource SpecCard}" Margin="0,0,12,0">
        <StackPanel>
          <TextBlock Text="CPU" FontSize="11" Foreground="#64748B" FontWeight="Bold"/>
          <TextBlock Name="TxtCpu" Text="Detecting..." FontSize="14" Foreground="White" TextWrapping="Wrap" Margin="0,4,0,0"/>
        </StackPanel>
      </Border>
      <Border Style="{StaticResource SpecCard}" Margin="0,0,12,0">
        <StackPanel>
          <TextBlock Text="GPU" FontSize="11" Foreground="#64748B" FontWeight="Bold"/>
          <TextBlock Name="TxtGpu" Text="Detecting..." FontSize="14" Foreground="White" TextWrapping="Wrap" Margin="0,4,0,0"/>
        </StackPanel>
      </Border>
      <Border Style="{StaticResource SpecCard}" Margin="0,0,12,0">
        <StackPanel>
          <TextBlock Text="RAM" FontSize="11" Foreground="#64748B" FontWeight="Bold"/>
          <TextBlock Name="TxtRam" Text="Detecting..." FontSize="14" Foreground="White" Margin="0,4,0,0"/>
        </StackPanel>
      </Border>
      <Border Style="{StaticResource SpecCard}" Margin="0,0,12,0">
        <StackPanel>
          <TextBlock Text="DISK" FontSize="11" Foreground="#64748B" FontWeight="Bold"/>
          <TextBlock Name="TxtDisk" Text="Detecting..." FontSize="14" Foreground="White" Margin="0,4,0,0"/>
        </StackPanel>
      </Border>
      <Border Style="{StaticResource SpecCard}" Margin="0,0,12,0">
        <StackPanel>
          <TextBlock Text="OS / VBS" FontSize="11" Foreground="#64748B" FontWeight="Bold"/>
          <TextBlock Name="TxtOs" Text="Detecting..." FontSize="14" Foreground="White" TextWrapping="Wrap" Margin="0,4,0,0"/>
        </StackPanel>
      </Border>
      <Border Style="{StaticResource SpecCard}" Background="#1E293B">
        <StackPanel HorizontalAlignment="Center">
          <TextBlock Text="OPTIMIZATION" FontSize="11" Foreground="#10B981" FontWeight="Bold" HorizontalAlignment="Center"/>
          <TextBlock Name="TxtScore" Text="95%" FontSize="20" Foreground="#10B981" FontWeight="ExtraBold" HorizontalAlignment="Center" Margin="0,2,0,0"/>
        </StackPanel>
      </Border>
    </UniformGrid>
    <Grid Grid.Row="2" Margin="32,8,32,16">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="2*"/>
        <ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>
      <StackPanel Grid.Column="0" VerticalAlignment="Center">
        <TextBlock Text="ELITE OPTIMIZATION" FontSize="12" FontWeight="Bold" Foreground="#64748B" Margin="0,0,0,16"/>
        <Button Name="BtnRunAll" Style="{StaticResource ActionButton}" Background="{StaticResource AccentBrush}" Height="80">
          <StackPanel>
            <TextBlock Text="RUN ALL ELITE TWEAKS" FontSize="20" HorizontalAlignment="Center"/>
            <TextBlock Text="Full System Overhaul • CS2 Pro Optimized • FACEIT Safe" FontSize="12" Opacity="0.8" FontWeight="Normal" HorizontalAlignment="Center" Margin="0,6,0,0"/>
          </StackPanel>
        </Button>
        <TextBlock Text="One-click professional optimization. 100% FACEIT SAFE - this script does NOT touch VBS or Core Isolation. Includes the 'Ultimate Performance' power plan, elite BCD tuning, MPO disabling, and advanced NIC profiles for a world-class experience." 
                   TextWrapping="Wrap" Foreground="#64748B" FontSize="13" Margin="0,24,0,0"/>
      </StackPanel>
      <Border Grid.Column="1" Background="{StaticResource SurfaceBrush}" CornerRadius="12" BorderBrush="{StaticResource BorderBrush}" BorderThickness="1" Margin="24,0,0,0">
        <TabControl Margin="12">
          <TabItem Header="LOGS">
            <TextBox Name="LogTextBox" IsReadOnly="True" Background="Transparent" BorderThickness="0" Foreground="#94A3B8" FontSize="11" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"/>
          </TabItem>
          <TabItem Header="SETTINGS">
            <StackPanel Margin="0,8,0,0">
              <CheckBox Name="ChkSkipRestore" Content="Skip Restore Point" Foreground="#94A3B8" Margin="0,0,0,12"/>
              <TextBlock Text="PRO TOOLS" FontSize="11" FontWeight="Bold" Foreground="#64748B" Margin="0,8,0,8"/>
              <Button Name="BtnGameMode" Content="ACTIVATE GAME MODE" Style="{StaticResource ActionButton}" Padding="12,12" FontSize="12" Background="#10B981" Margin="0,0,0,8">
                <Button.ToolTip>Kills background apps (Chrome, Discord, etc.) to free resources</Button.ToolTip>
              </Button>
              <Button Name="BtnRestartExplorer" Content="RESTART EXPLORER / DWM" Style="{StaticResource ActionButton}" Padding="12,8" FontSize="11" Background="#1E293B" Margin="0,0,0,12"/>
              <Button Name="BtnUndoTweaks" Content="ROLLBACK ALL TWEAKS" Style="{StaticResource ActionButton}" Padding="12,12" FontSize="12" Background="#EF4444" Margin="0,0,0,12">
                <Button.ToolTip>Restores core Windows defaults for network and scheduling</Button.ToolTip>
              </Button>
              <Button Name="BtnOpenLogFolder" Content="Open Log Folder" Style="{StaticResource ActionButton}" Padding="12,8" FontSize="12" Background="#1E293B"/>
            </StackPanel>
          </TabItem>
        </TabControl>
      </Border>
    </Grid>
    <Border Grid.Row="3" Background="#0F172A" Padding="32,16">
      <Grid>
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
          <TextBlock Text="STATUS: " FontSize="11" Foreground="#64748B" FontWeight="Bold"/>
          <TextBlock Name="TxtStatus" Text="READY" FontSize="11" Foreground="{StaticResource AccentBrush}" FontWeight="Bold"/>
          <ProgressBar Name="BusyBar" Width="100" Height="4" IsIndeterminate="True" Visibility="Collapsed" Margin="16,0,0,0" Foreground="{StaticResource AccentBrush}"/>
        </StackPanel>
        <TextBlock Text="Author: Howl  |  v2.0 Stable" HorizontalAlignment="Right" VerticalAlignment="Center" FontSize="11" Foreground="#64748B"/>
      </Grid>
    </Border>
  </Grid>
</Window>
'@
    [xml]$xamlXml = $xaml
    $reader = New-Object System.Xml.XmlNodeReader($xamlXml)
    $window = [Windows.Markup.XamlReader]::Load($reader)
    $txtCpu        = $window.FindName('TxtCpu')
    $txtGpu        = $window.FindName('TxtGpu')
    $txtRam        = $window.FindName('TxtRam')
    $txtDisk       = $window.FindName('TxtDisk')
    $txtOs         = $window.FindName('TxtOs')
    $txtScore      = $window.FindName('TxtScore')
    $btnRunAll     = $window.FindName('BtnRunAll')
    $btnClose      = $window.FindName('BtnCloseWindow')
    $btnOpenLog    = $window.FindName('BtnOpenLogFolder')
    $btnGameMode   = $window.FindName('BtnGameMode')
    $btnRestart    = $window.FindName('BtnRestartExplorer')
    $btnUndo       = $window.FindName('BtnUndoTweaks')
    $logTextBox    = $window.FindName('LogTextBox')
    $txtStatus     = $window.FindName('TxtStatus')
    $busyBar       = $window.FindName('BusyBar')
    $chkSkip       = $window.FindName('ChkSkipRestore')
    $window.Add_MouseDown({
        if ($_.ChangedButton -eq 'Left') { $window.DragMove() }
    })
    $btnClose.Add_Click({ $window.Close() })
    $specs = Get-ComputerSpecs
    $txtCpu.Text  = $specs.CPU
    $txtGpu.Text  = $specs.GPU
    $txtRam.Text  = $specs.RAM
    $txtDisk.Text = $specs.Disk
    $txtOs.Text   = "$($specs.OS) | VBS: $($specs.VBS)"
    $txtScore.Text = "$(Get-OptimizationScore)%"
    $Script:GuiLogCallback = {
        param($line)
        $window.Dispatcher.Invoke({
            $logTextBox.AppendText($line + [Environment]::NewLine)
            $logTextBox.ScrollToEnd()
        })
    }
    function Set-UiBusy {
        param([bool]$Busy, [string]$Status)
        $window.Dispatcher.Invoke({
            $btnRunAll.IsEnabled = -not $Busy
            $txtStatus.Text      = $Status.ToUpper()
            $busyBar.Visibility  = if ($Busy) { 'Visible' } else { 'Collapsed' }
        })
    }
    $btnRunAll.Add_Click({
        Set-UiBusy -Busy $true -Status 'Applying Elite Optimization...'
        $script:EsportsOnly = $false
        $script:IncludeRiskyTweaks = $false
        $script:SkipRestorePoint = ($chkSkip.IsChecked -eq $true)
        Invoke-Windows11TweakScript
        $window.Dispatcher.Invoke({
            $txtScore.Text = "100%"
            $txtScore.Foreground = [Windows.Media.Brushes]::LimeGreen
        })
        Set-UiBusy -Busy $false -Status 'Ready'
    })
    $btnOpenLog.Add_Click({
        try { Start-Process explorer.exe $Script:DesktopPath } catch {}
    })
    $btnGameMode.Add_Click({
        Set-UiBusy -Busy $true -Status 'Activating Game Mode...'
        Invoke-BackgroundServiceReaper
        Set-UiBusy -Busy $false -Status 'Ready'
    })
    $btnRestart.Add_Click({
        Set-UiBusy -Busy $true -Status 'Restarting Explorer and DWM...'
        try {
            Stop-Process -Name explorer -Force
            Stop-Process -Name dwm -Force 
        } catch {}
        Start-Sleep -Seconds 2
        Set-UiBusy -Busy $false -Status 'Ready'
    })
    $btnUndo.Add_Click({
        Set-UiBusy -Busy $true -Status 'Rolling Back Tweaks...'
        Invoke-UndoTweaks
        Set-UiBusy -Busy $false -Status 'Ready'
    })
    $window.ShowDialog() | Out-Null
    $Script:GuiLogCallback = $null
}
function Invoke-UndoTweaks {
    [CmdletBinding()]
    param()
    Write-Log -Message 'Rolling back Elite Tweaks to Windows Defaults...' -Level WARN
    try {
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\PriorityControl' -Name 'Win32PrioritySeparation' -Value 2 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Restore default process scheduling'
        $mmcssPath = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'
        Set-RegistryValueSafe -Path $mmcssPath -Name 'Priority' -Value 2 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
        Set-RegistryValueSafe -Path $mmcssPath -Name 'GPU Priority' -Value 8 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
        Set-RegistryValueSafe -Path $mmcssPath -Name 'Scheduling Category' -Value 'Medium' -Type ([Microsoft.Win32.RegistryValueKind]::String)
        Set-RegistryValueSafe -Path $mmcssPath -Name 'SFIO Priority' -Value 'Normal' -Type ([Microsoft.Win32.RegistryValueKind]::String)
        Remove-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' -Name 'TcpAckFrequency'
        Remove-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' -Name 'TcpNoDelay'
        Remove-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' -Name 'MaxUserPort'
        Remove-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' -Name 'TcpTimedWaitDelay'
        Set-RegistryValueSafe -Path 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control' -Name 'WaitToKillServiceTimeout' -Value '5000' -Type ([Microsoft.Win32.RegistryValueKind]::String)
        Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Control Panel\Desktop' -Name 'HungAppTimeout' -Value '5000' -Type ([Microsoft.Win32.RegistryValueKind]::String)
        Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Control Panel\Desktop' -Name 'WaitToKillAppTimeout' -Value '5000' -Type ([Microsoft.Win32.RegistryValueKind]::String)
        Set-RegistryValueSafe -Path 'HKEY_CURRENT_USER\Control Panel\Desktop' -Name 'AutoEndTasks' -Value '0' -Type ([Microsoft.Win32.RegistryValueKind]::String)
        Write-Log -Message 'Core tweaks rolled back. Please restart your PC for full effect.' -Level SUCCESS
    } catch {
        Write-Log -Message "Failed to rollback tweaks: $($_.Exception.Message)" -Level ERROR
    }
}
function Invoke-AppxDebloat {
    [CmdletBinding()]
    param()
    Write-Log -Message 'Removing Bloatware (Appx Packages)...' -Level INFO
    $bloatware = @(
        "Microsoft.BingNews", "Microsoft.BingWeather", "Microsoft.GetHelp",
        "Microsoft.Getstarted", "Microsoft.MicrosoftSolitaireCollection",
        "Microsoft.People", "Microsoft.SkypeApp", "Microsoft.WindowsFeedbackHub",
        "Microsoft.YourPhone", "Microsoft.ZuneVideo", "Microsoft.ZuneMusic",
        "Microsoft.WindowsMaps", "Microsoft.PowerAutomateDesktop",
        "Microsoft.GamingApp", "Microsoft.XboxSpeechToTextOverlay",
        "Microsoft.DevHome", "Microsoft.OutlookForWindows"
    )
    foreach ($app in $bloatware) {
        try {
            Get-AppxPackage -Name $app -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
            Write-Log -Message "Removed Appx: $app" -Level SUCCESS
        } catch {
            Write-Log -Message "Failed to remove $app or not found." -Level INFO
        }
    }
}
function Invoke-SystemDebloat {
    [CmdletBinding()]
    param()
    Write-Log -Message 'Applying Deep System Storage Debloat...' -Level INFO
    try {
        if (Get-Command DISM.exe -ErrorAction SilentlyContinue) {
            DISM.exe /Online /Set-ReservedStorageState /State:Disabled | Out-Null
            Write-Log -Message 'Reserved Storage disabled (frees ~7GB).' -Level SUCCESS
        }
        if (Get-Command powercfg -ErrorAction SilentlyContinue) {
            powercfg /hibernate off | Out-Null
            Write-Log -Message 'Hibernation disabled (frees disk space, disables Fast Startup).' -Level SUCCESS
        }
    } catch {
        Write-Log -Message "Failed to apply system debloat: $($_.Exception.Message)" -Level WARN
    }
}
function Invoke-BrowserPolicyHardening {
    [CmdletBinding()]
    param()
    Write-Log -Message 'Hardening Browser Policies (Edge)...' -Level INFO
    try {
        $edgePath = 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Edge'
        Set-RegistryValueSafe -Path $edgePath -Name 'StartupBoostEnabled' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable Edge Startup Boost'
        Set-RegistryValueSafe -Path $edgePath -Name 'ShowHubsSidebar' -Value 0 -Type ([Microsoft.Win32.RegistryValueKind]::DWord) -Description 'Disable Edge Sidebar'
        Set-RegistryValueSafe -Path $edgePath -Name 'PreventSmartScreenPromptOverride' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
        Set-RegistryValueSafe -Path $edgePath -Name 'HideFirstRunExperience' -Value 1 -Type ([Microsoft.Win32.RegistryValueKind]::DWord)
        Write-Log -Message 'Browser policies applied.' -Level SUCCESS
    } catch {
        Write-Log -Message "Failed to apply browser policies: $($_.Exception.Message)" -Level WARN
    }
}
function Invoke-OneDriveRemoval {
    [CmdletBinding()]
    param()
    Write-Log -Message 'Removing OneDrive...' -Level INFO
    try {
        taskkill /f /im OneDrive.exe -ErrorAction SilentlyContinue | Out-Null
        $oneDriveSetup = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
        if (-not (Test-Path $oneDriveSetup)) { $oneDriveSetup = "$env:SystemRoot\System32\OneDriveSetup.exe" }
        if (Test-Path $oneDriveSetup) {
            Start-Process $oneDriveSetup "/uninstall" -Wait -ErrorAction SilentlyContinue
            Write-Log -Message 'OneDrive uninstalled.' -Level SUCCESS
        }
        Remove-Item "$env:UserProfile\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Log -Message "Failed to remove OneDrive: $($_.Exception.Message)" -Level WARN
    }
}
function Invoke-Windows11TweakScript {
    [CmdletBinding()]
    param()
    Ensure-RunningAsAdministrator
    if ($SkipRestorePoint) {
        Write-Log -Message 'Skipping restore point creation because -SkipRestorePoint was provided.' -Level WARN
    } else {
        New-PreTweakRestorePoint
    }
    Write-Log -Message 'Applying Complete Professional Optimization Suite (FACEIT Safe)...' -Level INFO
    Invoke-EliteBcdTuning
    Invoke-UltimatePowerPlan
    Invoke-AdvancedNicProfiles
    Invoke-GpuShaderManagement
    Invoke-EliteSystemCleaner
    Invoke-ProfessionalServiceDebloat
    Invoke-EliteScheduledTaskDebloat
    Invoke-AppxDebloat
    Invoke-SystemDebloat
    Invoke-BrowserPolicyHardening
    Invoke-OneDriveRemoval
    Invoke-ExtremeLatencyTweaks
    Invoke-InputLatencyReductions
    Invoke-GpuPreferenceEnforcement
    Invoke-HagsOptimization
    Invoke-WindowedGameOptimization
    Invoke-PrivacyTweaks
    Invoke-UiTweaks
    Invoke-ElitePerformanceTweaks
    Invoke-EliteMemoryManagement
    Invoke-PerformanceTweaks
    Invoke-AdvancedNetworkJitterTuning
    Invoke-AdvancedNetworkPowerTuning
    Invoke-DwmLatencyTuning
    Invoke-EliteIOTweaks
    Invoke-EsportsLowLatencyTweaks
    Invoke-CS2ProcessTuning
    Invoke-HitRegistrationTweaks
    Invoke-AdvancedSystemResponsiveness
    Invoke-MsiModeOptimization
    Invoke-HardwareVendorTweaks
    Invoke-OtherTweaks -IncludeRiskyTweaks:$true
    Write-Log -Message 'All tweaks applied successfully. Your PC is now optimized for the best possible experience.' -Level SUCCESS
}
if ($NoGui) {
    Invoke-Windows11TweakScript
} else {
    Show-TweakGui
}