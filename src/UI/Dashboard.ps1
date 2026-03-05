function Show-Dashboard {
    [CmdletBinding()]
    param()

    Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Drawing

    # Load XAML
    $xamlPath = Join-Path $PSScriptRoot "MainWindow.xaml"
    [xml]$xaml = Get-Content $xamlPath -Raw
    $reader = New-Object System.Xml.XmlNodeReader($xaml)
    $window = [Windows.Markup.XamlReader]::Load($reader)

    # Find Controls
    $controls = @{
        BtnClose = $window.FindName("BtnClose")
        BtnMinimize = $window.FindName("BtnMinimize")
        BtnRun = $window.FindName("BtnRunOptimization")
        TxtCpu = $window.FindName("TxtCpuUsage")
        PbCpu = $window.FindName("PbCpu")
        TxtRam = $window.FindName("TxtRamUsage")
        PbRam = $window.FindName("PbRam")
        TxtLog = $window.FindName("TxtLogPreview")
        ViewDash = $window.FindName("ViewDashboard")
        ViewTweaks = $window.FindName("ViewTweaks")
    }

    # Window Drag
    $window.Add_MouseDown({
        if ($_.ChangedButton -eq 'Left') { $window.DragMove() }
    })
    
    # Event Handlers
    $controls.BtnClose.Add_Click({ $window.Close() })
    $controls.BtnMinimize.Add_Click({ $window.WindowState = 'Minimized' })

    # Metrics Timer
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromSeconds(1)
    $timer.Add_Tick({
        try {
            $cpu = Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average | Select-Object -ExpandProperty Average
            $mem = Get-CimInstance Win32_OperatingSystem
            $ramUsed = [math]::Round(($mem.TotalVisibleMemorySize - $mem.FreePhysicalMemory) / $mem.TotalVisibleMemorySize * 100)
            
            $controls.TxtCpu.Text = "$cpu%"
            $controls.PbCpu.Value = $cpu
            $controls.TxtRam.Text = "$ramUsed%"
            $controls.PbRam.Value = $ramUsed
        } catch {}
    })
    $timer.Start()

    # Logger Callback
    $Script:GuiLogCallback = {
        param($line, $level)
        $window.Dispatcher.Invoke({
            $controls.TxtLog.AppendText("$line`n")
            $controls.TxtLog.ScrollToEnd()
        })
    }

    # Run Optimization
    $controls.BtnRun.Add_Click({
        $controls.BtnRun.IsEnabled = $false
        $controls.BtnRun.Content = "OPTIMIZING..."
        
        # Async Job (Simulated with simple loop for now to avoid threading complexity in pure PS GUI)
        # In a real app, use Runspaces.
        $window.Dispatcher.Invoke({
            # Import Modules
            Import-Module "$PSScriptRoot\..\Modules\Network.psm1" -Force
            Import-Module "$PSScriptRoot\..\Modules\CPU.psm1" -Force
            Import-Module "$PSScriptRoot\..\Modules\GPU.psm1" -Force
            Import-Module "$PSScriptRoot\..\Modules\System.psm1" -Force
            Import-Module "$PSScriptRoot\..\Modules\Input.psm1" -Force

            # Run Tweaks
            Invoke-NetworkOptimization
            Invoke-CpuOptimization
            Invoke-GpuOptimization
            Invoke-SystemDebloat
            Invoke-InputOptimization
            
            $controls.BtnRun.Content = "OPTIMIZATION COMPLETE"
            $controls.BtnRun.Background = [System.Windows.Media.Brushes]::Green
            Start-Sleep -Seconds 2
            $controls.BtnRun.IsEnabled = $true
            $controls.BtnRun.Content = "RUN SYSTEM OPTIMIZATION"
            $controls.BtnRun.Background = [System.Windows.Media.Brushes]::Blue
        }, [System.Windows.Threading.DispatcherPriority]::Background)
    })

    $window.ShowDialog() | Out-Null
    $timer.Stop()
}

Export-ModuleMember -Function Show-Dashboard
