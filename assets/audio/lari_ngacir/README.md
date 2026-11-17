# Lari Ngacir: Stem & Audio Playback Specification

Sound Pack: **LARI_NGACIR**  
Artist: **DDHANNi**  
Source: `assets/audio/Ini kalo lari/` (`Buat Stadio_Layer 1.wav`, `Buat Stadio_Layer 2.wav`, `full beat.wav`)

---

## 1. Musical Profile

- **Tempo:** 140.000 BPM
- **Time Signature:** 4/4
- **Bar Duration:** 1.7143 seconds (1714.29 ms)
- **Beat Interval:** 428.57 ms
- **Loop Structure:** Exactly 72 bars (288 beats = 123.4286 seconds = 5,443,200 samples at 44.1 kHz)
- **Loop Seam:** 30 ms equal-power crossfade tail, 2 ms micro-fade head (sample jump: 0.00000, seamless click-free loop)

---

## 2. Audio Stems

| Filename | Role | Formats | Decibels (RMS) |
| :--- | :--- | :--- | :--- |
| `lari_ngacir_layer1_walk` | Foundational walking groove (synth pads, syncopated rhythm) | `.wav` (21.7 MB) / `.mp3` 320k (4.8 MB) | -16.2 dB to -20.1 dB |
| `lari_ngacir_layer2_jog` | Driving jogging drums & percussion energy | `.wav` (21.7 MB) / `.mp3` 320k (4.8 MB) | -10.3 dB to -20.9 dB |

---

## 3. Audio Engine Orchestration (Zero Step SFX)

- **Step SFX:** Inactive (0 dB). The dual-stem musical progression carries the full auditory experience.
- **Clock Synchronization:** Both stems start simultaneously at session ignition in exact sample-lock.
  - While walking (`< 130 SPM`): Layer 1 plays at unity volume (1.0). Layer 2 runs silently at volume 0.0.
  - Entering jogging zone (`>= 130 SPM`): Layer 2 schedules an 800 ms volume fade-in to land on the downbeat of the next musical bar line (max wait 1.71 s).
  - Dropping to walking zone (`< 120 SPM` for 3 consecutive seconds): Layer 2 fades down to volume 0.0 over 800 ms.
- **Looping:** Both players loop back to sample index 0 after bar 72 in perfect lockstep.
