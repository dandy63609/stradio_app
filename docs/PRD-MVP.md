# STRADIO MVP: Product Requirements Document (PRD-Light)

| Metadata | Details |
| :--- | :--- |
| **Product** | STRADIO (Stride + Audio) |
| **Tagline** | Run the Vibe. |
| **Document Type** | PRD-Light (MVP Specification) |
| **Target Milestone** | December Validation Pilot |
| **Status** | Draft |
| **Author** | John (Product Manager) & Dandy (Founder) |

---

## Table of Contents
- [Vision](#vision)
- [Users and Journeys](#users-and-journeys)
- [Features and Requirements](#features-and-requirements)
- [Non-Goals](#non-goals)
- [Technical Approach](#technical-approach)
- [Success](#success)
- [Open Questions](#open-questions)

---

## Vision

STRADIO turns physical running into an interactive, gamified audio experience. While traditional fitness apps treat runners like passive statistics engines (tracking miles, pace, and calories) and music apps treat runners as passive listeners, STRADIO establishes a direct, tactile relationship between human biomechanics and sound: **movement becomes music**. 

By detecting footsteps in real-time ($<30\ \text{ms}$) using raw smartphone acceleration, STRADIO triggers immediate sound feedback and modulates background musical arrangement based on cadence. The goal for this MVP is to validate whether runners find a movement-responsive audio experience compelling enough to repeat weekly, using a brutally simple, zero-friction mobile application.

---

## Users and Journeys

### Target Audience
1. **The Bored Recreational Runner:** Runs 2–4 times per week to stay active, regularly wears headphones, but struggles with the monotony of long, solo road running.
2. **The Social Tech & Meme Runner:** Younger, digital-first recreational runner excited by interactive technology and shareable, fun fitness moments.

### Core User Journeys

#### UJ-1: The Flow-State Run (Indonesian Breakbeat Vibe)
*Protagonist: Alex, a casual runner seeking rhythm and energy.*
1. Alex puts in wireless earbuds, opens STRADIO, and immediately sees the hero screen.
2. With zero login or setup screens, Alex taps **"Run the Vibe"** and selects the **"BREAKBEAT FVNKY"** (by DDHANNi) signature sound pack.
3. Alex begins walking. The background music remains silent, but each physical step fires a tight, punchy kick drum (`drums_1_step.mp3`) through the earbuds.
4. Alex accelerates into a steady jog. Cadence climbs past 130 SPM into the Jogging Zone.
5. The background music loop (`Full_Fade_NoKick_BG.mp3`) fades in over 800 ms with funky synth stabs ("Klung") and snares ("Cetas"). Alex's physical footsteps now drive the live kick drum of the breakbeat track in real time.
6. Alex finishes a 20-minute run, taps **"End Run"**, views the daylight liquid glass summary card (Cadence 156 SPM, Distance 5.42 km, Duration 32:40, Pace 5:12/km), exports a transparent sticker to Instagram Stories, and feels energized.

#### UJ-2: The Silly / Meme Run (Viral & Novelty Loop)
*Protagonist: Jordan, running a light recovery jog.*
1. Jordan opens the app and toggles the sound pack to **"SQUID"** (Squidward suction clunk), **"SPONGE"** (SpongeBob squish), or **"RUBBER_BOUNCY"** (springy cartoon shoe).
2. Jordan locks the phone, slips it into a pocket, and starts jogging.
3. Every step emits an absurd, perfectly timed cartoon footstep through the headphones. Jordan chuckles, keeping pace just to maintain the comedic rhythm.
4. The background service keeps the sound firing flawlessly even with the phone screen locked in Jordan's pocket.
5. Jordan records a quick screen/audio capture after the run to share on Instagram Reels/TikTok.

---

## Features and Requirements

### Feature 1: Real-Time Step Detection Engine (A1)
- **FR-1.1:** The app must ingest 3D raw acceleration at 100 Hz using the Euclidean norm:
  $$m(t) = \sqrt{a_x^2 + a_y^2 + a_z^2}$$
- **FR-1.2:** The app must compute dynamic thresholds using the **Adaptive Midpoint + Gravity** algorithm:
  $$T(t) = \frac{\max(\text{window}) + \min(\text{window})}{2}$$
  over a 1000 ms sliding window with 3-sample causal moving-average smoothing.
- **FR-1.3:** The engine must enforce a **1.2 m/s² stationary noise gate** (`minWindowSpreadMps2`) to produce exactly 0 steps when the phone is idle or resting on a table.
- **FR-1.4:** The engine must enforce a **250 ms refractory lockout** between consecutive confirmed steps to eliminate heel-to-toe double triggers (capping at 240 SPM).
- **FR-1.5:** Total detection latency from sensor sample arrival to step event dispatch must not exceed **30 ms**.

### Feature 2: Foreground Background Service & Pocket Mode
- **FR-2.1:** The app must run as an Android Foreground Service when a session is active, maintaining continuous sensor sampling and audio playback while the screen is locked or the app is minimized.
- **FR-2.2:** The app must show a persistent system notification during an active run displaying current run duration, step count, and a one-tap **"Stop Run"** action.

### Feature 3: Two-Layer Interactive Audio System
- **FR-3.1 (Layer Architecture):** The app must support a decoupled two-layer audio architecture:
  - *Layer 1 (Background Loop):* Continuous musical bed played via `audioplayers` with gapless looping.
  - *Layer 2 (Step SFX):* Low-latency one-shot sample pool played via `soundpool` ($\le 15\ \text{ms}$ native audio latency, $< 50\ \text{ms}$ end-to-end latency from footstrike).
- **FR-3.2 (BREAKBEAT FVNKY SPM Zone Modulation):** For the `BREAKBEAT FVNKY` pack:
  - *Walking Zone ($< 130\ \text{SPM}$):* Layer 1 background music is silent. Only Layer 2 kick drum (`drums_1_step.mp3`) fires on each confirmed step.
  - *Jogging Zone ($\ge 130\ \text{SPM}$):* Layer 1 background loop (`Full_Fade_NoKick_BG.mp3`) fades in smoothly over 800 ms. Physical steps continue driving `drums_1_step.mp3` as the real-time kick drum over the track's melodic stabs and snares.
  - *Hysteresis Lockout:* Layer 1 background music only fades out (over 800 ms) if cadence drops below 120 SPM for 3 consecutive seconds, preventing flutter around the 130 SPM threshold.
- **FR-3.3 (DSP Isolation & Anti-Clashing):** `Full_Fade_NoKick_BG.mp3` must be processed with a 135 Hz high-pass filter and -12 dB notch cut at 90 Hz to completely vacate the sub-bass frequency band, ensuring the runner's physical kick drum never phase-cancels or clashes with the background loop.
- **FR-3.4 (Pack-Specific Audio Behaviors):**
  - *LARI_NGACIR (by DDHANNi):* Dual-stem synchronous arrangement at 140 BPM (72-bar bar-aligned seamless loop). Both stems run in exact sample-synchronization from session start.
    - Layer 1 (`lari_ngacir_layer1_walk`): Audible from session start across all paces as the foundational walking groove.
    - Layer 2 (`lari_ngacir_layer2_jog`): Runs silently at volume 0.0 during walking (< 130 SPM). When cadence reaches >= 130 SPM, Layer 2 fades in over 800 ms, triggered on the downbeat of the next bar line (max 1.71 s alignment delay).
    - Hysteresis Lockout: Layer 2 fades out over 800 ms only after cadence remains < 120 SPM for 3 consecutive seconds.
    - Step SFX: Inactive (0 dB). The dual-stem musical arrangement handles all acoustic energy.
  - *GBA_SAND_HOP:* Layer 1 (`hoenn_island_loop.mp4` at 132.5 BPM) plays continuously from session start, with dynamic playback rate scaling:
    $$\text{playbackRate} = \text{clamp}\left(\frac{\text{SPM}}{132.5}, 0.90, 1.18\right)$$
    Layer 2 triggers round-robin crunchy sand footsteps (`gba_sand_01..03.mp3`).
  - *SQUID:* Layer 1 is silent across all paces. Layer 2 triggers deterministic alternating left/right hollow suction clunks (`squid_1.MP3` on odd steps, `squid_2.MP3` on even steps).
  - *SPONGE:* Layer 1 is silent across all paces. Layer 2 triggers deterministic alternating left/right wet cartoon squelches (`sponge_1.mp3` on odd steps, `sponge_2.mp3` on even steps).
  - *RUBBER_BOUNCY:* Layer 1 is silent across all paces. Layer 2 triggers springy elastic compression (`rubber_01.mp3`) with plus/minus 3% micro-pitch alternation (1.00 pitch on left steps, 1.03 pitch on right steps).

### Feature 4: Sound Pack Selector
- **FR-4.1 (Catalog Lineup):** The app must ship with six curated sound packs selectable from a carousel or bottom sheet:
  1. `BREAKBEAT FVNKY` (Artist: DDHANNi): Indonesian Koplo / Breakbeat energy, step kick + pace-activated background loop.
  2. `LARI NGACIR` (Artist: DDHANNi): Dual-stem synchronized electronic progression, bar-aligned jog drums layer, music-only flow.
  3. `GBA_SAND_HOP` (16-Bit Nostalgia): Route 104 coastal adventure, tempo-synced background music + crunchy sand step SFX.
  4. `SQUID` (Classic Squidward Stride): Alternating hollow wooden suction clunks, pure step SFX for comedic recovery jogs.
  5. `SPONGE` (Classic SpongeBob Stride): Alternating wet cartoon squelches, pure step SFX for viral social sharing.
  6. `RUBBER_BOUNCY` (Springy Rubber Footstep): Buoyant elastic bounce with bipedal micro-pitch alternation, pure step SFX.
- **FR-4.2 (Zero-Interruption Switching):** Switching sound packs must apply immediately without resetting active step counts, timers, or background service tasks.

### Feature 5: Minimalist Session UI & Shareable Glass Results
- **FR-5.0 (First-Launch Audio Immersion Dialog):** On initial application open (cold start with no prior session completed), the app presents a centered, non-blocking modal dialog: `"Use Earphones for Full Immersion"` (badge: `Recommended`).
  - *Purpose:* Guides the runner to wear earphones/headphones to properly experience real-time soundscapes and step-synced acoustic cues.
  - *Layout & Visual:* `340px` max-width Daylight Cream card (`#FAF7F2/95`, `24px` radius) over a `30%` Midnight scrim with `6px` backdrop blur, featuring a 3D daylight rendering of over-ear headphones floating with coral/violet soundwaves.
  - *Actions:* Primary button `"I'm Wearing Earphones"` (solid Midnight capsule) and secondary button `"Maybe later"` (text action), plus top-right circular close button.
  - *State Persistence:* Dismissal persists `has_seen_audio_recommendation = true` in local key-value storage (`SharedPreferences`) so returning runners bypass the dialog. Can be re-reviewed anytime via Settings.
- **FR-5.1:** The primary screen must feature a prominent one-tap **"Run the Vibe"** / **"Start"** button with zero mandatory account creation or onboarding tutorials.
- **FR-5.2:** During an active session, the screen displays a large, animated circular step counter with a visual pulse on each confirmed step, alongside elapsed time and current SPM.
- **FR-5.3:** A prominent **"End Run"** button confirms session termination with a hold or single tap.
- **FR-5.4 (Daylight Liquid Glass Summary):** The post-session summary card must render the Google Stitch-aligned frosted liquid glass aesthetic:
  - Hero Glass Circle displaying primary metric: large cadence display (e.g. `156 spm`), multi-color stride wave ribbons, and dynamic state pill (`Stride Resonance Lock`).
  - Triple Frosted Metric Pills: Distance (`5.42 km`), Duration (`32:40`), and Pace (`5:12 /km`).
  - Audio Footer Pill: Headphone icon with active sound pack name and harmonic stride status.
  - Strictly no extraneous header logos or timestamp chips inside the hero circle frame.
- **FR-5.5 (9:16 Instagram Story Export):** The summary screen must support two instant export formats optimized for social sharing:
  - *Format A (Transparent Sticker):* High-resolution transparent PNG cutout of the frosted glass circle and metric pills, ready to paste directly over user photos/videos in Instagram Stories.
  - *Format B (Photo Glass):* Full 9:16 vertical canvas (1080x1920) allowing the runner to upload/select a background run photo, with 4 corner viewfinder markers and frosted glass stats layered on top with auto-tinted backdrop blur.

### Feature 6: Product Telemetry & Validation
- **FR-6.1:** The app must send anonymous usage events to PostHog (session_started, session_completed, steps_total, duration_seconds, sfx_pack_selected).
- **FR-6.2:** All analytics calls must fail silently without blocking local audio or step counting if the device is offline during a run.

---

## Non-Goals (Strictly Out of Scope for December MVP)

| Non-Goal | Rationale |
| :--- | :--- |
| **GPS & Route Mapping** | Adds massive battery drain and map SDK complexity; does not test the core hypothesis that sound-driven running is fun. |
| **User Accounts & Social Feeds** | Authentication walls destroy top-of-funnel pilot adoption. Runs are local and anonymous. |
| **Calorie & Fitness Metrics** | STRADIO is an audio companion, not a medical/calorie dashboard. Avoid fabricating metabolic formulas. |
| **Streaming APIs (Spotify/Apple)** | SDK licensing, token refresh cycles, and streaming audio DRM prevent low-latency stem layering. |
| **Custom Playlist Uploads** | Curated offline stems guarantee latency performance and eliminate audio formatting crashes. |

---

## Technical Approach

```
┌─────────────────────────────────────────────────────────┐
│                     STRADIO FLUTTER APP                 │
├───────────────────────────┬─────────────────────────────┤
│  UI Layer (Material 3)    │  Background Service Manager │
│  - Hero Start Screen      │  - flutter_foreground_task  │
│  - Pulse Step Gauge       │  - WakeLock & Notification  │
│  - Sound Pack Selector    │                             │
├───────────────────────────┴─────────────────────────────┤
│                 Audio Engine (Layer 1 + Layer 2)        │
│  - Layer 1: Looped dynamic stem player (audioplayers)   │
│  - Layer 2: Ultra-low-latency SFX pool (soundpool)     │
├─────────────────────────────────────────────────────────┤
│            Real-Time Signal Processing Pipeline         │
│  - sensors_plus (raw accelerometer @ 100 Hz)            │
│  - StepDetector (A1: Adaptive Midpoint + Gravity)       │
│  - Cadence Calculator (Inter-step interval to SPM)      │
├─────────────────────────────────────────────────────────┤
│              Local Storage & Anonymous Analytics        │
│  - shared_preferences (Local run history)               │
│  - posthog_flutter (Session retention events)           │
└─────────────────────────────────────────────────────────┘
```

- **Framework:** Flutter (Dart 3.x) targeting Android (SDK 26+ / Android 8.0+).
- **Sensors:** `sensors_plus` reading raw tri-axial accelerometer @ 100 Hz.
- **Step Detection Core:** Extracted directly from validated `OFFICIAL_REPO_CENSOR_ONLY/lib/algorithms/step_detector.dart` (A1 variant).
- **Background Execution:** `flutter_foreground_task` keeping sensor streams and audio threads alive when the screen is locked in pocket.
- **Audio Implementation:**
  - *Layer 1:* `audioplayers` for continuous background music loops.
  - *Layer 2:* `soundpool` (native Android SoundPool API) for pre-cached, zero-latency one-shot triggers ($\le 15\ \text{ms}$ native audio latency).
- **Analytics:** PostHog Cloud (free tier up to 1M events).

---

## Success Criteria

1. **User Value Validation:** At least **25% Day-7 retention** ($D_7$) across the first cohort of 500 pilot runners (defined as completing at least 2 runs in a 7-day period).
2. **Audio Latency:** Perceived audio punch occurs within **$< 50\ \text{ms}$** of physical foot strike.
3. **Background Reliability:** **0% background crashes or silent sensor cutoffs** over a continuous 30-minute locked-screen pocket run across major Android OEMs (Samsung, Xiaomi, Transsion).
4. **Meme Engagement:** At least **20% of sessions** utilize the Silly / Cartoon SFX sound pack, indicating viral/novelty resonance.

---

## Open Questions & Decisions

| ID | Topic | Resolution / Decision | Status |
| :--- | :--- | :--- | :--- |
| **OQ-1** | **Silly SFX Sourcing** | Curated acoustic cartoon samples bundled directly in repo (`SQUID`, `SPONGE`, `RUBBER_BOUNCY`, and `GBA_SAND_HOP`). | Resolved |
| **OQ-2** | **Aggressive OEM Battery Killers** | Android foreground service with persistent sticky notification and wake-lock to prevent OS sensor thread killing on Xiaomi/Samsung. | Architecture Phase |
| **OQ-3** | **Audio Fadeout on Transitions & Pause** | Decided: 800 ms smooth crossfade curve for pace-triggered background entry/exit and session pause/stop. | Resolved |
| **OQ-4** | **Layer 2 Low-Latency SFX Package (`soundpool` discontinued)** | Decided: Use `audioplayers` with `PlayerMode.lowLatency` (wraps native Android `SoundPool` under the hood) instead of the discontinued `soundpool` pub.dev package to avoid AGP 8+ build breakage with no audio quality loss. | Resolved |
