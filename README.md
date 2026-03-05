<div align="center">

# ⚡ Optimizare
### The Ultimate Windows Optimization Suite

<img src="assets/logo.png" alt="Optimizare Logo" width="300">

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Platform](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-0078D6.svg)](https://www.microsoft.com/windows)

</div>

---

## 📖 Description

**Optimizare** (formerly IlumnulOS) is a state-of-the-art Windows optimization toolkit designed for gamers, power users, and enthusiasts. Built entirely in PowerShell, it automates complex system tuning to reduce latency, increase FPS, and remove Microsoft bloatware.

From deep registry hacks to kernel-level mitigations, Optimizare applies industry-standard tweaks used by esports professionals, packaged into a modern, easy-to-use interface.

> ⚠️ **Disclaimer**: This tool makes significant changes to your system configuration. While tested for stability, **always create a System Restore point** before applying optimizations.

---

## ✨ Features

### 🚀 Performance & Kernel
- **Process Priority Management**: Hard-coded Realtime/High priority for `dwm.exe` and `ntoskrnl.exe`; Low priority for background services.
- **MMCSS Tuning**: Custom "Gaming" profile with `GPU Priority=8` and `Scheduling Category=High`.
- **Kernel Mitigations**: Disables Spectre/Meltdown patches (`MitigationOptions`) for maximum CPU throughput.
- **Memory Management**: Disables Memory Compression and Page Combining to reduce CPU overhead.

### 🧹 Debloating & Cleaning
- **Appx Remover**: Automated removal of ~30 pre-installed bloatware apps (Bing, Maps, Solitaire, etc.).
- **Telemetry Killswitch**:
  - Disables ~40 Data Collection Scheduled Tasks.
  - Blocks ~35 WMI AutoLoggers.
  - Hard-disables `DiagTrack` and `dmwappushservice`.
- **PC Cleaner**: Deep cleaning of Temp folders, Prefetch, Crash Dumps, and Log files.

### 🎮 Gaming & Graphics
- **GPU Optimization**:
  - Forces **Contiguous Memory Allocation**.
  - Enables **MPO** (Multiplane Overlay) and **FSO** (Full Screen Optimizations).
  - Sets DirectX Kernel Latency Tolerance to minimum (`1`).
- **Input Lag Reduction**: Disables USB Selective Suspend and "Sticky Keys" interrupts.

### 🌐 Network Stack
- **TCP Tuning**: Optimized `TcpMaxDataRetransmissions`, disabled Timestamps, and tuned `MaxFreeTcbs`.
- **Throttling Removal**: Disables `NetworkThrottlingIndex` and sets System Responsiveness to 100%.

### 🛠️ Hardware (DevManView)
- Automated disabling of high-latency devices:
  - High Precision Event Timer (HPET)
  - Intel Management Engine (IME)
  - Unused WAN Miniports
  - Legacy System Speakers

---

## 📥 Installation

1.  **Download** the latest release or clone the repository:
    ```powershell
    git clone https://github.com/xhowlzzz/Optimizare.git
    ```
2.  **Navigate** to the folder:
    ```powershell
    cd Optimizare
    ```

---

## 🛠️ Usage

1.  **Run as Administrator**:
    Right-click `IlumnulOS.ps1` and select **"Run with PowerShell"**.
    
    *Or run via terminal:*
    ```powershell
    Set-ExecutionPolicy Unrestricted -Scope Process -Force
    .\IlumnulOS.ps1
    ```

2.  **Dashboard**:
    The GUI dashboard will launch. Select your desired optimizations.

3.  **Apply & Reboot**:
    Click **"Optimize"** and wait for the log to report completion. **Restart your PC** to finalize changes.

---

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1.  Fork the repository.
2.  Create a feature branch (`git checkout -b feature/AmazingFeature`).
3.  Commit your changes (`git commit -m 'Add some AmazingFeature'`).
4.  Push to the branch (`git push origin feature/AmazingFeature`).
5.  Open a Pull Request.

---

## 📜 License

Distributed under the MIT License. See `LICENSE` for more information.

---

<div align="center">
  <sub>Built with ❤️ for the Windows Community</sub>
</div>
