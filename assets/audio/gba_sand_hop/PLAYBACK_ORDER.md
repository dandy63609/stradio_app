# Playback Order & Cadence Guide - GBA Sand Hop

Sound Pack: **GBA_SAND_HOP (16-Bit Hoenn Sand Brush & Triangle Thump)**

This sound pack delivers tactile 16-bit coastal trail footsteps tailored to pair with the Hoenn Coastal Island arrangement (`hoenn_island_loop.mp4`, `132.5 BPM` in D Major). Each sound effect represents one isolated footstep (`205 ms` to `235 ms`).

---

## 1. Available Step Variations

| File | Identity | Duration | Acoustic Role |
| :--- | :--- | :--- | :--- |
| `gba_sand_01.mp3` | 16-Bit Sand Brush + 108 Hz Triangle Thump (Left primary) | 215 ms | Primary left-foot anchor: stepped LFSR noise-channel sand brush (`1.9 - 3.9 kHz`) over a warm `108 -> 66 Hz` triangle-wave footfall thump. |
| `gba_sand_02.mp3` | Bright Grass/Sand Brush + 116 Hz Triangle Thump (Right primary) | 205 ms | Complementary right-foot anchor: slightly brighter grain transient (`2.2 - 4.2 kHz`) for natural left/right stride alternation. |
| `gba_sand_03.mp3` | GBA Hop Accent + D5/A5 Pulse Micro-Blip (4th-step accent) | 235 ms | Periodic cadence-lock accent: combines the sand footfall with a soft 25%-duty pulse overtone (`D5 587.33 Hz -> A5 880.00 Hz`) tuned to the track's D Major key. |

---

## 2. Recommended Playback Sequences

### A. Deterministic 4-Step Stride Loop (Default)

```
01 -> 02 -> 01 -> 03 -> Repeat
```

### B. Extended 8-Step Cadence Lock Sequence (For 150+ SPM Running)

```
01 -> 02 -> 01 -> 02 -> 01 -> 02 -> 01 -> 03 -> Repeat
```

#### Why This Sequence Works:
- **Spectral Separation from GBA Brass & Pads:** Because `89.1%` of the Hoenn Coastal track's energy sits between `120 Hz` and `1500 Hz`, `gba_sand_01` and `gba_sand_02` place their body punch at `66 - 116 Hz` and their tactile sand brush at `1.9 - 4.2 kHz`, cutting cleanly through all three sections of the arrangement without masking the melody.
- **Harmonic Key Alignment:** `gba_sand_03` is tuned to `D5 -> A5` (the root and fifth of D Major), reinforcing the harmonic progression of both the `0:00 - 0:30` brass route theme and the `0:30 - 0:59` coastal synth pad bridge.

---

## 3. Cadence & SPM Compatibility

| Cadence (SPM) | Step Interval | Compatibility | Latency & Perception Notes |
| :--- | :--- | :--- | :--- |
| **100 SPM (Walking)** | 600 ms | **Optimal (5/5)** | Crisp pixel-art island stroll with `365+ ms` of clean air between footsteps. |
| **132 SPM (Native Track Pulse)** | 453 ms | **Optimal (5/5)** | Locks 1:1 with the native `132.5 BPM` quarter-note pulse of `hoenn_island_loop.mp4`. |
| **156 SPM (Stradio Lock Zone)** | 385 ms | **Optimal (5/5)** | Zero tail overlap (`205 - 235 ms` step duration leaves `150+ ms` clearance). |
| **180 SPM (Fast Running)** | 333 ms | **Optimal (5/5)** | Tight transient envelope (`<15 ms` attack) prevents high-speed rhythmic smear. |

---

## 4. Audio Engine Integration Notes

- **Max Gain Target:** `-16 LUFS` integrated, `-1.2 dB` True Peak with `5 ms` linear micro-fades.
- **Primary Background Track Pairing:** `assets/audio/hoenn_island_loop.mp4` (`132.5 BPM`, D Major / B Minor).
