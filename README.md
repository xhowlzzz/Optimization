# ⚡ Win11-EsportsTweaks (CS2 Ultimate Optimizer)

A professional-grade, open-source PowerShell optimization suite designed specifically for **Counter-Strike 2** and competitive gaming on **Windows 11 (24H2 Ready)**. 

This script applies hundreds of "paid-tier" registry and system tweaks to maximize FPS, eliminate micro-stutters, and ensure the lowest possible input latency—all while remaining **FACEIT Safe** and keeping critical security features intact.

![License](https://img.shields.io/badge/license-MIT-blue.svg) ![Platform](https://img.shields.io/badge/platform-Windows%2011-0078d7.svg) ![Game](https://img.shields.io/badge/game-CS2-orange.svg)

## 🚀 Key Features

### 🎮 **Performance & FPS**
*   **Ultimate Power Plan**: Unlocks hidden "Ultimate Performance" schemes, forcing 100% CPU frequency and disabling core parking.
*   **CS2 Priority Tuning**: Automatically sets `cs2.exe` to **High CPU** and **I/O Priority** via Image File Execution Options (IFEO).
*   **GPU Scheduling (HAGS)**: Enables Hardware-Accelerated GPU Scheduling for supported NVIDIA/AMD cards to reduce CPU overhead.
*   **MPO Disable**: Disables Multi-Plane Overlay to fix flickering and stuttering in fullscreen games.

### 🎯 **Input Latency & "1000Hz Feel"**
*   **0.5ms Timer Resolution**: Forces the system timer to the highest precision (`GlobalTimerResolutionRequests`) for instant input processing.
*   **USB Power Management**: Globally disables "Selective Suspend" and power saving for all USB devices to prevent wake-up latency.
*   **Mouse/Keyboard Optimization**: Reduces data queue sizes (`MouseDataQueueSize = 20`) for smoother high-polling rate (1000Hz-8000Hz) handling.
*   **Raw Input**: Disables Windows acceleration curves and smoothing for true 1:1 aim.

### 🌐 **Network & Hit Registration**
*   **Zero-Packet Delay**: Disables Nagle’s Algorithm (`TcpNoDelay`) and sets `TcpAckFrequency` to 1 for immediate packet sending.
*   **CS2 QoS Policies**: Creates custom DSCP 46 (Expedited Forwarding) rules to prioritize CS2 UDP traffic over all other network activity.
*   **NIC Debloat**: Disables Interrupt Moderation, Flow Control, and "Green Ethernet" power saving on your network adapter.

### 🧹 **Debloat & System Health**
*   **Appx Removal**: Strips bloatware like Bing News, Solitaire, People Bar, and the new web-based Outlook.
*   **Telemetry Killer**: Disables DiagTrack, WAP Push Service, and over 20+ scheduled telemetry tasks.
*   **Deep Cleaning**: Disables Hibernation (`hiberfil.sys`) and Reserved Storage to reclaim ~10GB+ of SSD space.
*   **Browser Hardening**: Prevents Edge from pre-launching processes at startup (`StartupBoostEnabled = 0`).

## 🛡️ Safety First (FACEIT Safe)
Unlike other "FPS Boosters," this script is built with anti-cheat compliance in mind:
*   ✅ **VBS / Core Isolation**: **UNTOUCHED**. We do not disable critical kernel security features.
*   ✅ **Restore Points**: Automatically creates a system restore point *before* applying any changes.
*   ✅ **Undo Button**: Includes a built-in "Rollback" feature to restore default Windows network and scheduling settings.

## 📥 Installation & Usage

### ⚡ One-Click Run (Recommended)
Run this command in **PowerShell (Admin)** to automatically download and start the optimizer:

```powershell
iwr -useb https://raw.githubusercontent.com/xhowlzzz/Optimization/refs/heads/main/Win11-EsportsTweaks.ps1 | iex
```

### 📦 Manual Download
1.  **Download**: Get the latest `Win11-EsportsTweaks.ps1` from the [Releases](#) page.
2.  **Run as Admin**: Right-click the file and select **"Run with PowerShell"**.
3.  **The GUI**:
    *   Click **"RUN ALL ELITE TWEAKS"** for the full optimization package.
    *   Use **"ACTIVATE GAME MODE"** before playing to kill background apps (Chrome, Discord, etc.).
    *   Check the **"Status"** bar to see VBS status and system specs.

### Command Line Mode
For power users or deployments, run without the GUI:
```powershell
.\Win11-EsportsTweaks.ps1 -NoGui
```

## ⚙️ Advanced Modules
The script includes specialized modules that run automatically:
*   **Invoke-ExtremeLatencyTweaks**: Disables Control Flow Guard (CFG) for `cs2.exe` and Fault Tolerant Heap (FTH).
*   **Invoke-MsiModeOptimization**: Switches your GPU and NIC to Message Signaled Interrupts (MSI) mode.
*   **Invoke-WindowedGameOptimization**: Forces "Legacy Flip Model" for lower latency in windowed/borderless modes.

## ⚠️ Disclaimer
While this script is designed to be safe, modifying registry keys and system services always carries some risk. **Always** let the script create the Restore Point (default behavior). The author is not responsible for any system instability.

---
*Created by Howl for the CS2 Community.*
