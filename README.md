# Optimizare âš¡

**Optimizare** (or IlumnulOS Optimizer) is a powerful, PowerShell-based Windows optimization suite designed to squeeze every last drop of performance from your system. It combines deep registry tweaks, service disabling, network stack tuning, and bloatware removal into a single, easy-to-use utility.

> âš ï¸ **Warning**: This tool applies aggressive optimizations. It is recommended to create a System Restore point before running.

## ðŸš€ Features

### **1. Extreme Performance Tweaks**
*   **Process Priority (IFEO)**: Hard-coded Realtime/High priority for critical system processes (`dwm.exe`, `ntoskrnl.exe`) and Low priority for background tasks (`SearchIndexer.exe`, `lsass.exe`).
*   **Multimedia Class Scheduler (MMCSS)**: Custom "Gaming" profile with `GPU Priority=8` and `Scheduling Category=High`.
*   **Kernel Optimizations**: Disabled `MitigationOptions` (Spectre/Meltdown patches), Memory Compression, and Page Combining for raw throughput.
*   **Power Throttling**: Disabled globally and specifically for Modern Standby (`CoalescingTimerInterval=0`).

### **2. Deep Debloating**
*   **Appx Removal**: Automatically removes ~30 bloatware apps (Bing, Solitaire, OfficeHub, Phone, Maps, etc.) while safely skipping protected system components.
*   **Telemetry Purge**:
    *   Disables ~40 Scheduled Tasks (CEIP, SQM, Family Safety).
    *   Blocks ~35 WMI AutoLoggers (Trace Sessions).
    *   Hard disables `DiagTrack` and `dmwappushservice`.
*   **Cortana & OneDrive**: Aggressive registry disables and full uninstall routines.

### **3. Gaming & Graphics**
*   **NVIDIA/AMD Optimization**:
    *   Disables HDCP, TCC, and Telemetry.
    *   Forces **Contiguous Memory Allocation** (`PreferSystemMemoryContiguous`).
    *   Sets **Latency Tolerance** to `1` (Lowest) for DirectX Kernel and Power management.
    *   Enables **MPO** (Multiplane Overlay) and **FSO** (Full Screen Optimizations).
*   **Input Lag Reduction**: Disables USB Selective Suspend, Sticky Keys shortcuts, and optimizes Mouse/Keyboard data queue sizes.

### **4. Network Tuning**
*   **TCP Stack**: Tuned `TcpMaxDataRetransmissions`, disabled `Tcp1323Opts` (Timestamps), and optimized `MaxFreeTcbs` for raw packet throughput.
*   **Throttling**: Disabled `NetworkThrottlingIndex` and set `SystemResponsiveness` to 10.

### **5. Hardware Disables (DevManView)**
*   Automatically downloads `DevManView` to disable high-overhead devices:
    *   High Precision Event Timer (HPET)
    *   WAN Miniports (IP, IPv6, PPTP, etc.)
    *   Intel Management Engine (IME) & SMBus
    *   System Speaker & Composite Bus Enumerator

### **6. PC Cleaner**
*   Safely cleans:
    *   Temp Folders (`%TEMP%`, `C:\Windows\Temp`)
    *   Prefetch
    *   Recycle Bin
    *   Thumbcache
    *   System Logs (`CBS.log`, `DISM.log`)

## ðŸ› ï¸ Usage

1.  **Run as Administrator**: Right-click `IlumnulOS.ps1` and select "Run with PowerShell".
2.  **Dashboard**: The tool will launch a GUI dashboard.
3.  **Apply Tweaks**: Click "Optimize" to apply all tweaks. The log window will show real-time progress.
4.  **Reboot**: Restart your computer for all changes (especially Registry and Service disables) to take effect.

## ðŸ“ Credits
*   **xhowlzzz**: Core developer.
*   **Ancel**: Source of many deep registry and batch optimizations.
*   **MelodyTheNeko**: Latency tolerance research.

---
*Built for Windows 10 & 11.*
