# CS2 Performance & Hit Registration Benchmarking Protocol

To measure the effectiveness of the "Elite Esports Optimizer" suite, follow these standardized protocols.

## 1. FPS & Stability Metrics (CapFrameX / 3DMark)
*   **Tool**: [CapFrameX](https://www.capframex.com/) (Recommended) or [MSI Afterburner + RivaTuner].
*   **Metric**: Focus on **1% Lows** and **0.1% Lows** rather than just average FPS. Consistent hit registration requires stable frame times.
*   **Test Environment**:
    *   Map: `de_dust2` or a dedicated benchmark map like `fps_benchmark` from the workshop.
    *   Duration: 120 seconds of a consistent bot match or a demo replay.
*   **Goal**: An increase in 1% lows indicates reduced stuttering and more reliable input/hit processing.

## 2. Input Latency (NVIDIA Reflex / LDAT)
*   **Tool**: NVIDIA Reflex Analyzer (if hardware is available) or the in-game `r_show_build_info` (which shows frame latency).
*   **Metric**: `Frame Latency` in milliseconds.
*   **Test**: Compare the "Before" and "After" latency values in the main menu and during active combat.
*   **Goal**: Lower frame latency directly correlates to faster "click-to-pixel" response.

## 3. Hit Registration Accuracy (In-Game Analysis)
*   **Tool**: `cq_netgraph 1` (Sub-tick network graph in CS2).
*   **Metric**: Observe the "Tick" and "Sub-tick" consistency bars.
*   **Test**:
    *   Join a community DM or practice server with bot movement.
    *   Observe if the blue/green bars remain stable during rapid fire.
    *   **Registry Check**: After applying tweaks, use `ping` in console to verify jitter stability.
*   **Goal**: Minimal "red" or "yellow" spikes in the network graph indicates the NIC and TCP tweaks are successfully prioritizing game packets.

## 4. System Responsiveness (LatencyMon)
*   **Tool**: [LatencyMon](https://www.resplendence.com/latencymon).
*   **Metric**: `Highest reported DPC latency`.
*   **Test**: Run LatencyMon for 5 minutes while the PC is idle, then for 5 minutes while running CS2 in the background.
*   **Goal**: Values should be below **500μs** (Green). MSI Mode and Interrupt Moderation tweaks should significantly reduce DPC spikes.

---

# Configuration Changelog (Premium Update)

| Tweak Category | Configuration Change | Benefit |
| :--- | :--- | :--- |
| **Hit Registration** | `MaxUserPort` (65534), `TcpTimedWaitDelay` (30) | Faster port reuse and less network overhead. |
| **Network Priority** | `NonBestEffortLimit` (0) | Disables Windows QoS bandwidth capping. |
| **System Latency** | `WaitToKillServiceTimeout` (2000ms) | Faster system response during background tasks. |
| **CS2 IFEO** | `DisableHeapCoalesceOnFree` (1) | Reduces memory management overhead for `cs2.exe`. |
| **MMCSS Pro** | `Priority` (8), `GPU Priority` (18) | Absolute maximum priority for the "Games" scheduler. |
| **Process Scheduling** | `Win32PrioritySeparation` (0x28) | Premium foreground scheduling for lower input lag. |
| **MSI Mode** | `MSISupported` (1) for GPU & NIC | Uses Message Signaled Interrupts for lower DPC latency. |
| **GPU Scheduling** | `HwSchMode` (2) | Enables Hardware-Accelerated GPU Scheduling (HAGS) for supported hardware. |
| **Windowed Mode** | `SwapEffectUpgrade` (1) | Forces legacy flip model upgrade for lower latency in windowed games. |
| **Safety** | VBS / Core Isolation | **UNTOUCHED** for maximum system stability and security. |
