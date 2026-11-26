# STRADIO UX Revision Handoff (Developer Implementation Checklist)

> **Purpose:** Self-contained UI/UX revision spec for the Flutter implementation team, bridging the updated Google Stitch designs, Mas Zay's design review feedback, and the current `lib/` codebase.
> **Interactive Visual Reference:** Open [`docs/mockups/stitch-liquid-glass-preview.html`](mockups/stitch-liquid-glass-preview.html) in any desktop browser (use **Focus 1:1** mode to inspect exact `390 x 920` spacing and test interactive states).
> **Canonical Specs:** [`docs/DESIGN.md`](DESIGN.md) & [`docs/EXPERIENCE.md`](EXPERIENCE.md).

---

## Summary of Revisions (4 Areas)

| # | Screen / Component | Flutter Target File | Preview Card | Key Change |
| :--- | :--- | :--- | :--- | :--- |
| **1** | **Pre-Run Ignition** | `lib/screens/stradio/pre_run_ignition_screen.dart` | **Card 07** (`a65e9b77ea57478893da48c0d41e1e93`) | Add unmistakable running context (top-bleed runner legs hero + orbital dial) + Suspended Liquid Glass Deck with `Audition` EQ & `SPM TARGET` / `PACE SYNC`. |
| **2** | **Active Run** | `lib/screens/stradio/active_run_screen.dart` & `lib/widgets/sonic_ribbon_painter.dart` | **Card 10** (`241f03f82b5a46f199cf058b98dc356b`) | Switch to `72px` Cadence Monolith, **step-triggered acoustic wave** (idle flat -> active surge on footstep), frosted 3-metric bar (`Distance`, `Pace`, **`Steps`**), and single `1.5s` `Hold to finish` Obsidian pill. |
| **3** | **Share Run Rhythm Modal** | `lib/widgets/share/share_run_rhythm_sheet.dart` | **Card 12** (`7b5582113012427782ee0b7b0f91e01a`) | Remove entire `Quick Share` icon row (`Stories`, `Save`, `Copy Link`, `Messages`). Keep only `Share Rhythm Card` (PNG + bundled caption for WhatsApp/messaging) and `Instagram story export 9:16`. Fix card/text sizing & overflow on `360px` to `390px` screens. |
| **4** | **Photo Glass & Topo Shard** | `lib/widgets/share/photo_glass_cards.dart` | **Cards 01, 02, 03** (`7915119495940639354`, `4e36334cee174834858424800e50a2e3`, `cf875846d06d41a3a0c188ccfabaecdf`) | Upgrade `_FrostedSurface` from flat milky blur to **multi-layer optical glassmorphism** (directional sheen gradient + specular rim + diagonal corner highlight). Set **Topo Shard** outer plate & metric tiles to strict **90-degree corners (`BorderRadius.zero`)**. |

---

## 1. Pre-Run Ignition: Suspended Glass Deck (Card 07)

**Design Review Rationale (Mas Zay Feedback):**
The previous ultra-minimal Pre-Run UI looked too abstract at first glance, making first-time users unsure what category of app Stradio is. Adding the striding runner cutout flush to the top edge alongside `SPM TARGET` and `PACE SYNC` immediately communicates "running app" in under 0.5 seconds while preserving the calm Warm Ivory (`#F5F0E8`) daylight aesthetic.

### Target File
- `lib/screens/stradio/pre_run_ignition_screen.dart`

### Implementation Checklist
1. **Top Hero Monolith Zone (Top 46% of Viewport):**
   - **Runner's Legs Cutout (Strict Top-Edge Bleed):** Pin the runner image **completely flush to the absolute top edge of the screen (`top: 0`, zero top gap)** behind the translucent system status bar (`SafeArea(top: false)` for the hero layer). Fade the bottom edge softly into Warm Ivory (`#F5F0E8`) via a vertical gradient vignette.
   - **Ambient Orbital Cadence Dial (Behind Runner):** Centered `288px` (`w-72`) subtle pulse ring with `STRIDE NORTH 0°` (top) and `180° PHASE` (bottom) micro-labels, plus a `224px` (`w-56`) slowly rotating dashed ring with Sonic Coral and Twilight Plum phase dots.
   - **Live Phase Coordinate Pill:** Floating bottom-right of hero zone (`100 Hz IMU • 168 Stride` with pulsing Sonic Coral dot).
   - **Floating Overlay Header (Top Safe Area):** Left `Stradio` brand lockup inside a frosted Warm Ivory halo pill; right two `36px` frosted circular action buttons (`graphic_eq` Equalizer/Settings and `tune` Calibration).
2. **Suspended Curved Liquid Glass Deck (Lower 54%, `BorderRadius.circular(32)`):**
   - **Sound Engine Selection Capsule:** Displays active sound pack (`Midnight Pulse`, `98% Match`, `Sound Engine • Adaptive Synth 28ms`), paired with:
     - An interactive **`Audition`** pill button (3-bar animated EQ that turns Sonic Coral and shows target BPM during the 10-second preview).
     - An expand chevron opening an upward frosted popover to select between available sound packs (`Midnight Pulse`, `Velvet Stride`, `Cartoon Squeak`, etc.).
   - **Split Hero Metric Row:** Two-column `46px` Sora Bold tabular readouts separated by a hairline vertical divider:
     - Left: `SPM TARGET` (`172 spm`)
     - Right: `PACE SYNC` (`5:12 /km`)
   - **Micro Telemetry Strip:** Bottom row inside the glass tray showing `142ms Impulse Damp` (Twilight Plum dot) and `99.4% Harmonic Lock` (Sonic Coral dot).
3. **Bottom Thumb Anchor:**
   - Single `56dp` Deep Midnight Obsidian (`#191923`) **`Swipe to start`** pill with left `44dp` circular alabaster slider (`chevron_right`) and right pulsing Sonic Coral sensor live ring.
4. **First-Launch Modal:**
   - Keep `EarphonesRecommendationModal` (`has_seen_audio_recommendation`) wired on cold start over the blurred Pre-Run canvas.

---

## 2. Active Run: Cadence Monolith + Step-Triggered Wave (Card 10)

**Design Review Rationale (Mas Zay Feedback):**
The acoustic wave must **only activate when a real footstep is detected** so the runner gets immediate, unmistakable visual confirmation that the `100 Hz` motion sensor is actively working. Replacing `Stride (m)` with **`Steps`** lets the runner immediately see how many steps they have taken during the run.

### Target Files
- `lib/screens/stradio/active_run_screen.dart`
- `lib/widgets/sonic_ribbon_painter.dart`

### Implementation Checklist
1. **Minimal Active Header:**
   - Replace the old dual-tone stacked `Stride / Rhythm` header with a clean single-row bar: `Stradio` brand icon + wordmark on the left, and a recessed live duration pill (`● LIVE • 32:14` with pulsing Sonic Coral dot) on the right.
2. **Cadence Monolith Hero Focus:**
   - Center a giant `72px` to `76px` Sora Medium tabular-numeral readout (`164 SPM`) with whisper subtitle `CADENCE MONOLITH` directly beneath the header.
3. **Concentric Acoustic Compass Dial (Strictly Centered):**
   - Outer `256px` orbit ring with cardinal marks (`0° / N`, `90°`, `180° / S`, `270°`) and ultra-fine crosshairs.
   - Middle `208px` slowly rotating dashed ring with Sonic Coral & Twilight Plum cadence notches.
   - Inner `144px` frosted optical core ring housing the central Sonic Coral strike node.
   - **Alignment Requirement:** All three rings must be concentrically aligned (`Stack(alignment: Alignment.center)`) right on the crosshair center.
4. **Step-Reactive Acoustic Wave Physics (`SonicRibbonPainter`):**
   - **Idle State (Zero Steps Detected):** Do **not** animate high-amplitude waves continuously. Rest all three ribbons (Sonic Coral primary, Rhythm Violet harmonic, fine dashed secondary) as a calm, nearly flat baseline (`~1.5px` amplitude, `35%` opacity), with the center strike node still.
   - **Step Detected (`<30 ms` Attack):** On every confirmed step from `StepDetector`, spike `waveEnergy = 1.0`:
     - Wave amplitude surges smoothly up to `36px` (`100%` opacity) with dynamic phase flow.
     - Central Sonic Coral strike node scales (`1.0 -> 1.55`) and emits an expanding shockwave ring (`0.55s` fade-out).
     - `Steps` counter live-increments (`+1`).
   - **Decay When Stationary:** Decay `waveEnergy` smoothly (`~850 ms` falloff) back to the calm flat baseline whenever stepping pauses.
5. **Frosted 3-Metric Running Bar (Replaces 2 Borderless Metrics):**
   - Single `rounded-3xl` frosted glass capsule (`bg-surface-glass`, `1px` white rim) displaying 3 tabular metrics separated by subtle micro dot dividers:
     1. **Distance** (`5.42 km`)
     2. **Pace** (`5:08 /km`)
     3. **Steps** (`4,820` cumulative step count; **replaces `Stride 1.18 m`**)
6. **Single `Hold to finish` (`1.5s`) Obsidian Pill (Replaces 3-Button Bottom Dock):**
   - Replace the old 3-button dock (`Sound` / `Pause` / `Stop`) with a single `56dp` Deep Midnight Obsidian pill:
     - Left `44dp` circular alabaster stop badge (`stop` icon in Deep Coral `#A93726`).
     - Centered label: `Hold to finish` -> updates to `Finishing...` while held -> `Run Saved ✓` on completion.
     - Right subtle `1.5s` duration hint.
     - **Gesture:** Pressing and holding sweeps a horizontal Sonic Coral progress fill from `0%` to `100%` across the pill over `1500 ms` with light haptic ticks every `300 ms`. Releasing early resets fill to `0%` without interrupting audio.

---

## 3. Share Run Rhythm Modal: Streamlined Actions & Proportion Fix (Card 12)

**User Feedback:**
Remove all Quick Share icons (`Stories`, `Save`, `Copy Link`, `Messages` / `Copy Text`) so only **`Share Rhythm Card`** and **`Instagram story export 9:16`** remain. Fix card sizing and proportions so text and buttons never overflow on compact phones.

### Target File
- `lib/widgets/share/share_run_rhythm_sheet.dart`

### Implementation Checklist
1. **Remove the Entire Quick Share Row:**
   - Delete the `Quick Share` section header and its icon button grid (`Stories`, `Save`, `Copy Link` / `Copy Text`, `Messages`).
2. **Keep Only 2 Primary Full-Width Pills:**
   - **`Share Rhythm Card`** (Solid Midnight `#191923` pill, `48dp` to `52dp` height):
     - Renders the currently selected Rhythm Card (`Aura Wave`, `Sonic Dial`, or `Minimal Stride`) as a high-res PNG and invokes the native OS share sheet (`SharePlus.instance.share(ShareParams(files: [XFile(path)], text: caption))`) with **both the image AND the pre-composed run summary message/caption bundled together** so sharing to WhatsApp, Telegram, or Messages includes the text automatically in one tap.
   - **`Instagram story export 9:16`** (Light Alabaster pill with subtle border):
     - Opens `ShareStudioScreen` directly in 9:16 Story Export mode (`Transparent Sticker` / `Photo Glass`).
3. **Fix Sizing, Proportions & Text Overflow:**
   - Ensure the bottom sheet strictly respects viewport width (`double.infinity` bounded by screen width, zero horizontal overflow) with balanced `20dp` horizontal padding (`EdgeInsets.symmetric(horizontal: 20)`).
   - Size carousel cards proportionally (`~244px` to `252px` width on `390px` screens, scaling cleanly down on `360px` devices via `LayoutBuilder` or `FractionallySizedBox`) so the active card sits cleanly framed with a subtle peek of the next card and zero clipped typography or overflowing footers.
   - Hide scrollbars on the horizontal card carousel and template tab chips.

---

## 4. Photo Glass: True Optical Glassmorphism & Topo Shard 90° Edges (Cards 01, 02, 03)

**User Feedback:**
Photo Glass currently feels like a flat milky blur box rather than true glassmorphism, and **Topo Shard** corners should be sharp **90-degree** edges.

### Target File
- `lib/widgets/share/photo_glass_cards.dart`

### Implementation Checklist
1. **Upgrade `_FrostedSurface` (Lines 85 to 117) to Multi-Layer Optical Glassmorphism:**
   - **Replace Flat `color: fill` with a 4-Stop Directional Glass `LinearGradient`:**
     - `Alignment.topLeft` -> `Alignment.bottomRight`
     - Stops: `[0.0, 0.42, 0.72, 1.0]`
     - Colors: tint/white at alpha `0.44` -> `0.16` -> `0.06` -> `0.26` (modulated slightly by the photo's sampled dynamic tint color so the underlying photograph glows vividly through the pane instead of getting buried under `70%` to `80%` opaque white).
   - **Backdrop Refraction:** Keep `BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16))` (optionally combine with a subtle `ColorFilter` saturation boost if supported cleanly without perf regression).
   - **Diagonal Specular Corner Reflection Layer:** Stack a `IgnorePointer` overlay inside the clipped surface with a `LinearGradient` from `Alignment.topLeft` to `Alignment(0.4, 0.5)` (`Colors.white.withValues(alpha: 0.44)` -> `0.10` -> `0.0`) so daylight visibly sweeps across the glass surface.
   - **Crisp Specular Rim & Deep Floating Shadow:**
     - Outer border: `1.25px` `Colors.white.withValues(alpha: 0.62)`.
     - Inner top-left catchlight highlight (subtle 1px top/left bright rim).
     - Ambient drop shadow: `BoxShadow(color: Color(0xFF080C16).withValues(alpha: 0.42), blurRadius: 36, offset: Offset(0, 18))` so the glass card floats with physical depth above the photo.
   - **Inner Telemetry Sub-Tiles:** Update the 3 metric pods (`Distance`, `Duration`, `Pace`) from opaque `0.80` white to translucent crystal glass (`LinearGradient` from `0.46` -> `0.20` white with `1.0px` `0.62` white rim) while maintaining crisp `#191923` Midnight text legibility.
   - **Accessibility Fallback:** Keep `highContrast` / reduced-transparency mode rendering as solid `#FAF7F2` with `1px` `#DFD9CE` border.
2. **Topo Shard Strict 90-Degree Corners (`_TopoShardGlassCard`, Line 514):**
   - Change `borderRadius: BorderRadius.circular(14)` to **`BorderRadius.zero`** on the outer `_FrostedSurface` glass plate.
   - Change the 3 inner metric tiles (`DST`, `TIME`, `TEMPO`) to **`BorderRadius.zero`** as well (sharp `90°` architectural right angles, zero chamfer or rounding).

---

## 5. Already Aligned (No Rework Needed)
- **First-Launch Earphone Immersion Modal** (`lib/widgets/earphones_recommendation_modal.dart`): Already matches Card 08 (`d2a348197ade4542b9cb973d00d90655`).
- **Transparent Sticker Suite** (`lib/widgets/share/transparent_sticker_cards.dart`): Already cleanly limited to the 3 canonical templates (`Aura Wave`, `Sonic Dial`, `Minimal Stride`); the 3 deprecated pod/HUD/pebble templates are already removed.
- **Post-Run Cadence Summary** (`lib/screens/stradio/post_run_summary_screen.dart`): Already matches Card 11 (`a4b5c2ac8b8c45baa05157d07f68479f`).
