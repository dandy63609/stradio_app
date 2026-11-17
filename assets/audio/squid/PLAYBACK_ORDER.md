# Playback Order & Cadence Guide: Squid

Sound Pack: **SQUID (Classic Squidward Walking Footsteps)**

This pack features the iconic hollow, quirky, wooden suction clunks characteristic of Squidward's walking animation. Each file represents exactly one individual footstep.

---

## 1. Available Step Variations

| File | Identity | Duration | Acoustic Role |
| :--- | :--- | :--- | :--- |
| `squid_1.MP3` | Hollow Suction Clunk (Left Foot) | 235 ms | Primary left footstep: dry, hollow wooden impact with subtle suction snap. |
| `squid_2.MP3` | Hollow Suction Clunk (Right Foot) | 287 ms | Complementary right footstep: slightly longer acoustic body for alternating stride. |

---

## 2. Recommended Playback Sequence

### Deterministic Left / Right Alternation (Strict 1-2-1-2)

Recommended sequence:
```
1 → 2 → 1 → 2 → 1 → 2 → Repeat
```

#### Why This Sequence Works:
- **Left / Right Mechanical Realism:** Perfectly captures the alternating heel-strike of Squidward's distinctive gait.
- **Rhythmic Clarity:** Sharp attack transients (<15 ms) and compact durations (<290 ms) provide an exceptional metronomic tempo guide for runners.

---

## 3. Cadence & SPM Compatibility

| Cadence (SPM) | Step Interval | Compatibility | Notes |
| :--- | :--- | :--- | :--- |
| **100 SPM (Walking)** | 600 ms | **Optimal (5/5)** | The signature awkward, grumpy cartoon stride. 313 ms silence between steps. |
| **140 SPM (Jogging)** | 428 ms | **Optimal (5/5)** | Excellent driving rhythm. Both sounds decay completely 141 ms before the next step. |
| **180 SPM (Running)** | 333 ms | **Optimal (5/5)** | Ultra-clean fast run. At 287 ms max duration, there is 46 ms of silence between steps: zero overlapping or mud. |

---

## 4. Audio Engine Integration Notes

- **Format:** MP3, 44.1 kHz, Stereo.
- **Trigger Strategy:** Simple alternating toggle:
  ```kotlin
  // Kotlin pseudo-code
  val currentSound = if (stepCount % 2 == 1) squid_1 else squid_2
  soundPool.play(currentSound, 1.0f, 1.0f, 1, 0, 1.0f)
  ```
