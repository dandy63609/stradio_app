# Playback Order & Cadence Guide: Sponge

Sound Pack: **SPONGE (Classic SpongeBob Walking Footsteps)**

This pack features the iconic soft, wet, squishy cartoon walking footsteps. Each file represents exactly one individual footstep.

---

## 1. Available Step Variations

| File | Identity | Duration | Acoustic Role |
| :--- | :--- | :--- | :--- |
| `sponge_1.mp3` | Wet Squelch (Left Foot) | 371 ms | Primary left footstep: fuller, deeper wet squish impact. |
| `sponge_2.mp3` | Wet Squelch (Right Foot) | 278 ms | Complementary right footstep: slightly shorter and higher-pitched release. |

---

## 2. Recommended Playback Sequence

### Deterministic Left / Right Alternation (Strict 1-2-1-2)

Recommended sequence:
```
1 → 2 → 1 → 2 → 1 → 2 → Repeat
```

#### Why This Sequence Works:
- **Natural Bipedal Pendulum:** The two variations were acoustically matched to form a continuous Left $\leftrightarrow$ Right walking loop.
- **Rhythmic Bounce:** `sponge_1` provides the weighted ground contact, while `sponge_2` provides the springy lift-off, mirroring the iconic animated walk cycle.

---

## 3. Cadence & SPM Compatibility

| Cadence (SPM) | Step Interval | Compatibility | Notes |
| :--- | :--- | :--- | :--- |
| **100 SPM (Walking)** | 600 ms | **Optimal (5/5)** | Amusing, leisurely cartoon waddle. Generous 229 ms silence between steps. |
| **140 SPM (Jogging)** | 428 ms | **Very Good (4.5/5)** | Energetic, funny cadence. Steps resolve cleanly with ~57 ms headroom. |
| **180 SPM (Running)** | 333 ms | **Good (4.0/5)** | Fast comic sprint. `sponge_1` (371 ms) slightly overlaps the 333 ms window at top sprint speed, creating an authentic chaotic cartoon running effect. |

---

## 4. Audio Engine Integration Notes

- **Format:** MP3, 44.1 kHz, Stereo.
- **Trigger Strategy:** Simple alternating toggle:
  ```kotlin
  // Kotlin pseudo-code
  val currentSound = if (stepCount % 2 == 1) sponge_1 else sponge_2
  soundPool.play(currentSound, 1.0f, 1.0f, 1, 0, 1.0f)
  ```
