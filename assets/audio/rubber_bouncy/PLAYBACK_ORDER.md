# Playback Order & Cadence Guide: Rubber Bouncy

Sound Pack: **RUBBER_BOUNCY (Cartoon Springy Rubber Footstep)**

This sound pack delivers a buoyant, elastic, soft rubber impact reminiscent of cartoon bouncy shoes and playful physical compression.

---

## 1. Available Step Asset

| File | Identity | Duration | Acoustic Role |
| :--- | :--- | :--- | :--- |
| `rubber_01.mp3` | Springy Rubber Compression | 280 ms | Definitive stride step: soft, rounded rubber compression with subtle upward elastic inflection. |

---

## 2. Recommended Playback & Audio Engine Behavior

Since `rubber_01.mp3` was selected as the sole definitive sound for this pack, the playback engine can utilize it in two ways:

### A. Direct One-Shot Playback (Zero-Complexity Mode)
Trigger `rubber_01.mp3` on every confirmed step event:
```
Step 1: rubber_01.mp3
Step 2: rubber_01.mp3
Step 3: rubber_01.mp3
...
```
- **Consistent Metronome:** Offers uniform auditory feedback on every strike.
- **Short Decay (280 ms):** Decays cleanly before the next step at all cadences up to 180+ SPM.

### B. Micro-Pitch Alternation (Left / Right Humanization)
If STRADIO's sound player supports runtime pitch shifting (SoundPool / ExoPlayer playback rate $\pm 2\text{--}3\%$):
- **Left Foot Strike:** `rubber_01.mp3` played at **pitch = 1.00** (default baseline).
- **Right Foot Strike:** `rubber_01.mp3` played at **pitch = 1.03** (+3% semitone lift).

This simple programmatic modulation simulates left/right footfall divergence using a single clean asset without increasing app package size!

---

## 3. Cadence & SPM Compatibility

| Cadence (SPM) | Step Interval | Compatibility | Latency & Perception Notes |
| :--- | :--- | :--- | :--- |
| **100 SPM (Walking)** | 600 ms | **Optimal (5/5)** | Relaxed, springy stroll. Generous 320 ms headroom between steps. |
| **140 SPM (Jogging)** | 428 ms | **Optimal (5/5)** | Bouncy, buoyant groove. Leaves ~148 ms clean silence before next strike. |
| **180 SPM (Running)** | 333 ms | **Optimal (5/5)** | Fast, energetic bounce. 280 ms duration comfortably completes within the 333 ms window. |
