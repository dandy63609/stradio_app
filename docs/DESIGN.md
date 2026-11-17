---
name: Stradio
description: Real-time movement-to-music running companion. Warm Ivory daylight minimalism, whisper-quiet sentence-case typography, and WebGL/GLSL Liquid Glass optical refraction.
colors:
  warm-ivory: '#F5F0E8'
  surface-base: '#F5F0E8'
  surface-recessed: '#EAE4DC'
  surface-card: '#FAF7F2'
  surface-glass: 'rgba(250, 247, 242, 0.72)'
  surface-glass-rim: 'rgba(255, 255, 255, 0.65)'
  midnight: '#191923'
  sonic-coral: '#FF765F'
  rhythm-violet: '#A995DB'
  twilight-plum: '#46509E'
  border-subtle: '#DFD9CE'
  border-focus: '#46509E'
  text-primary: '#191923'
  text-secondary: '#625D72'
  text-muted: '#625D72'
  text-on-dark: '#F5F0E8'
  text-plum: '#46509E'
  text-accent-deep: '#B53D28'
  glow-coral-soft: 'rgba(255, 118, 95, 0.14)'
  glow-violet-soft: 'rgba(169, 149, 219, 0.14)'
typography:
  title-primary:
    fontFamily: 'Sora'
    fontWeight: 600
    fontSize: '28px'
    lineHeight: '32px'
    letterSpacing: '-0.02em'
  title-muted:
    fontFamily: 'Sora'
    fontWeight: 500
    fontSize: '28px'
    lineHeight: '32px'
    letterSpacing: '-0.02em'
  metric-hero:
    fontFamily: 'Sora'
    fontWeight: 500
    fontSize: '44px'
    lineHeight: '48px'
    letterSpacing: '-0.03em'
  metric-value:
    fontFamily: 'Sora'
    fontWeight: 500
    fontSize: '28px'
    lineHeight: '32px'
    letterSpacing: '-0.02em'
  metric-label:
    fontFamily: 'Inter'
    fontWeight: 500
    fontSize: '12px'
    lineHeight: '16px'
    letterSpacing: '0.00em'
  micro-cap:
    fontFamily: 'Inter'
    fontWeight: 600
    fontSize: '11px'
    lineHeight: '14px'
    letterSpacing: '0.04em'
  body:
    fontFamily: 'Inter'
    fontWeight: 400
    fontSize: '14px'
    lineHeight: '20px'
    letterSpacing: '0.00em'
  button-label:
    fontFamily: 'Inter'
    fontWeight: 500
    fontSize: '15px'
    lineHeight: '20px'
    letterSpacing: '0.00em'
  pill-badge:
    fontFamily: 'Inter'
    fontWeight: 500
    fontSize: '13px'
    lineHeight: '16px'
    letterSpacing: '0.00em'
rounded:
  sm: '4px'
  md: '12px'
  lg: '20px'
  xl: '28px'
  full: '9999px'
spacing:
  '1': '4px'
  '2': '8px'
  '3': '12px'
  '4': '16px'
  '5': '20px'
  '6': '24px'
  '8': '32px'
  '10': '40px'
  '12': '48px'
  '16': '64px'
components:
  button-primary:
    backgroundColor: '{colors.midnight}'
    textColor: '{colors.text-on-dark}'
    borderRadius: '{rounded.full}'
    padding: '{spacing.4} {spacing.6}'
    typography: '{typography.button-label}'
  button-icon-circle:
    backgroundColor: '{colors.surface-card}'
    textColor: '{colors.text-primary}'
    borderColor: '{colors.border-subtle}'
    borderRadius: '{rounded.full}'
    size: '48px'
  liquid-glass-shader:
    sourceRepo: 'https://github.com/dashersw/liquid-glass-js'
    flutterShaderAsset: 'shaders/liquid_glass.frag'
    edgeIntensity: '0.032'
    rimIntensity: '0.095'
    baseIntensity: '0.015'
    edgeDistance: '0.15'
    rimDistance: '0.80'
    baseDistance: '0.12'
    cornerBoost: '0.045'
    rippleEffect: '0.08'
    blurRadius: '7.0'
    tintOpacity: '0.22'
  liquid-glass-tray:
    shapeType: 'rounded'
    borderRadius: '24px'
    backgroundColor: '{colors.surface-glass}'
    rimBorder: '{colors.surface-glass-rim}'
    shader: '{components.liquid-glass-shader}'
  liquid-glass-lens:
    shapeType: 'circle'
    size: '136px'
    borderRadius: '{rounded.full}'
    backgroundColor: '{colors.surface-glass}'
    rimBorder: '{colors.surface-glass-rim}'
    shader: '{components.liquid-glass-shader}'
  liquid-glass-dock:
    shapeType: 'pill'
    borderRadius: '{rounded.full}'
    backgroundColor: '{colors.surface-glass}'
    rimBorder: '{colors.surface-glass-rim}'
    shader: '{components.liquid-glass-shader}'
  visualizer-dial:
    surfaceColor: '{colors.surface-recessed}'
    ringColor: '{colors.border-subtle}'
    activeCoral: '{colors.sonic-coral}'
    activeViolet: '{colors.rhythm-violet}'
    borderRadius: '{rounded.full}'
  visualizer-stems:
    barWidth: '3.5px'
    barSpacing: '14px'
    baseColor: '{colors.border-subtle}'
    activeCoral: '{colors.sonic-coral}'
    activeViolet: '{colors.rhythm-violet}'
    activePlum: '{colors.twilight-plum}'
    borderRadius: '{rounded.full}'
  metric-pair:
    backgroundColor: 'transparent'
    labelColor: '{colors.text-secondary}'
    valueColor: '{colors.text-primary}'
    padding: '{spacing.2} 0'
  frosted-pod:
    backgroundColor: 'rgba(255, 255, 255, 0.45)'
    borderColor: 'rgba(255, 255, 255, 0.65)'
    borderRadius: '{rounded.xl}'
    padding: '{spacing.4}'
    backdropFilter: 'blur(20px)'
---

# STRADIO: Visual Design Specification (DESIGN.md)

> **Design Read:** Reading this as a real-time movement-to-music mobile companion for recreational runners, in a calm daylight sensor-instrument visual language with precision Liquid Glass optical lenses, dial **ENERGY 1 / RHYTHM 2 / MOTION 2**.
> **Visual Reference & Key-Screen Mockup:** [`mockups/daylight-minimal-screens.html`](mockups/daylight-minimal-screens.html) ([`mockups/daylight-minimal-screens.png`](mockups/daylight-minimal-screens.png)) & Flutter GLSL Shader [`../shaders/liquid_glass.frag`](../shaders/liquid_glass.frag). `DESIGN.md` and `EXPERIENCE.md` win on any conflict with a mockup.

## Brand & Style

STRADIO bridges human biomechanics with live sound synthesis: **Stride + Audio = STRADIO**. The visual aesthetic rejects both the cluttered, multi-table spreadsheet feel of endurance GPS trackers and the loud, neon-drenched clichés of dark-mode fitness apps.

Instead, STRADIO adopts **Daylight Instrument Minimalism**, combining a serene paper-matte canvas with precision **Liquid Glass optical lenses** (`dashersw/liquid-glass-js` shader architecture):
- **Warm Daylight Canvas:** A serene **Warm Ivory** (`{colors.warm-ivory}` `#F5F0E8`) background paired with soft recessed stone (`{colors.surface-recessed}` `#EAE4DC`) and elevated alabaster cards (`{colors.surface-card}` `#FAF7F2`). This eliminates harsh `#FFFFFF` glare in outdoor sunlight while keeping the interface airy, grounded, and calm.
- **Tactile Liquid Glass Lenses (Dose Cap: 1 to 2 per screen):** Using the signed-distance-field (SDF) refraction shader from `dashersw/liquid-glass-js` (ported to Flutter `shaders/liquid_glass.frag`), select foreground lenses (`liquid-glass-tray`, `liquid-glass-lens`, `liquid-glass-dock`) physically bend and refract the animated Sonic Coral and Rhythm Violet soundwaves passing underneath their curved edges.
- **Whisper-Minimal Copy:** Text is stripped to the absolute minimum required for instant comprehension at a running glance. Every label is 1 to 3 words in natural sentence case, using light-to-medium typographic weights (`400` to `600`) rather than heavy shouting all-caps.
- **Anchored Midnight Controls:** Deep **Midnight** (`{colors.midnight}` `#191923`) serves as the high-contrast ink (`15.37:1` against Warm Ivory) and anchors the bottom thumb zone as a solid, tactile pill (`Swipe to start`, `Stride Rhythm`).

## Colors

The light-mode palette rebalances the official STRADIO Brand Identity System (`Stradio_brand_identity_system_a65eef14_2K.jpg`) so that **Warm Ivory** leads as the 65% primary canvas, **Midnight** anchors structure and typography, and the sonic hues act as precision instruments refracted through Liquid Glass:

- **Warm Ivory (`#F5F0E8`)** (`{colors.warm-ivory}` / `{colors.surface-base}`):
  - *Purpose:* Primary screen background canvas across all surfaces. Prevents the clinical sterility of pure white while providing effortless outdoor readability.
- **Surface Recessed (`#EAE4DC`)** (`{colors.surface-recessed}`):
  - *Purpose:* Subtle tonal well used for the outer `256px` circular visualizer dial and summary card well, creating depth without drop shadows.
- **Surface Card (`#FAF7F2`)** (`{colors.surface-card}`):
  - *Purpose:* Solid opaque card surface for standard non-glass containers, separated from the base canvas by a `1px` `{colors.border-subtle}` (`#DFD9CE`) stroke.
- **Liquid Glass Tint & Specular Rim (`rgba(250, 247, 242, 0.72)` / `rgba(255, 255, 255, 0.65)`)** (`{colors.surface-glass}` / `{colors.surface-glass-rim}`):
  - *Purpose:* Warm ivory tint (`tintOpacity: 0.22`) and specular top-edge catchlight applied by the Liquid Glass shader over refracted background waveforms.
- **Midnight (`#191923`)** (`{colors.midnight}` / `{colors.text-primary}`):
  - *Purpose:* Primary typography, primary numeric readouts, and the solid floating bottom action pill. Delivers a `15.37:1` contrast ratio against `{colors.warm-ivory}` (WCAG AAA).
- **Text Secondary & Muted (`#625D72`)** (`{colors.text-secondary}` / `{colors.text-muted}`):
  - *Purpose:* Used for the second line of dual-tone stacked titles (`Stride / Rhythm`), metric labels (`Pace sync`, `Step latency`), and axis timestamps. Verified at `5.56:1` against `{colors.warm-ivory}`, `5.90:1` against `{colors.surface-card}`, and `5.00:1` against `{colors.surface-recessed}` (passing WCAG AA `4.5:1` for all text sizes).
- **Sonic Coral (`#FF765F`)** (`{colors.sonic-coral}`):
  - *Purpose:* Kinetic footstep strike indicator inside the visualizer, active state dots (`5px`), and progress ring fill during the hold-to-end gesture. Never used for small body text on light backgrounds (`2.31:1`); when a coral text accent is needed on light surfaces, use **Deep Coral (`#B53D28`)** (`{colors.text-accent-deep}`, verified at `5.05:1` WCAG AA).
- **Rhythm Violet (`#A995DB`)** & **Twilight Plum (`#46509E`)** (`{colors.rhythm-violet}` / `{colors.twilight-plum}`):
  - *Purpose:* Harmonic cadence bars, refracted background soundwaves, and focus rings (`#46509E` delivers `6.38:1` against `#F5F0E8`).

## Typography

STRADIO pairs **Sora** and **Inter** with deliberate restraint, replacing heavy display weights and wide-tracked uppercase labels with calm, airy hierarchy:

1. **Sora (Stacked Headers & Tabular Numerals):**
   - *Reason:* Geometric open counters keep numerals legible while jogging, and medium weights (`500` to `600`) preserve a calm, hardware-instrument aesthetic.
   - *Dual-Tone Title Motif:* Every screen header stacks two words vertically in `28px / 32px` Sora (`{typography.title-primary}` in `#191923` SemiBold `600` on line 1; `{typography.title-muted}` in `#625D72` Medium `500` on line 2), such as **Stride / Rhythm** or **Cadence / Flow**.
   - *Tabular Numerals:* All numeric readouts enforce `font-variant-numeric: tabular-nums` so live step and cadence updates never jitter horizontally.
2. **Inter (Whisper Microcopy & Controls):**
   - *Reason:* Neutral grotesque with tall x-height keeps `12px` to `15px` sentence-case labels crisp at arm's length, including over Liquid Glass surfaces.
   - *Minimal Copy Rule:* Labels use natural sentence case (`Step latency`, `Pace sync`, `Swipe to start`, `New run`) with `0.00em` tracking. Uppercase (`{typography.micro-cap}`) is restricted to single-word card category tags (`RHYTHM`, `STILLNESS`) at `11px`.

### Typographic Ramp

| Role | Font | Weight | Size / Line Height | Letter Spacing | Case & Purpose |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `title-primary` | Sora | 600 (SemiBold) | 28px / 32px | -0.02em | Line 1 of stacked screen header (`#191923`) |
| `title-muted` | Sora | 500 (Medium) | 28px / 32px | -0.02em | Line 2 of stacked screen header (`#625D72`) |
| `metric-hero` | Sora | 500 (Medium) | 44px / 48px | -0.03em | Primary summary or focal numeric value (`tnum`) |
| `metric-value` | Sora | 500 (Medium) | 28px / 32px | -0.02em | Live in-run metrics (`96%`, `28 ms`, `156 spm`) |
| `metric-label` | Inter | 500 (Medium) | 12px / 16px | 0.00em | Sentence-case metric labels (`Pace sync`, `Step latency`) |
| `micro-cap` | Inter | 600 (SemiBold) | 11px / 14px | +0.04em | Single-word card corner tag (`RHYTHM`, `STILLNESS`) |
| `body` | Inter | 400 (Regular) | 14px / 20px | 0.00em | Short 1-line status note (`Motion sensor active and synced`) |
| `button-label` | Inter | 500 (Medium) | 15px / 20px | 0.00em | Sentence-case pill action (`Swipe to start`) |
| `pill-badge` | Inter | 500 (Medium) | 13px / 16px | 0.00em | Active dock pill label (`Stride Rhythm`) |

## Layout & Spacing

STRADIO uses an 8-point spatial scale with a 4px half-step (`4 / 8 / 12 / 16 / 20 / 24 / 32 / 40 / 48 / 64 px`), designed so at least **60% of the viewport remains open Warm Ivory canvas**:

- **Screen Padding:** `24px` (`{spacing.6}`) horizontal margin on compact phones (`<600px`), expanding to a centered `480px` max-width column with `32px` gutters on tablets and foldables (`600px` to `1024px`).
- **Top Bar & Stacked Title Zone (Top 18%):** Small centered brand mark (`Stradio`) on Surface 1, or the top-left dual-tone stacked title (`Stride / Rhythm`) balanced by a single `48px` circular sensor button on the right.
- **Central Instrument Zone (Middle 52%):** Dedicated to a single focal visualizer:
  - *Surface 1 (Pre-Run):* Central 100 Hz IMU waveform profile overlapped at its base by the `liquid-glass-tray` (`type: 'rounded'`, `borderRadius: 24px`) holding the `Pulse` and `Squeak` cards.
  - *Surface 2 (Active Run):* A `256px` recessed circular dial (`{colors.surface-recessed}`) with a `136px` central `liquid-glass-lens` (`type: 'circle'`) that refracts the live sonic waveform passing underneath.
  - *Surface 3 (Summary):* Wide-spaced `3.5px` vertical pill stems (`14px` gap) showing cadence rhythm over time with `min. 118 spm` and `max. 164 spm` whispered below.
- **Borderless Metric Strip (Lower-Middle 15%):** Two clean metric pairs aligned left and right directly on the canvas (`Pace sync` on the left, `Step latency` on the right), eliminating boxy card grids during active running.
- **Thumb-Zone Dock (Bottom 15%):** Solid `{colors.midnight}` pill CTA on Surface 1, or the `liquid-glass-dock` capsule (`type: 'pill'`) on Surface 2 housing the `48px` circular controls and solid Midnight status pill.

## Elevation & Depth

Depth is achieved through **Daylight Tonal Layering + Optical Liquid Glass Refraction** (strictly capped at 1 to 2 glass elements per screen per `R-10`, with zero generic floating drop shadows):

1. **Layer 0 (Base Canvas):** Flat `{colors.warm-ivory}` (`#F5F0E8`).
2. **Layer 1 (Recessed Instrument Well & Sonic Underlay):** Flat `{colors.surface-recessed}` (`#EAE4DC`) and the animated Sonic Coral / Twilight Plum waveform curves.
3. **Layer 2 (Liquid Glass Optical Layer, 1 to 2 Elements Max per Screen):**
   - Powered by `dashersw/liquid-glass-js` in web mockups and `shaders/liquid_glass.frag` (`FragmentProgram` + `BackdropFilter`) in Flutter.
   - Uses shape-aware SDF surface normals (`roundedRectDistance`, `circleDistance`, `pillDistance`) to refract background pixels inward along curved edges (`edgeIntensity: 0.032`, `rimIntensity: 0.095`, `cornerBoost: 0.045`, `rippleEffect: 0.08`, `blurRadius: 7.0`, `tintOpacity: 0.22`).
   - **Accessibility Fallback:** Under `prefers-reduced-transparency: reduce` (or low-end GPU fallback), Liquid Glass disables refraction/blur and renders as solid `{colors.surface-card}` (`#FAF7F2`) with a `1px` `{colors.border-subtle}` (`#DFD9CE`) border.
4. **Layer 3 (Midnight Anchor Pill):** Solid `{colors.midnight}` (`#191923`) pill dock at the bottom of the viewport, creating crisp figure-ground separation.

## Shapes

The three shape primitives of `dashersw/liquid-glass-js` map 1:1 to STRADIO's component roles:

- **`type: 'rounded'` (`{rounded.xl}` / `24px`):** Used for the Pre-Run `liquid-glass-tray` (`roundedRectDistance` SDF normal with `cornerBoost: 0.045`).
- **`type: 'circle'` (`{rounded.full}` / `50%` square):** Used for the Active Run central `liquid-glass-lens` (`136px` diameter) and the Summary `Sync` orb lens (`circleDistance` radial normal).
- **`type: 'pill'` (`{rounded.full}` / capsule):** Used for the Active Run bottom `liquid-glass-dock` cradle (`pillDistance` horizontal capsule axis normal) and solid Midnight action pills.

## Components

### 1. Liquid Glass Sound-Pack Tray (`liquid-glass-tray` on Surface 1)
- **Purpose:** Overlaps the lower edge of the Pre-Run sonic waveform hero so the runner sees the live audio waves refracting through the tray before starting (`R-10`: sole glass element on Surface 1).
- **Shader Configuration (`dashersw/liquid-glass-js`):** `type: 'rounded'`, `borderRadius: 24`, `tintOpacity: 0.22`, `edgeIntensity: 0.032`, `rimIntensity: 0.095`, `cornerBoost: 0.045`.
- **Nested Children:** Houses the two interactive sound-pack cards (`Pulse 98%` and `Squeak 94%`) with high-contrast `#191923` and `#625D72` typography (`>= 5.00:1` WCAG AA).

### 2. Primary Ignition Pill (`button-primary` on Surface 1)
- **Purpose:** Provides an unmistakable, high-contrast start control (`Swipe to start`) in the bottom thumb zone.
- **Visuals:** Solid `{colors.midnight}` (`#191923`) pill, `56px` height, sentence-case `{typography.button-label}` in `{colors.text-on-dark}` (`#F5F0E8`), flanked by a `38px` subtle inner circle icon (`→`) on the left and a ring indicator on the right.

### 3. Circular Acoustic Dial with Liquid Glass Core Lens (`visualizer-dial` + `liquid-glass-lens` on Surface 2)
- **Purpose:** Translates real-time step detection (`<30 ms`) into an optical refraction pulse at the center of Surface 2 (`R-10`: glass element 1 of 2 on Surface 2).
- **Anatomy:** Outer `256px` circle in `{colors.surface-recessed}` (`#EAE4DC`) with four cardinal dot markers (`kick •`, `stem •`, `bass •`, `sync •`). Inside sits a `136px` `liquid-glass-lens` (`type: 'circle'`, `warp: true`) positioned directly over the animated Sonic Coral / Twilight Plum ribbon waves.
- **Footstep Refraction Pulse:** On every confirmed step, `u_rippleEffect` surges from `0.08` to `0.24` and `u_edgeIntensity` surges from `0.032` to `0.065` for `180 ms`, causing the liquid glass lens to physically ripple and magnify the waveform on foot impact.

### 4. Liquid Glass Bottom Dock Cradle (`liquid-glass-dock` on Surface 2)
- **Purpose:** Floating capsule cradle in the bottom thumb arc (`R-10`: glass element 2 of 2 on Surface 2).
- **Shader Configuration:** `type: 'pill'`, `borderRadius: 30`, `tintOpacity: 0.22`, sampling the warm ivory and subtle sonic bloom behind the dock.
- **Nested Controls:**
  - Left `48px` circular button: Hot-swaps Sound Pack (`Midnight Pulse` vs `Cartoon Squeak`).
  - Center solid `{colors.midnight}` pill: Displays `Stride Rhythm` with a `6px` `{colors.sonic-coral}` status dot.
  - Right `48px` circular Hold-to-End button (`■`): Holding for `1.5 seconds` fills its circular border in `{colors.sonic-coral}` before ending the session.

### 5. Minimal Cadence Stem Chart & Sync Lens (`visualizer-stems` on Surface 3)
- **Purpose:** Answers "How steady was my running rhythm across the session?" on Surface 3 without spreadsheet tables.
- **Anatomy:** 12 vertical `3.5px` pill bars spaced `14px` apart across `{colors.warm-ivory}`. Below the chart, the right summary card houses a `96px` circular `liquid-glass-lens` (`Sync`) refracting a soft coral-violet harmonic gradient (`R-10`: sole glass element on Surface 3).

### 6. Borderless Metric Pair (`metric-pair`)
- **Purpose:** Surfaces the two numbers a runner checks mid-stride (`Pace sync` and `Step latency`) directly on the flat `{colors.warm-ivory}` canvas with zero container noise.

### 7. Graphic Ribbon Wave System (Brand Graphic Language)
- **Purpose:** Supplies the high-contrast multi-layered soundwave curves (`assets/design/stradio_ribbon_vector.svg`, `ribbon_tight_duo.png`) that pass behind the Liquid Glass lenses so the SDF edge refraction has rich chromatic contours to bend.

### 8. Shareable Running Result 9:16 Story Card Suite (`story_06` to `story_14` for Instagram Story Export)
- **Purpose:** Lets the runner switch between **Transparent Sticker / Liquid Glass** and **Photo Glass** in the top 2-option navbar pill (`Transparent Sticker | Photo Glass`), plus toggle card themes in the sub-navbar below.
- **Transparent Sticker & Liquid Glass Series:**
  - `story_06_aura_wave` (`16178858045008238785`): Frosted Alabaster sticker with 20 cadence stem bars and bottom acoustic ribbon wave.
  - `story_07_sonic_dial` (`0d39adbba7224c97bea508340ae544d0`): Smoked Obsidian sticker with circular Cadence Resonance Dial (`156 SPM`).
  - `story_08_minimal_stride` (`9d02cbeb94854c8c90764045553d5dce`): Smoked Obsidian sticker with horizontal Cadence Range Consistency bar (`154-160 Lock Zone`).
  - *Retired Designs (Removed per user directive):* `story_09_glass_pods` (Bento capsule cluster), `story_10_biometric_hud` (Dual dark-indigo HUD pods), and `story_11_fluid_pebble` (Asymmetric pebble) have been completely removed from the product design plan in favor of the canonical Google Stitch daylight liquid glass system.
- **Photo Glass Dynamic Tint Series (`story_12` to `story_14`):**
  - Selecting `Photo Glass` reveals the Photo Glass options (`Classic Wave | Orbital Nexus | Topo Shard`) and the bottom **Horizontal Photo Carousel Strip** (`None`, `+ Add` custom photo upload, active photo thumbnail with `#FF765F` ring, and preset backdrops).
  - `story_13_pg_orbital_nexus` (`4e36334cee174834858424800e50a2e3` Canonical Google Stitch Liquid Glass): Circular `316px` frosted radar orb with 3D elevation stride ribbons and `156 spm / Stride Resonance Lock` hub, interlocking seamlessly into the lower `344px` capsule dock housing the triple frosted telemetry pods (`5.42 km`, `32:40`, `5:12 /km`). Header brand mark and timestamps are cleanly excised per design review.
  - `story_12_pg_classic_wave` (`7915119495940639354` Forest Trail Dynamic Tint Glass): Rounded `36px` frosted card with 4 corner anchor dots, 20 cadence stems, and bottom dual-wave SVG ribbon.
  - `story_14_pg_topo_shard` (`cf875846d06d41a3a0c188ccfabaecdf` Topo Shard): Sharp-edged architectural frosted glass matrix card featuring a faceted topographic ridge graph and 3 metric tiles (`DST 5.42`, `TIME 32:40`, `TEMPO 5:12`).
  - Uploading any photo via `+ Add` (or choosing a preset) samples its RGB palette on a 2D Canvas (`--pg-r`, `--pg-g`, `--pg-b`) and dynamically tints all three Photo Glass themes (`Classic Wave`, `Orbital Nexus`, `Topo Shard`) while preserving `#191923` Midnight and `#4A4658` Slate typography (`>= 4.5:1` contrast) and `prefers-reduced-transparency: reduce` fallback.

### 9. First-Launch Audio Device Recommendation Modal (`modal_first_launch_audio` • Stitch ID `d2a348197ade4542b9cb973d00d90655`)
- **Purpose:** On cold start when a runner launches Stradio for the very first time, this focused dialog advises using earphones or headphones to experience the full immersion of the real-time adaptive soundscapes and step-synchronized feedback.
- **Trigger Lifecycle:**
  - Evaluated on app cold start against local key `has_seen_audio_recommendation` (default `false`).
  - Renders as a modal sheet centered above the Pre-Run Ignition canvas with a `30%` Midnight scrim (`bg-text-primary/30`) and `6px` backdrop blur (`backdrop-blur-[6px]`).
  - Dismissing via either button or the top-right close icon writes `has_seen_audio_recommendation = true` so returning runners land directly on Pre-Run Ignition without friction.
- **Card Anatomy & Layout Tokens:**
  - **Outer Container:** Floating dialog card with `max-w-[340px]`, `24px` corner radius (`rounded-3xl`), `95%` opacity Surface Card fill (`#FAF7F2/95`), crisp `1px` translucent white rim (`rgba(255, 255, 255, 0.90)`), and soft ambient elevation (`shadow-2xl`).
  - **Hero Illustration Header:** `176px` height (`h-44`) top banner framed by an inner warm recessed ivory background (`#EAE4DC`), showcasing a floating daylight studio render of minimalist over-ear headphones encircled by kinetic coral and violet acoustic soundwave ribbons.
  - **Top-Right Dismiss Button:** `28px` circular floating blur pill (`w-7 h-7 rounded-full bg-black/20 hover:bg-black/35 backdrop-blur-md`) with centered `15px` white `close` icon.
  - **Title & Badge:** `18px` Sora semibold (`font-title-stacked-primary`, `#191923`, line-height `1.35`) headline reading `"Use Earphones for Full Immersion"`, flanked by a soft coral status badge `"Recommended"` (`bg-secondary-container/15 text-text-accent-deep`, `#B53D28`, `11px` font weight `600`).
  - **Instructional Microcopy:** `13px` Inter regular (`font-body-subtle`, `#625D72`, line-height `1.5`) reading: `"For a better experience, please use your earphones or headphones so you can clearly hear adaptive tempo soundscapes and stride feedback."`
  - **Action Controls Cluster:** Horizontal two-action thumb dock:
    - *Primary Action:* `"I'm Wearing Earphones"` (`flex-1`, `44px` touch target, solid Midnight `#191923` capsule pill with `#F5F0E8` Warm Ivory text, font weight `500`, active scale `0.98`).
    - *Secondary Action:* `"Maybe later"` (`px-3 py-2.5`, rounded-full text action in `#625D72` with subtle hover wash, active scale `0.98`).
- **Accessibility & Contrast:**
  - Headline contrast against card surface: `14.8:1` (WCAG AAA compliant).
  - Body text contrast against card surface: `5.1:1` (WCAG AA compliant).
  - Primary button contrast: `15.37:1` (WCAG AAA compliant).
  - Accessible name applied to close button (`aria-label="Close modal"`).
  - Fully dismissible via Android hardware back gesture and keyboard `Esc`.

## Do's and Don'ts

| Do | Don't |
| :--- | :--- |
| **Do** maintain an open **Warm Ivory** (`#F5F0E8`) daylight canvas across at least 60% of every screen. | **Don't** revert to dark-mode backgrounds or pure `#FFFFFF` sterile white canvases. |
| **Do** cap **Liquid Glass** (`liquid-glass-shader`) at **1 to 2 focal elements per screen** (`R-10`). | **Don't** apply Liquid Glass to every card, header, button, and background simultaneously. |
| **Do** place animated soundwave contours behind Liquid Glass lenses so edge refraction (`u_edgeIntensity`) is visible and purposeful. | **Don't** place Liquid Glass over a flat monochrome background where refraction does nothing. |
| **Do** use natural sentence case (`Swipe to start`, `Step latency`, `Stride Rhythm`) and medium weights (`400` to `600`). | **Don't** shout with `800 ExtraBold` all-caps strings or wide-tracked uppercase button labels. |
| **Do** anchor primary thumb actions in solid **Midnight** (`#191923`) pills with `#F5F0E8` text (`15.37:1` contrast). | **Don't** place low-contrast grey text over translucent glass without verifying `>= 4.5:1` WCAG AA contrast. |
| **Do** respect `prefers-reduced-motion` and `prefers-reduced-transparency` by falling back to solid `#FAF7F2` surfaces. | **Don't** run continuous high-amplitude shader ripples when the runner is stationary. |

## Design Rationale Log (R-31)

- **Why Warm Ivory (`#F5F0E8`) + Recessed Stone (`#EAE4DC`)?** Pulls directly from STRADIO's official brand palette while achieving the calm, daylight hardware-instrument feel of the reference without harsh `#FFFFFF` glare.
- **Why integrate `dashersw/liquid-glass-js` (and `shaders/liquid_glass.frag`) on 1 to 2 lenses per screen?** Gives the acoustic waves a physical, optical lens that ripples on footstrike (`<30 ms`) and refracts the sound-pack tray edges (`image.png` Screen 1 & 2) while strictly obeying the `R-10` glass dose cap.
- **Why solid Midnight (`#191923`) for the bottom pill dock?** Mirrors the reference's grounded dark bottom pill (`Swipe to start`, `Stride Rhythm`) and guarantees `15.37:1` contrast in outdoor sunlight.
- **Why Sora `500`/`600` + Inter `400`/`500` in sentence case?** Eliminates loud fitness-app shouting so the typography feels quiet, precise, and effortless to scan in under a second.
- **Why a `256px` circular dial and `3.5px` wide-spaced stem bars?** Gives each screen a single sculptural focal point with generous whitespace instead of a generic dashboard card grid.
- **Why borderless metric pairs on the Active Run screen?** Reduces visual boxes so the runner's eye reads two numbers (`Pace sync` and `Step latency`) immediately below the dial.
