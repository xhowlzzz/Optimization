function Show-Dashboard {
    [CmdletBinding()]
    param()

    Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Drawing

    # Load XAML
    try {
        $xamlPath = Join-Path $PSScriptRoot "MainWindow.xaml"
        if (-not (Test-Path $xamlPath)) { throw "MainWindow.xaml not found at $xamlPath" }
        
        [xml]$xaml = Get-Content $xamlPath -Raw
        $reader = New-Object System.Xml.XmlNodeReader($xaml)
        $window = [Windows.Markup.XamlReader]::Load($reader)
    } catch {
        Write-Error "Failed to load UI: $($_.Exception.Message)"
        Write-Warning "Ensure you are running on Windows 10/11 with .NET Framework 4.7.2+"
        return
    }

    # ---------------------------------------------------------
    # UI CONTROLS BINDING
    # ---------------------------------------------------------
    $c = @{
        # Window
        Window = $window
        TitleBar = $window.FindName("TitleBar")
        BtnClose = $window.FindName("BtnClose")
        BtnMinimize = $window.FindName("BtnMinimize")
        
        # Navigation
        BtnDash = $window.FindName("BtnNavDashboard")
        BtnTweaks = $window.FindName("BtnNavTweaks")
        BtnBench = $window.FindName("BtnNavBenchmarks")
        BtnLogs = $window.FindName("BtnNavLogs")
        BtnSet = $window.FindName("BtnNavSettings")
        
        # Views
        ViewDash = $window.FindName("ViewDashboard")
        ViewTweaks = $window.FindName("ViewTweaks")
        ViewBench = $window.FindName("ViewBenchmarks")
        ViewLogs = $window.FindName("ViewLogs")
        ViewSet = $window.FindName("ViewSettings")
        TxtPageTitle = $window.FindName("TxtPageTitle")

        # Dashboard Widgets
        TxtGpu = $window.FindName("TxtGpuModel")
        TxtCpu = $window.FindName("TxtCpuModel")
        TxtOs = $window.FindName("TxtOsVersion")
        
        TxtCpuUsage = $window.FindName("TxtCpuUsage")
        PbCpu = $window.FindName("PbCpu")
        TxtCpuDetails = $window.FindName("TxtCpuDetails")
        
        TxtRamUsage = $window.FindName("TxtRamUsage")
        PbRam = $window.FindName("PbRam")
        TxtRamDetails = $window.FindName("TxtRamDetails")
        
        BtnRun = $window.FindName("BtnRunOptimization")
        TxtLog = $window.FindName("TxtLogPreview")
        TxtFullLog = $window.FindName("TxtFullLog")
    }

    # ---------------------------------------------------------
    # HARDWARE INFO
    # ---------------------------------------------------------
    try {
        $cpuInfo = Get-CimInstance Win32_Processor | Select-Object -First 1
        $osInfo = Get-CimInstance Win32_OperatingSystem
        $gpuInfo = Get-CimInstance Win32_VideoController | Select-Object -First 1
        
        $c.TxtCpu.Text = $cpuInfo.Name.Trim()
        $c.TxtGpu.Text = $gpuInfo.Name.Trim()
        $c.TxtOs.Text = ($osInfo.Caption -replace "Microsoft ", "").Trim()
        
        # Initial RAM calc
        $totalRamGB = [math]::Round($osInfo.TotalVisibleMemorySize / 1MB, 1)
        $c.TxtRamDetails.Text = "$totalRamGB GB Total Memory"
        $c.TxtCpuDetails.Text = "$($cpuInfo.NumberOfCores) Cores / $($cpuInfo.NumberOfLogicalProcessors) Threads"
    } catch {
        $c.TxtCpu.Text = "Unknown CPU"
    }

    # ---------------------------------------------------------
    # EVENT HANDLERS
    # ---------------------------------------------------------

    # Window Drag
    $c.TitleBar.Add_MouseDown({
        if ($_.ChangedButton -eq 'Left') { $window.DragMove() }
    })
    
    $c.BtnClose.Add_Click({ $window.Close() })
    $c.BtnMinimize.Add_Click({ $window.WindowState = 'Minimized' })

    # Navigation Logic
    $navAction = {
        param($sender, $view, $title)
        
        # Reset all buttons
        $c.BtnDash.IsEnabled = $true
        $c.BtnTweaks.IsEnabled = $true
        $c.BtnBench.IsEnabled = $true
        $c.BtnLogs.IsEnabled = $true
        $c.BtnSet.IsEnabled = $true
        
        # Highlight active
        $sender.IsEnabled = $false
        
        # Hide all views
        $c.ViewDash.Visibility = 'Collapsed'
        $c.ViewTweaks.Visibility = 'Collapsed'
        $c.ViewBench.Visibility = 'Collapsed'
        $c.ViewLogs.Visibility = 'Collapsed'
        $c.ViewSet.Visibility = 'Collapsed'
        
        # Show target
        $view.Visibility = 'Visible'
        $c.TxtPageTitle.Text = $title
    }

    $c.BtnDash.Add_Click({ & $navAction $c.BtnDash $c.ViewDash "System Dashboard" })
    $c.BtnTweaks.Add_Click({ & $navAction $c.BtnTweaks $c.ViewTweaks "Performance Tweaks" })
    $c.BtnBench.Add_Click({ & $navAction $c.BtnBench $c.ViewBench "Benchmarks" })
    $c.BtnLogs.Add_Click({ & $navAction $c.BtnLogs $c.ViewLogs "Activity Logs" })
    $c.BtnSet.Add_Click({ & $navAction $c.BtnSet $c.ViewSet "Settings" })

    # Metrics Timer
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromSeconds(1)
    $timer.Add_Tick({
        try {
            # CPU
            $cpu = Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average | Select-Object -ExpandProperty Average
            $c.TxtCpuUsage.Text = "$cpu%"
            $c.PbCpu.Value = $cpu
            
            # RAM
            $mem = Get-CimInstance Win32_OperatingSystem
            $used = $mem.TotalVisibleMemorySize - $mem.FreePhysicalMemory
            $perc = [math]::Round(($used / $mem.TotalVisibleMemorySize) * 100)
            $usedGB = [math]::Round($used / 1MB, 1)
            
            $c.TxtRamUsage.Text = "$perc%"
            $c.PbRam.Value = $perc
            $c.TxtRamDetails.Text = "$usedGB GB Used / $([math]::Round($mem.TotalVisibleMemorySize / 1MB, 1)) GB Total"
            
        } catch {}
    })
    $timer.Start()

    # Logger Callback
    $Script:GuiLogCallback = {
        param($line, $level)
        $window.Dispatcher.Invoke({
            $c.TxtLog.AppendText("$line`n")
            $c.TxtLog.ScrollToEnd()
            
            if ($c.TxtFullLog) {
                $c.TxtFullLog.AppendText("$line`n")
                $c.TxtFullLog.ScrollToEnd()
            }
        })
    }

    # Run Optimization
    $c.BtnRun.Add_Click({
        $c.BtnRun.IsEnabled = $false
        $c.BtnRun.Content = "OPTIMIZING..."
        
        $window.Dispatcher.Invoke({
            # Import Modules (Ensure paths are correct relative to PSScriptRoot)
            $modPath = Join-Path $PSScriptRoot "..\Modules"
            
            Import-Module (Join-Path $modPath "Network.psm1") -Force
            Import-Module (Join-Path $modPath "CPU.psm1") -Force
            Import-Module (Join-Path $modPath "GPU.psm1") -Force
            Import-Module (Join-Path $modPath "System.psm1") -Force
            Import-Module (Join-Path $modPath "Input.psm1") -Force

            # Run Tweaks
            Invoke-NetworkOptimization
            Invoke-CpuOptimization
            Invoke-GpuOptimization
            Invoke-SystemDebloat
            Invoke-InputOptimization
            
            $c.BtnRun.Content = "OPTIMIZATION COMPLETE"
            $c.BtnRun.Background = [System.Windows.Media.Brushes]::Green
            Start-Sleep -Seconds 2
            $c.BtnRun.IsEnabled = $true
            $c.BtnRun.Content = "RUN SYSTEM OPTIMIZATION"
            $c.BtnRun.Background = [System.Windows.Media.Brushes]::Blue
        }, [System.Windows.Threading.DispatcherPriority]::Background)
    })

    $window.ShowDialog() | Out-Null
    $timer.Stop()
}

Export-ModuleMember -Function Show-Dashboard
