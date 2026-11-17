---
name: Stradio
status: draft
sources:
  - docs/PRD-MVP.md
  - assets/design/Stradio_brand_identity_system_a65eef14_2K.jpg
updated: 2026-11-13
---

# STRADIO: Experience Specification (EXPERIENCE.md)

## Foundation

STRADIO is a single-surface mobile application targeting Android (SDK 26+, Android 8.0+) with a Flutter cross-platform architecture ready for iOS.

`DESIGN.md` is the visual identity reference (Daylight Instrument Minimalism: Warm Ivory `{colors.warm-ivory}` canvas, dual-tone stacked headers, sentence-case microcopy, and solid Midnight `{colors.midnight}` bottom docks); this spine governs **how the product behaves, moves, and feels**.

### Core Experience Principles
1. **Zero-Friction Ignition:** From icon tap to headphones playing in under 3 seconds. Zero onboarding carousels, zero sign-in modals, zero profile setup.
2. **Tactile Synchronicity:** Every physical step must feel instantly registered through ear and eye (`<30 ms` sensor detection, `<50 ms` audio trigger).
3. **Pocket Immunity:** Running happens with phones locked in shorts pockets, armbands, or waist packs. The experience must deliver 100% of its audio feedback and state awareness with the screen completely off.
4. **Whisper-Quiet Glanceability:** Never shout at the runner with all-caps walls of text or dense stat tables. Every screen has one central instrument and at most two borderless numbers.

---

## Information Architecture

The STRADIO MVP architecture is deliberately flat: a single continuous session lifecycle spanning 3 primary visual surfaces and 1 background state:

```
┌────────────────────────────────────────────────────────┐
│                   SURFACE 1: PRE-RUN                   │
│   - Minimal top brand mark (STRADIO)                   │
│   - Central runner/sonic hero visual                   │
│   - 6 Sound Pack Cards (Breakbeat, Lari Ngacir, GBA,   │
│     Squid, Sponge, Rubber Bouncy)                      │
│   - Solid Midnight Pill CTA: [ ->  Swipe to start  o ] │
└───────────────────────────┬────────────────────────────┘
                            │ Trigger Start
                            ▼
┌────────────────────────────────────────────────────────┐
│                  SURFACE 2: ACTIVE RUN                 │
│   - Dual-Tone Stacked Header: Stride / Rhythm          │
│   - 280px Circular Acoustic Dial (visualizer-dial)     │
│   - 2 Borderless Metrics: Steps & Cadence (spm)        │
│   - Bottom Dock Cradle: [ Sound ] [ Active Stride ] [■]│
└──────────────┬───────────────────────────┬─────────────┘
               │ Screen Locked             │ Hold 1.5s
               ▼                           ▼
┌──────────────────────────────┐ ┌───────────────────────┐
│   BACKGROUND POCKET MODE     │ │  SURFACE 3: SUMMARY   │
│   - Android Foreground Task  │ │  - Liquid Glass Hero  │
│   - Real-time Audio Engine   │ │    Circle (SPM Ring)  │
│   - Step Detection Active    │ │  - 3 Frosted Stat     │
│   - Lockscreen Notification  │ │    Cards (Km/Time/Pace│
└──────────────────────────────┘ │  - [ Export IG Story ]│
                                 │  - [ Start new run ]  │
                                 └───────────────────────┘
```

| Surface | Reached From | Primary Purpose | Visual Focal Point | Primary Actions |
| :--- | :--- | :--- | :--- | :--- |
| **First-Launch Immersion Modal** | Initial Cold App Launch (`has_seen_audio_recommendation == false`) | Guide runner to wear headphones or earphones for full adaptive audio immersion. | Daylight dialog card (`340px`) with 3D floating headphones and kinetic soundwaves over `6px` blurred Pre-Run canvas | 1. Tap `I'm Wearing Earphones`<br>2. Tap `Maybe later`<br>3. Tap `X` close |
| **Surface 1: Pre-Run** | Cold App Launch / Modal Dismiss | Choose sound character and start session immediately without friction. | Central sonic visual framed by two `{colors.surface-card}` sound pack tiles | 1. Select Sound Pack tile<br>2. Trigger `Swipe to start` pill |
| **Surface 2: Active Run** | Pre-Run Start Pill | Deliver real-time kinetic audio-visual synchrony and two glanceable stats. | `280px` circular `{colors.surface-recessed}` acoustic dial (`visualizer-dial`) | 1. Glance at dial & borderless metrics<br>2. Tap left dock button to swap sound<br>3. Hold right dock button `1.5s` to end |
| **Background Pocket Mode** | Screen Lock / Home | Maintain uninterrupted step detection, stem layering, and audio SFX in pocket. | System Notification Shade (Lockscreen) | 1. Lockscreen notification `Stop run` action |
| **Surface 3: Run Summary** | Active Run Hold-to-End | Reflect on rhythm consistency and cadence flow before exit or restart. | Open `{colors.warm-ivory}` stem chart (`visualizer-stems`, `3px` bars) | 1. Inspect cadence stems & sync cards<br>2. Tap `Start new run` |

---

## Voice and Tone

STRADIO speaks like a calm, precise studio instrument. Short, natural sentence case, zero hype, zero exclamation marks.

| Do | Don't |
| :--- | :--- |
| `Swipe to start` | `RUN THE VIBE NOW!!!` |
| `Stride` / `Rhythm` (dual-tone stacked header) | `ACTIVE WORKOUT TRACKING SESSION` |
| `Sensor active and synced` | `Revolutionary AI-powered biomechanics engine online` |
| `Hold 1.5s to end` | `Are you sure you want to quit this exercise?` |
| `Active •` / `Walking •` / `Avg. SPM` | `Cadence zone: Low intensity endurance matrix` |
| `Midnight Pulse` / `Cartoon Squeak` | `Sound profile 1` / `Audio preset 2` |

---

## Component Patterns

### 1. Primary Ignition Pill (`button-primary`)
- **Location:** Surface 1 (Pre-Run), bottom thumb-zone dock.
- **Behavior:**
  - Triggering the solid `{colors.midnight}` pill fires an immediate haptic click (`HapticFeedback.mediumImpact`).
  - Layer 1 background music stem initiates immediately with a `200 ms` fade-in.
  - Sensor stream begins sampling raw accelerometer at `100 Hz`.
  - Transitions viewport smoothly to Surface 2 (Active Run).

### 2. Active Dock & Hold-to-End Control (`dock-pill` + `button-icon-circle`)
- **Location:** Surface 2 (Active Run), bottom recessed pill cradle (`{colors.surface-recessed}`).
- **Anatomy:**
  - Left `48px` circle button: Hot-swaps the active Sound Pack (Breakbeat, Lari Ngacir, GBA, Squid, Sponge, Rubber Bouncy).
  - Center solid `{colors.midnight}` pill: Displays `Active Stride` with a `5px` `{colors.sonic-coral}` status dot.
  - Right `48px` circle button: Hold-to-end session control (`■`).
- **Behavior (Anti-Accidental-Trigger):**
  - Instant taps on the stop circle do *not* end the run; the status line whispers `Hold 1.5s to end`.
  - Pressing and holding fills the `48px` circular border stroke with `{colors.sonic-coral}` over **1.5 seconds**, accompanied by light haptic ticks every `300 ms`.
  - Reaching `1.5 seconds` triggers heavy haptic confirmation, fades Layer 1 audio over `500 ms`, and transitions to Surface 3 (Run Summary).
  - Releasing early snaps the ring back to `0` without interrupting audio.

### 3. Circular Acoustic Dial & Liquid Glass Core Lens (`visualizer-dial` + `liquid-glass-lens`)
- **Location:** Center of Surface 2 (`256px` recessed circle in `{colors.surface-recessed}` housing a `136px` `{components.liquid-glass-lens}`).
- **Optical Shader Engine:**
  - Powered by `dashersw/liquid-glass-js` in web prototypes and `shaders/liquid_glass.frag` (`FragmentProgram` + `BackdropFilter`) in Flutter.
  - Uses `circleDistance` SDF normals (`u_edgeIntensity: 0.032`, `u_rimIntensity: 0.095`, `u_rippleEffect: 0.08`, `u_blurRadius: 7.0`, `u_tintOpacity: 0.22`) to refract the multi-layered Sonic Coral and Twilight Plum waveforms passing underneath the lens.
- **Behavior:**
  - **Idle State:** When stationary, the central sonic ribbon breathes gently behind the glass lens.
  - **Footstrike Refraction Pulse:** Within `<30 ms` of foot contact, `u_rippleEffect` surges from `0.08` to `0.24` and `u_edgeIntensity` surges from `0.032` to `0.065` for `180 ms`, causing the liquid glass rim to physically bend and magnify the Sonic Coral wave on impact.
  - **Reduced Motion & Transparency:** When `prefers-reduced-motion: reduce` is enabled, radial expansion is replaced by a calm opacity cross-fade. When `prefers-reduced-transparency: reduce` is enabled, the shader yields to a solid `{colors.surface-card}` (`#FAF7F2`) surface.

### 4. Minimal Cadence Stem Chart (`visualizer-stems`)
- **Location:** Upper-middle zone of Surface 3 (Run Summary).
- **Behavior:**
  - Renders 12 to 16 vertical `3px` pill stems with `14px` horizontal spacing directly on `{colors.warm-ivory}`.
  - Running intervals (`>= 130 SPM`) display in `{colors.twilight-plum}` and `{colors.sonic-coral}`; walking intervals (`< 130 SPM`) display in `{colors.rhythm-violet}`.
  - Tapping `Active •` or `Walking •` in the legend highlights the matching intervals.

### 5. In-Pocket Lockscreen Notification
- **Location:** Android System Notification Shade and Always-On Display.
- **Behavior:**
  - Persistent foreground service notification titled `Stradio • Active Stride`.
  - Subtitle updates once per second in sentence case: `24:18 • 3,620 steps • 154 spm`.
  - Includes a direct `[ Stop run ]` action.

---

## State Patterns

| State | Context | Visual & Audio Behavior |
| :--- | :--- | :--- |
| **Cold Launch (First Time)** | First-time app open (`has_seen_audio_recommendation == false`) | Presents the focused Earphone Immersion Dialog ("Use Earphones for Full Immersion") over blurred Pre-Run Ignition. |
| **Cold Launch (Returning)** | Subsequent app opens (`has_seen_audio_recommendation == true`) | Opens directly to Surface 1 on `{colors.warm-ivory}` in `<800 ms`. Pre-caches SFX pool into memory. |
| **Empty / First Run** | 0 steps recorded at session start | Dial sits at calm equilibrium; metric pairs read `0` steps and `-- spm` with helper note `Take a step to trigger audio`. |
| **Loading Sensor** | Accelerometer stream initializing | Subtle pulsing dot next to `Calibrating motion sensor...` inside the status strip; controls remain responsive. |
| **Sensor / Audio Error** | Permission denied or audio init failure | Clear inline card on `{colors.surface-card}` with `1px` `{colors.text-accent-deep}` border stating the exact cause (`Motion sensor permission required to detect steps`) and a single `[ Grant permission ]` button. |
| **Walking Mode** | Active run, cadence `< 130 SPM` | Layer 1 stem plays ambient arrangement. Dial status dot turns `{colors.rhythm-violet}` (`Walking groove`). |
| **Running Mode** | Active run, cadence `>= 130 SPM` | Layer 1 stem cross-fades into driving rhythm stem. Dial pulses with `{colors.sonic-coral}` (`Active Stride`). |
| **Pocket / Screen Off** | Runner locks phone and pockets device | Foreground service maintains wake lock; sensor sampling and audio layering continue without dropped beats. |

---

## Interaction Primitives

1. **Thumb-Zone Dominance:** Every primary control sits in the bottom 15% to 30% of the viewport for effortless one-handed use while jogging.
2. **Defensive Running Affordances:**
   - Minimum `48 x 48 dp` circular controls and `56 dp` tall primary pill docks with `12 dp` separation.
   - `1.5-second` hold gesture on session termination to prevent accidental pocket or sweat taps.
3. **Multi-Sensory Confirmation:** Every critical transition registers across three channels:
   - **Visual:** Tonal shift or ring fill inside the daylight instrument.
   - **Auditory:** Discrete low-latency one-shot SFX in headphones.
   - **Haptic:** Crisp tactile pulse through the device chassis.
4. **Banned Patterns:**
   - No account login or sign-up walls.
   - No mandatory GPS permission dialogs.
   - No social feeds, fake leaderboards, or calorie spreadsheets.
   - No all-caps shouting or decorative AI badges.

---

## Accessibility Floor

- **Daylight Contrast Verification:** Primary text in `{colors.midnight}` (`#191923`) on `{colors.warm-ivory}` (`#F5F0E8`) achieves **15.37:1** (WCAG AAA). Secondary labels in `{colors.text-secondary}` (`#625D72`) achieve **5.56:1** on Warm Ivory, **5.90:1** on `{colors.surface-card}`, and **5.00:1** on `{colors.surface-recessed}` (passing WCAG AA `4.5:1` across all surfaces).
- **Non-Color State Signaling:** Every status dot (`5px`) is paired with an explicit text label (`Active •`, `Walking •`, `Sensor active`) so state never relies on hue alone.
- **Eyes-Free Audio Navigation:** Distinct audio earcons accompany run start, tempo transitions (`130 SPM` threshold), and run completion.
- **Dynamic Type & Reflow:** Tabular numeric containers (`tnum`) scale to 200% text zoom without clipping, and dual cards stack into a single column on narrow screens (`<360px`).

---

## Key Flows

### Flow 1: Alex, Evening Decompression Run
*Alex is a 27-year-old developer going for a 5K jog before sunset to clear their head.*

1. **Preparation & First-Launch Guidance:** Alex steps outside and opens STRADIO for the first time. The app presents the Daylight Immersion Dialog: `"Use Earphones for Full Immersion"`. Alex connects wireless earbuds and taps **`"I'm Wearing Earphones"`**. The dialog smoothly scales away in `180 ms`, saving the preference to device cache.
2. **Ignition:** Surface 1 opens on a calm Warm Ivory canvas. The `BREAKBEAT FVNKY` card shows `Ready • 98% sync`. Alex triggers the solid Midnight bottom pill: **`[ ->  Swipe to start  o ]`**.
3. **Stride Lock:** A warm synth pad fades in. Surface 2 appears with the dual-tone header **`Stride / Rhythm`** and the `280px` circular dial. On the third step, Alex's foot strikes the pavement: a deep sub-kick fires in the earbuds within `28 ms` while the dial pulses softly in Sonic Coral.
4. **Acceleration:** Alex settles into a `154 spm` rhythm. The borderless metric pair below the dial updates smoothly in tabular numerals (`154 spm`, `28 ms`).
5. **The Climax Beat:** As cadence holds above `130 spm`, the background stem cross-fades into a driving rhythm. Alex locks the phone, slips it into a pocket, and runs eyes-free for 24 minutes as every footfall drives the beat.
6. **Finish:** Back at the doorstep, Alex unlocks the phone and holds the right circular stop button in the bottom dock for `1.5 seconds`. The coral ring completes, audio fades out, and Surface 3 (`Cadence / Flow`) displays the clean `3px` vertical cadence stems alongside `3,620` steps and `94%` rhythm sync.

---

### Flow 2: Jordan, Recovery Jog with Friends
*Jordan is a 21-year-old student taking an easy recovery jog and wants playful audio feedback.*

1. **Selection:** Jordan launches STRADIO on Surface 1, taps the `SQUID` card (`Playful • Squidward Clunk`), and triggers **`Swipe to start`**.
2. **In-Run Swap:** Halfway through the jog on Surface 2, Jordan taps the left `48px` circular sound-pack button in the bottom dock to toggle between `SQUID`, `SPONGE`, and `BREAKBEAT FVNKY` without dropping a beat.
3. **Wrap Up:** Jordan taps `[ Stop run ]` directly from the Android lockscreen notification and reviews the session summary.
