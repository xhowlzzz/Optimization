function Show-Dashboard {
    [CmdletBinding()]
    param()

    Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Drawing

    # Load XAML
    try {
        $xamlPath = Join-Path $PSScriptRoot "MainWindow.xaml"
        if (-not (Test-Path $xamlPath)) { throw "MainWindow.xaml not found at $xamlPath" }
        
        # File Integrity Check
        $expectedHash = "54EDAE5C0F96E646728F4072A22E8D3AFD6F523B2E64F76FD11A7B7651797CCF"
        $currentHash = (Get-FileHash $xamlPath -Algorithm SHA256).Hash
        if ($currentHash -ne $expectedHash) {
            Write-Log -Message "CORRUPT: MainWindow.xaml hash mismatch. Expected $expectedHash, got $currentHash" -Level WARN -Component "UI"
            # We continue but warn
        }

        [xml]$xaml = Get-Content $xamlPath -Raw
        $reader = New-Object System.Xml.XmlNodeReader($xaml)
        $window = [Windows.Markup.XamlReader]::Load($reader)
    } catch {
        $ex = $_.Exception
        $inner = if ($ex.InnerException) { $ex.InnerException.Message } else { "None" }
        $errorMsg = "CRITICAL UI ERROR: Failed to load MainWindow.xaml.`n`nError: $($ex.Message)`nInner Exception: $inner`n`nTroubleshooting:`n1. Ensure .NET Framework 4.7.2+ is installed.`n2. Check for file corruption."
        
        Write-Log -Message $errorMsg -Level ERROR -Component "UI"
        Write-Error $errorMsg
        
        # We can use a MessageBox if available, otherwise just console error
        if ([System.Windows.MessageBox]::Show($errorMsg, "Optimizer Load Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) -eq 'OK') {}
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
        ChkUpdates = $window.FindName("ChkUpdates")
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

    # ---------------------------------------------------------
    # HELPER FUNCTIONS
    # ---------------------------------------------------------

    function Initialize-Benchmarks {
        param($c)
        
        # Ping Test
        if (-not $c.ContainsKey('BtnRunPing')) {
            $c.BtnRunPing = $c.Window.FindName("BtnRunPing")
            $c.TxtPingResult = $c.Window.FindName("TxtPingResult")
            $c.PbPing = $c.Window.FindName("PbPing")
            
            $c.BtnRunPing.Add_Click({
                $c.BtnRunPing.IsEnabled = $false
                $c.TxtPingResult.Text = "Testing..."
                $c.PbPing.IsIndeterminate = $true
                
                $c.Window.Dispatcher.Invoke({
                    Start-Sleep -Milliseconds 500
                    $ping = Test-Connection -ComputerName 1.1.1.1 -Count 4 -ErrorAction SilentlyContinue | Measure-Object -Property ResponseTime -Average
                    
                    $c.PbPing.IsIndeterminate = $false
                    if ($ping) {
                        $avg = [math]::Round($ping.Average)
                        $c.TxtPingResult.Text = "$avg ms (Cloudflare DNS)"
                        $val = 100 - $avg
                        if ($val -lt 0) { $val = 0 }
                        if ($val -gt 100) { $val = 100 }
                        $c.PbPing.Value = $val
                    } else {
                        $c.TxtPingResult.Text = "Timeout"
                    }
                    $c.BtnRunPing.IsEnabled = $true
                }, [System.Windows.Threading.DispatcherPriority]::Background)
            })
        }

        # Disk Test
        if (-not $c.ContainsKey('BtnRunDisk')) {
            $c.BtnRunDisk = $c.Window.FindName("BtnRunDisk")
            $c.TxtDiskResult = $c.Window.FindName("TxtDiskResult")
            $c.PbDisk = $c.Window.FindName("PbDisk")
            
            $c.BtnRunDisk.Add_Click({
                $c.BtnRunDisk.IsEnabled = $false
                $c.TxtDiskResult.Text = "Testing (may take 1-2 mins)..."
                $c.PbDisk.IsIndeterminate = $true
                
                $c.Window.Dispatcher.Invoke({
                    Start-Sleep -Milliseconds 500
                    
                    # Run WinSAT if needed
                    $disk = Get-CimInstance Win32_WinSAT
                    if (-not $disk -or $disk.DiskScore -eq 0) {
                        Start-Process -FilePath "winsat" -ArgumentList "disk -drive c -ran -read -count 10" -WindowStyle Hidden -Wait
                        $disk = Get-CimInstance Win32_WinSAT
                    }
                    
                    $c.PbDisk.IsIndeterminate = $false
                    if ($disk) {
                        $score = $disk.DiskScore
                        $c.TxtDiskResult.Text = "Disk Score: $score / 9.9"
                        $c.PbDisk.Value = ($score * 100)
                    } else {
                        $c.TxtDiskResult.Text = "Assessment Failed (Run as Admin)"
                    }
                    $c.BtnRunDisk.IsEnabled = $true
                }, [System.Windows.Threading.DispatcherPriority]::Background)
            })
        }
    }

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

        # Special logic for Benchmark view
        if ($view.Name -eq "ViewBenchmarks") {
            Initialize-Benchmarks $c
        }
    }

    $c.BtnDash.Add_Click({ & $navAction $c.BtnDash $c.ViewDash "IlumnulOS Dashboard" })
    $c.BtnTweaks.Add_Click({ & $navAction $c.BtnTweaks $c.ViewTweaks "Performance Tweaks" })
    $c.BtnBench.Add_Click({ & $navAction $c.BtnBench $c.ViewBench "Benchmarks" })
    $c.BtnLogs.Add_Click({ & $navAction $c.BtnLogs $c.ViewLogs "Activity Logs" })
    $c.BtnSet.Add_Click({ & $navAction $c.BtnSet $c.ViewSet "Settings" })

    # ---------------------------------------------------------
    # AUTO-UPDATE CHECK (Async)
    # ---------------------------------------------------------
    $updateJob = $null
    if ($c.ChkUpdates -and $c.ChkUpdates.IsChecked -eq $true) {
        $updatePath = Join-Path $PSScriptRoot "..\Core\Update.psm1"
        if (Test-Path $updatePath) {
            $updateJob = Start-Job -ScriptBlock {
                param($path)
                function Write-Log { param($Message, $Level, $Component) Write-Output "[$Level] $Component : $Message" }
                Import-Module $path
                Update-Win11Tweaks -CurrentVersion "2.0.8"
            } -ArgumentList $updatePath
        }
    }

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
            
            # Check Update Job
            if ($updateJob -and $updateJob.State -ne 'Running') {
                Receive-Job -Job $updateJob | ForEach-Object {
                    $c.TxtLog.AppendText("$($_)`n")
                    $c.TxtLog.ScrollToEnd()
                }
                Remove-Job -Job $updateJob -Force
                $updateJob = $null
            }
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
            Invoke-RemoveWindowsAI
            Invoke-InputOptimization
            
            $c.BtnRun.Content = "OPTIMIZATION COMPLETE"
            $c.BtnRun.Background = [System.Windows.Media.Brushes]::Green
            Start-Sleep -Seconds 2
            $c.BtnRun.IsEnabled = $true
            $c.BtnRun.Content = "RUN ILUMNULOS OPTIMIZATION"
            $c.BtnRun.Background = [System.Windows.Media.Brushes]::Blue
        }, [System.Windows.Threading.DispatcherPriority]::Background)
    })

    $window.ShowDialog() | Out-Null
    $timer.Stop()
}

Export-ModuleMember -Function Show-Dashboard
